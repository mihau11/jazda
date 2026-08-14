package body Gun is

   function Turn_Rate (S : Sensitivity_Level) return Float is
   begin
      case S is
         when Low    => return 0.003;
         when Medium => return 0.006;
         when High   => return 0.010;
      end case;
   end Turn_Rate;

   function Elevation_Rate (S : Sensitivity_Level) return Float is
   begin
      case S is
         when Low    => return 0.04;
         when Medium => return 0.08;
         when High   => return 0.14;
      end case;
   end Elevation_Rate;

   procedure Cycle_Sensitivity (G : in out State) is
   begin
      G.Sensitivity :=
        (case G.Sensitivity is
            when Low    => Medium,
            when Medium => High,
            when High   => Low);
   end Cycle_Sensitivity;

end Gun;
