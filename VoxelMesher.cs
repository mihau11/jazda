using System.Collections.Generic;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace Trojkat;

public class MeshData
{
    public VertexPositionNormalTexture[] Vertices;
    public int[] Indices;
}

// Turns a Chunk's voxel data into triangles. Each triangle is an independent cell
// addressed by (col, y, row) — see TriangleGrid for the col = 2*x + orientation
// scheme and its per-triangle edge/neighbor table. A triangle's edge is only
// internal (skipped) when the neighbor triangle across it is also solid; that's
// true uniformly for all 3 edges, including the diagonal shared with its former
// "sibling" — there's no special-casing between orientations here anymore.
public static class VoxelMesher
{
    private const byte AirValue = (byte)BlockType.Air;

    public static MeshData BuildMesh(Chunk chunk)
    {
        var vertices = new List<VertexPositionNormalTexture>();
        var indices = new List<int>();

        for (int col = 0; col < Chunk.TriWidth; col++)
        for (int y = 0; y < Chunk.Height; y++)
        for (int row = 0; row < Chunk.Depth; row++)
        {
            EmitTriangle(chunk, col, y, row, vertices, indices);
        }

        return new MeshData { Vertices = vertices.ToArray(), Indices = indices.ToArray() };
    }

    private static void EmitTriangle(Chunk chunk, int col, int y, int row,
        List<VertexPositionNormalTexture> vertices, List<int> indices)
    {
        byte cellValue = chunk.Get(col, y, row);
        if (cellValue == AirValue) return;
        var type = (BlockType)cellValue;

        var (p1, p2, p3) = TriangleGrid.Corners(col, row);

        bool topOpen = chunk.Get(col, y + 1, row) == AirValue;
        bool bottomOpen = chunk.Get(col, y - 1, row) == AirValue;
        AddCaps(vertices, indices, type, col >> 1, y, row, p1, p2, p3, topOpen, bottomOpen);

        foreach (var edge in TriangleGrid.Edges(col, row))
        {
            if (chunk.Get(edge.NeighborCol, y, edge.NeighborRow) != AirValue) continue;

            Vector2 apex = ThirdCorner(p1, p2, p3, edge.A, edge.B);
            AddSideQuad(vertices, indices, type, edge.A, edge.B, y, OutwardNormal(edge.A, edge.B, apex));
        }
    }

    // Index-space equality — deliberately not world-space, so this doesn't care about the shear.
    private static Vector2 ThirdCorner(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 a, Vector2 b)
    {
        if (p1 != a && p1 != b) return p1;
        if (p2 != a && p2 != b) return p2;
        return p3;
    }

    // Perpendicular to the edge, pointing away from the triangle's third corner (apex).
    // Operates on WORLD-space (post-shear) points: the shear isn't angle-preserving, so an
    // index-space perpendicular would not be perpendicular after transforming to world space.
    private static Vector3 OutwardNormal(Vector2 indexE1, Vector2 indexE2, Vector2 indexApex)
    {
        Vector2 e1 = TriangleGrid.IndexToWorld(indexE1.X, indexE1.Y);
        Vector2 e2 = TriangleGrid.IndexToWorld(indexE2.X, indexE2.Y);
        Vector2 apex = TriangleGrid.IndexToWorld(indexApex.X, indexApex.Y);

        Vector2 edge = e2 - e1;
        Vector2 normal = Vector2.Normalize(new Vector2(edge.Y, -edge.X));
        Vector2 mid = (e1 + e2) * 0.5f;
        if (Vector2.Dot(normal, apex - mid) > 0) normal = -normal;
        return new Vector3(normal.X, 0, normal.Y);
    }

    private static void AddCaps(List<VertexPositionNormalTexture> vertices, List<int> indices,
        BlockType type, int cellX, int cellY, int cellZ, Vector2 p1, Vector2 p2, Vector2 p3,
        bool topOpen, bool bottomOpen)
    {
        Vector2 w1 = TriangleGrid.IndexToWorld(p1.X, p1.Y);
        Vector2 w2 = TriangleGrid.IndexToWorld(p2.X, p2.Y);
        Vector2 w3 = TriangleGrid.IndexToWorld(p3.X, p3.Y);

        if (topOpen)
        {
            var (u0, v0, u1, v1) = AtlasUV.GetRect(type, FaceKind.Top);
            AddTriangle(vertices, indices,
                CapVertex(new Vector3(w1.X, cellY + 1, w1.Y), p1, cellX, cellZ, u0, v0, u1, v1, Vector3.Up),
                CapVertex(new Vector3(w2.X, cellY + 1, w2.Y), p2, cellX, cellZ, u0, v0, u1, v1, Vector3.Up),
                CapVertex(new Vector3(w3.X, cellY + 1, w3.Y), p3, cellX, cellZ, u0, v0, u1, v1, Vector3.Up));
        }

        if (bottomOpen)
        {
            var (u0, v0, u1, v1) = AtlasUV.GetRect(type, FaceKind.Bottom);
            AddTriangle(vertices, indices,
                CapVertex(new Vector3(w1.X, cellY, w1.Y), p1, cellX, cellZ, u0, v0, u1, v1, Vector3.Down),
                CapVertex(new Vector3(w3.X, cellY, w3.Y), p3, cellX, cellZ, u0, v0, u1, v1, Vector3.Down),
                CapVertex(new Vector3(w2.X, cellY, w2.Y), p2, cellX, cellZ, u0, v0, u1, v1, Vector3.Down));
        }
    }

    private static VertexPositionNormalTexture CapVertex(Vector3 position, Vector2 indexCorner, int cellX, int cellZ,
        float u0, float v0, float u1, float v1, Vector3 normal)
    {
        float lx = indexCorner.X - cellX;
        float lz = indexCorner.Y - cellZ;
        var uv = new Vector2(u0 + lx * (u1 - u0), v0 + lz * (v1 - v0));
        return new VertexPositionNormalTexture(position, normal, uv);
    }

    private static void AddSideQuad(List<VertexPositionNormalTexture> vertices, List<int> indices,
        BlockType type, Vector2 indexE1, Vector2 indexE2, int y, Vector3 normal)
    {
        var (u0, v0, u1, v1) = AtlasUV.GetRect(type, FaceKind.Side);
        Vector2 e1 = TriangleGrid.IndexToWorld(indexE1.X, indexE1.Y);
        Vector2 e2 = TriangleGrid.IndexToWorld(indexE2.X, indexE2.Y);

        var v00 = new VertexPositionNormalTexture(new Vector3(e1.X, y, e1.Y), normal, new Vector2(u0, v1));
        var v01 = new VertexPositionNormalTexture(new Vector3(e1.X, y + 1, e1.Y), normal, new Vector2(u0, v0));
        var v11 = new VertexPositionNormalTexture(new Vector3(e2.X, y + 1, e2.Y), normal, new Vector2(u1, v0));
        var v10 = new VertexPositionNormalTexture(new Vector3(e2.X, y, e2.Y), normal, new Vector2(u1, v1));

        AddTriangle(vertices, indices, v00, v01, v11);
        AddTriangle(vertices, indices, v00, v11, v10);
    }

    private static void AddTriangle(List<VertexPositionNormalTexture> vertices, List<int> indices,
        VertexPositionNormalTexture a, VertexPositionNormalTexture b, VertexPositionNormalTexture c)
    {
        int baseIndex = vertices.Count;
        vertices.Add(a);
        vertices.Add(b);
        vertices.Add(c);
        indices.Add(baseIndex);
        indices.Add(baseIndex + 1);
        indices.Add(baseIndex + 2);
    }
}
