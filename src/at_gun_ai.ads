package At_Gun_Ai is

   Aim_Time    : constant Float := 3.0;  --  seconds of continuous view before the first shot
   Reload_Time : constant Float := 5.0;  --  seconds between shots once locked on

   function Update (Player_X, Player_Y : Float; Dt : Float) return Natural;
   --  Advances every alive AT gun's fire timer by Dt seconds. An AT gun
   --  needs Aim_Time seconds of continuous line of sight on the player
   --  before its first shot; once it has fired, it fires again every
   --  Reload_Time seconds for as long as line of sight holds (no repeat
   --  aim delay). Losing line of sight at any point resets it back to
   --  needing a fresh Aim_Time acquisition. Returns how many AT guns
   --  fired this call.

end At_Gun_Ai;
