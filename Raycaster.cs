using System;
using Microsoft.Xna.Framework;

namespace Trojkat;

public struct RaycastHit
{
    public bool Found;
    public int X, Y, Z;
    public int NormalX, NormalY, NormalZ;
    public int Col;
}

// Amanatides-Woo grid DDA: walks the integer cube lattice cell by cell along the ray,
// stopping at the first cell with either triangle solid. The lattice is axis-aligned only
// in grid-INDEX space (world space is sheared — see TriangleGrid), so the ray is transformed
// into index space first; since that transform is linear, a unit-length world direction still
// makes the DDA's "traveled" parameter equal true world-space distance; see TriangleGrid.
// Once a cell is hit, the exact XZ entry point (in index space) picks out which of the two
// triangles was actually struck.
public static class Raycaster
{
    public static RaycastHit Cast(Chunk chunk, Vector3 worldOrigin, Vector3 worldDirection, float maxDistance)
    {
        worldDirection = Vector3.Normalize(worldDirection);

        Vector2 indexOriginXZ = TriangleGrid.WorldToIndex(worldOrigin.X, worldOrigin.Z);
        Vector2 indexDirXZ = TriangleGrid.WorldToIndex(worldDirection.X, worldDirection.Z);
        Vector3 origin = new(indexOriginXZ.X, worldOrigin.Y, indexOriginXZ.Y);
        Vector3 direction = new(indexDirXZ.X, worldDirection.Y, indexDirXZ.Y);

        int x = (int)MathF.Floor(origin.X);
        int y = (int)MathF.Floor(origin.Y);
        int z = (int)MathF.Floor(origin.Z);

        int stepX = Math.Sign(direction.X);
        int stepY = Math.Sign(direction.Y);
        int stepZ = Math.Sign(direction.Z);

        float tDeltaX = direction.X != 0 ? MathF.Abs(1f / direction.X) : float.PositiveInfinity;
        float tDeltaY = direction.Y != 0 ? MathF.Abs(1f / direction.Y) : float.PositiveInfinity;
        float tDeltaZ = direction.Z != 0 ? MathF.Abs(1f / direction.Z) : float.PositiveInfinity;

        float tMaxX = NextBoundary(origin.X, x, stepX, direction.X);
        float tMaxY = NextBoundary(origin.Y, y, stepY, direction.Y);
        float tMaxZ = NextBoundary(origin.Z, z, stepZ, direction.Z);

        int normalX = 0, normalY = 0, normalZ = 0;
        float traveled = 0f;

        while (traveled <= maxDistance)
        {
            if (!chunk.IsCellEmpty(x, y, z))
            {
                Vector3 entry = origin + direction * traveled;
                int col = HitTriangleCol(chunk, x, y, z, entry.X - x, entry.Z - z);

                return new RaycastHit
                {
                    Found = true,
                    X = x, Y = y, Z = z,
                    NormalX = normalX, NormalY = normalY, NormalZ = normalZ,
                    Col = col,
                };
            }

            if (tMaxX < tMaxY && tMaxX < tMaxZ)
            {
                x += stepX;
                traveled = tMaxX;
                tMaxX += tDeltaX;
                normalX = -stepX; normalY = 0; normalZ = 0;
            }
            else if (tMaxY < tMaxZ)
            {
                y += stepY;
                traveled = tMaxY;
                tMaxY += tDeltaY;
                normalX = 0; normalY = -stepY; normalZ = 0;
            }
            else
            {
                z += stepZ;
                traveled = tMaxZ;
                tMaxZ += tDeltaZ;
                normalX = 0; normalY = 0; normalZ = -stepZ;
            }
        }

        return new RaycastHit { Found = false };
    }

    // Given the fractional entry point (lx, lz in [0,1]) within a cell, figure out which
    // triangle that point falls in; fall back to whichever one is actually solid if the
    // point lands in the empty one (the DDA is cube-level, so this is approximate).
    private static int HitTriangleCol(Chunk chunk, int x, int y, int z, float lx, float lz)
    {
        int o = lx + lz <= 1f ? 0 : 1;
        int geometric = 2 * x + o;

        if (chunk.Get(geometric, y, z) != 0) return geometric;

        int other = 2 * x + (1 - o);
        return chunk.Get(other, y, z) != 0 ? other : geometric;
    }

    // Which triangle a placed block should land in, given the hit face's cube-normal:
    // straight up/down keeps the same triangle at the adjacent Y layer; an X/Z face
    // (an "outer" edge of the hit triangle) reuses TriangleGrid's own edge table so this
    // doesn't re-derive the adjacency the mesher already knows.
    public static (int Col, int Y, int Row) GetPlacementTarget(RaycastHit hit)
    {
        if (hit.NormalY != 0) return (hit.Col, hit.Y + hit.NormalY, hit.Z);

        foreach (var edge in TriangleGrid.Edges(hit.Col, hit.Z))
        {
            if ((edge.NormalDx, edge.NormalDz) == (hit.NormalX, hit.NormalZ) && (edge.NormalDx != 0 || edge.NormalDz != 0))
                return (edge.NeighborCol, hit.Y, edge.NeighborRow);
        }

        return (hit.Col, hit.Y, hit.Z);
    }

    private static float NextBoundary(float originComponent, int cell, int step, float dirComponent)
    {
        if (dirComponent == 0) return float.PositiveInfinity;
        float boundary = step > 0 ? cell + 1 : cell;
        return MathF.Abs((boundary - originComponent) / dirComponent);
    }
}
