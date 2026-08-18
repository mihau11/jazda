with Framebuffer;
with World_Map;

package Map_Editor is

   Spawn_X : constant Float := 1.5;
   Spawn_Y : constant Float := 1.5;
   --  A fixed interior cell, forced empty before gameplay starts, so the
   --  hull always has a valid spawn point regardless of what was stamped.

   procedure Adjust_Width (Delta_V : Integer);
   procedure Adjust_Height (Delta_V : Integer);
   --  Size-select phase: nudges Sel_Width/Sel_Height by Delta_V, clamped
   --  to World_Map.Min_.. Max_ range.

   procedure Begin_Grid_Edit;
   --  Ends size selection: calls World_Map.Reset (Sel_Width, Sel_Height)
   --  and centers the cursor in the new interior.

   procedure Move_Cursor (Dx, Dy : Integer);
   --  Grid-edit phase: moves the cursor by one cell, clamped to the
   --  interior (border ring is never reachable).

   procedure Stamp (Value : World_Map.Cell_Value);
   --  Sets the cell under the cursor to Value.

   function Difficulty return Positive;
   --  1 .. 11, from the current free-interior-cell fraction (more free
   --  space = harder). Live -- reflects whatever's stamped right now.

   procedure Finish_Grid_Edit;
   --  Forces the reserved spawn cell back to empty, regardless of what
   --  was stamped over it. Call once, right before starting the mission.

   procedure Draw_Main_Menu (Fb : in out Framebuffer.Pixel_Array);
   procedure Draw_Size_Select (Fb : in out Framebuffer.Pixel_Array);
   procedure Draw_Grid_Edit (Fb : in out Framebuffer.Pixel_Array);

end Map_Editor;
