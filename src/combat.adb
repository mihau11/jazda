with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with World_Map; use World_Map;
with Entities; use Entities;

package body Combat is

   Max_Range : constant Float := 20.0;
   Step      : constant Float := 0.05;

   function Can_Affect (Weapon_Kind : Weapon; Target : Entities.Kind) return Boolean is
   begin
      case Weapon_Kind is
         when Machine_Gun => return Target = Infantry;
         when Autocannon  => return True;
      end case;
   end Can_Affect;

   --  Deliberately well under half each entity's rendered sprite width --
   --  a radius matching the full silhouette gives a forgiving hit cone
   --  that widens with range (anywhere on the sprite counts), which reads
   --  as "hits when I aimed to the side." This requires closer-to-center
   --  aim instead.
   function Hit_Radius (Target : Entities.Kind) return Float is
   begin
      case Target is
         when Infantry => return 0.08;
         when AT_Gun   => return 0.15;
      end case;
   end Hit_Radius;

   procedure Fire
     (Weapon_Kind        : Weapon;
      Origin_X, Origin_Y : Float;
      Angle              : Float)
   is
      Dx       : constant Float := Cos (Angle);
      Dy       : constant Float := Sin (Angle);
      Traveled : Float := 0.0;
   begin
      while Traveled < Max_Range loop
         declare
            Px : constant Float := Origin_X + Dx * Traveled;
            Py : constant Float := Origin_Y + Dy * Traveled;
         begin
            if World_Map.Cell (Integer (Float'Floor (Px)), Integer (Float'Floor (Py))) /= 0 then
               return;  --  blocked by a wall
            end if;

            for I in Entities.List'Range loop
               if Entities.List (I).Alive
                 and then Can_Affect (Weapon_Kind, Entities.List (I).Kind)
               then
                  declare
                     Ex : constant Float := Entities.List (I).X - Px;
                     Ey : constant Float := Entities.List (I).Y - Py;
                     R  : constant Float := Hit_Radius (Entities.List (I).Kind);
                  begin
                     if Ex * Ex + Ey * Ey <= R * R then
                        Entities.List (I).Alive := False;
                        return;
                     end if;
                  end;
               end if;
            end loop;
         end;
         Traveled := Traveled + Step;
      end loop;
   end Fire;

   function Has_Line_Of_Sight (X1, Y1, X2, Y2 : Float) return Boolean is
      Dx       : constant Float := X2 - X1;
      Dy       : constant Float := Y2 - Y1;
      Dist     : constant Float := Sqrt (Dx * Dx + Dy * Dy);
      Ux       : constant Float := (if Dist > 0.0 then Dx / Dist else 0.0);
      Uy       : constant Float := (if Dist > 0.0 then Dy / Dist else 0.0);
      Traveled : Float := 0.0;
   begin
      while Traveled < Dist loop
         declare
            Px : constant Float := X1 + Ux * Traveled;
            Py : constant Float := Y1 + Uy * Traveled;
         begin
            if World_Map.Cell (Integer (Float'Floor (Px)), Integer (Float'Floor (Py))) /= 0 then
               return False;
            end if;
         end;
         Traveled := Traveled + Step;
      end loop;
      return True;
   end Has_Line_Of_Sight;

end Combat;
