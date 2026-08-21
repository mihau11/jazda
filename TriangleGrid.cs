using Microsoft.Xna.Framework;

namespace Trojkat;

// Maps integer grid indices to world XZ via a shear, turning the index-space unit square
// into a rhombus of two equilateral triangles (see VoxelMesher for the uniform diagonal
// split that exploits this). The map is purely linear (no translation), so it can transform
// both points and direction vectors — the latter needed by Raycaster.
public static class TriangleGrid
{
    public const float RowHeight = 0.8660254f; // sqrt(3)/2

    public static Vector2 IndexToWorld(float ix, float iz) => new(ix + 0.5f * iz, iz * RowHeight);

    public static Vector2 WorldToIndex(float wx, float wz)
    {
        float iz = wz / RowHeight;
        return new Vector2(wx - 0.5f * iz, iz);
    }

    // Every triangle is addressed by a single column `col = 2*x + o` (o=0 "up", o=1
    // "down") and `row`, instead of an (x, half) pair — this table is the one place
    // that knows how a triangle's 3 edges map to its 3 neighbors, shared by the
    // mesher (which needs all 3) and the raycaster (which needs the one matching a
    // given cube-face normal).
    public static (Vector2 P1, Vector2 P2, Vector2 P3) Corners(int col, int row)
    {
        int x = col >> 1;
        bool up = (col & 1) == 0;
        return up
            ? (new Vector2(x, row), new Vector2(x + 1, row), new Vector2(x, row + 1))
            : (new Vector2(x + 1, row), new Vector2(x + 1, row + 1), new Vector2(x, row + 1));
    }

    public static TriangleEdge[] Edges(int col, int row)
    {
        var (p1, p2, p3) = Corners(col, row);
        bool up = (col & 1) == 0;
        return up
            ? new[]
            {
                new TriangleEdge(p1, p2, col + 1, row - 1, 0, -1),
                new TriangleEdge(p3, p1, col - 1, row, -1, 0),
                new TriangleEdge(p2, p3, col + 1, row, 0, 0),
            }
            : new[]
            {
                new TriangleEdge(p1, p2, col + 1, row, 1, 0),
                new TriangleEdge(p2, p3, col - 1, row + 1, 0, 1),
                new TriangleEdge(p3, p1, col - 1, row, 0, 0),
            };
    }
}

// One edge of a triangle cell: its two index-space endpoints, the (col, row) of the
// triangle across it, and the cube-face normal that edge corresponds to — (0,0) for
// the internal diagonal edge, which isn't a cube-axis face.
public readonly struct TriangleEdge
{
    public readonly Vector2 A, B;
    public readonly int NeighborCol, NeighborRow;
    public readonly int NormalDx, NormalDz;

    public TriangleEdge(Vector2 a, Vector2 b, int neighborCol, int neighborRow, int normalDx, int normalDz)
    {
        A = a;
        B = b;
        NeighborCol = neighborCol;
        NeighborRow = neighborRow;
        NormalDx = normalDx;
        NormalDz = normalDz;
    }
}
