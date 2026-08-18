with Framebuffer;
with View;
with Interfaces;
with Hull;

package Hud is

   Header_Height : constant := 24;

   Max_Hit_Pips : constant := 3;  --  hits the tank can absorb before the next one destroys it

   procedure Draw
     (Fb             : in out Framebuffer.Pixel_Array;
      Dir_Angle      : Float;
      Relative_Angle : Float;
      Hits_Taken     : Natural;
      Mode           : View.Mode;
      Left_Lever     : Hull.Lever_Position;
      Right_Lever    : Hull.Lever_Position);
   --  Overlays a header bar onto the top of Fb: a numeric azimuth readout
   --  (Dir_Angle, world-facing), a small hull-icon indicator showing
   --  Relative_Angle -- the periscope/gun offset from hull-forward, as a
   --  red line against a rectangle standing in for the hull -- two
   --  3-pip columns showing the current Left_Lever/Right_Lever steering
   --  positions (the current position filled, the other two outlined),
   --  Max_Hit_Pips small boxes (filled red for each of Hits_Taken), a
   --  bottom-right legend explaining the lever positions (a small
   --  3-stop icon per track next to a "D DRIVE / C CLUTCH / B BRAKE"
   --  text key) -- plus a center reticle when Mode is Gun_Sight.

   procedure Apply_Flash
     (Fb        : in out Framebuffer.Pixel_Array;
      Intensity : Float);
   --  Blends every pixel toward a flash color by Intensity (0.0 = no
   --  effect, 1.0 = fully replaced) -- a brief hit-taken cue.

   procedure Apply_Muzzle_Flash
     (Fb        : in out Framebuffer.Pixel_Array;
      Intensity : Float);
   --  Same blend as Apply_Flash but toward a brief, bright color distinct
   --  from the red hit-taken flash -- driven by a much shorter timer in
   --  practice, for a quick blink on firing rather than a wash.

   procedure Draw_Banner (Fb : in out Framebuffer.Pixel_Array; Text : String);
   --  A text banner across the bottom of Fb (dark background band behind
   --  it for legibility), centered horizontally. No-op for an empty
   --  string. Drawn on top of everything Draw produces, so it stays
   --  legible in any view mode/vignette.

   procedure Put (Fb : in out Framebuffer.Pixel_Array; X, Y : Integer; Color : Interfaces.Unsigned_32);
   --  Bounds-checked single-pixel write. Exposed so other screens (the
   --  pre-game map editor) can draw without duplicating this primitive.

   procedure Draw_Text
     (Fb     : in out Framebuffer.Pixel_Array;
      X0, Y0 : Integer;
      S      : String;
      Scale  : Integer;
      Color  : Interfaces.Unsigned_32);
   --  Renders S left-to-right at (X0, Y0) using the shared 3x5 bitmap
   --  font. Exposed for the same reason as Put.

end Hud;
