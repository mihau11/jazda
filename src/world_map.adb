package body World_Map is

   function Cell (X, Y : Integer) return Cell_Value is
   begin
      if X < 0 or else X > Width - 1 or else Y < 0 or else Y > Height - 1 then
         return 1;
      end if;
      return Level (Y, X);
   end Cell;

   procedure Set_Cell (X, Y : Integer; Value : Cell_Value) is
   begin
      if X in 1 .. Width - 2 and then Y in 1 .. Height - 2 then
         Level (Y, X) := Value;
      end if;
   end Set_Cell;

   procedure Reset (New_Width, New_Height : Natural) is
      Clamped_Width  : constant Natural :=
        Natural'Max (Min_Width, Natural'Min (Max_Width, New_Width));
      Clamped_Height : constant Natural :=
        Natural'Max (Min_Height, Natural'Min (Max_Height, New_Height));
   begin
      Width  := Clamped_Width;
      Height := Clamped_Height;

      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            Level (Y, X) := 0;
         end loop;
      end loop;

      for X in 0 .. Width - 1 loop
         Level (0, X)          := 1;
         Level (Height - 1, X) := 1;
      end loop;
      for Y in 0 .. Height - 1 loop
         Level (Y, 0)         := 1;
         Level (Y, Width - 1) := 1;
      end loop;
   end Reset;

   function Free_Cell_Count return Natural is
      Count : Natural := 0;
   begin
      for Y in 1 .. Height - 2 loop
         for X in 1 .. Width - 2 loop
            if Level (Y, X) = 0 then
               Count := Count + 1;
            end if;
         end loop;
      end loop;
      return Count;
   end Free_Cell_Count;

end World_Map;
