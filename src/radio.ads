package Radio is

   Max_Message_Length : constant := 40;
   Display_Duration   : constant Float := 4.0;  --  seconds each message stays up

   procedure Check_Spawns (Player_X, Player_Y : Float);
   --  Scans Entities.List for any alive, not-yet-reported entity and
   --  queues a spawn report for it: kind plus its bearing from the
   --  player's position at this moment (not when the player spots it --
   --  see DESIGN.md). Cheap to call every frame; a no-op once everything
   --  currently in the world has already been reported.

   procedure Update (Dt : Float);
   --  Advances the currently-displayed message's timer by Dt seconds,
   --  pulling the next queued message once it expires.

   function Has_Message return Boolean;
   function Current_Text return String;
   --  The message to show right now, if Has_Message.

end Radio;
