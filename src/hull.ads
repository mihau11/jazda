package Hull is

   type State is record
      X, Y   : Float := 2.5;  --  world position
      Angle  : Float := 0.0;  --  facing, radians
      Left_Speed, Right_Speed : Float := 0.0;
      --  persistent per-track speed, world units/frame -- carried between
      --  frames so a track can ease toward a target instead of snapping
      --  to it (needed for Declutched coasting and Brake stopping to
      --  feel distinct from each other).
   end record;

   type Throttle_State is (Idle, Forward, Back);

   type Lever_Position is (Drive, Declutched, Brake);
   --  T-34-style steering lever, one per track: Drive couples the track
   --  to the engine, which keeps accelerating that track for as long as
   --  Throttle is held -- there is no fixed top speed, only the universal
   --  rolling friction below, which it climbs toward asymptotically;
   --  Declutched frees it -- no engine thrust and no clutch drag, it
   --  simply keeps whatever speed it already had (bar that same rolling
   --  friction); Brake actively hauls it toward zero, fast, regardless of
   --  Throttle.

   procedure Update
     (H           : in out State;
      Throttle    : Throttle_State;
      Left_Lever  : Lever_Position;
      Right_Lever : Lever_Position);
   --  Advances H by one frame step. Turning comes from the two levers'
   --  independent effect on each track's persistent speed (T-34-style
   --  clutch-brake steering), not a direct turn input: standard
   --  differential-drive kinematics combine the two track speeds into
   --  hull linear/angular velocity. A small rolling-friction decay
   --  applies to both tracks every frame regardless of lever position --
   --  it is what makes a Declutched track (no clutch drag of its own)
   --  still gradually lose speed, since the whole vehicle drags against
   --  the ground. Blocked by World_Map walls (slides along them rather
   --  than stopping dead).

end Hull;
