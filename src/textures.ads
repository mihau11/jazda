--  Optional user-supplied bitmaps: drop .bmp files into an assets/ folder
--  next to the executable and Raycaster texture-maps walls/floor/ceiling/
--  entity sprites with them instead of its procedural flat colors. Any
--  file that is missing, unreadable, or oversized just leaves that one
--  slot Loaded = False, so the game renders exactly as it always has
--  (no assets/ folder required at all).

with Interfaces; use Interfaces;

package Textures is

   Max_Dim : constant := 512;
   --  Generous for a 320x200-framebuffer game; also bounds memory/perf and
   --  guards against someone dropping in a huge photo by mistake.

   type Pixel_Array is array (0 .. Max_Dim * Max_Dim - 1) of Unsigned_32;

   type Texture is record
      Loaded : Boolean := False;
      W, H   : Natural := 0;
      Key    : Unsigned_32 := 0;  --  top-left pixel's color; sprite
                                   --  textures treat this as transparent
      Pixels : Pixel_Array;
   end record;

   type Slot is
     (Infantry_Tex, At_Gun_Tex, Wall_1_Tex, Wall_2_Tex, Wall_3_Tex,
      Floor_Tex, Ceiling_Tex);

   type Texture_Set is array (Slot) of Texture;
   Set : Texture_Set;

   function File_Name (S : Slot) return String;
   --  Fixed filename Load_All looks for under Assets_Dir, one per Slot
   --  (infantry.bmp, at_gun.bmp, wall_1.bmp .. wall_3.bmp matching
   --  World_Map.Cell_Value 1..3, floor.bmp, ceiling.bmp).

   procedure Load_All (Assets_Dir : String := "assets");
   --  Attempts to load every Slot's file. Safe to call whether or not
   --  Assets_Dir exists.

   function Texel (T : Texture; X, Y : Natural) return Unsigned_32;
   --  Direct pixel lookup, clamped into T's actual W x H.

   function Sample (T : Texture; U, V : Float) return Unsigned_32;
   --  U, V wrapped into [0.0, 1.0) and mapped onto T's W x H -- for the
   --  floor/ceiling world-space cast, where coordinates are unbounded.

   function Is_Key (T : Texture; Color : Unsigned_32) return Boolean;
   --  True if Color matches T.Key (ignoring alpha) closely enough to treat
   --  as transparent background on a sprite texture.

end Textures;
