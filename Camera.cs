using System;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;

namespace Trojkat;

// First-person no-clip fly camera: WASD move, mouse look, Space/Ctrl up-down, Shift sprint.
public class Camera
{
    public Vector3 Position;
    public float Yaw;
    public float Pitch;

    public Matrix Projection { get; }

    public Vector3 Forward => Vector3.Normalize(new Vector3(
        MathF.Cos(Pitch) * MathF.Sin(Yaw),
        MathF.Sin(Pitch),
        MathF.Cos(Pitch) * MathF.Cos(Yaw)));

    public Matrix View => Matrix.CreateLookAt(Position, Position + Forward, Vector3.Up);

    private bool _firstUpdate = true;

    public Camera(float aspectRatio, Vector3 startPosition)
    {
        Position = startPosition;
        Pitch = -0.6f; // start tilted down so the spawned-above-terrain view isn't just sky
        Projection = Matrix.CreatePerspectiveFieldOfView(MathHelper.PiOver4, aspectRatio, 0.05f, 500f);
    }

    public void Update(GameTime gameTime, KeyboardState kb, int windowCenterX, int windowCenterY)
    {
        float dt = (float)gameTime.ElapsedGameTime.TotalSeconds;
        float speed = kb.IsKeyDown(Keys.LeftShift) ? 12f : 5f;

        Vector3 forwardFlat = new(MathF.Sin(Yaw), 0, MathF.Cos(Yaw));
        Vector3 right = Vector3.Cross(forwardFlat, Vector3.Up);

        if (kb.IsKeyDown(Keys.W)) Position += forwardFlat * speed * dt;
        if (kb.IsKeyDown(Keys.S)) Position -= forwardFlat * speed * dt;
        if (kb.IsKeyDown(Keys.D)) Position += right * speed * dt;
        if (kb.IsKeyDown(Keys.A)) Position -= right * speed * dt;
        if (kb.IsKeyDown(Keys.Space)) Position += Vector3.Up * speed * dt;
        if (kb.IsKeyDown(Keys.LeftControl)) Position -= Vector3.Up * speed * dt;

        var mouse = Mouse.GetState();
        if (_firstUpdate)
        {
            // Discard the first frame's delta: the OS cursor can be anywhere on screen
            // when the window first gains focus, which would otherwise clobber Pitch/Yaw.
            _firstUpdate = false;
        }
        else
        {
            float dx = mouse.X - windowCenterX;
            float dy = mouse.Y - windowCenterY;
            Yaw -= dx * 0.0025f;
            Pitch = MathHelper.Clamp(Pitch - dy * 0.0025f, -MathHelper.PiOver2 + 0.01f, MathHelper.PiOver2 - 0.01f);
        }
        Mouse.SetPosition(windowCenterX, windowCenterY);
    }
}
