using System;

namespace Trojkat;

public static class TerrainGenerator
{
    public static int[,] Generate(Chunk chunk, int seed)
    {
        var heightNoise = new SimpleNoise(seed);
        var halfNoise = new SimpleNoise(seed + 9973);

        var heights = new int[Chunk.Width, Chunk.Depth];

        for (int x = 0; x < Chunk.Width; x++)
        for (int z = 0; z < Chunk.Depth; z++)
        {
            float n = heightNoise.Noise2D(x * 0.06f, z * 0.06f);
            int height = 6 + (int)MathF.Round(n * 1.5f);
            height = Math.Clamp(height, 1, Chunk.Height - 1);
            heights[x, z] = height;

            for (int y = 0; y < height; y++)
            {
                byte block = y >= height - 3 ? (byte)BlockType.Dirt : (byte)BlockType.Stone;
                SetBoth(chunk, x, y, z, block);
            }

            // The surface layer leaves each triangle solid independently, so the terrain
            // reads as a field of individual wedges rather than a flat cube-tiled cap.
            float h = halfNoise.Noise2D(x * 0.4f, z * 0.4f);
            bool aSolid = h > -0.3f;
            bool bSolid = h < 0.3f;
            if (aSolid) chunk.Set(2 * x, height, z, (byte)BlockType.Grass);
            if (bSolid) chunk.Set(2 * x + 1, height, z, (byte)BlockType.Grass);
        }

        return heights;
    }

    private static void SetBoth(Chunk chunk, int x, int y, int z, byte value)
    {
        chunk.Set(2 * x, y, z, value);
        chunk.Set(2 * x + 1, y, z, value);
    }
}
