using System.Numerics;
using System.Runtime.InteropServices;
using Raylib_cs;

// ---------------------------------------------------------------------------
// Icosahedron Walker
// A first-person walk on the surface of a subdivided icosahedron. You always
// walk within the triangular face you're standing on; when you step past an
// edge, you get "unfolded" across that edge into the neighboring face (the
// same trick used for walking on any polyhedron) instead of guessing which
// face you're on from a ray through the center.
//
// Rendering is batched: the whole mesh is uploaded to the GPU once, as a
// handful of Mesh chunks, and drawn with a couple of DrawMesh calls per
// frame - not one draw call per triangle. That's what makes very high
// subdivision levels (millions of faces) renderable at all; the old
// per-triangle immediate-mode approach was the actual bottleneck, not the
// GPU or CPU raw power. Mesh generation also avoids per-face heap objects
// (Dictionary<K, List<int>> adjacency, duplicated per-face positions) in
// favor of flat arrays, since those blow up memory at tens of millions of
// faces.
// ---------------------------------------------------------------------------

const float DefaultRadius = 32f;   // reference radius at subdivision level 0; the actual world
                                    // radius grows with level (see ComputeScaledRadius) so that
                                    // individual face size stays constant across levels
const float MinRadius = 8f;
const float MaxRadius = 128f;
const float EyeHeight = 0.55f;     // how far above the face surface the camera floats
const float MoveSpeed = 6f;        // units per second
const float MouseSensitivity = 0.0035f;
const float UpSmoothing = 12f;     // camera-roll smoothing only, doesn't affect movement math
const float JumpSpeed = 9f;        // initial upward speed, in units/sec along the face normal
const float Gravity = 30f;         // units/sec^2, pulls back down along the face normal
// Every grid cell on a face is real geometry now: a triangular prism raised
// BlockHeight off the ground. Each face has a constant edge length of
// ~91.8m at human scale (EyeHeight = 1.5m real-world eyes), so 8 blocks per
// edge gives ~11.5m blocks.
const float BlockHeight = 1f;
// How many blocks stack vertically in a single column, chosen in the picker.
// Breaking targets whichever specific layer the crosshair lands on, so a
// column can end up with a floating block over a hole - see brokenLayers.
const int DefaultLayersPerColumn = 2;
const int MinLayersPerColumn = 1;
const int MaxLayersPerColumn = 8;
// Max height difference the player can step up between two blocks before
// movement is blocked - just over one block's height, so a single uniform
// step is always climbable. Only matters once block heights vary.
const float MaxStepHeight = 0f;
const float DefaultBlocksPerEdge = 8f;
const float MinBlocksPerEdge = 2f;
const float MaxBlocksPerEdge = 64f;
// Above this many blocks in a single planet chunk (~1.4M triangles), a
// chunk rebuild when crossing into a new region is likely to cause a
// visible hitch - flagged in red in the picker.
const int BlocksPerChunkWarnThreshold = 200_000;

const int DefaultSubdivisionLevels = 4;  // 20 * 4^levels faces; used when no CLI arg is given
const int MaxSubdivisionLevel = 11;      // 20 * 4^11 = ~84 million faces at the slider's top end (here be dragons)
const int WarnAtSubdivisionLevel = 7;    // levels at or above this will likely need a lot of RAM/time - flagged in red

// A planet "chunk" is one of the 20 base icosahedron faces. Only the chunk
// the player is standing in, plus its edge- and vertex-adjacent neighbours,
// have block geometry built and resident on the GPU at any time.
const int BaseFaceCount = 20;

// Assets/Textures/atlas.png is 3 square tiles laid out left to right:
// grass top, dirt side, bare ground - these are the u-offset (in atlas
// fractions) of each tile's left edge.
const float AtlasTileWidth = 1f / 3f;
const float AtlasTileTop = 0f * AtlasTileWidth;
const float AtlasTileSide = 1f * AtlasTileWidth;
const float AtlasTileBare = 2f * AtlasTileWidth;

// A block prism has 9 unique corners - 3 floor, plus the roof duplicated
// (3 for the top cap, 3 for the wall tops) so the cap and the walls can each
// carry their own vertex color - but is still used by only 7 triangles (top
// + 3 side walls x 2), so indexed geometry still cuts vertex data (and the
// work to build it) well below emitting each triangle's 3 corners
// separately. raylib's Mesh.Indices is 16-bit, so a single Mesh can only
// address up to 65535 vertices - that caps how many blocks fit in one Mesh
// chunk.
const int VerticesPerBlock = 9;
const int TrianglesPerBlockWallsOnly = 6;  // 3 side walls x 2 triangles each - top/bottom caps
                                            // are added on top of this per-instance when exposed
const int MaxVerticesPerMesh = 65535; // raylib Mesh.Indices is ushort
const int MaxBlocksPerMesh = MaxVerticesPerMesh / VerticesPerBlock;

// Optional: `dotnet run -- <levels>` skips the popup entirely for a quick start.
int? cliLevel = args.Length > 0 && int.TryParse(args[0], out int requested)
    ? Math.Clamp(requested, 0, MaxSubdivisionLevel)
    : null;

Raylib.InitWindow(1280, 720, "Icosahedron Walker");
Raylib.SetTargetFPS(60);
Rlgl.DisableBackfaceCulling(); // faces may be viewed from inside or outside

int subdivisionLevels;
float blocksPerEdgeF;
float radiusF;
int layersPerColumn;
if (cliLevel is int lvl)
{
    subdivisionLevels = lvl;
    blocksPerEdgeF = DefaultBlocksPerEdge;
    radiusF = DefaultRadius;
    layersPerColumn = DefaultLayersPerColumn;
}
else
{
    (subdivisionLevels, blocksPerEdgeF, layersPerColumn, radiusF) = ShowSubdivisionPicker(
        DefaultSubdivisionLevels, MaxSubdivisionLevel, WarnAtSubdivisionLevel,
        DefaultBlocksPerEdge, MinBlocksPerEdge, MaxBlocksPerEdge, BlocksPerChunkWarnThreshold,
        DefaultLayersPerColumn, MinLayersPerColumn, MaxLayersPerColumn,
        DefaultRadius, MinRadius, MaxRadius);
}
int blocksPerEdge = Math.Max(1, (int)MathF.Round(blocksPerEdgeF));

DrawLoadingScreen(subdivisionLevels);

float worldRadius = ComputeScaledRadius(radiusF, subdivisionLevels);
var (vertices, triangles, baseFaceOf) = BuildIcosahedronMesh(worldRadius, subdivisionLevels);
Face[] faces = BuildFaces(vertices, triangles, baseFaceOf);
List<int>[] trianglesByBaseFace = GroupTrianglesByBaseFace(faces);
int[][] baseFaceNeighbors = BuildBaseFaceNeighbors();
var (latticeCells, cellIndexLookup) = BuildLatticeCells(blocksPerEdge);

// Which individual layers have been broken, keyed by (mesh triangle, lattice
// cell, layer index) - a column can have any subset of its LayersPerColumn
// layers missing, not just a contiguous run off the top, so breaking the
// layer under the crosshair can leave a floating block above an empty gap.
// BuildChunkMeshData renders whichever layers remain (plus a bare-ground tile
// if layer 0 is gone), and GetGroundHeightAt derives standing height from the
// contiguous run of layers starting at the ground - a player can't stand on a
// floating layer with nothing under it.
HashSet<(int TriIdx, int CellIdx, int Layer)> brokenLayers = new();

// How far ahead (in world units) the crosshair can reach to break a block -
// a couple of blocks' worth, scaled to whatever face/grid size was chosen.
float faceEdgeLength = Vector3.Distance(vertices[faces[0].VA], vertices[faces[0].VB]);
float reachDistance = (faceEdgeLength / blocksPerEdge) * 2f;

Material fillMaterial = Raylib.LoadMaterialDefault();
Material wireMaterial = Raylib.LoadMaterialDefault();
unsafe { wireMaterial.Maps[0].Color = new Color(0, 0, 0, 60); }

// Simple texture pack: a 3-tile atlas (grass top / dirt side / bare stone),
// see Assets/Textures/atlas.png. Vertices are written with UVs already
// scoped to their tile (see AtlasTileU in BuildChunkMeshData), so one
// texture and one draw call still covers every block; raylib's default
// shader multiplies the sampled texel by each vertex's color, so the
// existing per-column hue tint keeps working on top of the texture.
Texture2D blockAtlas = Raylib.LoadTexture("Assets/Textures/atlas.png");
unsafe { fillMaterial.Maps[(int)MaterialMapIndex.Albedo].Texture = blockAtlas; }

// Only the current planet chunk (base icosahedron face) and its neighbours
// have block geometry built and uploaded at any time. Builds run on
// background threads (BuildChunkMeshData only touches managed arrays, no
// raylib/GL calls) so crossing into a new region doesn't stall the main
// thread; the result is uploaded to the GPU (main-thread only, needs the GL
// context) once the background build finishes.
Dictionary<int, Mesh[]> loadedChunks = new();
Dictionary<int, Task<ChunkMeshData[]>> pendingChunkBuilds = new();
HashSet<int> desiredChunks = new();

Mesh[] UploadChunkMeshData(ChunkMeshData[] data)
{
    var meshes = new Mesh[data.Length];
    for (int i = 0; i < data.Length; i++)
    {
        ChunkMeshData d = data[i];
        Mesh mesh = new() { VertexCount = d.VertexCount, TriangleCount = d.TriangleCount };
        unsafe
        {
            IntPtr vPtr = Marshal.AllocHGlobal(d.Positions.Length * sizeof(float));
            Marshal.Copy(d.Positions, 0, vPtr, d.Positions.Length);
            mesh.Vertices = (float*)vPtr;

            IntPtr cPtr = Marshal.AllocHGlobal(d.Colors.Length);
            Marshal.Copy(d.Colors, 0, cPtr, d.Colors.Length);
            mesh.Colors = (byte*)cPtr;

            IntPtr tPtr = Marshal.AllocHGlobal(d.TexCoords.Length * sizeof(float));
            Marshal.Copy(d.TexCoords, 0, tPtr, d.TexCoords.Length);
            mesh.TexCoords = (float*)tPtr;

            int indexBytes = d.Indices.Length * sizeof(ushort);
            IntPtr iPtr = Marshal.AllocHGlobal(indexBytes);
            fixed (ushort* iSrc = d.Indices)
                Buffer.MemoryCopy(iSrc, (void*)iPtr, indexBytes, indexBytes);
            mesh.Indices = (ushort*)iPtr;
        }
        Raylib.UploadMesh(ref mesh, false);
        meshes[i] = mesh;
    }
    return meshes;
}

void UpdateLoadedChunks(int baseFaceId)
{
    desiredChunks = new HashSet<int>(baseFaceNeighbors[baseFaceId]) { baseFaceId };

    foreach (int id in desiredChunks)
    {
        if (!loadedChunks.ContainsKey(id) && !pendingChunkBuilds.ContainsKey(id))
        {
            // Snapshot on the calling thread - brokenLayers may keep
            // changing on the main thread while this build runs in the background.
            var brokenSnapshot = new HashSet<(int, int, int)>(brokenLayers);
            pendingChunkBuilds[id] = Task.Run(() =>
                BuildChunkMeshData(id, vertices, triangles, faces, trianglesByBaseFace, latticeCells, BlockHeight, brokenSnapshot, layersPerColumn));
        }
    }

    foreach (int id in loadedChunks.Keys.Where(id => !desiredChunks.Contains(id)).ToList())
    {
        foreach (Mesh m in loadedChunks[id]) Raylib.UnloadMesh(m);
        loadedChunks.Remove(id);
    }
}

// Forces a chunk's mesh to be rebuilt (e.g. after a block in it was broken).
// Any in-flight build for it is dropped since it was started against a stale
// brokenLayers snapshot; if the chunk is still desired, a fresh build is
// scheduled with the current snapshot.
void RebuildChunk(int baseFaceId)
{
    if (loadedChunks.TryGetValue(baseFaceId, out Mesh[]? oldMeshes))
    {
        foreach (Mesh m in oldMeshes) Raylib.UnloadMesh(m);
        loadedChunks.Remove(baseFaceId);
    }
    pendingChunkBuilds.Remove(baseFaceId);

    if (!desiredChunks.Contains(baseFaceId)) return;
    var brokenSnapshot = new HashSet<(int, int, int)>(brokenLayers);
    pendingChunkBuilds[baseFaceId] = Task.Run(() =>
        BuildChunkMeshData(baseFaceId, vertices, triangles, faces, trianglesByBaseFace, latticeCells, BlockHeight, brokenSnapshot, layersPerColumn));
}

// Picks up finished background builds and uploads them; called every frame.
// A build that finished for a chunk we've since left (desiredChunks no
// longer contains it) is just discarded - never uploaded, never drawn.
void PollPendingChunkBuilds()
{
    foreach (int id in pendingChunkBuilds.Keys.ToList())
    {
        Task<ChunkMeshData[]> task = pendingChunkBuilds[id];
        if (!task.IsCompleted) continue;

        pendingChunkBuilds.Remove(id);
        if (task.IsFaulted || !desiredChunks.Contains(id)) continue;
        loadedChunks[id] = UploadChunkMeshData(task.Result);
    }
}

Raylib.DisableCursor(); // switch to FPS mouse-look now that generation is done

// Authoritative player state: which face you're on, and where on its plane.
int currentFace = 0;
int currentBaseFace = faces[0].BaseFaceId;
Vector3 groundPos = Centroid(vertices, faces[0]); // start at the middle of face 0
Vector3 visualUp = faces[0].Normal;               // smoothed, camera-only
float yaw = 0f;
float pitch = 0f;
float airHeight = 0f;      // height above the standing block's surface, along `up`
float verticalSpeed = 0f;  // rate of change of airHeight; negative = falling
// Height of the surface currently underfoot, persisted across frames so a
// floating block (nothing under it) can be identified and stood on without
// blocking the space beneath it - GetGroundHeightAt picks the highest solid
// layer at or below wherever the player's feet already are, so standing on
// top of a floating block and walking underneath it both resolve correctly.
float standingSurfaceHeight = layersPerColumn * BlockHeight;

// The very first chunk set is built synchronously (with the loading screen
// already up) so the game doesn't start on a blank globe waiting on
// background tasks that haven't even been scheduled yet.
desiredChunks = new HashSet<int>(baseFaceNeighbors[currentBaseFace]) { currentBaseFace };
foreach (int id in desiredChunks)
    loadedChunks[id] = UploadChunkMeshData(
        BuildChunkMeshData(id, vertices, triangles, faces, trianglesByBaseFace, latticeCells, BlockHeight, brokenLayers, layersPerColumn));

Camera3D camera = new()
{
    Position = groundPos,
    Target = groundPos + Vector3.UnitX,
    Up = visualUp,
    FovY = 65f,
    Projection = CameraProjection.Perspective,
};

while (!Raylib.WindowShouldClose())
{
    // Clamped so a stall (e.g. the synchronous UploadMesh in
    // PollPendingChunkBuilds after breaking a block triggers a chunk rebuild)
    // can't be integrated as one giant physics step - without this, gravity
    // would resolve an entire fall in a single frame, looking like a
    // teleport instead of a fall.
    float dt = MathF.Min(Raylib.GetFrameTime(), 0.05f);

    // --- mouse look ---
    Vector2 mouseDelta = Raylib.GetMouseDelta();
    yaw -= mouseDelta.X * MouseSensitivity;
    pitch -= mouseDelta.Y * MouseSensitivity;
    pitch = Math.Clamp(pitch, -1.5f, 1.5f);

    Vector3 up = faces[currentFace].Normal; // authoritative, exact - used for all movement math

    // --- local tangent basis for the current face ---
    Vector3 reference = MathF.Abs(Vector3.Dot(up, Vector3.UnitZ)) > 0.9f ? Vector3.UnitX : Vector3.UnitZ;
    Vector3 tangentForward = Vector3.Normalize(reference - up * Vector3.Dot(reference, up));
    Vector3 tangentRight = Vector3.Normalize(Vector3.Cross(tangentForward, up));

    Vector3 moveForward = RotateAroundAxis(tangentForward, up, yaw);
    Vector3 moveRight = RotateAroundAxis(tangentRight, up, yaw);

    // --- WASD movement, constrained to the current face's plane ---
    Vector3 move = Vector3.Zero;
    if (Raylib.IsKeyDown(KeyboardKey.W)) move += moveForward;
    if (Raylib.IsKeyDown(KeyboardKey.S)) move -= moveForward;
    if (Raylib.IsKeyDown(KeyboardKey.D)) move += moveRight;
    if (Raylib.IsKeyDown(KeyboardKey.A)) move -= moveRight;
    if (move != Vector3.Zero) move = Vector3.Normalize(move) * MoveSpeed * dt;

    // Absolute height the player's feet are at right now, before this frame's
    // move - the reference GetGroundHeightAt uses to pick which shelf (if
    // any) they're on, so a floating block only counts as ground when they're
    // already at or above it, not when they're passing underneath it.
    float feetHeight = standingSurfaceHeight + airHeight;

    Vector3 tentative = groundPos + move;
    float oldBlockHeight = standingSurfaceHeight;

    // --- walk within the current face, unfolding across edges as needed ---
    // Operates on a local candidate so a step-blocked move (see below) never
    // leaves currentFace pointing somewhere groundPos doesn't match.
    (tentative, int candidateFace) = UnfoldAcrossFaces(tentative, currentFace, faces, vertices);

    float newBlockHeight = GetGroundHeightAt(tentative, candidateFace, vertices, triangles, blocksPerEdge, cellIndexLookup, brokenLayers, layersPerColumn, feetHeight);
    bool wasGrounded = airHeight <= 0f;
    float groundBlockHeight;
    // Compare against feetHeight (current absolute foot elevation, including
    // any airHeight) rather than oldBlockHeight - otherwise, while airborne,
    // a column whose top sits between the last-stood-on block and the
    // player's current height would pass this check and yank the player
    // upward onto it instead of being felt as a wall. Grounded players get
    // MaxStepHeight of slack to climb small ledges; airborne players get
    // none, so a block taller than their feet blocks them like a wall
    // exactly as it would on foot.
    float allowedRise = wasGrounded ? MaxStepHeight : 0f;
    if (newBlockHeight > feetHeight + allowedRise)
    {
        // Too tall to step up onto (or, mid-air, blocks the path) - reject the move, stay put this frame.
        groundBlockHeight = oldBlockHeight;
    }
    else
    {
        currentFace = candidateFace;
        groundPos = tentative;
        airHeight = MathF.Max(0f, feetHeight - newBlockHeight); // preserve absolute height across the rebase; let gravity carry any resulting fall
        groundBlockHeight = newBlockHeight;

        int newBaseFace = faces[currentFace].BaseFaceId;
        if (newBaseFace != currentBaseFace)
        {
            currentBaseFace = newBaseFace;
            UpdateLoadedChunks(currentBaseFace);
        }
    }
    standingSurfaceHeight = groundBlockHeight;

    PollPendingChunkBuilds();

    up = faces[currentFace].Normal;

    float smoothT = 1f - MathF.Exp(-UpSmoothing * dt);
    visualUp = Vector3.Normalize(Vector3.Lerp(visualUp, up, smoothT));

    // --- jumping: airHeight is extra height above the standing block, along
    // `up`, driven by a simple velocity + gravity integrator. Landing snaps
    // it back to exactly 0 rather than letting it settle slightly negative. ---
    if (wasGrounded && Raylib.IsKeyPressed(KeyboardKey.Space)) verticalSpeed = JumpSpeed;
    verticalSpeed -= Gravity * dt;
    airHeight += verticalSpeed * dt;
    if (airHeight <= 0f) { airHeight = 0f; verticalSpeed = 0f; }

    // --- camera --- (rests on top of the block the player is standing on, plus any jump height)
    Vector3 eyePos = groundPos + up * (groundBlockHeight + airHeight + EyeHeight);
    Vector3 lookDir = RotateAroundAxis(moveForward, moveRight, pitch);
    camera.Position = eyePos;
    camera.Target = eyePos + lookDir;
    camera.Up = visualUp;

    // --- crosshair targeting: raymarch the actual 3D look ray (so pitch
    // matters) across the block columns, walking across faces the same way
    // WASD movement does. Each column is a stack of layersPerColumn slabs
    // (any subset of which may already be broken), so this finds the first
    // *solid* slab the ray's height falls into as it descends - a block's
    // flat top or exposed side, or a lower layer visible through a gap left
    // by a broken layer above it. ---
    bool hasTarget = false;
    int targetFace = -1, targetI = 0, targetJ = 0, targetSlot = 0, targetLayer = 0;
    {
        const int raySteps = 48;
        float stepSize = reachDistance / raySteps;
        int rayFace = currentFace;
        Vector3 rayPoint = eyePos;
        for (int step = 1; step <= raySteps; step++)
        {
            rayPoint += lookDir * stepSize;
            (rayPoint, rayFace) = UnfoldAcrossFaces(rayPoint, rayFace, faces, vertices);
            Face rf = faces[rayFace];
            float sampleHeight = Vector3.Dot(rayPoint - vertices[rf.VA], rf.Normal);

            (int i, int j, int slot) = ResolveBlockCell(rayPoint, rayFace, vertices, triangles, blocksPerEdge);
            int cellIdx = cellIndexLookup[i, j, slot];
            if (cellIdx < 0) cellIdx = cellIndexLookup[i, j, 0]; // outermost diagonal row has no slot-1 cell

            int layerHere = (int)MathF.Floor(sampleHeight / BlockHeight);
            if (layerHere < 0)
            {
                break; // somehow below the ground plane - nothing to hit
            }
            else if (layerHere >= layersPerColumn)
            {
                continue; // above the whole column - open air, keep marching
            }
            else if (!brokenLayers.Contains((rayFace, cellIdx, layerHere)))
            {
                targetI = i; targetJ = j; targetSlot = slot; targetLayer = layerHere;
                targetFace = rayFace;
                hasTarget = true;
                break;
            }
            // else: this layer's already broken - a gap - keep marching down through it.
        }
    }

    if (hasTarget && Raylib.IsMouseButtonPressed(MouseButton.Left))
    {
        int cellIdx = cellIndexLookup[targetI, targetJ, targetSlot];
        if (cellIdx < 0) cellIdx = cellIndexLookup[targetI, targetJ, 0]; // outermost diagonal row has no slot-1 cell
        if (brokenLayers.Add((targetFace, cellIdx, targetLayer)))
            RebuildChunk(faces[targetFace].BaseFaceId);
    }

    Raylib.BeginDrawing();
    Raylib.ClearBackground(new Color(15, 15, 25, 255));

    Raylib.BeginMode3D(camera);
    foreach (Mesh[] chunkMeshes in loadedChunks.Values)
        foreach (Mesh chunk in chunkMeshes) Raylib.DrawMesh(chunk, fillMaterial, Matrix4x4.Identity);
    Rlgl.EnableWireMode();
    foreach (Mesh[] chunkMeshes in loadedChunks.Values)
        foreach (Mesh chunk in chunkMeshes) Raylib.DrawMesh(chunk, wireMaterial, Matrix4x4.Identity);
    Rlgl.DisableWireMode();
    Raylib.EndMode3D();

    int crosshairX = Raylib.GetScreenWidth() / 2, crosshairY = Raylib.GetScreenHeight() / 2;
    Color crosshairColor = hasTarget ? Color.Lime : Color.RayWhite;
    const int crosshairSize = 10, crosshairGap = 3;
    Raylib.DrawLine(crosshairX - crosshairSize, crosshairY, crosshairX - crosshairGap, crosshairY, crosshairColor);
    Raylib.DrawLine(crosshairX + crosshairGap, crosshairY, crosshairX + crosshairSize, crosshairY, crosshairColor);
    Raylib.DrawLine(crosshairX, crosshairY - crosshairSize, crosshairX, crosshairY - crosshairGap, crosshairColor);
    Raylib.DrawLine(crosshairX, crosshairY + crosshairGap, crosshairX, crosshairY + crosshairSize, crosshairColor);

    Raylib.DrawFPS(10, 10);
    Raylib.DrawText("WASD to walk, mouse to look, space to jump, left click to break blocks, ESC to quit", 10, 40, 20, Color.RayWhite);
    Raylib.DrawText(
        $"Face #{currentFace} / {faces.Length:N0}   Chunk #{currentBaseFace} ({loadedChunks.Count} loaded, {pendingChunkBuilds.Count} building)",
        10, 65, 18, Color.LightGray);
    Raylib.EndDrawing();
}

Raylib.EnableCursor();
Raylib.UnloadTexture(blockAtlas);
Raylib.CloseWindow();
return;

// ---------------------------------------------------------------------------
// Popup / loading screen
// ---------------------------------------------------------------------------

// A tiny pre-game popup: drag the sliders (or use arrow keys) to pick how
// finely the icosahedron is subdivided, how fine the decorative grid on each
// face is, how many blocks stack vertically in a column, and the planet
// radius; see the resulting numbers live, then press Enter or click Generate
// to build the globe.
static (int Level, float BlocksPerEdge, int LayersPerColumn, float Radius) ShowSubdivisionPicker(
    int initialLevel, int maxLevel, int warnAtLevel,
    float initialBlocksPerEdge, float minBlocksPerEdge, float maxBlocksPerEdge, int blocksPerChunkWarnThreshold,
    int initialLayersPerColumn, int minLayersPerColumn, int maxLayersPerColumn,
    float initialRadius, float minRadius, float maxRadius)
{
    int level = initialLevel;
    float blocksPerEdge = initialBlocksPerEdge;
    int layersPerColumn = initialLayersPerColumn;
    float radius = initialRadius;
    bool draggingLevelHandle = false;
    bool draggingBlocksHandle = false;
    bool draggingLayersHandle = false;
    bool draggingRadiusHandle = false;

    const int trackX = 340, trackWidth = 600, trackHeight = 10;
    const int levelTrackY = 168, blocksTrackY = 288, layersTrackY = 380, radiusTrackY = 470;
    const int handleRadius = 12;
    Rectangle generateButton = new(540, 510, 200, 50);

    while (!Raylib.WindowShouldClose())
    {
        int screenW = Raylib.GetScreenWidth();
        int centerXOffset = screenW / 2 - 640; // keep the layout centered if the window is resized
        int tx = trackX + centerXOffset;
        Rectangle button = generateButton with { X = generateButton.X + centerXOffset };

        Vector2 mouse = Raylib.GetMousePosition();
        float levelHandleX = tx + (float)level / maxLevel * trackWidth;
        float blocksT = (blocksPerEdge - minBlocksPerEdge) / (maxBlocksPerEdge - minBlocksPerEdge);
        float blocksHandleX = tx + blocksT * trackWidth;
        float layersT = (float)(layersPerColumn - minLayersPerColumn) / (maxLayersPerColumn - minLayersPerColumn);
        float layersHandleX = tx + layersT * trackWidth;
        float radiusT = (radius - minRadius) / (maxRadius - minRadius);
        float radiusHandleX = tx + radiusT * trackWidth;

        if (Raylib.IsMouseButtonPressed(MouseButton.Left))
        {
            if (Vector2.Distance(mouse, new Vector2(levelHandleX, levelTrackY)) <= handleRadius + 6)
                draggingLevelHandle = true;
            else if (Vector2.Distance(mouse, new Vector2(blocksHandleX, blocksTrackY)) <= handleRadius + 6)
                draggingBlocksHandle = true;
            else if (Vector2.Distance(mouse, new Vector2(layersHandleX, layersTrackY)) <= handleRadius + 6)
                draggingLayersHandle = true;
            else if (Vector2.Distance(mouse, new Vector2(radiusHandleX, radiusTrackY)) <= handleRadius + 6)
                draggingRadiusHandle = true;
        }
        if (Raylib.IsMouseButtonReleased(MouseButton.Left))
        {
            draggingLevelHandle = false;
            draggingBlocksHandle = false;
            draggingLayersHandle = false;
            draggingRadiusHandle = false;
        }

        if (draggingLevelHandle)
        {
            float t = Math.Clamp((mouse.X - tx) / trackWidth, 0f, 1f);
            level = (int)MathF.Round(t * maxLevel);
        }
        if (draggingBlocksHandle)
        {
            float t = Math.Clamp((mouse.X - tx) / trackWidth, 0f, 1f);
            blocksPerEdge = MathF.Round(minBlocksPerEdge + t * (maxBlocksPerEdge - minBlocksPerEdge));
        }
        if (draggingLayersHandle)
        {
            float t = Math.Clamp((mouse.X - tx) / trackWidth, 0f, 1f);
            layersPerColumn = (int)MathF.Round(minLayersPerColumn + t * (maxLayersPerColumn - minLayersPerColumn));
        }
        if (draggingRadiusHandle)
        {
            float t = Math.Clamp((mouse.X - tx) / trackWidth, 0f, 1f);
            radius = MathF.Round(minRadius + t * (maxRadius - minRadius));
        }

        if (Raylib.IsKeyPressed(KeyboardKey.Right)) level = Math.Min(maxLevel, level + 1);
        if (Raylib.IsKeyPressed(KeyboardKey.Left)) level = Math.Max(0, level - 1);
        if (Raylib.IsKeyPressed(KeyboardKey.Up)) blocksPerEdge = Math.Min(maxBlocksPerEdge, blocksPerEdge + 1f);
        if (Raylib.IsKeyPressed(KeyboardKey.Down)) blocksPerEdge = Math.Max(minBlocksPerEdge, blocksPerEdge - 1f);
        if (Raylib.IsKeyPressed(KeyboardKey.Period)) layersPerColumn = Math.Min(maxLayersPerColumn, layersPerColumn + 1);
        if (Raylib.IsKeyPressed(KeyboardKey.Comma)) layersPerColumn = Math.Max(minLayersPerColumn, layersPerColumn - 1);
        if (Raylib.IsKeyPressed(KeyboardKey.PageUp)) radius = Math.Min(maxRadius, radius + 4f);
        if (Raylib.IsKeyPressed(KeyboardKey.PageDown)) radius = Math.Max(minRadius, radius - 4f);

        bool confirmed = Raylib.IsKeyPressed(KeyboardKey.Enter) ||
            (Raylib.IsMouseButtonPressed(MouseButton.Left) && Raylib.CheckCollisionPointRec(mouse, button));
        if (confirmed) return (level, blocksPerEdge, layersPerColumn, radius);

        long faceCount = 20L * (long)Math.Pow(4, level);
        bool levelDanger = level >= warnAtLevel;
        float blockEdgeMeters = 91.8f / blocksPerEdge; // see ComputeScaledRadius / EyeHeight-to-meters note
        // Worst case (nothing broken yet): every column carries its full stack.
        long blocksPerChunk = (long)Math.Pow(4, level) * (long)(blocksPerEdge * blocksPerEdge) * layersPerColumn;
        bool chunkDanger = blocksPerChunk >= blocksPerChunkWarnThreshold;

        Raylib.BeginDrawing();
        Raylib.ClearBackground(new Color(15, 15, 25, 255));

        Raylib.DrawText("Icosahedron Walker", tx, 40, 40, Color.RayWhite);

        Raylib.DrawText("Choose subdivision level", tx, 90, 22, Color.LightGray);
        Raylib.DrawText($"Level {level}  -  {faceCount:N0} faces", tx, 120, 26, levelDanger ? Color.Red : Color.SkyBlue);
        if (levelDanger)
            Raylib.DrawText("Warning: needs a lot of RAM/time to generate at this size!", tx, 148, 18, Color.Red);

        Raylib.DrawRectangle(tx, levelTrackY - trackHeight / 2, trackWidth, trackHeight, Color.DarkGray);
        for (int i = 0; i <= maxLevel; i++)
        {
            float tickX = tx + (float)i / maxLevel * trackWidth;
            Raylib.DrawRectangle((int)tickX - 1, levelTrackY - trackHeight, 2, trackHeight * 2, Color.Gray);
        }
        Raylib.DrawCircle((int)levelHandleX, levelTrackY, handleRadius, Color.SkyBlue);

        Raylib.DrawText("Choose blocks per face edge", tx, 210, 22, Color.LightGray);
        Raylib.DrawText($"{blocksPerEdge:N0} blocks/edge  -  ~{blockEdgeMeters:0.###}m blocks  -  {blocksPerChunk:N0} blocks/chunk",
            tx, 240, 22, chunkDanger ? Color.Red : Color.SkyBlue);
        if (chunkDanger)
            Raylib.DrawText("Warning: crossing into a new chunk may hitch at this size!", tx, 268, 18, Color.Red);

        Raylib.DrawRectangle(tx, blocksTrackY - trackHeight / 2, trackWidth, trackHeight, Color.DarkGray);
        Raylib.DrawCircle((int)blocksHandleX, blocksTrackY, handleRadius, Color.SkyBlue);

        Raylib.DrawText("Choose layers per column", tx, 330, 22, Color.LightGray);
        Raylib.DrawText($"{layersPerColumn} layer{(layersPerColumn == 1 ? "" : "s")} tall", tx, 360, 22, Color.SkyBlue);

        Raylib.DrawRectangle(tx, layersTrackY - trackHeight / 2, trackWidth, trackHeight, Color.DarkGray);
        Raylib.DrawCircle((int)layersHandleX, layersTrackY, handleRadius, Color.SkyBlue);

        Raylib.DrawText("Choose planet radius", tx, 420, 22, Color.LightGray);
        Raylib.DrawText($"Radius {radius:0}", tx, 450, 26, Color.SkyBlue);

        Raylib.DrawRectangle(tx, radiusTrackY - trackHeight / 2, trackWidth, trackHeight, Color.DarkGray);
        Raylib.DrawCircle((int)radiusHandleX, radiusTrackY, handleRadius, Color.SkyBlue);

        Raylib.DrawRectangleRec(button, Color.DarkGreen);
        Raylib.DrawText("Generate", (int)button.X + 40, (int)button.Y + 14, 22, Color.RayWhite);

        Raylib.DrawText("Drag sliders or use Left/Right, Up/Down, Comma/Period, PageUp/PageDown, then press Enter",
            tx, 590, 18, Color.Gray);

        Raylib.EndDrawing();
    }

    // window was closed during the picker
    return (initialLevel, initialBlocksPerEdge, initialLayersPerColumn, initialRadius);
}

static void DrawLoadingScreen(int subdivisionLevels)
{
    long faceCount = 20L * (long)Math.Pow(4, subdivisionLevels);
    Raylib.BeginDrawing();
    Raylib.ClearBackground(new Color(15, 15, 25, 255));
    Raylib.DrawText($"Generating {faceCount:N0} faces...", 340, 330, 28, Color.RayWhite);
    Raylib.DrawText("The window may look frozen for a bit at high levels.", 340, 370, 18, Color.Gray);
    Raylib.EndDrawing();
}

// ---------------------------------------------------------------------------
// Math helpers
// ---------------------------------------------------------------------------

static Vector3 Centroid(Vector3[] vertices, Face f) =>
    (vertices[f.VA] + vertices[f.VB] + vertices[f.VC]) / 3f;

static Vector3 RotateAroundAxis(Vector3 v, Vector3 axis, float angleRad)
{
    axis = Vector3.Normalize(axis);
    float c = MathF.Cos(angleRad);
    float s = MathF.Sin(angleRad);
    return v * c + Vector3.Cross(axis, v) * s + axis * Vector3.Dot(axis, v) * (1f - c);
}

// Walks a point that started on `startFace`'s plane to wherever it actually
// ends up, "unfolding" across each edge it crosses into the neighboring
// face's plane (the same trick used for walking on any polyhedron) instead
// of guessing which face a point is on from a ray through the center. Shared
// by WASD movement and the crosshair's reach raycast - both are just points
// moving in a straight line across the surface.
static (Vector3 Position, int Face) UnfoldAcrossFaces(Vector3 point, int startFace, Face[] faces, Vector3[] vertices)
{
    int candidateFace = startFace;
    for (int guard = 0; guard < 6; guard++)
    {
        Face f = faces[candidateFace];
        Vector3 fa = vertices[f.VA], fb = vertices[f.VB], fc = vertices[f.VC];
        (float u, float v, float w) = Barycentric(point, fa, fb, fc);
        const float eps = 1e-4f;
        if (u >= -eps && v >= -eps && w >= -eps) break; // inside this face, done

        // Which edge did we cross? u<0 -> edge BC (opposite A), v<0 -> edge CA, w<0 -> edge AB.
        int neighbor;
        Vector3 edgeStart, edgeEnd;
        if (u <= v && u <= w) { neighbor = f.NeighborBC; edgeStart = fb; edgeEnd = fc; }
        else if (v <= w) { neighbor = f.NeighborCA; edgeStart = fc; edgeEnd = fa; }
        else { neighbor = f.NeighborAB; edgeStart = fa; edgeEnd = fb; }

        Face nf = faces[neighbor];
        Vector3 axis = Vector3.Normalize(edgeEnd - edgeStart);

        float cosA = Vector3.Dot(f.Normal, nf.Normal);
        float sinA = Vector3.Dot(Vector3.Cross(f.Normal, nf.Normal), axis);
        float angle = MathF.Atan2(sinA, cosA);

        point = edgeStart + RotateAroundAxis(point - edgeStart, axis, angle);
        candidateFace = neighbor;
    }
    return (point, candidateFace);
}

// Each subdivision level exactly halves the angular edge length of triangles
// descending from an original base vertex (midpoint-then-renormalize of two
// unit vectors at angle theta lands exactly at theta/2, by the law of
// cosines: |A+B| = 2*cos(theta/2) for unit A, B). To keep world-space face
// size constant across levels despite that shrinkage, the sphere radius is
// grown so the chord length (2*R*sin(theta/2)) at the finest level matches
// the chord length at level 0.
static float ComputeScaledRadius(float baseRadius, int levels)
{
    if (levels == 0) return baseRadius;

    var (unitVerts, _) = BuildBaseIcosahedron(1f);
    float theta0 = MathF.Acos(Vector3.Dot(unitVerts[0], unitVerts[1]));
    float half = theta0 / 2f;
    float finest = theta0 / MathF.Pow(2f, levels + 1);
    return baseRadius * MathF.Sin(half) / MathF.Sin(finest);
}

static (float U, float V, float W) Barycentric(Vector3 p, Vector3 a, Vector3 b, Vector3 c)
{
    Vector3 v0 = b - a, v1 = c - a, v2 = p - a;
    float d00 = Vector3.Dot(v0, v0);
    float d01 = Vector3.Dot(v0, v1);
    float d11 = Vector3.Dot(v1, v1);
    float d20 = Vector3.Dot(v2, v0);
    float d21 = Vector3.Dot(v2, v1);
    float denom = d00 * d11 - d01 * d01;
    float v = (d11 * d20 - d01 * d21) / denom;
    float w = (d00 * d21 - d01 * d20) / denom;
    float u = 1f - v - w;
    return (u, v, w);
}

// Resolves a position within mesh triangle `faceIdx` to the block (lattice
// cell) that contains it, as (i, j, slot). The barycentric (u, v, w) from
// Barycentric (p = u*a + v*b + w*c) already gives exactly the (v, w)
// fraction pair BuildLatticeCells/LatticePoint use to place lattice corners
// (a + v*(b-a) + w*(c-a) = u*a + v*b + w*c since u = 1 - v - w), so no new
// coordinate math is needed - just scale by blocksPerEdge. Each (i, j)
// square is split by the local diagonal u+v=1 into 2 triangles: slot 0 is
// the corner at the square's own (i, j) origin (always present), slot 1 is
// the opposite corner (absent on the outermost diagonal row, where the
// square is clipped to a single triangle by the parent mesh triangle's edge).
static (int I, int J, int Slot) ResolveBlockCell(
    Vector3 position, int faceIdx, Vector3[] vertices, (int A, int B, int C)[] triangles, int blocksPerEdge)
{
    var (ia, ib, ic) = triangles[faceIdx];
    Vector3 a = vertices[ia], b = vertices[ib], c = vertices[ic];
    (_, float v, float w) = Barycentric(position, a, b, c);

    float fv = v * blocksPerEdge, fw = w * blocksPerEdge;
    int i = Math.Clamp((int)MathF.Floor(fv), 0, blocksPerEdge - 1);
    int j = Math.Clamp((int)MathF.Floor(fw), 0, blocksPerEdge - 1 - i);
    int slot = (fv - i) + (fw - j) <= 1f ? 0 : 1;
    return (i, j, slot);
}

// Finds the surface the player is standing on (or would land on): the top of
// the highest solid layer whose floor is at or below their current feet
// height. A floating layer (nothing under it) still counts once the player
// is already up at or above it - e.g. having jumped or walked onto it from a
// taller neighbor - but is ignored while they're below it, so walking
// underneath a floating block never snaps them up onto its top. Bare ground
// (height 0) is always the fallback since nothing is ever missing beneath
// the planet's surface itself.
static float GetGroundHeightAt(
    Vector3 position, int faceIdx, Vector3[] vertices, (int A, int B, int C)[] triangles, int blocksPerEdge,
    int[,,] cellIndexLookup, HashSet<(int TriIdx, int CellIdx, int Layer)> brokenLayers, int layersPerColumn,
    float feetHeight)
{
    (int i, int j, int slot) = ResolveBlockCell(position, faceIdx, vertices, triangles, blocksPerEdge);
    int cellIdx = cellIndexLookup[i, j, slot];
    if (cellIdx < 0) cellIdx = cellIndexLookup[i, j, 0]; // outermost diagonal row has no slot-1 cell

    const float eps = 1e-3f;
    float standingHeight = 0f;
    for (int layer = 0; layer < layersPerColumn; layer++)
    {
        float floor = layer * BlockHeight;
        if (floor > feetHeight + eps) break; // this and every layer above it is out of reach from here
        if (!brokenLayers.Contains((faceIdx, cellIdx, layer)))
            standingHeight = (layer + 1) * BlockHeight;
    }
    return standingHeight;
}

static Color HsvColor(float h, float s, float v)
{
    float c = v * s;
    float x = c * (1 - MathF.Abs((h / 60f) % 2 - 1));
    float m = v - c;
    (float r, float g, float b) = h switch
    {
        < 60 => (c, x, 0f),
        < 120 => (x, c, 0f),
        < 180 => (0f, c, x),
        < 240 => (0f, x, c),
        < 300 => (x, 0f, c),
        _ => (c, 0f, x),
    };
    return new Color((byte)((r + m) * 255), (byte)((g + m) * 255), (byte)((b + m) * 255), (byte)255);
}

// ---------------------------------------------------------------------------
// Mesh generation (flat arrays, sized exactly up front - no per-edge Dictionary
// of heap objects at the final, largest subdivision level)
// ---------------------------------------------------------------------------

static (Vector3[] Vertices, (int A, int B, int C)[] Triangles, int[] BaseFaceOf) BuildIcosahedronMesh(float radius, int levels)
{
    var (vertices, triangles) = BuildBaseIcosahedron(radius);
    int[] baseFaceOf = Enumerable.Range(0, triangles.Length).ToArray(); // each base triangle is its own chunk id, 0..19
    for (int i = 0; i < levels; i++)
        (vertices, triangles, baseFaceOf) = Subdivide(vertices, triangles, baseFaceOf, radius);
    return (vertices, triangles, baseFaceOf);
}

static (Vector3[] Vertices, (int A, int B, int C)[] Triangles) BuildBaseIcosahedron(float radius)
{
    float phi = (1f + MathF.Sqrt(5f)) / 2f;

    Vector3[] raw =
    [
        new(-1,  phi, 0), new(1,  phi, 0), new(-1, -phi, 0), new(1, -phi, 0),
        new(0, -1,  phi), new(0, 1,  phi), new(0, -1, -phi), new(0, 1, -phi),
        new(phi, 0, -1), new(phi, 0, 1), new(-phi, 0, -1), new(-phi, 0, 1),
    ];

    Vector3[] vertices = raw.Select(r => Vector3.Normalize(r) * radius).ToArray();

    (int, int, int)[] triangles =
    [
        (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
        (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
        (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
        (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1),
    ];

    return (vertices, triangles);
}

// Splits each triangle into 4 by its edge midpoints, pushing new vertices out to
// `radius` (a one-step geodesic subdivision). Shared edges reuse the same
// midpoint vertex so the mesh stays a valid closed manifold. For a closed
// triangle mesh, #edges = 3*#faces/2 exactly, so the new vertex/triangle counts
// are known up front and arrays are sized once (no List doubling/reallocation).
static (Vector3[] Vertices, (int A, int B, int C)[] Triangles, int[] BaseFaceOf) Subdivide(
    Vector3[] vertices, (int A, int B, int C)[] triangles, int[] baseFaceOf, float radius)
{
    int newVertexBudget = 3 * triangles.Length / 2;
    var newVertices = new List<Vector3>(vertices.Length + newVertexBudget);
    newVertices.AddRange(vertices);
    // A (int,int) tuple key (proper bit-mixing hash) rather than a packed
    // `long` (min<<32|max) - Int64's default hashcode just XORs the two
    // halves, and since both halves are vertex indices in the same numeric
    // range, that collapses many keys onto the same bucket once the mesh
    // gets large, turning every lookup into an O(n) chain walk.
    var midpointCache = new Dictionary<(int, int), int>(newVertexBudget);

    int Midpoint(int a, int b)
    {
        (int, int) key = (Math.Min(a, b), Math.Max(a, b));
        if (midpointCache.TryGetValue(key, out int existing)) return existing;
        Vector3 mid = Vector3.Normalize((vertices[a] + vertices[b]) / 2f) * radius;
        int index = newVertices.Count;
        newVertices.Add(mid);
        midpointCache[key] = index;
        return index;
    }

    var newTriangles = new (int, int, int)[triangles.Length * 4];
    var newBaseFaceOf = new int[triangles.Length * 4];
    int t = 0;
    for (int i = 0; i < triangles.Length; i++)
    {
        var (a, b, c) = triangles[i];
        int ab = Midpoint(a, b), bc = Midpoint(b, c), ca = Midpoint(c, a);
        int parentBaseFace = baseFaceOf[i];
        newTriangles[t] = (a, ab, ca); newBaseFaceOf[t] = parentBaseFace; t++;
        newTriangles[t] = (b, bc, ab); newBaseFaceOf[t] = parentBaseFace; t++;
        newTriangles[t] = (c, ca, bc); newBaseFaceOf[t] = parentBaseFace; t++;
        newTriangles[t] = (ab, bc, ca); newBaseFaceOf[t] = parentBaseFace; t++;
    }

    return (newVertices.ToArray(), newTriangles, newBaseFaceOf);
}

// Builds per-face gameplay data: normal, plane distance, and the neighboring
// face across each edge. Adjacency is computed by sorting the 3 edges of every
// face (packed into a single long key) instead of a Dictionary<edge, List<face>>
// - at tens of millions of faces, a dictionary of heap-allocated lists is the
// single biggest memory hog; sorting flat arrays avoids that entirely.
static Face[] BuildFaces(Vector3[] vertices, (int A, int B, int C)[] triangles, int[] baseFaceOf)
{
    int faceCount = triangles.Length;
    int edgeSlotCount = faceCount * 3;

    var edgeKeys = new long[edgeSlotCount];
    var edgeRef = new int[edgeSlotCount]; // (faceIndex << 2) | slot,  slot: 0=BC 1=CA 2=AB

    for (int i = 0; i < faceCount; i++)
    {
        var (ia, ib, ic) = triangles[i];
        int baseIdx = i * 3;

        edgeKeys[baseIdx + 0] = EdgeKey(ib, ic);
        edgeRef[baseIdx + 0] = (i << 2) | 0;

        edgeKeys[baseIdx + 1] = EdgeKey(ic, ia);
        edgeRef[baseIdx + 1] = (i << 2) | 1;

        edgeKeys[baseIdx + 2] = EdgeKey(ia, ib);
        edgeRef[baseIdx + 2] = (i << 2) | 2;
    }

    Array.Sort(edgeKeys, edgeRef);

    var neighborBC = new int[faceCount];
    var neighborCA = new int[faceCount];
    var neighborAB = new int[faceCount];

    for (int i = 0; i < edgeSlotCount; i += 2)
    {
        // Every edge of a closed manifold appears in exactly 2 faces, so after
        // sorting by key they land as consecutive pairs.
        int refA = edgeRef[i], refB = edgeRef[i + 1];
        int faceA = refA >> 2, slotA = refA & 3;
        int faceB = refB >> 2, slotB = refB & 3;
        SetNeighbor(neighborBC, neighborCA, neighborAB, faceA, slotA, faceB);
        SetNeighbor(neighborBC, neighborCA, neighborAB, faceB, slotB, faceA);
    }

    var faces = new Face[faceCount];
    for (int i = 0; i < faceCount; i++)
    {
        var (ia, ib, ic) = triangles[i];
        Vector3 a = vertices[ia], b = vertices[ib], c = vertices[ic];
        Vector3 normal = Vector3.Normalize((a + b + c) / 3f);
        float planeD = Vector3.Dot(normal, a);
        faces[i] = new Face(ia, ib, ic, normal, planeD, neighborBC[i], neighborCA[i], neighborAB[i], baseFaceOf[i]);
    }

    return faces;

    static long EdgeKey(int x, int y) => ((long)Math.Min(x, y) << 32) | (uint)Math.Max(x, y);

    static void SetNeighbor(int[] bc, int[] ca, int[] ab, int face, int slot, int neighbor)
    {
        switch (slot)
        {
            case 0: bc[face] = neighbor; break;
            case 1: ca[face] = neighbor; break;
            default: ab[face] = neighbor; break;
        }
    }
}

// ---------------------------------------------------------------------------
// Planet chunking: a "chunk" is one of the 20 base icosahedron faces. Each
// mesh triangle remembers which base face it descends from (Face.BaseFaceId,
// propagated through Subdivide), so triangles can be grouped by chunk, and
// the 20-face adjacency graph tells the chunk manager which chunks to keep
// loaded around the player.
// ---------------------------------------------------------------------------

// Groups mesh-triangle indices by the base icosahedron face they descend
// from, so a chunk's geometry can be built from just its own triangles.
static List<int>[] GroupTrianglesByBaseFace(Face[] faces)
{
    var groups = new List<int>[BaseFaceCount];
    for (int i = 0; i < BaseFaceCount; i++) groups[i] = [];
    for (int i = 0; i < faces.Length; i++) groups[faces[i].BaseFaceId].Add(i);
    return groups;
}

// The 20 base faces form a small, fixed graph - unlike the scale-sensitive
// adjacency code above (millions of faces), a plain Dictionary/HashSet here
// is fine, since this only ever runs once over 20 elements.
static int[][] BuildBaseFaceNeighbors()
{
    var (baseVertices, baseTriangles) = BuildBaseIcosahedron(1f);
    int[] identityBaseFace = Enumerable.Range(0, baseTriangles.Length).ToArray();
    Face[] baseFaces = BuildFaces(baseVertices, baseTriangles, identityBaseFace);

    var vertexToFaces = new Dictionary<int, List<int>>();
    for (int i = 0; i < baseTriangles.Length; i++)
    {
        var (a, b, c) = baseTriangles[i];
        foreach (int v in (int[])[a, b, c])
        {
            if (!vertexToFaces.TryGetValue(v, out var list)) vertexToFaces[v] = list = [];
            list.Add(i);
        }
    }

    var neighbors = new int[baseTriangles.Length][];
    for (int i = 0; i < baseTriangles.Length; i++)
    {
        var set = new HashSet<int> { baseFaces[i].NeighborBC, baseFaces[i].NeighborCA, baseFaces[i].NeighborAB };
        var (a, b, c) = baseTriangles[i];
        foreach (int v in (int[])[a, b, c])
            foreach (int f in vertexToFaces[v])
                if (f != i) set.Add(f);
        neighbors[i] = [.. set];
    }
    return neighbors;
}

// Splits a triangle into blocksPerEdge^2 smaller triangles via barycentric
// interpolation of its 3 corners (flat - no sphere renormalization, since a
// single mesh triangle is already flat). Alongside the cells themselves,
// builds the (i, j, slot) -> cell-index lookup that ResolveBlockCell's
// output is fed into (see its comment for what slot means); -1 marks the
// slot-1 cells that don't exist on the outermost diagonal row.
static (LatticeCell[] Cells, int[,,] IndexLookup) BuildLatticeCells(int blocksPerEdge)
{
    int n = blocksPerEdge;
    var cells = new List<LatticeCell>(n * n);
    var lookup = new int[n, n, 2];
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            lookup[i, j, 0] = lookup[i, j, 1] = -1;

    for (int i = 0; i < n; i++)
    {
        for (int j = 0; j < n - i; j++)
        {
            float u0 = i / (float)n, v0 = j / (float)n;
            float u1 = (i + 1) / (float)n, v1 = j / (float)n;
            float u2 = i / (float)n, v2 = (j + 1) / (float)n;
            lookup[i, j, 0] = cells.Count;
            cells.Add(new LatticeCell(u0, v0, u1, v1, u2, v2));

            if (j < n - i - 1)
            {
                float u3 = (i + 1) / (float)n, v3 = (j + 1) / (float)n;
                lookup[i, j, 1] = cells.Count;
                cells.Add(new LatticeCell(u1, v1, u3, v3, u2, v2));
            }
        }
    }
    return ([.. cells], lookup);
}

static Vector3 LatticePoint(Vector3 a, Vector3 b, Vector3 c, float u, float v) =>
    a + (b - a) * u + (c - a) * v;

// Local corner-index layout within a block's 9 vertices: 0/1/2 = floor
// p0/p1/p2 (side color), 3/4/5 = wall-top r0/r1/r2 (side color), 6/7/8 = cap
// r0/r1/r2 (top color) - the wall-top and cap vertices sit at the same
// positions (roof i = floor i + layer height * normal) but are duplicated so
// the top face and the walls below it can each carry their own color. The
// walls-only template omits the cap triangle for a layer that has another
// block resting directly on top of it, where the cap would be buried and
// coplanar with that block's floor (z-fighting) rather than actually visible.
static ushort[] BuildBlockIndexTemplateFull() =>
[
    6, 7, 8,          // top (cap)
    0, 1, 4, 0, 4, 3, // wall AB (floor edge p0->p1)
    1, 2, 5, 1, 5, 4, // wall BC (floor edge p1->p2)
    2, 0, 3, 2, 3, 5, // wall CA (floor edge p2->p0)
];

static ushort[] BuildBlockIndexTemplateWallsOnly() =>
[
    0, 1, 4, 0, 4, 3, // wall AB (floor edge p0->p1)
    1, 2, 5, 1, 5, 4, // wall BC (floor edge p1->p2)
    2, 0, 3, 2, 3, 5, // wall CA (floor edge p2->p0)
];

static ushort[] BuildBlockIndexTemplateFullWithBottom() =>
[
    6, 7, 8,          // top (cap)
    0, 2, 1,          // bottom (cap, reversed winding to face down)
    0, 1, 4, 0, 4, 3, // wall AB (floor edge p0->p1)
    1, 2, 5, 1, 5, 4, // wall BC (floor edge p1->p2)
    2, 0, 3, 2, 3, 5, // wall CA (floor edge p2->p0)
];

static ushort[] BuildBlockIndexTemplateWallsWithBottom() =>
[
    0, 2, 1,          // bottom (cap, reversed winding to face down)
    0, 1, 4, 0, 4, 3, // wall AB (floor edge p0->p1)
    1, 2, 5, 1, 5, 4, // wall BC (floor edge p1->p2)
    2, 0, 3, 2, 3, 5, // wall CA (floor edge p2->p0)
];

// Builds the block geometry for one chunk (one base icosahedron face). Every
// grid cell of every mesh triangle in the chunk is a column that contributes
// one stacked prism per remaining (unbroken) layer - each raised `blockHeight
// * layer index` off the ground along its parent triangle's normal. A column
// can have any subset of its layers broken (not just a contiguous run off the
// top), so a surviving layer gets a top cap whenever the layer above it is
// missing (whether that's the top of the stack or just a gap), and a bottom
// cap whenever the layer below it is missing, exposing its underside over a
// gap. If layer 0 itself is broken, a flat ground tile (drawn in a dull grey)
// is added underneath so there's still ground to walk on, matching
// GetGroundHeightAt's height-0 for that case. Chunked further by
// MaxBlocksPerMesh if a single base face's prism count needs more than one
// Mesh's worth of 16-bit-indexable vertices.
static ChunkMeshData[] BuildChunkMeshData(
    int baseFaceId, Vector3[] vertices, (int A, int B, int C)[] triangles, Face[] faces,
    List<int>[] trianglesByBaseFace, LatticeCell[] latticeCells, float blockHeight,
    HashSet<(int TriIdx, int CellIdx, int Layer)> brokenLayers, int layersPerColumn)
{
    List<int> triIndices = trianglesByBaseFace[baseFaceId];
    int blocksPerTriangle = latticeCells.Length;
    long totalColumns = (long)triIndices.Count * blocksPerTriangle;
    if (totalColumns == 0) return [];

    var instances = new List<BlockInstance>();
    for (int triLocal = 0; triLocal < triIndices.Count; triLocal++)
    {
        int triIdx = triIndices[triLocal];
        for (int cellIdx = 0; cellIdx < blocksPerTriangle; cellIdx++)
        {
            long columnIndex = (long)triLocal * blocksPerTriangle + cellIdx;
            float hue = columnIndex / (float)totalColumns * 360f;

            bool LayerBroken(int layer) => brokenLayers.Contains((triIdx, cellIdx, layer));

            if (LayerBroken(0))
                instances.Add(new BlockInstance(triIdx, cellIdx, 0, 0, true, false, hue, true));

            for (int layer = 0; layer < layersPerColumn; layer++)
            {
                if (LayerBroken(layer)) continue;
                bool topExposed = layer == layersPerColumn - 1 || LayerBroken(layer + 1);
                bool bottomExposed = layer > 0 && LayerBroken(layer - 1);
                instances.Add(new BlockInstance(triIdx, cellIdx, layer, layer + 1, topExposed, bottomExposed, hue, false));
            }
        }
    }

    int chunkCount = (instances.Count + MaxBlocksPerMesh - 1) / MaxBlocksPerMesh;
    var meshes = new ChunkMeshData[chunkCount];
    ushort[] fullTemplate = BuildBlockIndexTemplateFull();
    ushort[] wallsOnlyTemplate = BuildBlockIndexTemplateWallsOnly();
    ushort[] fullWithBottomTemplate = BuildBlockIndexTemplateFullWithBottom();
    ushort[] wallsWithBottomTemplate = BuildBlockIndexTemplateWallsWithBottom();

    static ushort[] TemplateFor(BlockInstance inst, ushort[] full, ushort[] wallsOnly, ushort[] fullBottom, ushort[] wallsBottom) =>
        (inst.IncludeCap, inst.IncludeBottomCap) switch
        {
            (true, true) => fullBottom,
            (true, false) => full,
            (false, true) => wallsBottom,
            (false, false) => wallsOnly,
        };

    static int TriangleCountFor(BlockInstance inst)
    {
        int count = TrianglesPerBlockWallsOnly;
        if (inst.IncludeCap) count++;
        if (inst.IncludeBottomCap) count++;
        return count;
    }

    for (int chunk = 0; chunk < chunkCount; chunk++)
    {
        int startInstance = chunk * MaxBlocksPerMesh;
        int instanceCount = Math.Min(MaxBlocksPerMesh, instances.Count - startInstance);
        int vertexCount = instanceCount * VerticesPerBlock;

        int totalTriangles = 0;
        for (int i = 0; i < instanceCount; i++)
            totalTriangles += TriangleCountFor(instances[startInstance + i]);

        float[] positions = new float[vertexCount * 3];
        byte[] colors = new byte[vertexCount * 4];
        float[] texcoords = new float[vertexCount * 2];
        ushort[] indices = new ushort[totalTriangles * 3];

        int indexCursor = 0;
        for (int localBlock = 0; localBlock < instanceCount; localBlock++)
        {
            BlockInstance inst = instances[startInstance + localBlock];

            var (ia, ib, ic) = triangles[inst.TriIdx];
            Vector3 a = vertices[ia], b = vertices[ib], c = vertices[ic];
            Vector3 normal = faces[inst.TriIdx].Normal;
            Vector3 floorOffset = normal * blockHeight * inst.FloorLayer;
            Vector3 roofOffset = normal * blockHeight * inst.RoofLayer;

            LatticeCell cell = latticeCells[inst.CellIdx];
            Vector3 basep0 = LatticePoint(a, b, c, cell.U0, cell.V0);
            Vector3 basep1 = LatticePoint(a, b, c, cell.U1, cell.V1);
            Vector3 basep2 = LatticePoint(a, b, c, cell.U2, cell.V2);
            Vector3 p0 = basep0 + floorOffset, p1 = basep1 + floorOffset, p2 = basep2 + floorOffset;
            Vector3 r0 = basep0 + roofOffset, r1 = basep1 + roofOffset, r2 = basep2 + roofOffset;

            Color topCol = inst.Bare ? new Color(70, 70, 70, 255) : HsvColor(inst.Hue, 0.55f, 0.85f);
            Color sideCol = inst.Bare ? topCol : HsvColor(inst.Hue, 0.65f, 0.5f); // darker/more saturated than the top

            // Atlas tiles: 0 = grass top, 1 = dirt side, 2 = bare ground -
            // a bare instance's cap uses the bare tile instead of grass.
            float topTile = inst.Bare ? AtlasTileBare : AtlasTileTop;
            float sideTile = inst.Bare ? AtlasTileBare : AtlasTileSide;

            int vertexBase = localBlock * VerticesPerBlock;
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 0, p0, sideCol, 0f, 0f, sideTile);
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 1, p1, sideCol, 1f, 0f, sideTile);
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 2, p2, sideCol, 0f, 1f, sideTile);
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 3, r0, sideCol, 0f, 0f, sideTile);
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 4, r1, sideCol, 1f, 0f, sideTile);
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 5, r2, sideCol, 0f, 1f, sideTile);
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 6, r0, topCol, 0f, 0f, topTile);
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 7, r1, topCol, 1f, 0f, topTile);
            WriteBlockVertex(positions, colors, texcoords, vertexBase + 8, r2, topCol, 0f, 1f, topTile);

            ushort[] template = TemplateFor(inst, fullTemplate, wallsOnlyTemplate, fullWithBottomTemplate, wallsWithBottomTemplate);
            foreach (ushort t in template)
                indices[indexCursor++] = (ushort)(vertexBase + t);
        }

        meshes[chunk] = new ChunkMeshData(positions, colors, texcoords, indices, vertexCount, totalTriangles);
    }

    return meshes;
}

static void WriteBlockVertex(
    float[] positions, byte[] colors, float[] texcoords, int vertexIndex,
    Vector3 v, Color col, float u, float w, float tileU)
{
    int p = vertexIndex * 3;
    positions[p + 0] = v.X; positions[p + 1] = v.Y; positions[p + 2] = v.Z;

    int uv = vertexIndex * 2;
    texcoords[uv + 0] = tileU + u * AtlasTileWidth; texcoords[uv + 1] = w;

    int cIdx = vertexIndex * 4;
    colors[cIdx + 0] = col.R;
    colors[cIdx + 1] = col.G;
    colors[cIdx + 2] = col.B;
    colors[cIdx + 3] = col.A;
}

readonly record struct Face(
    int VA, int VB, int VC, Vector3 Normal, float PlaneD,
    int NeighborBC, int NeighborCA, int NeighborAB, int BaseFaceId);

// One prism to be emitted into a chunk's mesh: either one surviving layer of
// a column's stack (FloorLayer/RoofLayer count layers up from the ground, in
// units of BlockHeight) - capped on top if the layer above is missing and/or
// on the bottom if the layer below is missing - or, when layer 0 itself is
// broken, a single flat bare-ground tile (FloorLayer = RoofLayer = 0).
readonly record struct BlockInstance(
    int TriIdx, int CellIdx, int FloorLayer, int RoofLayer, bool IncludeCap, bool IncludeBottomCap, float Hue, bool Bare);

// One small triangle within a base mesh triangle's barycentric lattice,
// described as fractional (u, v) coordinates along edges AB/AC of its
// parent. Precomputed once and reused for every source triangle in a chunk.
readonly record struct LatticeCell(float U0, float V0, float U1, float V1, float U2, float V2);

// Plain-data mesh payload - only managed arrays, no raylib/GL calls - so it
// can be built on a background thread. UploadChunkMeshData does the
// GL-context-bound part (Marshal alloc + UploadMesh) on the main thread.
readonly record struct ChunkMeshData(
    float[] Positions, byte[] Colors, float[] TexCoords, ushort[] Indices, int VertexCount, int TriangleCount);
