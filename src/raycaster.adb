with Interfaces; use Interfaces;
with World_Map; use World_Map;
with Entities; use Entities;

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

            Perp_Wall_Dist       : Float;
            Line_Height          : Integer;
            Draw_Start, Draw_End : Integer;
            Color                : Unsigned_32;
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

            Line_Height := Integer (Float (H) / Perp_Wall_Dist);
            Draw_Start  := Integer'Max (0, -Line_Height / 2 + H / 2 + Horizon_Shift);
            Draw_End    := Integer'Min (H - 1, Line_Height / 2 + H / 2 + Horizon_Shift);
            Color       := Wall_Color (Hit, Side);
            Depths (X)  := Perp_Wall_Dist;

            for Y in 0 .. H - 1 loop
               if Y < Draw_Start then
                  Fb (Y * W + X) := Sky_Color;
               elsif Y > Draw_End then
                  Fb (Y * W + X) := Ground_Color;
               else
                  Fb (Y * W + X) := Color;
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
                     Color        : constant Unsigned_32 := Sprite_Color (E.Kind);
                  begin
                     for Stripe in Integer'Max (0, Draw_Start_X) ..
                       Integer'Min (W - 1, Draw_End_X - 1)
                     loop
                        if Transform_Y < Depths (Stripe) then
                           for Y in Integer'Max (0, Draw_Start_Y) ..
                             Integer'Min (H - 1, Draw_End_Y - 1)
                           loop
                              Fb (Y * W + Stripe) := Color;
                           end loop;
                        end if;
                     end loop;
                  end;
               end if;
            end;
         end if;
      end loop;
   end Render_Entities;

end Raycaster;
