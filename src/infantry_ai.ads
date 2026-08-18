package Infantry_Ai is

   procedure Update (Player_X, Player_Y : Float; Dt : Float);
   --  Advances every alive Infantry entity one step closer to the player,
   --  in a straight line at a slow walking pace, blocked by World_Map
   --  walls -- slides along them on whichever axis is still open, the
   --  same technique Hull.Update uses, rather than stopping dead or
   --  clipping through. AT guns are stationary emplacements and are not
   --  moved by this.

end Infantry_Ai;
