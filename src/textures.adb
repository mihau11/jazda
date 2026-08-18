with Ada.Text_IO; use Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Interfaces.C.Strings;
with System;
with SDL2_Thin; use SDL2_Thin;

package body Textures is

   function File_Name (S : Slot) return String is
   begin
      case S is
         when Infantry_Tex => return "infantry.bmp";
         when At_Gun_Tex   => return "at_gun.bmp";
         when Wall_1_Tex   => return "wall_1.bmp";
         when Wall_2_Tex   => return "wall_2.bmp";
         when Wall_3_Tex   => return "wall_3.bmp";
         when Floor_Tex    => return "floor.bmp";
         when Ceiling_Tex  => return "ceiling.bmp";
      end case;
   end File_Name;

   --  Fixed-size overlay used only to read back a loaded surface's pixel
   --  buffer by address; the real bounds are the surface's own W*H, always
   --  <= Max_Dim * Max_Dim since that is checked before this is ever read.
   type Raw_Pixels is array (0 .. Max_Dim * Max_Dim - 1) of Unsigned_32;
   type Raw_Pixels_Access is access all Raw_Pixels;
   pragma Convention (C, Raw_Pixels_Access);

   function To_Raw is new Ada.Unchecked_Conversion
     (System.Address, Raw_Pixels_Access);

   procedure Load_One (S : Slot; Assets_Dir : String) is
      Path   : constant String := Assets_Dir & "/" & File_Name (S);
      C_Path : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Path);
      C_Mode : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("rb");
      Raw  : Surface_Ptr;
      Conv : Surface_Ptr;
   begin
      Raw := SDL_LoadBMP_RW (SDL_RWFromFile (C_Path, C_Mode), 1);
      Interfaces.C.Strings.Free (C_Path);
      Interfaces.C.Strings.Free (C_Mode);

      if Raw = null then
         return;  --  no such file, or not a valid BMP -- stays Loaded=False
      end if;

      Conv := SDL_ConvertSurfaceFormat (Raw, SDL_PIXELFORMAT_ARGB8888, 0);
      SDL_FreeSurface (Raw);

      if Conv = null then
         Put_Line ("Textures: failed to convert " & Path & " to ARGB8888");
         return;
      end if;

      declare
         W : constant Natural := Natural (Conv.W);
         H : constant Natural := Natural (Conv.H);
      begin
         if W = 0 or else H = 0 or else W > Max_Dim or else H > Max_Dim then
            Put_Line
              ("Textures: skipping " & Path & " (" & W'Image & "x" &
               H'Image & ", max" & Max_Dim'Image & " per side)");
            SDL_FreeSurface (Conv);
            return;
         end if;

         declare
            Src         : constant Raw_Pixels_Access := To_Raw (Conv.Pixels);
            Pitch_Words : constant Natural := Natural (Conv.Pitch) / 4;
            T           : Texture renames Set (S);
         begin
            for Y in 0 .. H - 1 loop
               for X in 0 .. W - 1 loop
                  T.Pixels (Y * W + X) := Src (Y * Pitch_Words + X);
               end loop;
            end loop;
            T.W      := W;
            T.H      := H;
            T.Key    := T.Pixels (0);
            T.Loaded := True;
         end;
      end;

      SDL_FreeSurface (Conv);
   end Load_One;

   procedure Load_All (Assets_Dir : String := "assets") is
   begin
      for S in Slot loop
         Load_One (S, Assets_Dir);
      end loop;
   end Load_All;

   function Texel (T : Texture; X, Y : Natural) return Unsigned_32 is
      Cx : constant Natural := Natural'Min (X, T.W - 1);
      Cy : constant Natural := Natural'Min (Y, T.H - 1);
   begin
      return T.Pixels (Cy * T.W + Cx);
   end Texel;

   function Sample (T : Texture; U, V : Float) return Unsigned_32 is
      Fu : constant Float := U - Float'Floor (U);
      Fv : constant Float := V - Float'Floor (V);
      X  : constant Natural := Natural (Fu * Float (T.W)) mod T.W;
      Y  : constant Natural := Natural (Fv * Float (T.H)) mod T.H;
   begin
      return Texel (T, X, Y);
   end Sample;

   function Is_Key (T : Texture; Color : Unsigned_32) return Boolean is
   begin
      return (Color and 16#FFFFFF#) = (T.Key and 16#FFFFFF#);
   end Is_Key;

end Textures;
