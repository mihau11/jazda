using System;
using Microsoft.Xna.Framework;

namespace Trojkat;

public struct RaycastHit
{
    public bool Found;
    public int Col, Y, Z;
    public int PlacementCol, PlacementY, PlacementZ;
}

// Walks the triangulated grid one triangle (or Y layer) at a time along the ray, rather
// than DDA-stepping whole cube columns and guessing which triangle got hit afterwards —
// the walker always knows exactly which triangle it occupies, either from the unconditional
// geometric split at the ray's start or from the edge it just crossed into, so there's no
// "which triangle did I actually hit" ambiguity to get wrong.
//
// The lattice is axis-aligned only in grid-INDEX space (world space is sheared — see
// TriangleGrid), so the ray is transformed into index space first; since that transform is
// linear, a unit-length world direction still makes the walk's "traveled" parameter equal
// true world-space distance; see TriangleGrid.
public static class Raycaster
{
    private const float TEpsilon = 1e-4f;
    private const float SEpsilon = 1e-4f;
    private const float DetEpsilon = 1e-6f;
    private const int MaxIterations = 8192;

    public static RaycastHit Cast(Chunk chunk, Vector3 worldOrigin, Vector3 worldDirection, float maxDistance)
    {
        worldDirection = Vector3.Normalize(worldDirection);

        Vector2 O = TriangleGrid.WorldToIndex(worldOrigin.X, worldOrigin.Z);
        Vector2 D = TriangleGrid.WorldToIndex(worldDirection.X, worldDirection.Z);
        float originY = worldOrigin.Y;
        float dirY = worldDirection.Y;

        // Starting triangle: the same lx+lz<=1 split TriangleGrid.Corners encodes, computed
        // unconditionally from geometry alone - never a guess based on what's solid.
        int cellX = (int)MathF.Floor(O.X);
        int row = (int)MathF.Floor(O.Y);
        int y = (int)MathF.Floor(originY);
        float lx = O.X - cellX;
        float lz = O.Y - row;
        int col = 2 * cellX + (lx + lz <= 1f ? 0 : 1);

        int stepY = Math.Sign(dirY);
        float tDeltaY = dirY != 0 ? MathF.Abs(1f / dirY) : float.PositiveInfinity;
        float tMaxY = NextBoundary(originY, y, stepY, dirY);

        int prevCol = col, prevY = y, prevRow = row;
        float traveled = 0f;

        for (int iteration = 0; iteration < MaxIterations && traveled <= maxDistance; iteration++)
        {
            if (chunk.Get(col, y, row) != 0)
            {
                return new RaycastHit
                {
                    Found = true,
                    Col = col, Y = y, Z = row,
                    PlacementCol = prevCol, PlacementY = prevY, PlacementZ = prevRow,
                };
            }

            prevCol = col; prevY = y; prevRow = row;

            float bestT = tMaxY;
            bool bestIsEdge = false;
            TriangleEdge bestEdge = default;

            foreach (var edge in TriangleGrid.Edges(col, row))
            {
                if (TryIntersect(O, D, edge, traveled, out float t) && t < bestT)
                {
                    bestT = t;
                    bestIsEdge = true;
                    bestEdge = edge;
                }
            }

            traveled = bestT;

            if (bestIsEdge)
            {
                col = bestEdge.NeighborCol;
                row = bestEdge.NeighborRow;
            }
            else
            {
                y += stepY;
                tMaxY += tDeltaY;
            }
        }

        return new RaycastHit { Found = false };
    }

    // 2D ray-vs-segment intersection in index space: solve O + t*D = A + s*(B-A) for (t, s)
    // via the standard cross-product formulation. Valid only strictly ahead of where we
    // already are (t > traveled) and within the segment's span (s in [0,1]).
    private static bool TryIntersect(Vector2 O, Vector2 D, TriangleEdge edge, float traveled, out float t)
    {
        Vector2 e = edge.B - edge.A;
        float det = Cross(e, D);
        if (MathF.Abs(det) < DetEpsilon)
        {
            t = 0f;
            return false;
        }

        Vector2 ao = edge.A - O;
        t = Cross(e, ao) / det;
        float s = Cross(D, ao) / det;

        return t > traveled + TEpsilon && s >= -SEpsilon && s <= 1f + SEpsilon;
    }

    private static float Cross(Vector2 a, Vector2 b) => a.X * b.Y - a.Y * b.X;

    public static (int Col, int Y, int Row) GetPlacementTarget(RaycastHit hit) =>
        (hit.PlacementCol, hit.PlacementY, hit.PlacementZ);

    private static float NextBoundary(float originComponent, int cell, int step, float dirComponent)
    {
        if (dirComponent == 0) return float.PositiveInfinity;
        float boundary = step > 0 ? cell + 1 : cell;
        return MathF.Abs((boundary - originComponent) / dirComponent);
    }
}
