with Framebuffer;

package Raycaster is

   --  Per-column wall distance, filled in by Render and consumed by
   --  Render_Entities so sprites are occluded by nearer walls.
   type Depth_Buffer is array (0 .. Framebuffer.Width - 1) of Float;

   --  Casts one ray per screen column (Lodev-style grid DDA) and fills Fb
   --  with sky/wall/ground for the given camera pose. Dir_X/Dir_Y is the
   --  facing unit vector; Plane_X/Plane_Y is the camera plane vector
   --  (perpendicular to facing, its length sets the field of view).
   --  Horizon_Shift is a y-shear pitch approximation (a la Doom look-up/
   --  down): a pixel offset added to every column's vertical wall
   --  placement, so gun elevation can tilt the picture without true 3D
   --  perspective. Positive shifts the horizon down the screen (looking up).
   procedure Render
     (Fb               : in out Framebuffer.Pixel_Array;
      Depths           : out Depth_Buffer;
      Pos_X, Pos_Y     : Float;
      Dir_X, Dir_Y     : Float;
      Plane_X, Plane_Y : Float;
      Horizon_Shift    : Integer := 0);

   --  Billboard-sprite pass for Entities.List, depth-tested against Depths
   --  so a sprite behind a wall doesn't show through. Same camera pose and
   --  Horizon_Shift as the Render call it follows.
   procedure Render_Entities
     (Fb               : in out Framebuffer.Pixel_Array;
      Depths           : Depth_Buffer;
      Pos_X, Pos_Y     : Float;
      Dir_X, Dir_Y     : Float;
      Plane_X, Plane_Y : Float;
      Horizon_Shift    : Integer := 0);

end Raycaster;
