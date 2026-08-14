package Combat is

   type Weapon is (Machine_Gun, Autocannon);

   procedure Fire
     (Weapon_Kind        : Weapon;
      Origin_X, Origin_Y : Float;
      Angle              : Float);
   --  Hitscans along Angle from the origin. Machine_Gun only affects
   --  Infantry (anti-infantry use, per design); Autocannon affects either
   --  kind. Stops at the first wall or the first affectable alive entity
   --  it reaches, whichever is closer; kills the entity it hits.

   function Has_Line_Of_Sight (X1, Y1, X2, Y2 : Float) return Boolean;
   --  True if no wall blocks the straight line between the two points.

end Combat;
