package World_Map is

   --  Fixed compile-time buffer bounds. Actual in-play size is chosen by
   --  the player in the pre-game map editor (milestone 9) and tracked
   --  separately in Width/Height below -- this is a fixed max-size buffer
   --  with a runtime-tracked active size, not a true dynamic array.
   Max_Width  : constant := 32;
   Max_Height : constant := 20;
   Min_Width  : constant := 8;
   Min_Height : constant := 8;

   Width  : Natural := 12;
   Height : Natural := 10;

   type Cell_Value is range 0 .. 3;
   --  0 = empty, 1 = concrete wall, 2 = pillar, 3 = low barrier wall.
   --  Distinct ids so Raycaster can give each material a different color.

   type Grid is array (0 .. Max_Height - 1, 0 .. Max_Width - 1) of Cell_Value;

   Level : Grid := (others => (others => 0));

   function Cell (X, Y : Integer) return Cell_Value;
   --  Out-of-bounds reads as solid, so a ray can never escape the grid.

   procedure Set_Cell (X, Y : Integer; Value : Cell_Value);
   --  Interior-only (1 .. Width - 2, 1 .. Height - 2); a no-op outside
   --  that range, so the border wall ring can never be edited away.

   procedure Reset (New_Width, New_Height : Natural);
   --  Clamps New_Width/New_Height into Min_.. Max_ range, sets Width/
   --  Height, clears the active area to empty, then stamps a solid wall
   --  ring around the new border (same style as the old fixed test level).

   function Free_Cell_Count return Natural;
   --  Number of empty interior cells (border ring excluded) in the
   --  currently active Width x Height area.

end World_Map;
