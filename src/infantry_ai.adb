with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with World_Map; use World_Map;
with Entities; use Entities;

package body Infantry_Ai is

   Speed : constant Float := 0.6;  --  world units/second -- a slow walking
                                    --  pace, well under the tank's own
                                    --  throttle speed

   function Solid (X, Y : Float) return Boolean is
   begin
      return World_Map.Cell
        (Integer (Float'Floor (X)), Integer (Float'Floor (Y))) /= 0;
   end Solid;

   procedure Update (Player_X, Player_Y : Float; Dt : Float) is
   begin
      for I in Entities.List'Range loop
         declare
            E : Entities.Entity renames Entities.List (I);
         begin
            if E.Alive and then E.Kind = Entities.Infantry then
               declare
                  Dx   : constant Float := Player_X - E.X;
                  Dy   : constant Float := Player_Y - E.Y;
                  Dist : constant Float := Sqrt (Dx * Dx + Dy * Dy);
               begin
                  if Dist > 0.0001 then
                     declare
                        Step  : constant Float := Speed * Dt;
                        Ux    : constant Float := Dx / Dist;
                        Uy    : constant Float := Dy / Dist;
                        New_X : constant Float := E.X + Ux * Step;
                        New_Y : constant Float := E.Y + Uy * Step;
                     begin
                        --  Slide along walls: test each axis independently,
                        --  same approach as Hull.Update.
                        if not Solid (New_X, E.Y) then
                           E.X := New_X;
                        end if;
                        if not Solid (E.X, New_Y) then
                           E.Y := New_Y;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Update;

end Infantry_Ai;
