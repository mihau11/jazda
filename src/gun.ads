with Ada.Numerics;

package Gun is

   type Sensitivity_Level is (Low, Medium, High);

   type State is record
      Angle       : Float := 0.0;              --  radians, offset from hull facing, clamped below
      Elevation   : Float := 0.0;              --  degrees, clamped below
      Sensitivity : Sensitivity_Level := Medium;
   end record;

   Min_Elevation : constant Float := -10.0;
   Max_Elevation : constant Float := 20.0;

   --  Limited traverse arc (this fictional tankette's mount, not a full
   --  360-degree turret) -- 7 degrees either side of hull-forward.
   Max_Traverse : constant Float := 7.0 * Ada.Numerics.Pi / 180.0;

   procedure Cycle_Sensitivity (G : in out State);

   --  Fine-aim rates for the current sensitivity tier -- deliberately much
   --  slower than a plain camera turn, for precise gun-laying via I/J/K/L.
   function Turn_Rate (S : Sensitivity_Level) return Float;
   function Elevation_Rate (S : Sensitivity_Level) return Float;

end Gun;
