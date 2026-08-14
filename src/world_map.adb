package body World_Map is

   function Cell (X, Y : Integer) return Cell_Value is
   begin
      if X < 0 or else X > Map_Width - 1 or else Y < 0 or else Y > Map_Height - 1 then
         return 1;
      end if;
      return Level (Y, X);
   end Cell;

end World_Map;
