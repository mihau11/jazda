using System;

namespace Trojkat;

// Small self-contained 2D value-noise: lattice of pseudo-random values,
// bilinearly interpolated with a smoothstep easing curve. Output in [-1, 1].
public class SimpleNoise
{
    private readonly int _seed;

    public SimpleNoise(int seed)
    {
        _seed = seed;
    }

    private float LatticeValue(int x, int z)
    {
        unchecked
        {
            int h = x * 374761393 + z * 668265263 + _seed * 1274126177;
            h = (h ^ (h >> 13)) * 1274126177;
            h ^= h >> 16;
            // map to [-1, 1]
            return (h & 0xFFFFFF) / (float)0xFFFFFF * 2f - 1f;
        }
    }

    private static float Smoothstep(float t) => t * t * (3f - 2f * t);

    public float Noise2D(float x, float z)
    {
        int x0 = (int)MathF.Floor(x);
        int z0 = (int)MathF.Floor(z);
        int x1 = x0 + 1;
        int z1 = z0 + 1;

        float tx = Smoothstep(x - x0);
        float tz = Smoothstep(z - z0);

        float v00 = LatticeValue(x0, z0);
        float v10 = LatticeValue(x1, z0);
        float v01 = LatticeValue(x0, z1);
        float v11 = LatticeValue(x1, z1);

        float ix0 = v00 + (v10 - v00) * tx;
        float ix1 = v01 + (v11 - v01) * tx;

        return ix0 + (ix1 - ix0) * tz;
    }
}
