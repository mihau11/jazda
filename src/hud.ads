with Framebuffer;
with View;

package Hud is

   Header_Height : constant := 24;

   Max_Hit_Pips : constant := 3;  --  hits the tank can absorb before the next one destroys it

   procedure Draw
     (Fb             : in out Framebuffer.Pixel_Array;
      Dir_Angle      : Float;
      Relative_Angle : Float;
      Hits_Taken     : Natural;
      Mode           : View.Mode);
   --  Overlays a header bar onto the top of Fb: a numeric azimuth readout
   --  (Dir_Angle, world-facing), a small hull-icon indicator showing
   --  Relative_Angle -- the periscope/gun offset from hull-forward, as a
   --  red line against a rectangle standing in for the hull -- and
   --  Max_Hit_Pips small boxes (filled red for each of Hits_Taken) --
   --  plus a center reticle when Mode is Gun_Sight.

   procedure Apply_Flash
     (Fb        : in out Framebuffer.Pixel_Array;
      Intensity : Float);
   --  Blends every pixel toward a flash color by Intensity (0.0 = no
   --  effect, 1.0 = fully replaced) -- a brief hit-taken cue.

   procedure Draw_Banner (Fb : in out Framebuffer.Pixel_Array; Text : String);
   --  A text banner across the bottom of Fb (dark background band behind
   --  it for legibility), centered horizontally. No-op for an empty
   --  string. Drawn on top of everything Draw produces, so it stays
   --  legible in any view mode/vignette.

end Hud;
