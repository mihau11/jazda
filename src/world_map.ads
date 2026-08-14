package World_Map is

   Map_Width  : constant := 12;
   Map_Height : constant := 10;

   type Cell_Value is range 0 .. 3;
   --  0 = empty, 1 = concrete wall, 2 = pillar, 3 = low barrier wall.
   --  Distinct ids so Raycaster can give each material a different color.

   type Grid is array (0 .. Map_Height - 1, 0 .. Map_Width - 1) of Cell_Value;

   --  A small test room: bordered box, an enclosed inner chamber (corners),
   --  a lone pillar, and a barrier wall with corridor gaps on both ends.
   Level : constant Grid :=
     (0 => (1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
      1 => (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
      2 => (1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1),
      3 => (1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1),
      4 => (1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 1),
      5 => (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
      6 => (1, 0, 3, 3, 3, 3, 3, 3, 3, 3, 0, 1),
      7 => (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
      8 => (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
      9 => (1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1));

   function Cell (X, Y : Integer) return Cell_Value;
   --  Out-of-bounds reads as solid, so a ray can never escape the grid.

end World_Map;
