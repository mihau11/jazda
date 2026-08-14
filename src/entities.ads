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

   Max_Entities : constant := 8;
   type Entity_Array is array (1 .. Max_Entities) of Entity;

   --  A small fixed test placement in the milestone-2 room: two infantry
   --  contacts and one AT gun, at open (non-wall) grid cells.
   List : Entity_Array :=
     (1      => (Kind => Infantry, X => 9.5, Y => 1.5, Alive => True,
                 Timer => 0.0, Locked_On => False, Reported => False),
      2      => (Kind => Infantry, X => 3.5, Y => 8.5, Alive => True,
                 Timer => 0.0, Locked_On => False, Reported => False),
      3      => (Kind => AT_Gun,   X => 9.5, Y => 8.5, Alive => True,
                 Timer => 0.0, Locked_On => False, Reported => False),
      others => (Kind => Infantry, X => 0.0, Y => 0.0, Alive => False,
                 Timer => 0.0, Locked_On => False, Reported => False));

end Entities;
