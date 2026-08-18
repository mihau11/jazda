with Ada.Numerics.Float_Random;
with World_Map; use World_Map;
with Entities;

package body Mission is

   Max_Interval : constant Float := 30.0;  --  difficulty 1: a contact every 30s
   Min_Interval : constant Float := 6.0;   --  difficulty 11: a contact every 6s
   Min_Spawn_Dist : constant Float := 3.0; --  keep new contacts off the player's back

   Contacts_Total   : Natural := 0;
   Contacts_Spawned : Natural := 0;
   Spawn_Timer      : Float := 0.0;
   Spawn_Interval   : Float := Max_Interval;

   Gen : Ada.Numerics.Float_Random.Generator;

   procedure Spawn_One (Player_X, Player_Y : Float) is
      use Ada.Numerics.Float_Random;
      Gx, Gy : Integer := 1;
      Found  : Boolean := False;
   begin
      for Attempt in 1 .. 30 loop
         Gx := 1 + Integer (Float'Floor (Float (World_Map.Width - 2) * Random (Gen)));
         Gy := 1 + Integer (Float'Floor (Float (World_Map.Height - 2) * Random (Gen)));
         if World_Map.Cell (Gx, Gy) = 0 then
            declare
               Dx : constant Float := Float (Gx) + 0.5 - Player_X;
               Dy : constant Float := Float (Gy) + 0.5 - Player_Y;
            begin
               if Dx * Dx + Dy * Dy >= Min_Spawn_Dist * Min_Spawn_Dist then
                  Found := True;
                  exit;
               end if;
            end;
         end if;
      end loop;

      if not Found then
         Fallback_Scan :
         for Y in 1 .. World_Map.Height - 2 loop
            for X in 1 .. World_Map.Width - 2 loop
               if World_Map.Cell (X, Y) = 0 then
                  Gx := X;
                  Gy := Y;
                  Found := True;
                  exit Fallback_Scan;
               end if;
            end loop;
         end loop Fallback_Scan;
      end if;

      if Found then
         declare
            Chosen_Kind : constant Entities.Kind :=
              (if Random (Gen) < 0.25 then Entities.AT_Gun else Entities.Infantry);
         begin
            Entities.Spawn (Chosen_Kind, Float (Gx) + 0.5, Float (Gy) + 0.5);
         end;
      end if;
   end Spawn_One;

   procedure Begin_Mission (Difficulty : Positive) is
      Step : constant Float := (Max_Interval - Min_Interval) / 10.0;
   begin
      Contacts_Total   := Natural'Min (Difficulty, Entities.Max_Entities);
      Contacts_Spawned := 0;
      Spawn_Interval   := Max_Interval - Float (Difficulty - 1) * Step;
      Spawn_Timer      := 0.0;  --  first contact arrives immediately
      Entities.Reset;
      Ada.Numerics.Float_Random.Reset (Gen);
   end Begin_Mission;

   procedure Update (Player_X, Player_Y : Float; Dt : Float) is
   begin
      if Contacts_Spawned < Contacts_Total then
         Spawn_Timer := Spawn_Timer - Dt;
         if Spawn_Timer <= 0.0 then
            Spawn_One (Player_X, Player_Y);
            Contacts_Spawned := Contacts_Spawned + 1;
            Spawn_Timer := Spawn_Interval;
         end if;
      end if;
   end Update;

   function Is_Won return Boolean is
   begin
      return Contacts_Total > 0
        and then Contacts_Spawned = Contacts_Total
        and then not Entities.Any_Alive;
   end Is_Won;

end Mission;
