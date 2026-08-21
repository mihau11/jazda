namespace Trojkat;

public enum FaceKind
{
    Top,
    Bottom,
    Side,
}

// Looks up UV sub-rects in the 3x2 texture atlas
// (tile 0=grass-top, 1=grass-side, 2=dirt, 3=stone, 4=wood, 5=leaves).
public static class AtlasUV
{
    private const int Cols = 3;
    private const int Rows = 2;

    private static int TileIndex(BlockType type, FaceKind face)
    {
        if (type == BlockType.Grass)
        {
            return face switch
            {
                FaceKind.Top => 0,
                FaceKind.Bottom => 2,
                _ => 1,
            };
        }

        return type switch
        {
            BlockType.Dirt => 2,
            BlockType.Stone => 3,
            BlockType.Wood => 4,
            BlockType.Leaves => 5,
            _ => 3,
        };
    }

    public static (float U0, float V0, float U1, float V1) GetRect(BlockType type, FaceKind face)
    {
        int tile = TileIndex(type, face);
        int tx = tile % Cols;
        int ty = tile / Cols;

        float u0 = tx / (float)Cols;
        float v0 = ty / (float)Rows;
        float u1 = (tx + 1) / (float)Cols;
        float v1 = (ty + 1) / (float)Rows;

        return (u0, v0, u1, v1);
    }
}
