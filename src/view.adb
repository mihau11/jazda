package body View is

   function Plane_Length (M : Mode) return Float is
   begin
      case M is
         when Periscope => return 1.00;  --  ~90 deg: wide situational view
         when Gun_Sight  => return 0.18; --  ~20 deg: narrow aiming zoom
      end case;
   end Plane_Length;

end View;
