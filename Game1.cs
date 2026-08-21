using System.IO;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;

namespace Trojkat;

public class Game1 : Game
{
    private GraphicsDeviceManager _graphics;

    private Chunk _chunk;
    private Camera _camera;
    private BasicEffect _effect;
    private Texture2D _atlas;

    private VertexBuffer _vertexBuffer;
    private IndexBuffer _indexBuffer;
    private int _indexCount;

    private SpriteBatch _spriteBatch;
    private Texture2D _pixel;

    private BlockType _selectedBlock = BlockType.Stone;
    private MouseState _prevMouse;
    private KeyboardState _prevKeyboard;

    private int _windowCenterX;
    private int _windowCenterY;

    public Game1()
    {
        _graphics = new GraphicsDeviceManager(this)
        {
            PreferredBackBufferWidth = 1280,
            PreferredBackBufferHeight = 720,
        };
        Content.RootDirectory = "Content";
        IsMouseVisible = false;
    }

    protected override void Initialize()
    {
        _windowCenterX = _graphics.PreferredBackBufferWidth / 2;
        _windowCenterY = _graphics.PreferredBackBufferHeight / 2;
        Mouse.SetPosition(_windowCenterX, _windowCenterY);

        _chunk = new Chunk();
        TerrainGenerator.Generate(_chunk, seed: 1337);

        // Spawn near the center of the world, above the terrain (which only reaches
        // roughly y=3..10 — Chunk.Height=11 is just the max build limit).
        float aspect = _graphics.PreferredBackBufferWidth / (float)_graphics.PreferredBackBufferHeight;
        var startPosition = new Vector3(Chunk.Width / 2f, 13f, Chunk.Depth / 2f);
        _camera = new Camera(aspect, startPosition) { Yaw = MathHelper.PiOver2, Pitch = -0.3f };

        base.Initialize();
    }

    protected override void LoadContent()
    {
        using (var stream = TitleContainer.OpenStream("Content/atlas.png"))
            _atlas = Texture2D.FromStream(GraphicsDevice, stream);

        _effect = new BasicEffect(GraphicsDevice)
        {
            TextureEnabled = true,
            Texture = _atlas,
            LightingEnabled = true,
            VertexColorEnabled = false,
            World = Matrix.Identity,
        };
        _effect.EnableDefaultLighting();
        _effect.AmbientLightColor = new Vector3(0.35f, 0.35f, 0.35f);

        _spriteBatch = new SpriteBatch(GraphicsDevice);
        _pixel = new Texture2D(GraphicsDevice, 1, 1);
        _pixel.SetData(new[] { Color.White });

        RebuildMesh();
    }

    private void RebuildMesh()
    {
        MeshData mesh = VoxelMesher.BuildMesh(_chunk);
        _indexCount = mesh.Indices.Length;

        _vertexBuffer?.Dispose();
        _indexBuffer?.Dispose();

        if (mesh.Vertices.Length == 0)
        {
            _vertexBuffer = null;
            _indexBuffer = null;
            return;
        }

        _vertexBuffer = new VertexBuffer(GraphicsDevice, typeof(VertexPositionNormalTexture),
            mesh.Vertices.Length, BufferUsage.WriteOnly);
        _vertexBuffer.SetData(mesh.Vertices);

        _indexBuffer = new IndexBuffer(GraphicsDevice, IndexElementSize.ThirtyTwoBits,
            mesh.Indices.Length, BufferUsage.WriteOnly);
        _indexBuffer.SetData(mesh.Indices);

        _chunk.IsDirty = false;
    }

    protected override void Update(GameTime gameTime)
    {
        var kb = Keyboard.GetState();
        if (GamePad.GetState(PlayerIndex.One).Buttons.Back == ButtonState.Pressed || kb.IsKeyDown(Keys.Escape))
            Exit();

        if (IsActive)
        {
            _camera.Update(gameTime, kb, _windowCenterX, _windowCenterY);
            HandleBlockSelection(kb);
            HandlePlaceAndBreak();
        }

        if (_chunk.IsDirty)
            RebuildMesh();

        _prevKeyboard = kb;
        base.Update(gameTime);
    }

    private void HandleBlockSelection(KeyboardState kb)
    {
        if (kb.IsKeyDown(Keys.D1) && !_prevKeyboard.IsKeyDown(Keys.D1)) _selectedBlock = BlockType.Grass;
        if (kb.IsKeyDown(Keys.D2) && !_prevKeyboard.IsKeyDown(Keys.D2)) _selectedBlock = BlockType.Dirt;
        if (kb.IsKeyDown(Keys.D3) && !_prevKeyboard.IsKeyDown(Keys.D3)) _selectedBlock = BlockType.Stone;
        if (kb.IsKeyDown(Keys.D4) && !_prevKeyboard.IsKeyDown(Keys.D4)) _selectedBlock = BlockType.Wood;
        if (kb.IsKeyDown(Keys.D5) && !_prevKeyboard.IsKeyDown(Keys.D5)) _selectedBlock = BlockType.Leaves;
    }

    private void HandlePlaceAndBreak()
    {
        var mouse = Mouse.GetState();

        bool leftClicked = mouse.LeftButton == ButtonState.Pressed && _prevMouse.LeftButton == ButtonState.Released;
        bool rightClicked = mouse.RightButton == ButtonState.Pressed && _prevMouse.RightButton == ButtonState.Released;

        if (leftClicked || rightClicked)
        {
            RaycastHit hit = Raycaster.Cast(_chunk, _camera.Position, _camera.Forward, 8f);
            if (hit.Found)
            {
                if (leftClicked)
                {
                    _chunk.Set(hit.Col, hit.Y, hit.Z, (byte)BlockType.Air);
                }
                else
                {
                    var (col, py, row) = Raycaster.GetPlacementTarget(hit);
                    if (Chunk.InBounds(col, py, row) && _chunk.Get(col, py, row) == (byte)BlockType.Air)
                    {
                        _chunk.Set(col, py, row, (byte)_selectedBlock);
                    }
                }
            }
        }

        _prevMouse = mouse;
    }

    protected override void Draw(GameTime gameTime)
    {
        GraphicsDevice.Clear(Color.CornflowerBlue);

        if (_vertexBuffer != null && _indexBuffer != null && _indexCount > 0)
        {
            GraphicsDevice.DepthStencilState = DepthStencilState.Default;
            GraphicsDevice.RasterizerState = RasterizerState.CullNone;
            GraphicsDevice.SetVertexBuffer(_vertexBuffer);
            GraphicsDevice.Indices = _indexBuffer;

            _effect.View = _camera.View;
            _effect.Projection = _camera.Projection;

            foreach (EffectPass pass in _effect.CurrentTechnique.Passes)
            {
                pass.Apply();
                GraphicsDevice.DrawIndexedPrimitives(PrimitiveType.TriangleList, 0, 0, _indexCount / 3);
            }
        }

        DrawCrosshair();

        base.Draw(gameTime);
    }

    private void DrawCrosshair()
    {
        const int size = 10;
        const int thickness = 2;
        int cx = _graphics.PreferredBackBufferWidth / 2;
        int cy = _graphics.PreferredBackBufferHeight / 2;

        _spriteBatch.Begin();
        _spriteBatch.Draw(_pixel, new Rectangle(cx - size / 2, cy - size / 2, size, thickness), Color.White);
        _spriteBatch.Draw(_pixel, new Rectangle(cx - thickness / 2, cy - size / 2, thickness, size), Color.White);
        _spriteBatch.End();
    }
}
