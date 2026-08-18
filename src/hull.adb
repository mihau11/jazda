with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with World_Map; use World_Map;

package body Hull is

   Accel_Increment  : constant Float := 0.0009;  --  world units/frame^2: constant engine thrust while Drive+throttled
   Reverse_Accel_Increment : constant Float := 0.0003;  --  much weaker thrust in reverse
   Track_Base       : constant Float := 1.6;     --  differential-steering divisor
   Clearance        : constant Float := 0.25;    --  collision radius around hull center
   Brake_Rate       : constant Float := 0.35;    --  per-frame fraction: Brake hauls a track toward zero
   Rolling_Friction : constant Float := 0.02;    --  per-frame speed loss, always on (ground/mechanical drag)
   --  No top-speed constant: Drive just keeps adding Accel_Increment every
   --  frame the throttle is held, so speed climbs for as long as you hold
   --  it -- the only thing opposing it is Rolling_Friction, which settles
   --  at a natural equilibrium (Accel_Increment * (1 - Rolling_Friction)
   --  / Rolling_Friction) rather than an artificial hard cap.

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

   --  One track's next persistent speed, given its lever and the current
   --  throttle-derived thrust. Drive keeps adding Thrust every frame (no
   --  eased approach to a capped target); Declutched holds steady (no
   --  clutch drag of its own); Brake eases toward zero, fast.
   --  Rolling_Friction then applies to all three cases alike.
   function Track_Speed
     (Lever  : Lever_Position;
      Speed  : Float;
      Thrust : Float) return Float
   is
      Eased : Float;
   begin
      case Lever is
         when Drive      => Eased := Speed + Thrust;
         when Declutched => Eased := Speed;
         when Brake      => Eased := Speed + (0.0 - Speed) * Brake_Rate;
      end case;
      return Eased * (1.0 - Rolling_Friction);
   end Track_Speed;

   procedure Update
     (H           : in out State;
      Throttle    : Throttle_State;
      Left_Lever  : Lever_Position;
      Right_Lever : Lever_Position)
   is
      Thrust : constant Float :=
        (case Throttle is
            when Idle    => 0.0,
            when Forward => Accel_Increment,
            when Back => -Reverse_Accel_Increment);

      Linear_Speed, Angular_Speed : Float;
      New_X, New_Y                : Float;
   begin
      H.Left_Speed  := Track_Speed (Left_Lever, H.Left_Speed, Thrust);
      H.Right_Speed := Track_Speed (Right_Lever, H.Right_Speed, Thrust);

      Linear_Speed  := (H.Left_Speed + H.Right_Speed) / 2.0;
      Angular_Speed := (H.Left_Speed - H.Right_Speed) / Track_Base;

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
