package Mission is

   procedure Begin_Mission (Difficulty : Positive);
   --  Starts a fresh mission at the given difficulty (1 .. 11, from the
   --  map editor's free-space readout): resets Entities, picks a total
   --  contact quota and spawn interval scaled to Difficulty, and spawns
   --  the first contact immediately.

   procedure Update (Player_X, Player_Y : Float; Dt : Float);
   --  Advances the spawn timer; when it elapses and the quota isn't yet
   --  met, spawns one new contact (Infantry or, more rarely, AT_Gun) at a
   --  random free map cell.

   function Is_Won return Boolean;
   --  True once every contact in the mission's quota has spawned and none
   --  of them are still alive -- the "contact list resolved" win state.

end Mission;
