using System;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;

namespace Trojkat;

// First-person walking camera: WASD move, mouse look, Space to jump, Shift sprint.
// Position is the eye point; a capsule-ish AABB body (EyeHeight below it, PlayerRadius
// around it) is what actually collides with the voxel grid and falls under gravity.
public class Camera
{
    public Vector3 Position;
    public float Yaw;
    public float Pitch;
    public bool Grounded;

    private Vector3 _velocity;

    public const float EyeHeight = 1.6f;
    public const float PlayerHeight = 1.8f;
    public const float PlayerRadius = 0.3f;
    private const float Gravity = -20f;
    private const float JumpSpeed = 7f;
    private const float MaxFallSpeed = -40f;

    public Matrix Projection { get; }

    public Vector3 Forward => Vector3.Normalize(new Vector3(
        MathF.Cos(Pitch) * MathF.Sin(Yaw),
        MathF.Sin(Pitch),
        MathF.Cos(Pitch) * MathF.Cos(Yaw)));

    public Matrix View => Matrix.CreateLookAt(Position, Position + Forward, Vector3.Up);

    private bool _firstUpdate = true;

    public Camera(float aspectRatio, Vector3 startPosition)
    {
        Position = startPosition;
        Pitch = -0.6f; // start tilted down so the spawned-above-terrain view isn't just sky
        Projection = Matrix.CreatePerspectiveFieldOfView(MathHelper.PiOver4, aspectRatio, 0.05f, 500f);
    }

    public void Update(GameTime gameTime, KeyboardState kb, Chunk chunk, int windowCenterX, int windowCenterY)
    {
        float dt = (float)gameTime.ElapsedGameTime.TotalSeconds;
        float speed = kb.IsKeyDown(Keys.LeftShift) ? 8f : 5f;

        Vector3 forwardFlat = new(MathF.Sin(Yaw), 0, MathF.Cos(Yaw));
        Vector3 right = Vector3.Cross(forwardFlat, Vector3.Up);

        Vector3 moveDelta = Vector3.Zero;
        if (kb.IsKeyDown(Keys.W)) moveDelta += forwardFlat * speed * dt;
        if (kb.IsKeyDown(Keys.S)) moveDelta -= forwardFlat * speed * dt;
        if (kb.IsKeyDown(Keys.D)) moveDelta += right * speed * dt;
        if (kb.IsKeyDown(Keys.A)) moveDelta -= right * speed * dt;

        _velocity.Y = MathF.Max(_velocity.Y + Gravity * dt, MaxFallSpeed);
        if (Grounded && kb.IsKeyDown(Keys.Space))
        {
            _velocity.Y = JumpSpeed;
            Grounded = false;
        }

        // Resolve one axis at a time so sliding along a wall/floor doesn't get vetoed
        // by the other axis's collision.
        MoveAndCollide(chunk, new Vector3(moveDelta.X, 0, 0));
        MoveAndCollide(chunk, new Vector3(0, 0, moveDelta.Z));
        Grounded = false;
        MoveAndCollide(chunk, new Vector3(0, _velocity.Y * dt, 0));

        var mouse = Mouse.GetState();
        if (_firstUpdate)
        {
            // Discard the first frame's delta: the OS cursor can be anywhere on screen
            // when the window first gains focus, which would otherwise clobber Pitch/Yaw.
            _firstUpdate = false;
        }
        else
        {
            float dx = mouse.X - windowCenterX;
            float dy = mouse.Y - windowCenterY;
            Yaw -= dx * 0.0025f;
            Pitch = MathHelper.Clamp(Pitch - dy * 0.0025f, -MathHelper.PiOver2 + 0.01f, MathHelper.PiOver2 - 0.01f);
        }
        Mouse.SetPosition(windowCenterX, windowCenterY);
    }

    // Moves by delta (nonzero on at most one axis) and undoes it if the destination
    // overlaps solid terrain; a blocked vertical move also zeroes fall speed and, if
    // moving downward, marks the player as standing on ground.
    private void MoveAndCollide(Chunk chunk, Vector3 delta)
    {
        if (delta == Vector3.Zero) return;

        Vector3 candidate = Position + delta;
        if (!Collides(chunk, candidate))
        {
            Position = candidate;
            return;
        }

        if (delta.Y < 0) Grounded = true;
        if (delta.Y != 0) _velocity.Y = 0f;
    }

    // Approximates the player as a vertical box (PlayerRadius around, EyeHeight below
    // and PlayerHeight - EyeHeight above the eye) and tests it against every solid
    // triangle whose footprint could overlap that box — corner/edge sampling isn't
    // enough here because the grid is sheared, so a triangle can lie entirely under
    // the middle of the box without any single sample point landing inside it.
    private static bool Collides(Chunk chunk, Vector3 eyePosition)
    {
        float feetY = eyePosition.Y - EyeHeight;
        float topY = feetY + PlayerHeight;

        int minY = (int)MathF.Floor(feetY + 0.01f);
        int maxY = (int)MathF.Floor(topY - 0.01f);

        float minX = eyePosition.X - PlayerRadius;
        float maxX = eyePosition.X + PlayerRadius;
        float minZ = eyePosition.Z - PlayerRadius;
        float maxZ = eyePosition.Z + PlayerRadius;

        // The shear is linear, so the box's 4 corners bound its image in index space.
        Vector2 c00 = TriangleGrid.WorldToIndex(minX, minZ);
        Vector2 c10 = TriangleGrid.WorldToIndex(maxX, minZ);
        Vector2 c01 = TriangleGrid.WorldToIndex(minX, maxZ);
        Vector2 c11 = TriangleGrid.WorldToIndex(maxX, maxZ);

        int ixMin = (int)MathF.Floor(MathF.Min(MathF.Min(c00.X, c10.X), MathF.Min(c01.X, c11.X)));
        int ixMax = (int)MathF.Floor(MathF.Max(MathF.Max(c00.X, c10.X), MathF.Max(c01.X, c11.X)));
        int izMin = (int)MathF.Floor(MathF.Min(MathF.Min(c00.Y, c10.Y), MathF.Min(c01.Y, c11.Y)));
        int izMax = (int)MathF.Floor(MathF.Max(MathF.Max(c00.Y, c10.Y), MathF.Max(c01.Y, c11.Y)));

        for (int iy = minY; iy <= maxY; iy++)
        {
            for (int ix = ixMin; ix <= ixMax; ix++)
            {
                for (int iz = izMin; iz <= izMax; iz++)
                {
                    for (int half = 0; half < 2; half++)
                    {
                        int col = 2 * ix + half;
                        if (chunk.Get(col, iy, iz) == 0) continue;

                        var (p1, p2, p3) = TriangleGrid.Corners(col, iz);
                        Vector2 w1 = TriangleGrid.IndexToWorld(p1.X, p1.Y);
                        Vector2 w2 = TriangleGrid.IndexToWorld(p2.X, p2.Y);
                        Vector2 w3 = TriangleGrid.IndexToWorld(p3.X, p3.Y);

                        if (BoxOverlapsTriangle(minX, maxX, minZ, maxZ, w1, w2, w3)) return true;
                    }
                }
            }
        }

        return false;
    }

    // Separating-axis test between an axis-aligned box and a triangle in world XZ:
    // the box's own axes are covered by the bounding-box early-out, so only the
    // triangle's 3 edge normals need to be checked as candidate separating axes.
    private static bool BoxOverlapsTriangle(float minX, float maxX, float minZ, float maxZ,
        Vector2 p1, Vector2 p2, Vector2 p3)
    {
        float triMinX = MathF.Min(p1.X, MathF.Min(p2.X, p3.X));
        float triMaxX = MathF.Max(p1.X, MathF.Max(p2.X, p3.X));
        float triMinZ = MathF.Min(p1.Y, MathF.Min(p2.Y, p3.Y));
        float triMaxZ = MathF.Max(p1.Y, MathF.Max(p2.Y, p3.Y));
        if (maxX < triMinX || minX > triMaxX || maxZ < triMinZ || minZ > triMaxZ) return false;

        Span<Vector2> boxCorners = stackalloc Vector2[]
        {
            new Vector2(minX, minZ), new Vector2(maxX, minZ), new Vector2(minX, maxZ), new Vector2(maxX, maxZ),
        };
        Span<Vector2> triPoints = stackalloc Vector2[] { p1, p2, p3 };
        Span<Vector2> edges = stackalloc Vector2[] { p2 - p1, p3 - p2, p1 - p3 };

        foreach (Vector2 edge in edges)
        {
            Vector2 axis = new(-edge.Y, edge.X);

            float triMin = float.MaxValue, triMax = float.MinValue;
            foreach (Vector2 p in triPoints)
            {
                float d = Vector2.Dot(p, axis);
                triMin = MathF.Min(triMin, d);
                triMax = MathF.Max(triMax, d);
            }

            float boxMin = float.MaxValue, boxMax = float.MinValue;
            foreach (Vector2 c in boxCorners)
            {
                float d = Vector2.Dot(c, axis);
                boxMin = MathF.Min(boxMin, d);
                boxMax = MathF.Max(boxMax, d);
            }

            if (boxMax < triMin || boxMin > triMax) return false;
        }

        return true;
    }
}
