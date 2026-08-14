with Ada.Numerics; use Ada.Numerics;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Entities; use Entities;

package body Radio is

   type Message is record
      Text   : String (1 .. Max_Message_Length) := (others => ' ');
      Length : Natural := 0;
   end record;

   Max_Queued  : constant := Entities.Max_Entities;
   Queue       : array (1 .. Max_Queued) of Message;
   Queue_Count : Natural := 0;

   Current       : Message;
   Display_Timer : Float := 0.0;

   --  Same convention as Hud's azimuth: "north" is +Y, increasing
   --  clockwise, matching the azimuth number shown in the header.
   function Bearing_Deg (Player_X, Player_Y, Target_X, Target_Y : Float) return Integer is
      Math_Rad : constant Float := Arctan (Target_Y - Player_Y, Target_X - Player_X);
      Math_Deg : constant Float := Math_Rad * 180.0 / Pi;
      Az       : Float := Math_Deg + 90.0;
   begin
      while Az < 0.0 loop
         Az := Az + 360.0;
      end loop;
      while Az >= 360.0 loop
         Az := Az - 360.0;
      end loop;
      return Integer (Az) mod 360;
   end Bearing_Deg;

   function Az_To_3Digit (Az : Integer) return String is
      V : constant Integer := Az mod 360;
   begin
      return
        Character'Val (Character'Pos ('0') + V / 100)
        & Character'Val (Character'Pos ('0') + (V / 10) mod 10)
        & Character'Val (Character'Pos ('0') + V mod 10);
   end Az_To_3Digit;

   function Build_Message
     (E                  : Entities.Entity;
      Player_X, Player_Y : Float) return Message
   is
      Az       : constant Integer := Bearing_Deg (Player_X, Player_Y, E.X, E.Y);
      Kind_Str : constant String :=
        (if E.Kind = Entities.Infantry
           then "INFANTRY SQUAD SPOTTED AT "
           else "AT GUN SPOTTED AT ");
      Full     : constant String := Kind_Str & Az_To_3Digit (Az);
      Result   : Message;
   begin
      Result.Length              := Full'Length;
      Result.Text (1 .. Full'Length) := Full;
      return Result;
   end Build_Message;

   procedure Enqueue (M : Message) is
   begin
      if Queue_Count < Max_Queued then
         Queue_Count          := Queue_Count + 1;
         Queue (Queue_Count) := M;
      end if;
   end Enqueue;

   procedure Check_Spawns (Player_X, Player_Y : Float) is
   begin
      for I in Entities.List'Range loop
         declare
            E : Entities.Entity renames Entities.List (I);
         begin
            if E.Alive and then not E.Reported then
               Enqueue (Build_Message (E, Player_X, Player_Y));
               E.Reported := True;
            end if;
         end;
      end loop;
   end Check_Spawns;

   procedure Update (Dt : Float) is
   begin
      if Display_Timer > 0.0 then
         Display_Timer := Display_Timer - Dt;
      end if;
      if Display_Timer <= 0.0 and then Queue_Count > 0 then
         Current := Queue (1);
         for I in 1 .. Queue_Count - 1 loop
            Queue (I) := Queue (I + 1);
         end loop;
         Queue_Count   := Queue_Count - 1;
         Display_Timer := Display_Duration;
      end if;
   end Update;

   function Has_Message return Boolean is
   begin
      return Display_Timer > 0.0;
   end Has_Message;

   function Current_Text return String is
   begin
      return Current.Text (1 .. Current.Length);
   end Current_Text;

end Radio;
