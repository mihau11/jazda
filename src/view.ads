package View is

   type Mode is (Periscope, Gun_Sight);

   function Plane_Length (M : Mode) return Float;
   --  Camera plane length for the given mode; this sets the field of view
   --  (FOV = 2 * arctan (Plane_Length), since the facing vector has unit
   --  length). Periscope is wide/unmagnified; Gun_Sight is a narrow zoom.

end View;
