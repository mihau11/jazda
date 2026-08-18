with Interfaces; use Interfaces;
with Ada.Numerics; use Ada.Numerics;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with View; use View;

package body Hud is

   Header_Color    : constant Unsigned_32 := 16#FF14140F#;
   Digit_Color     : constant Unsigned_32 := 16#FFE8D9A0#;
   Reticle_Color   : constant Unsigned_32 := 16#FFE04030#;
   Mask_Color      : constant Unsigned_32 := 16#FF000000#;
   Hull_Icon_Color : constant Unsigned_32 := 16#FF8FA06A#;
   Flash_Color     : constant Unsigned_32 := 16#FFFF3020#;
   Muzzle_Color    : constant Unsigned_32 := 16#FFFFB020#;

   procedure Put (Fb : in out Framebuffer.Pixel_Array; X, Y : Integer; Color : Unsigned_32) is
   begin
      if X >= 0 and then X < Framebuffer.Width
        and then Y >= 0 and then Y < Framebuffer.Height
      then
         Fb (Y * Framebuffer.Width + X) := Color;
      end if;
   end Put;

   function Normalize_360 (Deg : Float) return Float is
      Result : Float := Deg;
   begin
      while Result < 0.0 loop
         Result := Result + 360.0;
      end loop;
      while Result >= 360.0 loop
         Result := Result - 360.0;
      end loop;
      return Result;
   end Normalize_360;

   --  Minimal 3x5 pixel font. Digits cover the azimuth readout; letters
   --  cover only what radio-report text (milestone 8) actually uses so
   --  far -- add more letters here as new report text needs them.
   type Glyph_Rows is array (0 .. 4) of String (1 .. 3);
   Blank_Glyph : constant Glyph_Rows := ("000", "000", "000", "000", "000");

   Digit_Glyphs : constant array (0 .. 9) of Glyph_Rows :=
     (0 => ("111", "101", "101", "101", "111"),
      1 => ("010", "110", "010", "010", "111"),
      2 => ("111", "001", "111", "100", "111"),
      3 => ("111", "001", "111", "001", "111"),
      4 => ("101", "101", "111", "001", "001"),
      5 => ("111", "100", "111", "001", "111"),
      6 => ("111", "100", "111", "101", "111"),
      7 => ("111", "001", "001", "001", "001"),
      8 => ("111", "101", "111", "101", "111"),
      9 => ("111", "101", "111", "001", "111"));

   function Letter_Glyph (C : Character) return Glyph_Rows is
   begin
      case C is
         when 'A' => return ("010", "101", "111", "101", "101");
         when 'B' => return ("110", "101", "110", "101", "110");
         when 'C' => return ("111", "100", "100", "100", "111");
         when 'D' => return ("110", "101", "101", "101", "110");
         when 'E' => return ("111", "100", "110", "100", "111");
         when 'F' => return ("111", "100", "110", "100", "100");
         when 'G' => return ("111", "100", "101", "101", "111");
         when 'H' => return ("101", "101", "111", "101", "101");
         when 'I' => return ("111", "010", "010", "010", "111");
         when 'K' => return ("101", "101", "110", "101", "101");
         when 'L' => return ("100", "100", "100", "100", "111");
         when 'M' => return ("101", "111", "111", "111", "101");
         when 'N' => return ("101", "111", "111", "101", "101");
         when 'O' => return ("111", "101", "101", "101", "111");
         when 'P' => return ("111", "101", "111", "100", "100");
         when 'Q' => return ("111", "101", "101", "111", "001");
         when 'R' => return ("111", "101", "111", "110", "101");
         when 'S' => return ("111", "100", "111", "001", "111");
         when 'T' => return ("111", "010", "010", "010", "010");
         when 'U' => return ("101", "101", "101", "101", "111");
         when 'V' => return ("101", "101", "101", "101", "010");
         when 'W' => return ("101", "101", "111", "111", "101");
         when 'Y' => return ("101", "101", "010", "010", "010");
         when others => return Blank_Glyph;
      end case;
   end Letter_Glyph;

   function Glyph_For (C : Character) return Glyph_Rows is
   begin
      if C in '0' .. '9' then
         return Digit_Glyphs (Character'Pos (C) - Character'Pos ('0'));
      elsif C in 'A' .. 'Z' then
         return Letter_Glyph (C);
      else
         return Blank_Glyph;  --  space and anything else render blank
      end if;
   end Glyph_For;

   procedure Draw_Glyph
     (Fb     : in out Framebuffer.Pixel_Array;
      X0, Y0 : Integer;
      Glyph  : Glyph_Rows;
      Scale  : Integer;
      Color  : Unsigned_32)
   is
   begin
      for Row in 0 .. 4 loop
         for Col in 0 .. 2 loop
            if Glyph (Row) (Col + 1) = '1' then
               for Sy in 0 .. Scale - 1 loop
                  for Sx in 0 .. Scale - 1 loop
                     Put (Fb, X0 + Col * Scale + Sx, Y0 + Row * Scale + Sy, Color);
                  end loop;
               end loop;
            end if;
         end loop;
      end loop;
   end Draw_Glyph;

   procedure Draw_Text
     (Fb     : in out Framebuffer.Pixel_Array;
      X0, Y0 : Integer;
      S      : String;
      Scale  : Integer;
      Color  : Unsigned_32)
   is
      Glyph_W : constant Integer := 3 * Scale;
      Gap     : constant Integer := Scale;
   begin
      for I in S'Range loop
         Draw_Glyph
           (Fb, X0 + (I - S'First) * (Glyph_W + Gap), Y0, Glyph_For (S (I)), Scale, Color);
      end loop;
   end Draw_Text;

   procedure Draw_Azimuth_Number (Fb : in out Framebuffer.Pixel_Array; Value : Integer) is
      Scale : constant Integer := 2;
      X0    : constant Integer := 6;
      Y0    : constant Integer := (Header_Height - 5 * Scale) / 2;
      V     : constant Integer := Value mod 360;
      Text  : constant String :=
        Character'Val (Character'Pos ('0') + V / 100)
        & Character'Val (Character'Pos ('0') + (V / 10) mod 10)
        & Character'Val (Character'Pos ('0') + V mod 10);
   begin
      Draw_Text (Fb, X0, Y0, Text, Scale, Digit_Color);
   end Draw_Azimuth_Number;

   --  Small top-down hull rectangle (nose = up, i.e. hull-forward) with a
   --  red line showing Offset_Angle -- how far the periscope/gun is
   --  currently turned away from dead-ahead. Same angle-to-screen mapping
   --  as the azimuth conversion: 0 = up, increasing = clockwise (turning
   --  right, since the Right key increases these offsets).
   procedure Draw_Hull_Icon
     (Fb           : in out Framebuffer.Pixel_Array;
      Cx, Cy       : Integer;
      Offset_Angle : Float)
   is
      Half_W   : constant Integer := 4;
      Half_H   : constant Integer := 6;
      Line_Len : constant Integer := 8;
      Dx       : constant Float := Sin (Offset_Angle);
      Dy       : constant Float := -Cos (Offset_Angle);
   begin
      for X in Cx - Half_W .. Cx + Half_W loop
         Put (Fb, X, Cy - Half_H, Hull_Icon_Color);
         Put (Fb, X, Cy + Half_H, Hull_Icon_Color);
      end loop;
      for Y in Cy - Half_H .. Cy + Half_H loop
         Put (Fb, Cx - Half_W, Y, Hull_Icon_Color);
         Put (Fb, Cx + Half_W, Y, Hull_Icon_Color);
      end loop;

      for I in 0 .. Line_Len loop
         Put (Fb, Cx + Integer (Float (I) * Dx), Cy + Integer (Float (I) * Dy), Reticle_Color);
      end loop;
   end Draw_Hull_Icon;

   --  Max_Hit_Pips small boxes near the top-right of the header, filled
   --  red for each hit already taken, outline-only for hits remaining.
   procedure Draw_Hit_Pips (Fb : in out Framebuffer.Pixel_Array; Hits_Taken : Natural) is
      Pip_Size : constant Integer := 6;
      Gap      : constant Integer := 3;
      Y0       : constant Integer := (Header_Height - Pip_Size) / 2;
      X_Start  : constant Integer :=
        Framebuffer.Width - (Max_Hit_Pips * (Pip_Size + Gap)) - 4;
   begin
      for I in 0 .. Max_Hit_Pips - 1 loop
         declare
            X0     : constant Integer := X_Start + I * (Pip_Size + Gap);
            Filled : constant Boolean := I < Hits_Taken;
         begin
            for Y in Y0 .. Y0 + Pip_Size - 1 loop
               for X in X0 .. X0 + Pip_Size - 1 loop
                  if Filled then
                     Put (Fb, X, Y, Reticle_Color);
                  elsif Y = Y0 or else Y = Y0 + Pip_Size - 1
                    or else X = X0 or else X = X0 + Pip_Size - 1
                  then
                     Put (Fb, X, Y, Hull_Icon_Color);
                  end if;
               end loop;
            end loop;
         end;
      end loop;
   end Draw_Hit_Pips;

   --  Three small pips per lever, laid out horizontally starting at
   --  X_Start: the pip matching Position is filled, the other two are
   --  outline-only. Same visual language as Draw_Hit_Pips, just smaller
   --  and grouped by track instead of by hit count.
   procedure Draw_Lever_Pips
     (Fb       : in out Framebuffer.Pixel_Array;
      X_Start  : Integer;
      Position : Hull.Lever_Position)
   is
      Pip_Size : constant Integer := 5;
      Gap      : constant Integer := 2;
      Y0       : constant Integer := (Header_Height - Pip_Size) / 2;
      Active   : constant Integer :=
        (case Position is
            when Hull.Drive      => 0,
            when Hull.Declutched => 1,
            when Hull.Brake      => 2);
   begin
      for I in 0 .. 2 loop
         declare
            X0     : constant Integer := X_Start + I * (Pip_Size + Gap);
            Filled : constant Boolean := I = Active;
         begin
            for Y in Y0 .. Y0 + Pip_Size - 1 loop
               for X in X0 .. X0 + Pip_Size - 1 loop
                  if Filled then
                     Put (Fb, X, Y, Reticle_Color);
                  elsif Y = Y0 or else Y = Y0 + Pip_Size - 1
                    or else X = X0 or else X = X0 + Pip_Size - 1
                  then
                     Put (Fb, X, Y, Hull_Icon_Color);
                  end if;
               end loop;
            end loop;
         end;
      end loop;
   end Draw_Lever_Pips;

   --  A single lever's position as a vertical 3-stop icon: top stop =
   --  Drive (pushed forward), middle = Declutched, bottom = Brake
   --  (pulled all the way back) -- mirrors a real clutch-brake lever's
   --  travel. The current stop is filled, the other two outline-only.
   procedure Draw_Lever_Icon
     (Fb       : in out Framebuffer.Pixel_Array;
      X0, Y0   : Integer;
      Position : Hull.Lever_Position)
   is
      Pip    : constant Integer := 4;
      Gap    : constant Integer := 1;
      Active : constant Integer :=
        (case Position is
            when Hull.Drive      => 0,
            when Hull.Declutched => 1,
            when Hull.Brake      => 2);
   begin
      for Stop in 0 .. 2 loop
         declare
            Y1     : constant Integer := Y0 + Stop * (Pip + Gap);
            Filled : constant Boolean := Stop = Active;
         begin
            for Y in Y1 .. Y1 + Pip - 1 loop
               for X in X0 .. X0 + Pip - 1 loop
                  if Filled then
                     Put (Fb, X, Y, Reticle_Color);
                  elsif Y = Y1 or else Y = Y1 + Pip - 1
                    or else X = X0 or else X = X0 + Pip - 1
                  then
                     Put (Fb, X, Y, Hull_Icon_Color);
                  end if;
               end loop;
            end loop;
         end;
      end loop;
   end Draw_Lever_Icon;

   --  Bottom-right legend: a small lever icon per track next to a
   --  three-line text key spelling out what each position means --
   --  the header pips alone show current state, not what it stands for.
   --  Positioned to clear Draw_Banner's reserved bottom band (see
   --  Draw_Banner below) so the two never overlap.
   procedure Draw_Lever_Legend
     (Fb          : in out Framebuffer.Pixel_Array;
      Left_Lever  : Hull.Lever_Position;
      Right_Lever : Hull.Lever_Position)
   is
      Pip             : constant Integer := 4;
      Icon_Gap        : constant Integer := 1;
      Col_Gap         : constant Integer := 2;
      Icon_Height     : constant Integer := 3 * Pip + 2 * Icon_Gap;
      Text_Scale      : constant Integer := 1;
      Line_Height     : constant Integer := 5 * Text_Scale + 1;
      Text_Height     : constant Integer := 3 * Line_Height - 1;
      Block_Height    : constant Integer := Integer'Max (Icon_Height, Text_Height);
      Banner_Reserve  : constant Integer := 22;  --  clears Draw_Banner's bottom band
      Text_X          : constant Integer := Framebuffer.Width - 34;
      Icon_X          : constant Integer := Text_X - Col_Gap - 2 * Pip - Col_Gap;
      Y0              : constant Integer :=
        Framebuffer.Height - Banner_Reserve - Block_Height;
   begin
      Draw_Lever_Icon (Fb, Icon_X, Y0, Left_Lever);
      Draw_Lever_Icon (Fb, Icon_X + Pip + Col_Gap, Y0, Right_Lever);
      Draw_Text (Fb, Text_X, Y0,                   "D DRIVE",  Text_Scale, Digit_Color);
      Draw_Text (Fb, Text_X, Y0 + Line_Height,     "C CLUTCH", Text_Scale, Digit_Color);
      Draw_Text (Fb, Text_X, Y0 + 2 * Line_Height, "B BRAKE",  Text_Scale, Digit_Color);
   end Draw_Lever_Legend;

   function Blend_Channel (P, Target : Integer; Intensity : Float) return Unsigned_32 is
      Result : Integer := Integer (Float (P) + Intensity * (Float (Target) - Float (P)));
   begin
      if Result < 0 then
         Result := 0;
      elsif Result > 255 then
         Result := 255;
      end if;
      return Unsigned_32 (Result);
   end Blend_Channel;

   procedure Apply_Color_Flash
     (Fb        : in out Framebuffer.Pixel_Array;
      Intensity : Float;
      Color     : Unsigned_32)
   is
      Clamped : constant Float := Float'Max (0.0, Float'Min (1.0, Intensity));
      Fr      : constant Integer := Integer (Shift_Right (Color, 16) and 16#FF#);
      Fg      : constant Integer := Integer (Shift_Right (Color, 8) and 16#FF#);
      Fbl     : constant Integer := Integer (Color and 16#FF#);
   begin
      if Clamped <= 0.0 then
         return;
      end if;
      for I in Fb'Range loop
         declare
            Pixel : constant Unsigned_32 := Fb (I);
            Pr    : constant Integer := Integer (Shift_Right (Pixel, 16) and 16#FF#);
            Pg    : constant Integer := Integer (Shift_Right (Pixel, 8) and 16#FF#);
            Pb    : constant Integer := Integer (Pixel and 16#FF#);
            Nr    : constant Unsigned_32 := Blend_Channel (Pr, Fr, Clamped);
            Ng    : constant Unsigned_32 := Blend_Channel (Pg, Fg, Clamped);
            Nb    : constant Unsigned_32 := Blend_Channel (Pb, Fbl, Clamped);
         begin
            Fb (I) := 16#FF00_0000# or Shift_Left (Nr, 16) or Shift_Left (Ng, 8) or Nb;
         end;
      end loop;
   end Apply_Color_Flash;

   procedure Apply_Flash
     (Fb        : in out Framebuffer.Pixel_Array;
      Intensity : Float)
   is
   begin
      Apply_Color_Flash (Fb, Intensity, Flash_Color);
   end Apply_Flash;

   procedure Apply_Muzzle_Flash
     (Fb        : in out Framebuffer.Pixel_Array;
      Intensity : Float)
   is
   begin
      Apply_Color_Flash (Fb, Intensity, Muzzle_Color);
   end Apply_Muzzle_Flash;

   procedure Draw_Banner (Fb : in out Framebuffer.Pixel_Array; Text : String) is
      Scale   : constant Integer := 2;
      Glyph_W : constant Integer := 3 * Scale;
      Gap     : constant Integer := Scale;
      Band_H  : constant Integer := 5 * Scale + 6;
      Y0_Band : constant Integer := Framebuffer.Height - Band_H;
      Y0_Text : constant Integer := Y0_Band + (Band_H - 5 * Scale) / 2;
      Text_W  : constant Integer := Text'Length * (Glyph_W + Gap);
      X0      : constant Integer := (Framebuffer.Width - Text_W) / 2;
   begin
      if Text'Length = 0 then
         return;
      end if;
      for Y in Y0_Band .. Framebuffer.Height - 1 loop
         for X in 0 .. Framebuffer.Width - 1 loop
            Put (Fb, X, Y, Header_Color);
         end loop;
      end loop;
      Draw_Text (Fb, X0, Y0_Text, Text, Scale, Digit_Color);
   end Draw_Banner;

   procedure Draw
     (Fb             : in out Framebuffer.Pixel_Array;
      Dir_Angle      : Float;
      Relative_Angle : Float;
      Hits_Taken     : Natural;
      Mode           : View.Mode;
      Left_Lever     : Hull.Lever_Position;
      Right_Lever    : Hull.Lever_Position)
   is
      --  "North" is defined as +Y in world coordinates -- the same
      --  convention future radio-report bearings (milestone 8) will use.
      --  Azimuth increases the same way Dir_Angle does (turning one way
      --  increases the number, the other way decreases it).
      Math_Deg    : constant Float := Dir_Angle * 180.0 / Pi;
      Azimuth_Deg : constant Float := Normalize_360 (Math_Deg + 90.0);
   begin
      --  Gun-sight vignette: crop the (already narrow-FOV) render into a
      --  round scope-tube picture.
      if Mode = View.Gun_Sight then
         declare
            Vc_X      : constant Integer := Framebuffer.Width / 2;
            Vc_Y      : constant Integer :=
              Header_Height + (Framebuffer.Height - Header_Height) / 2;
            Radius    : constant Integer := 80;  --  larger sight-picture circle, same FOV
            Radius_Sq : constant Integer := Radius * Radius;
         begin
            for Y in Header_Height .. Framebuffer.Height - 1 loop
               for X in 0 .. Framebuffer.Width - 1 loop
                  declare
                     Dx : constant Integer := X - Vc_X;
                     Dy : constant Integer := Y - Vc_Y;
                  begin
                     if Dx * Dx + Dy * Dy > Radius_Sq then
                        Put (Fb, X, Y, Mask_Color);
                     end if;
                  end;
               end loop;
            end loop;
         end;
      end if;

      --  Periscope vignette: binocular mask -- two overlapping circles
      --  side by side, black outside their union.
      if Mode = View.Periscope then
         declare
            Vc_Y      : constant Integer :=
              Header_Height + (Framebuffer.Height - Header_Height) / 2;
            Radius    : constant Integer := 70;
            H_Offset  : constant Integer := 55;  --  center-to-center offset from mid-screen
            Left_Cx   : constant Integer := Framebuffer.Width / 2 - H_Offset;
            Right_Cx  : constant Integer := Framebuffer.Width / 2 + H_Offset;
            Radius_Sq : constant Integer := Radius * Radius;
         begin
            for Y in Header_Height .. Framebuffer.Height - 1 loop
               for X in 0 .. Framebuffer.Width - 1 loop
                  declare
                     Dy       : constant Integer := Y - Vc_Y;
                     Dx_Left  : constant Integer := X - Left_Cx;
                     Dx_Right : constant Integer := X - Right_Cx;
                     In_Left  : constant Boolean := Dx_Left * Dx_Left + Dy * Dy <= Radius_Sq;
                     In_Right : constant Boolean := Dx_Right * Dx_Right + Dy * Dy <= Radius_Sq;
                  begin
                     if not (In_Left or In_Right) then
                        Put (Fb, X, Y, Mask_Color);
                     end if;
                  end;
               end loop;
            end loop;
         end;
      end if;

      --  Header bar background.
      for Y in 0 .. Header_Height - 1 loop
         for X in 0 .. Framebuffer.Width - 1 loop
            Put (Fb, X, Y, Header_Color);
         end loop;
      end loop;

      Draw_Azimuth_Number (Fb, Integer (Azimuth_Deg));
      Draw_Hull_Icon (Fb, 46, Header_Height / 2, Relative_Angle);
      Draw_Lever_Pips (Fb, 60, Left_Lever);
      Draw_Lever_Pips (Fb, 90, Right_Lever);
      Draw_Hit_Pips (Fb, Hits_Taken);
      Draw_Lever_Legend (Fb, Left_Lever, Right_Lever);

      --  Gun-sight reticle: a Mauser-style post -- a thin horizontal wire
      --  through center, plus a thick post rising from below into the
      --  center only (nothing above), forming a "T".
      if Mode = View.Gun_Sight then
         declare
            Cx        : constant Integer := Framebuffer.Width / 2;
            Cy        : constant Integer :=
              Header_Height + (Framebuffer.Height - Header_Height) / 2;
            Horiz_Len : constant Integer := 8;
            Post_Len  : constant Integer := 8;
         begin
            for I in -Horiz_Len .. Horiz_Len loop
               Put (Fb, Cx + I, Cy, Reticle_Color);
            end loop;
            for I in 0 .. Post_Len loop
               Put (Fb, Cx,     Cy + I, Reticle_Color);
               Put (Fb, Cx - 1, Cy + I, Reticle_Color);
            end loop;
         end;
      end if;
   end Draw;

end Hud;
