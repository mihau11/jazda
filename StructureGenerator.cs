using System;
using System.Collections.Generic;
using Microsoft.Xna.Framework;

namespace Trojkat;

// Scatters WWI battlefield dressing across the terrain produced by
// TerrainGenerator: dug trenches with sandbag parapets, ruined brick houses,
// and wrecked tanks sitting in scorched ground. Operates at the same
// per-(x,z) "cell" granularity as TerrainGenerator (both triangles of a
// column set together via SetBoth).
public static class StructureGenerator
{
    private const int Margin = 10;
    private const float MinCenterDistance = 14f;

    private static readonly (int Dx, int Dz)[] Directions =
    {
        (1, 0), (-1, 0), (0, 1), (0, -1),
    };

    public static void Generate(Chunk chunk, int[,] heights, int seed)
    {
        var rng = new Random(seed + 424242);
        var placedCenters = new List<Vector2>();

        PlaceTrenches(chunk, heights, rng, placedCenters, count: 3);
        PlaceRuinedHouses(chunk, heights, rng, placedCenters, count: 4);
        PlaceTankWrecks(chunk, heights, rng, placedCenters, count: 5);
    }

    private static void SetBoth(Chunk chunk, int x, int y, int z, byte value)
    {
        chunk.Set(2 * x, y, z, value);
        chunk.Set(2 * x + 1, y, z, value);
    }

    private static bool InCellBounds(int x, int z) =>
        x >= 0 && x < Chunk.Width && z >= 0 && z < Chunk.Depth;

    private static bool TryClaim(List<Vector2> placedCenters, int x, int z)
    {
        var candidate = new Vector2(x, z);
        foreach (var c in placedCenters)
            if (Vector2.Distance(c, candidate) < MinCenterDistance) return false;

        placedCenters.Add(candidate);
        return true;
    }

    // ---------------------------------------------------------------- trenches

    private static void PlaceTrenches(Chunk chunk, int[,] heights, Random rng,
        List<Vector2> placedCenters, int count)
    {
        int placed = 0;
        int attempts = 0;
        while (placed < count && attempts < count * 20)
        {
            attempts++;
            int startX = rng.Next(Margin, Chunk.Width - Margin);
            int startZ = rng.Next(Margin, Chunk.Depth - Margin);
            if (!TryClaim(placedCenters, startX, startZ)) continue;

            int dirIndex = rng.Next(Directions.Length);
            int length = rng.Next(15, 26);

            int x = startX, z = startZ;
            for (int step = 0; step < length; step++)
            {
                if (!InCellBounds(x, z)) break;

                if (step > 0 && rng.Next(6) == 0)
                    dirIndex = rng.Next(Directions.Length);

                var (dx, dz) = Directions[dirIndex];
                int px = -dz, pz = dx; // perpendicular to travel direction

                DigTrenchCell(chunk, heights, x, z, px, pz, rng);

                x += dx;
                z += dz;
            }

            placed++;
        }
    }

    // Trench floor is 2 cells wide (perpendicular offsets 0 and 1); sandbag
    // parapets sit just outside that, at offsets -1 and 2.
    private static void DigTrenchCell(Chunk chunk, int[,] heights, int x, int z, int px, int pz, Random rng)
    {
        for (int widthOffset = 0; widthOffset <= 1; widthOffset++)
        {
            int wx = x + px * widthOffset;
            int wz = z + pz * widthOffset;
            if (!InCellBounds(wx, wz)) continue;

            int height = heights[wx, wz];
            int floor = Math.Max(height - 2, 0);
            for (int y = floor + 1; y <= height; y++)
                SetBoth(chunk, wx, y, wz, (byte)BlockType.Air);
        }

        foreach (int parapetOffset in new[] { -1, 2 })
        {
            int wx = x + px * parapetOffset;
            int wz = z + pz * parapetOffset;
            if (!InCellBounds(wx, wz)) continue;

            int height = heights[wx, wz];
            SetBoth(chunk, wx, height, wz, (byte)BlockType.Sandbags);

            if (rng.Next(3) == 0 && height + 1 < Chunk.Height)
                SetBoth(chunk, wx, height + 1, wz, (byte)BlockType.BarbedWire);
        }
    }

    // ------------------------------------------------------------- ruined houses

    private static void PlaceRuinedHouses(Chunk chunk, int[,] heights, Random rng,
        List<Vector2> placedCenters, int count)
    {
        int placed = 0;
        int attempts = 0;
        while (placed < count && attempts < count * 20)
        {
            attempts++;
            int size = rng.Next(5, 9); // 5..8
            int centerX = rng.Next(Margin + size, Chunk.Width - Margin - size);
            int centerZ = rng.Next(Margin + size, Chunk.Depth - Margin - size);
            if (!TryClaim(placedCenters, centerX, centerZ)) continue;

            int x0 = centerX - size / 2;
            int z0 = centerZ - size / 2;
            int x1 = x0 + size - 1;
            int z1 = z0 + size - 1;
            int reference = heights[centerX, centerZ];

            for (int x = x0; x <= x1; x++)
            for (int z = z0; z <= z1; z++)
            {
                if (!InCellBounds(x, z)) continue;

                int current = heights[x, z];
                if (current < reference)
                    for (int y = current + 1; y <= reference; y++)
                        SetBoth(chunk, x, y, z, (byte)BlockType.Dirt);

                bool isPerimeter = x == x0 || x == x1 || z == z0 || z == z1;
                if (!isPerimeter) continue;
                if (rng.Next(100) < 20) continue; // ruined gap in the wall

                int wallHeight = rng.Next(1, 5); // 1..4
                for (int h = 1; h <= wallHeight; h++)
                {
                    int y = reference + h;
                    if (y >= Chunk.Height) break;
                    SetBoth(chunk, x, y, z, (byte)BlockType.Brick);
                }
            }

            int debrisCount = rng.Next(2, 6);
            for (int i = 0; i < debrisCount; i++)
            {
                int rx = rng.Next(x0 + 1, x1);
                int rz = rng.Next(z0 + 1, z1);
                int y = reference + 1;
                if (InCellBounds(rx, rz) && y < Chunk.Height)
                    SetBoth(chunk, rx, y, rz, (byte)BlockType.Wood);
            }

            placed++;
        }
    }

    // -------------------------------------------------------------- tank wrecks

    private static void PlaceTankWrecks(Chunk chunk, int[,] heights, Random rng,
        List<Vector2> placedCenters, int count)
    {
        int placed = 0;
        int attempts = 0;
        while (placed < count && attempts < count * 20)
        {
            attempts++;
            int cx = rng.Next(Margin, Chunk.Width - Margin);
            int cz = rng.Next(Margin, Chunk.Depth - Margin);
            if (!TryClaim(placedCenters, cx, cz)) continue;

            bool alongX = rng.Next(2) == 0;
            int reference = heights[cx, cz];

            for (int li = -2; li <= 2; li++)
            for (int wi = -1; wi <= 1; wi++)
            {
                var (x, z) = alongX ? (cx + li, cz + wi) : (cx + wi, cz + li);
                if (!InCellBounds(x, z)) continue;

                for (int h = 1; h <= 2; h++)
                {
                    int y = reference + h;
                    if (y >= Chunk.Height) break;
                    SetBoth(chunk, x, y, z, (byte)BlockType.Metal);
                }
            }

            if (rng.Next(100) < 80) // occasionally the turret has been blown off
            {
                var (tx, tz) = alongX ? (cx + 1, cz) : (cx, cz + 1);
                int ty = reference + 3;
                if (InCellBounds(tx, tz) && ty < Chunk.Height)
                    SetBoth(chunk, tx, ty, tz, (byte)BlockType.Metal);
            }

            int radius = rng.Next(4, 6);
            for (int dx = -radius; dx <= radius; dx++)
            for (int dz = -radius; dz <= radius; dz++)
            {
                if (dx * dx + dz * dz > radius * radius) continue;
                if (rng.Next(100) < 15) continue; // ragged scorch edge

                int x = cx + dx, z = cz + dz;
                if (!InCellBounds(x, z)) continue;

                int li = alongX ? dx : dz;
                int wi = alongX ? dz : dx;
                if (li >= -2 && li <= 2 && wi >= -1 && wi <= 1) continue; // skip hull footprint

                int height = heights[x, z];
                SetBoth(chunk, x, height, z, (byte)BlockType.ScorchedGround);
            }

            placed++;
        }
    }
}
