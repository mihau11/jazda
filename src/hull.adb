with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with World_Map; use World_Map;

package body Hull is

   Engine_Speed : constant Float := 0.04;  --  world units/frame, one track driven
   Track_Base   : constant Float := 1.6;   --  differential-steering divisor
   Clearance    : constant Float := 0.25;  --  collision radius around hull center

   function Solid (X, Y : Float) return Boolean is
   begin
      return World_Map.Cell
        (Integer (Float'Floor (X)), Integer (Float'Floor (Y))) /= 0;
   end Solid;

   function Blocked_Near (X, Y : Float) return Boolean is
   begin
      return Solid (X - Clearance, Y - Clearance)
        or else Solid (X + Clearance, Y - Clearance)
        or else Solid (X - Clearance, Y + Clearance)
        or else Solid (X + Clearance, Y + Clearance);
   end Blocked_Near;

   procedure Update
     (H                : in out State;
      Throttle         : Throttle_State;
      Left_Declutched  : Boolean;
      Right_Declutched : Boolean)
   is
      Base_Speed : constant Float :=
        (case Throttle is
            when Idle    => 0.0,
            when Forward => Engine_Speed,
            when Back => -Engine_Speed);

      Left_Speed  : constant Float := (if Left_Declutched then 0.0 else Base_Speed);
      Right_Speed : constant Float := (if Right_Declutched then 0.0 else Base_Speed);

      Linear_Speed  : constant Float := (Left_Speed + Right_Speed) / 2.0;
      Angular_Speed : constant Float := (Right_Speed - Left_Speed) / Track_Base;

      New_X, New_Y : Float;
   begin
      H.Angle := H.Angle + Angular_Speed;

      New_X := H.X + Linear_Speed * Cos (H.Angle);
      New_Y := H.Y + Linear_Speed * Sin (H.Angle);

      --  Slide along walls: test each axis independently.
      if not Blocked_Near (New_X, H.Y) then
         H.X := New_X;
      end if;
      if not Blocked_Near (H.X, New_Y) then
         H.Y := New_Y;
      end if;
   end Update;

end Hull;
