package Entities is

   type Kind is (Infantry, AT_Gun);

   type Entity is record
      Kind      : Entities.Kind;
      X, Y      : Float;
      Alive     : Boolean := True;
      Timer     : Float := 0.0;      --  AT_Gun only: fire-cycle timer, seconds
      Locked_On : Boolean := False;  --  AT_Gun only: has fired at least once this engagement
      Reported  : Boolean := False;  --  has its spawn radio report already been generated
   end record;

   Max_Entities : constant := 11;  --  matches the mission's max difficulty (1 .. 11)
   type Entity_Array is array (1 .. Max_Entities) of Entity;

   --  Fixed buffer, runtime-populated by Mission's spawn timer (milestone
   --  9) rather than a compile-time test placement. Slots 1 .. Count are
   --  the ones spawned so far this mission; the rest are unused defaults.
   List  : Entity_Array :=
     (others => (Kind => Infantry, X => 0.0, Y => 0.0, Alive => False,
                 Timer => 0.0, Locked_On => False, Reported => False));
   Count : Natural := 0;

   procedure Reset;
   --  Clears List back to all-dead defaults and zeroes Count. Called once
   --  at the start of each mission.

   procedure Spawn (Kind : Entities.Kind; X, Y : Float);
   --  Appends a new alive entity at List (Count + 1), if Count < Max_Entities.

   function Any_Alive return Boolean;
   --  True if any entity in List is currently alive.

end Entities;
