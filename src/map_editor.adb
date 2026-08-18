with Interfaces; use Interfaces;
with Hud;

package body Map_Editor is

   Bg_Color      : constant Unsigned_32 := 16#FF14140F#;
   Empty_Color   : constant Unsigned_32 := 16#FF202018#;
   Wall_Color    : constant Unsigned_32 := 16#FF806040#;
   Pillar_Color  : constant Unsigned_32 := 16#FF90A060#;
   Barrier_Color : constant Unsigned_32 := 16#FF605040#;
   Cursor_Color  : constant Unsigned_32 := 16#FFE8D9A0#;
   Spawn_Color   : constant Unsigned_32 := 16#FFE04030#;
   Text_Color    : constant Unsigned_32 := 16#FFE8D9A0#;

   Reserved_Text_H : constant := 24;  --  bottom strip for difficulty/legend

   Sel_Width  : Natural := World_Map.Width;
   Sel_Height : Natural := World_Map.Height;

   Cursor_X : Natural := 1;
   Cursor_Y : Natural := 1;

   function Two_Digit (N : Natural) return String is
      V : constant Natural := N mod 100;
   begin
      return
        Character'Val (Character'Pos ('0') + V / 10)
        & Character'Val (Character'Pos ('0') + V mod 10);
   end Two_Digit;

   procedure Adjust_Width (Delta_V : Integer) is
      New_V : constant Integer := Integer (Sel_Width) + Delta_V;
   begin
      Sel_Width :=
        Natural'Max
          (World_Map.Min_Width, Natural'Min (World_Map.Max_Width, Natural'Max (0, New_V)));
   end Adjust_Width;

   procedure Adjust_Height (Delta_V : Integer) is
      New_V : constant Integer := Integer (Sel_Height) + Delta_V;
   begin
      Sel_Height :=
        Natural'Max
          (World_Map.Min_Height, Natural'Min (World_Map.Max_Height, Natural'Max (0, New_V)));
   end Adjust_Height;

   procedure Begin_Grid_Edit is
   begin
      World_Map.Reset (Sel_Width, Sel_Height);
      Cursor_X := World_Map.Width / 2;
      Cursor_Y := World_Map.Height / 2;
   end Begin_Grid_Edit;

   procedure Move_Cursor (Dx, Dy : Integer) is
      New_X : constant Integer := Integer (Cursor_X) + Dx;
      New_Y : constant Integer := Integer (Cursor_Y) + Dy;
   begin
      Cursor_X := Natural'Max (1, Natural'Min (World_Map.Width - 2, Natural'Max (0, New_X)));
      Cursor_Y := Natural'Max (1, Natural'Min (World_Map.Height - 2, Natural'Max (0, New_Y)));
   end Move_Cursor;

   procedure Stamp (Value : World_Map.Cell_Value) is
   begin
      World_Map.Set_Cell (Cursor_X, Cursor_Y, Value);
   end Stamp;

   function Difficulty return Positive is
      Interior_Area : constant Natural :=
        (World_Map.Width - 2) * (World_Map.Height - 2);
      Fraction : constant Float :=
        Float (World_Map.Free_Cell_Count) / Float (Interior_Area);
      Raw : constant Integer := 1 + Integer (Float'Floor (Fraction * 10.0));
   begin
      return Positive (Integer'Max (1, Integer'Min (11, Raw)));
   end Difficulty;

   procedure Finish_Grid_Edit is
   begin
      World_Map.Set_Cell (1, 1, 0);
   end Finish_Grid_Edit;

   procedure Fill_Screen (Fb : in out Framebuffer.Pixel_Array; Color : Unsigned_32) is
   begin
      for Y in 0 .. Framebuffer.Height - 1 loop
         for X in 0 .. Framebuffer.Width - 1 loop
            Hud.Put (Fb, X, Y, Color);
         end loop;
      end loop;
   end Fill_Screen;

   procedure Draw_Main_Menu (Fb : in out Framebuffer.Pixel_Array) is
   begin
      Fill_Screen (Fb, Bg_Color);
      Hud.Draw_Text (Fb, 20, 30, "TANKETTE COMMANDER", 1, Text_Color);
      Hud.Draw_Text (Fb, 20, 70, "1 MISSION", 2, Text_Color);
      Hud.Draw_Text (Fb, 20, 95, "2 TEST DRIVE", 2, Text_Color);
      Hud.Draw_Text (Fb, 20, 120, "3 TROLLING", 2, Text_Color);
      Hud.Draw_Text (Fb, 20, 160, "TEST DRIVE AND TROLLING HAVE NO ENEMIES", 1, Text_Color);
   end Draw_Main_Menu;

   procedure Draw_Size_Select (Fb : in out Framebuffer.Pixel_Array) is
   begin
      Fill_Screen (Fb, Bg_Color);
      Hud.Draw_Text (Fb, 20, 30, "WIDTH " & Two_Digit (Sel_Width), 3, Text_Color);
      Hud.Draw_Text (Fb, 20, 70, "HEIGHT " & Two_Digit (Sel_Height), 3, Text_Color);
      Hud.Draw_Text (Fb, 20, 140, "ARROWS CHANGE", 2, Text_Color);
      Hud.Draw_Text (Fb, 20, 160, "ENTER GO", 2, Text_Color);
   end Draw_Size_Select;

   function Cell_Color (Value : World_Map.Cell_Value) return Unsigned_32 is
   begin
      case Value is
         when 0 => return Empty_Color;
         when 1 => return Wall_Color;
         when 2 => return Pillar_Color;
         when 3 => return Barrier_Color;
      end case;
   end Cell_Color;

   procedure Draw_Grid_Edit (Fb : in out Framebuffer.Pixel_Array) is
      Available_H : constant Integer := Framebuffer.Height - Reserved_Text_H;
      Cell_Size   : constant Integer :=
        Integer'Min
          (Framebuffer.Width / World_Map.Width, Available_H / World_Map.Height);
      Grid_W    : constant Integer := Cell_Size * World_Map.Width;
      Grid_H    : constant Integer := Cell_Size * World_Map.Height;
      Origin_X  : constant Integer := (Framebuffer.Width - Grid_W) / 2;
      Origin_Y  : constant Integer := (Available_H - Grid_H) / 2;
   begin
      Fill_Screen (Fb, Bg_Color);

      for Gy in 0 .. World_Map.Height - 1 loop
         for Gx in 0 .. World_Map.Width - 1 loop
            declare
               Color : constant Unsigned_32 := Cell_Color (World_Map.Cell (Gx, Gy));
               X0    : constant Integer := Origin_X + Gx * Cell_Size;
               Y0    : constant Integer := Origin_Y + Gy * Cell_Size;
            begin
               for Y in Y0 .. Y0 + Cell_Size - 2 loop
                  for X in X0 .. X0 + Cell_Size - 2 loop
                     Hud.Put (Fb, X, Y, Color);
                  end loop;
               end loop;
            end;
         end loop;
      end loop;

      declare
         Sx0 : constant Integer := Origin_X + 1 * Cell_Size;
         Sy0 : constant Integer := Origin_Y + 1 * Cell_Size;
      begin
         Hud.Draw_Text (Fb, Sx0 + 1, Sy0 + 1, "S", 1, Spawn_Color);
      end;

      declare
         Cx0 : constant Integer := Origin_X + Cursor_X * Cell_Size;
         Cy0 : constant Integer := Origin_Y + Cursor_Y * Cell_Size;
      begin
         for X in Cx0 .. Cx0 + Cell_Size - 2 loop
            Hud.Put (Fb, X, Cy0, Cursor_Color);
            Hud.Put (Fb, X, Cy0 + Cell_Size - 2, Cursor_Color);
         end loop;
         for Y in Cy0 .. Cy0 + Cell_Size - 2 loop
            Hud.Put (Fb, Cx0, Y, Cursor_Color);
            Hud.Put (Fb, Cx0 + Cell_Size - 2, Y, Cursor_Color);
         end loop;
      end;

      Hud.Draw_Text
        (Fb, 4, Framebuffer.Height - Reserved_Text_H + 8,
         "DIFFICULTY " & Two_Digit (Difficulty), 1, Text_Color);
      Hud.Draw_Text
        (Fb, 200, Framebuffer.Height - Reserved_Text_H + 8,
         "0-3 STAMP ENTER GO", 1, Text_Color);
   end Draw_Grid_Edit;

end Map_Editor;
