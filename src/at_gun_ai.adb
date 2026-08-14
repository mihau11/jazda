with Combat;
with Entities; use Entities;

package body At_Gun_Ai is

   function Update (Player_X, Player_Y : Float; Dt : Float) return Natural is
      Hits : Natural := 0;
   begin
      for I in Entities.List'Range loop
         declare
            E : Entities.Entity renames Entities.List (I);
         begin
            if E.Alive and then E.Kind = Entities.AT_Gun then
               if Combat.Has_Line_Of_Sight (E.X, E.Y, Player_X, Player_Y) then
                  E.Timer := E.Timer + Dt;
                  declare
                     Threshold : constant Float :=
                       (if E.Locked_On then Reload_Time else Aim_Time);
                  begin
                     if E.Timer >= Threshold then
                        Hits := Hits + 1;
                        E.Locked_On := True;
                        E.Timer := 0.0;
                     end if;
                  end;
               else
                  E.Timer := 0.0;
                  E.Locked_On := False;
               end if;
            end if;
         end;
      end loop;
      return Hits;
   end Update;

end At_Gun_Ai;
