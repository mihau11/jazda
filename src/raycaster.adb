with Interfaces; use Interfaces;
with World_Map; use World_Map;
with Entities; use Entities;
with Textures;

package body Raycaster is

   Sky_Color    : constant Unsigned_32 := 16#FF5B7B9C#;
   Ground_Color : constant Unsigned_32 := 16#FF3B3025#;

   function Wall_Color (Cell : World_Map.Cell_Value; Side : Integer) return Unsigned_32 is
   begin
      case Cell is
         when 1 =>
            return (if Side = 0 then 16#FFB0B0B0# else 16#FF808080#);
         when 2 =>
            return (if Side = 0 then 16#FFC98A4B# else 16#FF8F5F32#);
         when 3 =>
            return (if Side = 0 then 16#FF6B8F4B# else 16#FF4B6335#);
         when others =>
            return 16#FFFF00FF#;  --  magenta: an id with no color defined
      end case;
   end Wall_Color;

   --  Cell_Value 0 (empty) never reaches here: the DDA loop in Render only
   --  exits on a non-zero Hit, same guarantee Wall_Color above relies on.
   function Wall_Slot (Cell : World_Map.Cell_Value) return Textures.Slot is
   begin
      case Cell is
         when 1      => return Textures.Wall_1_Tex;
         when 2      => return Textures.Wall_2_Tex;
         when others => return Textures.Wall_3_Tex;
      end case;
   end Wall_Slot;

   --  Darkens a textured/flat pixel's RGB (Y-side walls, same depth cue the
   --  flat-color path already gave via a separate darker constant per side).
   function Shade (Color : Unsigned_32; Factor : Float) return Unsigned_32 is
      A : constant Unsigned_32 := Color and 16#FF00_0000#;
      R : constant Unsigned_32 :=
        Unsigned_32 (Float (Shift_Right (Color, 16) and 16#FF#) * Factor);
      G : constant Unsigned_32 :=
        Unsigned_32 (Float (Shift_Right (Color, 8) and 16#FF#) * Factor);
      B : constant Unsigned_32 := Unsigned_32 (Float (Color and 16#FF#) * Factor);
   begin
      return A or Shift_Left (R, 16) or Shift_Left (G, 8) or B;
   end Shade;

   procedure Render
     (Fb               : in out Framebuffer.Pixel_Array;
      Depths           : out Depth_Buffer;
      Pos_X, Pos_Y     : Float;
      Dir_X, Dir_Y     : Float;
      Plane_X, Plane_Y : Float;
      Horizon_Shift    : Integer := 0)
   is
      W : constant Integer := Framebuffer.Width;
      H : constant Integer := Framebuffer.Height;

      --  Floor/ceiling casting (Lodev-style): Pos_Z is the camera height
      --  in screen-space units, matching the same pinhole-camera model
      --  Line_Height below already assumes (a wall of world-height 1 at
      --  distance 1 exactly fills the screen). Horizon_Row folds in the
      --  same pitch (y-shear) approximation Draw_Start/Draw_End use, so
      --  floor/ceiling stay aligned with the wall picture under elevation.
      Pos_Z       : constant Float := Float (H) / 2.0;
      Horizon_Row : constant Integer := H / 2 + Horizon_Shift;

      Floor_Tex   : Textures.Texture renames Textures.Set (Textures.Floor_Tex);
      Ceiling_Tex : Textures.Texture renames Textures.Set (Textures.Ceiling_Tex);
   begin
      for X in 0 .. W - 1 loop
         declare
            Camera_X  : constant Float := 2.0 * Float (X) / Float (W) - 1.0;
            Ray_Dir_X : constant Float := Dir_X + Plane_X * Camera_X;
            Ray_Dir_Y : constant Float := Dir_Y + Plane_Y * Camera_X;

            Map_X : Integer := Integer (Float'Floor (Pos_X));
            Map_Y : Integer := Integer (Float'Floor (Pos_Y));

            Delta_Dist_X : constant Float :=
              (if Ray_Dir_X = 0.0 then 1.0e30 else abs (1.0 / Ray_Dir_X));
            Delta_Dist_Y : constant Float :=
              (if Ray_Dir_Y = 0.0 then 1.0e30 else abs (1.0 / Ray_Dir_Y));

            Step_X, Step_Y           : Integer;
            Side_Dist_X, Side_Dist_Y : Float;
            Side                     : Integer := 0;
            Hit                      : World_Map.Cell_Value := 0;

            Perp_Wall_Dist              : Float;
            Line_Height                 : Integer;
            Unclipped_Start             : Integer;
            Draw_Start, Draw_End        : Integer;
            Flat_Color                  : Unsigned_32;
            Wall_Slot_Id                : Textures.Slot;
            Wall_Loaded                  : Boolean;
            Tex_X                       : Natural := 0;
         begin
            if Ray_Dir_X < 0.0 then
               Step_X      := -1;
               Side_Dist_X := (Pos_X - Float (Map_X)) * Delta_Dist_X;
            else
               Step_X      := 1;
               Side_Dist_X := (Float (Map_X) + 1.0 - Pos_X) * Delta_Dist_X;
            end if;

            if Ray_Dir_Y < 0.0 then
               Step_Y      := -1;
               Side_Dist_Y := (Pos_Y - Float (Map_Y)) * Delta_Dist_Y;
            else
               Step_Y      := 1;
               Side_Dist_Y := (Float (Map_Y) + 1.0 - Pos_Y) * Delta_Dist_Y;
            end if;

            loop
               if Side_Dist_X < Side_Dist_Y then
                  Side_Dist_X := Side_Dist_X + Delta_Dist_X;
                  Map_X       := Map_X + Step_X;
                  Side        := 0;
               else
                  Side_Dist_Y := Side_Dist_Y + Delta_Dist_Y;
                  Map_Y       := Map_Y + Step_Y;
                  Side        := 1;
               end if;
               Hit := World_Map.Cell (Map_X, Map_Y);
               exit when Hit /= 0;
            end loop;

            if Side = 0 then
               Perp_Wall_Dist :=
                 (Float (Map_X) - Pos_X + (1.0 - Float (Step_X)) / 2.0) / Ray_Dir_X;
            else
               Perp_Wall_Dist :=
                 (Float (Map_Y) - Pos_Y + (1.0 - Float (Step_Y)) / 2.0) / Ray_Dir_Y;
            end if;

            --  Clamped to at least 1 so the per-row texture-V division
            --  below can never divide by zero on an extremely close wall.
            Line_Height     := Integer'Max (1, Integer (Float (H) / Perp_Wall_Dist));
            Unclipped_Start := -Line_Height / 2 + H / 2 + Horizon_Shift;
            Draw_Start      := Integer'Max (0, Unclipped_Start);
            Draw_End        := Integer'Min (H - 1, Line_Height / 2 + H / 2 + Horizon_Shift);
            Depths (X)      := Perp_Wall_Dist;

            Wall_Slot_Id := Wall_Slot (Hit);
            Wall_Loaded  := Textures.Set (Wall_Slot_Id).Loaded;

            if Wall_Loaded then
               declare
                  Tex      : Textures.Texture renames Textures.Set (Wall_Slot_Id);
                  Wall_Hit : Float;
                  Fu       : Float;
               begin
                  if Side = 0 then
                     Wall_Hit := Pos_Y + Perp_Wall_Dist * Ray_Dir_Y;
                  else
                     Wall_Hit := Pos_X + Perp_Wall_Dist * Ray_Dir_X;
                  end if;
                  Fu    := Wall_Hit - Float'Floor (Wall_Hit);
                  Tex_X := Natural (Fu * Float (Tex.W)) mod Tex.W;
                  if (Side = 0 and then Ray_Dir_X > 0.0)
                    or else (Side = 1 and then Ray_Dir_Y < 0.0)
                  then
                     Tex_X := Tex.W - 1 - Tex_X;
                  end if;
               end;
            else
               Flat_Color := Wall_Color (Hit, Side);
            end if;

            for Y in 0 .. H - 1 loop
               if Y < Draw_Start then
                  declare
                     P : constant Integer := Horizon_Row - Y;
                  begin
                     if P > 0 and then Ceiling_Tex.Loaded then
                        declare
                           Row_Dist : constant Float := Pos_Z / Float (P);
                        begin
                           Fb (Y * W + X) :=
                             Textures.Sample
                               (Ceiling_Tex,
                                Pos_X + Row_Dist * Ray_Dir_X,
                                Pos_Y + Row_Dist * Ray_Dir_Y);
                        end;
                     else
                        Fb (Y * W + X) := Sky_Color;
                     end if;
                  end;
               elsif Y > Draw_End then
                  declare
                     P : constant Integer := Y - Horizon_Row;
                  begin
                     if P > 0 and then Floor_Tex.Loaded then
                        declare
                           Row_Dist : constant Float := Pos_Z / Float (P);
                        begin
                           Fb (Y * W + X) :=
                             Textures.Sample
                               (Floor_Tex,
                                Pos_X + Row_Dist * Ray_Dir_X,
                                Pos_Y + Row_Dist * Ray_Dir_Y);
                        end;
                     else
                        Fb (Y * W + X) := Ground_Color;
                     end if;
                  end;
               elsif Wall_Loaded then
                  declare
                     Tex   : Textures.Texture renames Textures.Set (Wall_Slot_Id);
                     Tex_Y : constant Natural :=
                       Natural'Min
                         (Tex.H - 1,
                          Natural'Max
                            (0,
                             Natural
                               (Float (Y - Unclipped_Start) / Float (Line_Height) *
                                Float (Tex.H))));
                     Sampled : constant Unsigned_32 := Textures.Texel (Tex, Tex_X, Tex_Y);
                  begin
                     Fb (Y * W + X) := (if Side = 1 then Shade (Sampled, 0.7) else Sampled);
                  end;
               else
                  Fb (Y * W + X) := Flat_Color;
               end if;
            end loop;
         end;
      end loop;
   end Render;

   function Sprite_Color (Entity_Kind : Entities.Kind) return Unsigned_32 is
   begin
      case Entity_Kind is
         when Entities.Infantry => return 16#FF4A5A32#;
         when Entities.AT_Gun   => return 16#FF703030#;
      end case;
   end Sprite_Color;

   function Sprite_Slot (Entity_Kind : Entities.Kind) return Textures.Slot is
   begin
      case Entity_Kind is
         when Entities.Infantry => return Textures.Infantry_Tex;
         when Entities.AT_Gun   => return Textures.At_Gun_Tex;
      end case;
   end Sprite_Slot;

   procedure Render_Entities
     (Fb               : in out Framebuffer.Pixel_Array;
      Depths           : Depth_Buffer;
      Pos_X, Pos_Y     : Float;
      Dir_X, Dir_Y     : Float;
      Plane_X, Plane_Y : Float;
      Horizon_Shift    : Integer := 0)
   is
      W       : constant Integer := Framebuffer.Width;
      H       : constant Integer := Framebuffer.Height;
      Inv_Det : constant Float := 1.0 / (Plane_X * Dir_Y - Dir_X * Plane_Y);
   begin
      for E of Entities.List loop
         if E.Alive then
            declare
               Sprite_X    : constant Float := E.X - Pos_X;
               Sprite_Y    : constant Float := E.Y - Pos_Y;
               Transform_X : constant Float := Inv_Det * (Dir_Y * Sprite_X - Dir_X * Sprite_Y);
               Transform_Y : constant Float :=
                 Inv_Det * (-Plane_Y * Sprite_X + Plane_X * Sprite_Y);
            begin
               --  Transform_Y is depth along the camera's forward axis;
               --  ignore anything behind or right at the camera.
               if Transform_Y > 0.1 then
                  declare
                     Screen_X : constant Integer :=
                       Integer (Float (W) / 2.0 * (1.0 + Transform_X / Transform_Y));
                     World_H : constant Float :=
                       (if E.Kind = Entities.Infantry then 1.0 else 0.6);
                     World_W : constant Float :=
                       (if E.Kind = Entities.Infantry then 0.4 else 0.8);
                     Sprite_H : constant Integer :=
                       Integer (abs (Float (H) * World_H / Transform_Y));
                     Sprite_W : constant Integer :=
                       Integer (abs (Float (H) * World_W / Transform_Y));
                     Draw_Start_Y : constant Integer := -Sprite_H / 2 + H / 2 + Horizon_Shift;
                     Draw_End_Y   : constant Integer := Sprite_H / 2 + H / 2 + Horizon_Shift;
                     Draw_Start_X : constant Integer := -Sprite_W / 2 + Screen_X;
                     Draw_End_X   : constant Integer := Sprite_W / 2 + Screen_X;
                     Flat_Color   : constant Unsigned_32 := Sprite_Color (E.Kind);
                     Slot_Id      : constant Textures.Slot := Sprite_Slot (E.Kind);
                     Sprite_Loaded : constant Boolean := Textures.Set (Slot_Id).Loaded;
                  begin
                     for Stripe in Integer'Max (0, Draw_Start_X) ..
                       Integer'Min (W - 1, Draw_End_X - 1)
                     loop
                        if Transform_Y < Depths (Stripe) then
                           if Sprite_Loaded then
                              declare
                                 Tex   : Textures.Texture renames Textures.Set (Slot_Id);
                                 Tex_X : constant Natural :=
                                   Natural'Min
                                     (Tex.W - 1,
                                      Natural'Max
                                        (0,
                                         Natural
                                           (Float (Stripe - Draw_Start_X) /
                                            Float (Integer'Max (1, Sprite_W)) *
                                            Float (Tex.W))));
                              begin
                                 for Y in Integer'Max (0, Draw_Start_Y) ..
                                   Integer'Min (H - 1, Draw_End_Y - 1)
                                 loop
                                    declare
                                       Tex_Y : constant Natural :=
                                         Natural'Min
                                           (Tex.H - 1,
                                            Natural'Max
                                              (0,
                                               Natural
                                                 (Float (Y - Draw_Start_Y) /
                                                  Float (Integer'Max (1, Sprite_H)) *
                                                  Float (Tex.H))));
                                       Pixel : constant Unsigned_32 := Textures.Texel (Tex, Tex_X, Tex_Y);
                                    begin
                                       if not Textures.Is_Key (Tex, Pixel) then
                                          Fb (Y * W + Stripe) := Pixel;
                                       end if;
                                    end;
                                 end loop;
                              end;
                           else
                              for Y in Integer'Max (0, Draw_Start_Y) ..
                                Integer'Min (H - 1, Draw_End_Y - 1)
                              loop
                                 Fb (Y * W + Stripe) := Flat_Color;
                              end loop;
                           end if;
                        end if;
                     end loop;
                  end;
               end if;
            end;
         end if;
      end loop;
   end Render_Entities;

end Raycaster;
