--  Milestone 10: minimal audio pass. The codebase has no external assets
--  of any kind (no images, no sound files) -- everything is procedurally
--  drawn. To stay consistent with that, Audio synthesizes every sound at
--  runtime (square/sine tones plus a cheap noise generator) and pushes the
--  samples straight to a raw SDL2 audio device, rather than pulling in
--  SDL2_mixer or shipping .wav files.

package Audio is

   type Weapon_Sound is (Machine_Gun, Autocannon);

   procedure Init;
   --  Opens a mono 22050 Hz S16 output device and starts it unpaused. If
   --  the audio subsystem or device cannot be opened (no backend
   --  available), Audio quietly becomes a no-op for the rest of the run --
   --  unlike video init, a missing audio device does not stop the game.

   procedure Shutdown;

   procedure Update (Engine_Load : Float; Track_Strain : Boolean);
   --  Tops up the output queue to a small fixed target (rather than
   --  queueing a fixed Dt worth each call) so at most a few tens of
   --  milliseconds of audio ever sit buffered ahead of what is currently
   --  playing -- keeping perceived latency low and roughly constant
   --  regardless of frame-time jitter. Synthesizes a continuous engine
   --  drone whose pitch follows Engine_Load (0.0 idle .. 1.0 full
   --  throttle), with a detuned overtone mixed in while Track_Strain is
   --  True (a track declutched under power), plus whatever one-shot
   --  effect was armed by Play_Gunfire / Play_At_Gun_Fire /
   --  Play_Radio_Blip. Call once per frame while the engine should be
   --  audible; simply stop calling it (e.g. in menus or after death) to
   --  let the engine fall silent.

   procedure Play_Gunfire (Sound : Weapon_Sound);
   --  Arms a short one-shot player-weapon report, restarting it if one is
   --  already playing.

   procedure Play_At_Gun_Fire;
   --  Arms a short one-shot enemy AT-gun bark, lower-pitched than the
   --  player's own weapons so it reads as a distinct, distant threat.

   procedure Play_Radio_Blip;
   --  Arms a short one-shot two-tone beep for a new radio report, playing
   --  independently of any weapon fire that happens to coincide with it.

end Audio;
