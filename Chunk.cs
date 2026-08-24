namespace Trojkat;

public class Chunk
{
    public const int Width = 128;  // X
    public const int Height = 11;  // Y
    public const int Depth = 128;  // Z
    public const int TriWidth = Width * 2; // each X column holds 2 independent triangles

    // The atomic placeable/breakable unit is one triangle, addressed directly by
    // its own column — no pairing with a sibling half.
    private readonly byte[,,] _cells = new byte[TriWidth, Height, Depth];

    public bool IsDirty { get; set; } = true;

    public byte Get(int col, int y, int row) =>
        InBounds(col, y, row) ? _cells[col, y, row] : (byte)0;

    public void Set(int col, int y, int row, byte value)
    {
        if (!InBounds(col, y, row)) return;
        _cells[col, y, row] = value;
        IsDirty = true;
    }

    public static bool InBounds(int col, int y, int row) =>
        col >= 0 && col < TriWidth && y >= 0 && y < Height && row >= 0 && row < Depth;
}
