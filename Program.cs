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

const float Radius = 32f;          // distance from center to each vertex
const float EyeHeight = 0.55f;     // how far above the face surface the camera floats
const float MoveSpeed = 6f;        // units per second
const float MouseSensitivity = 0.0035f;
const float UpSmoothing = 12f;     // camera-roll smoothing only, doesn't affect movement math
const int MaxTrianglesPerChunk = 1_000_000; // GPU mesh chunk size

const int DefaultSubdivisionLevels = 4;  // 20 * 4^levels faces; used when no CLI arg is given
const int MaxSubdivisionLevel = 11;      // 20 * 4^11 = ~84 million faces at the slider's top end (here be dragons)
const int WarnAtSubdivisionLevel = 7;    // levels at or above this will likely need a lot of RAM/time - flagged in red

// Optional: `dotnet run -- <levels>` skips the popup entirely for a quick start.
int? cliLevel = args.Length > 0 && int.TryParse(args[0], out int requested)
    ? Math.Clamp(requested, 0, MaxSubdivisionLevel)
    : null;

Raylib.InitWindow(1280, 720, "Icosahedron Walker");
Raylib.SetTargetFPS(60);
Rlgl.DisableBackfaceCulling(); // faces may be viewed from inside or outside

int subdivisionLevels = cliLevel ?? ShowSubdivisionPicker(DefaultSubdivisionLevels, MaxSubdivisionLevel, WarnAtSubdivisionLevel);

DrawLoadingScreen(subdivisionLevels);

var (vertices, triangles) = BuildIcosahedronMesh(Radius, subdivisionLevels);
Face[] faces = BuildFaces(vertices, triangles);
Mesh[] renderChunks = BuildRenderChunks(vertices, triangles);
Material fillMaterial = Raylib.LoadMaterialDefault();
Material wireMaterial = Raylib.LoadMaterialDefault();
unsafe { wireMaterial.Maps[0].Color = new Color(0, 0, 0, 60); }

Raylib.DisableCursor(); // switch to FPS mouse-look now that generation is done

// Authoritative player state: which face you're on, and where on its plane.
int currentFace = 0;
Vector3 groundPos = Centroid(vertices, faces[0]); // start at the middle of face 0
Vector3 visualUp = faces[0].Normal;               // smoothed, camera-only
float yaw = 0f;
float pitch = 0f;

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
    float dt = Raylib.GetFrameTime();

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

    Vector3 tentative = groundPos + move;

    // --- walk within the current face, unfolding across edges as needed ---
    for (int guard = 0; guard < 6; guard++)
    {
        Face f = faces[currentFace];
        Vector3 fa = vertices[f.VA], fb = vertices[f.VB], fc = vertices[f.VC];
        (float u, float v, float w) = Barycentric(tentative, fa, fb, fc);
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

        tentative = edgeStart + RotateAroundAxis(tentative - edgeStart, axis, angle);
        currentFace = neighbor;
    }

    groundPos = tentative;
    up = faces[currentFace].Normal;

    float smoothT = 1f - MathF.Exp(-UpSmoothing * dt);
    visualUp = Vector3.Normalize(Vector3.Lerp(visualUp, up, smoothT));

    // --- camera ---
    Vector3 eyePos = groundPos + up * EyeHeight;
    Vector3 lookDir = RotateAroundAxis(moveForward, moveRight, pitch);
    camera.Position = eyePos;
    camera.Target = eyePos + lookDir;
    camera.Up = visualUp;

    Raylib.BeginDrawing();
    Raylib.ClearBackground(new Color(15, 15, 25, 255));

    Raylib.BeginMode3D(camera);
    foreach (Mesh chunk in renderChunks) Raylib.DrawMesh(chunk, fillMaterial, Matrix4x4.Identity);
    Rlgl.EnableWireMode();
    foreach (Mesh chunk in renderChunks) Raylib.DrawMesh(chunk, wireMaterial, Matrix4x4.Identity);
    Rlgl.DisableWireMode();
    Raylib.EndMode3D();

    Raylib.DrawFPS(10, 10);
    Raylib.DrawText("WASD to walk, mouse to look, ESC to quit", 10, 40, 20, Color.RayWhite);
    Raylib.DrawText($"Face #{currentFace} / {faces.Length:N0}", 10, 65, 18, Color.LightGray);
    Raylib.EndDrawing();
}

Raylib.EnableCursor();
Raylib.CloseWindow();
return;

// ---------------------------------------------------------------------------
// Popup / loading screen
// ---------------------------------------------------------------------------

// A tiny pre-game popup: drag the slider (or use Left/Right arrows) to pick how
// finely the icosahedron is subdivided, see the resulting face count live, then
// press Enter or click Generate to build the globe.
static int ShowSubdivisionPicker(int initialLevel, int maxLevel, int warnAtLevel)
{
    int level = initialLevel;
    bool draggingHandle = false;

    const int trackX = 340, trackY = 360, trackWidth = 600, trackHeight = 10;
    const int handleRadius = 12;
    Rectangle generateButton = new(540, 440, 200, 50);

    while (!Raylib.WindowShouldClose())
    {
        int screenW = Raylib.GetScreenWidth();
        int centerXOffset = screenW / 2 - 640; // keep the layout centered if the window is resized
        int tx = trackX + centerXOffset;
        Rectangle button = generateButton with { X = generateButton.X + centerXOffset };

        Vector2 mouse = Raylib.GetMousePosition();
        float handleX = tx + (float)level / maxLevel * trackWidth;

        if (Raylib.IsMouseButtonPressed(MouseButton.Left) &&
            Vector2.Distance(mouse, new Vector2(handleX, trackY)) <= handleRadius + 6)
        {
            draggingHandle = true;
        }
        if (Raylib.IsMouseButtonReleased(MouseButton.Left)) draggingHandle = false;

        if (draggingHandle)
        {
            float t = Math.Clamp((mouse.X - tx) / trackWidth, 0f, 1f);
            level = (int)MathF.Round(t * maxLevel);
        }

        if (Raylib.IsKeyPressed(KeyboardKey.Right)) level = Math.Min(maxLevel, level + 1);
        if (Raylib.IsKeyPressed(KeyboardKey.Left)) level = Math.Max(0, level - 1);

        bool confirmed = Raylib.IsKeyPressed(KeyboardKey.Enter) ||
            (Raylib.IsMouseButtonPressed(MouseButton.Left) && Raylib.CheckCollisionPointRec(mouse, button));
        if (confirmed) return level;

        long faceCount = 20L * (long)Math.Pow(4, level);
        bool danger = level >= warnAtLevel;

        Raylib.BeginDrawing();
        Raylib.ClearBackground(new Color(15, 15, 25, 255));

        Raylib.DrawText("Icosahedron Walker", tx, 200, 40, Color.RayWhite);
        Raylib.DrawText("Choose subdivision level", tx, 260, 22, Color.LightGray);
        Raylib.DrawText($"Level {level}  -  {faceCount:N0} faces", tx, 300, 26, danger ? Color.Red : Color.SkyBlue);
        if (danger)
            Raylib.DrawText("Warning: needs a lot of RAM/time to generate at this size!", tx, 330, 20, Color.Red);

        Raylib.DrawRectangle(tx, trackY - trackHeight / 2, trackWidth, trackHeight, Color.DarkGray);
        for (int i = 0; i <= maxLevel; i++)
        {
            float tickX = tx + (float)i / maxLevel * trackWidth;
            Raylib.DrawRectangle((int)tickX - 1, trackY - trackHeight, 2, trackHeight * 2, Color.Gray);
        }
        Raylib.DrawCircle((int)handleX, trackY, handleRadius, Color.SkyBlue);

        Raylib.DrawRectangleRec(button, Color.DarkGreen);
        Raylib.DrawText("Generate", (int)button.X + 40, (int)button.Y + 14, 22, Color.RayWhite);

        Raylib.DrawText("Drag the slider or use Left/Right, then press Enter", tx, 510, 18, Color.Gray);

        Raylib.EndDrawing();
    }

    return initialLevel; // window was closed during the picker
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

static (Vector3[] Vertices, (int A, int B, int C)[] Triangles) BuildIcosahedronMesh(float radius, int levels)
{
    var (vertices, triangles) = BuildBaseIcosahedron(radius);
    for (int i = 0; i < levels; i++)
        (vertices, triangles) = Subdivide(vertices, triangles, radius);
    return (vertices, triangles);
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
static (Vector3[] Vertices, (int A, int B, int C)[] Triangles) Subdivide(
    Vector3[] vertices, (int A, int B, int C)[] triangles, float radius)
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
    int t = 0;
    foreach (var (a, b, c) in triangles)
    {
        int ab = Midpoint(a, b), bc = Midpoint(b, c), ca = Midpoint(c, a);
        newTriangles[t++] = (a, ab, ca);
        newTriangles[t++] = (b, bc, ab);
        newTriangles[t++] = (c, ca, bc);
        newTriangles[t++] = (ab, bc, ca);
    }

    return (newVertices.ToArray(), newTriangles);
}

// Builds per-face gameplay data: normal, plane distance, and the neighboring
// face across each edge. Adjacency is computed by sorting the 3 edges of every
// face (packed into a single long key) instead of a Dictionary<edge, List<face>>
// - at tens of millions of faces, a dictionary of heap-allocated lists is the
// single biggest memory hog; sorting flat arrays avoids that entirely.
static Face[] BuildFaces(Vector3[] vertices, (int A, int B, int C)[] triangles)
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
        faces[i] = new Face(ia, ib, ic, normal, planeD, neighborBC[i], neighborCA[i], neighborAB[i]);
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
// GPU mesh upload (batched: a handful of draw calls total, regardless of how
// many millions of triangles the globe has)
// ---------------------------------------------------------------------------

static Mesh[] BuildRenderChunks(Vector3[] vertices, (int A, int B, int C)[] triangles)
{
    int chunkCount = (triangles.Length + MaxTrianglesPerChunk - 1) / MaxTrianglesPerChunk;
    var meshes = new Mesh[chunkCount];

    for (int chunk = 0; chunk < chunkCount; chunk++)
    {
        int start = chunk * MaxTrianglesPerChunk;
        int count = Math.Min(MaxTrianglesPerChunk, triangles.Length - start);

        // Non-indexed triangle soup: raylib's Mesh.Indices is 16-bit, which can't
        // address the tens of millions of unique vertices a high subdivision
        // level needs, so each triangle gets its own 3 (unshared) vertices.
        float[] positions = new float[count * 9];
        byte[] colors = new byte[count * 12];

        for (int t = 0; t < count; t++)
        {
            var (ia, ib, ic) = triangles[start + t];
            Vector3 a = vertices[ia], b = vertices[ib], c = vertices[ic];
            Color col = HsvColor((start + t) / (float)triangles.Length * 360f, 0.55f, 0.85f);

            int p = t * 9;
            positions[p + 0] = a.X; positions[p + 1] = a.Y; positions[p + 2] = a.Z;
            positions[p + 3] = b.X; positions[p + 4] = b.Y; positions[p + 5] = b.Z;
            positions[p + 6] = c.X; positions[p + 7] = c.Y; positions[p + 8] = c.Z;

            int cIdx = t * 12;
            for (int v = 0; v < 3; v++)
            {
                colors[cIdx + v * 4 + 0] = col.R;
                colors[cIdx + v * 4 + 1] = col.G;
                colors[cIdx + v * 4 + 2] = col.B;
                colors[cIdx + v * 4 + 3] = col.A;
            }
        }

        Mesh mesh = new() { VertexCount = count * 3, TriangleCount = count };
        unsafe
        {
            IntPtr vPtr = Marshal.AllocHGlobal(positions.Length * sizeof(float));
            Marshal.Copy(positions, 0, vPtr, positions.Length);
            mesh.Vertices = (float*)vPtr;

            IntPtr cPtr = Marshal.AllocHGlobal(colors.Length);
            Marshal.Copy(colors, 0, cPtr, colors.Length);
            mesh.Colors = (byte*)cPtr;
        }

        Raylib.UploadMesh(ref mesh, false);
        meshes[chunk] = mesh;
    }

    return meshes;
}

readonly record struct Face(
    int VA, int VB, int VC, Vector3 Normal, float PlaneD,
    int NeighborBC, int NeighborCA, int NeighborAB);
