package Hull is

   type State is record
      X, Y  : Float := 2.5;  --  world position
      Angle : Float := 0.0;  --  facing, radians
   end record;

   type Throttle_State is (Idle, Forward, Back);

   procedure Update
     (H                : in out State;
      Throttle         : Throttle_State;
      Left_Declutched  : Boolean;
      Right_Declutched : Boolean);
   --  Advances H by one frame step. Turning comes from declutching one
   --  track (T-34-style), not a direct turn input: each track's speed is
   --  the throttle speed unless declutched (then zero, clutch-brake
   --  style), and standard differential-drive kinematics combine the two
   --  track speeds into hull linear/angular velocity. Blocked by
   --  World_Map walls (slides along them rather than stopping dead).

end Hull;
