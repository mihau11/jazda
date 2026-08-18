package body Entities is

   procedure Reset is
   begin
      List :=
        (others => (Kind => Infantry, X => 0.0, Y => 0.0, Alive => False,
                    Timer => 0.0, Locked_On => False, Reported => False));
      Count := 0;
   end Reset;

   procedure Spawn (Kind : Entities.Kind; X, Y : Float) is
   begin
      if Count < Max_Entities then
         Count := Count + 1;
         List (Count) :=
           (Kind => Kind, X => X, Y => Y, Alive => True,
            Timer => 0.0, Locked_On => False, Reported => False);
      end if;
   end Spawn;

   function Any_Alive return Boolean is
   begin
      for E of List loop
         if E.Alive then
            return True;
         end if;
      end loop;
      return False;
   end Any_Alive;

end Entities;
