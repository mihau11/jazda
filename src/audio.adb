with Ada.Numerics; use Ada.Numerics;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Interfaces; use Interfaces;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;
with SDL2_Thin; use SDL2_Thin;

package body Audio is

   Sample_Rate : constant := 22_050;

   Device : SDL2_Thin.Audio_Device_ID := 0;

   --  Continuous engine-drone phase/LFO state.
   Engine_Phase : Float := 0.0;
   Strain_Phase : Float := 0.0;
   Time_Accum   : Float := 0.0;

   --  One-shot player-weapon / AT-gun report state (mutually exclusive --
   --  refiring restarts whichever is currently sounding).
   type Report_Kind is (None, Mg, Ac, At_Bark);
   Report        : Report_Kind := None;
   Report_Sample : Natural := 0;
   Report_Phase  : Float := 0.0;

   --  One-shot radio-blip state, independent of Report so a gunshot and a
   --  radio cue can overlap.
   Blip_Active : Boolean := False;
   Blip_Sample : Natural := 0;
   Blip_Phase  : Float := 0.0;

   Rng_State : Unsigned_32 := 2_463_534_242;

   function Next_Noise return Float is
   begin
      Rng_State := Rng_State * 1_103_515_245 + 12_345;
      return Float ((Rng_State / 2) mod 65_536) / 32_768.0 - 1.0;
   end Next_Noise;

   procedure Advance_Phase (Phase : in out Float; Freq : Float) is
   begin
      Phase := Phase + Freq / Float (Sample_Rate);
      if Phase >= 1.0 then
         Phase := Phase - 1.0;
      end if;
   end Advance_Phase;

   function Square (Phase : Float) return Float is
   begin
      return (if Phase < 0.5 then 1.0 else -1.0);
   end Square;

   --  Advances every persistent phase/timer by one sample and returns the
   --  mixed, clamped result ready to drop straight into the output buffer.
   function Next_Sample (Load : Float; Strain : Boolean) return Integer_16 is
      Engine_Freq : constant Float := 55.0 + Load * 110.0;
      Mix         : Float;
   begin
      Advance_Phase (Engine_Phase, Engine_Freq);
      Time_Accum := Time_Accum + 1.0 / Float (Sample_Rate);

      declare
         Tremolo : constant Float := 0.8 + 0.2 * Sin (2.0 * Pi * 6.0 * Time_Accum);
      begin
         Mix := Square (Engine_Phase) * (1800.0 + 1600.0 * Load) * Tremolo;
      end;

      if Strain then
         Advance_Phase (Strain_Phase, Engine_Freq * 1.5);
         Mix := Mix + Square (Strain_Phase) * 900.0;
      end if;

      case Report is
         when None =>
            null;
         when Mg =>
            declare
               Dur         : constant Natural := Natural (0.15 * Float (Sample_Rate));
               Gate_Period : constant Natural := Sample_Rate / 16;
            begin
               if Report_Sample < Dur then
                  declare
                     Envelope : constant Float :=
                       1.0 - Float (Report_Sample) / Float (Dur);
                     Gate_On  : constant Boolean :=
                       (Report_Sample mod Gate_Period) < Gate_Period / 2;
                  begin
                     if Gate_On then
                        Mix := Mix + Next_Noise * 7000.0 * Envelope;
                     end if;
                  end;
                  Report_Sample := Report_Sample + 1;
               else
                  Report := None;
               end if;
            end;
         when Ac =>
            declare
               Dur : constant Natural := Natural (0.22 * Float (Sample_Rate));
            begin
               if Report_Sample < Dur then
                  declare
                     Envelope : constant Float :=
                       (1.0 - Float (Report_Sample) / Float (Dur)) ** 2;
                  begin
                     Advance_Phase (Report_Phase, 90.0);
                     Mix := Mix + (Square (Report_Phase) * 9000.0
                                    + Next_Noise * 3500.0) * Envelope;
                  end;
                  Report_Sample := Report_Sample + 1;
               else
                  Report := None;
               end if;
            end;
         when At_Bark =>
            declare
               Dur : constant Natural := Natural (0.30 * Float (Sample_Rate));
            begin
               if Report_Sample < Dur then
                  declare
                     Envelope : constant Float :=
                       (1.0 - Float (Report_Sample) / Float (Dur)) ** 2;
                  begin
                     Advance_Phase (Report_Phase, 60.0);
                     Mix := Mix + (Square (Report_Phase) * 8500.0
                                    + Next_Noise * 4500.0) * Envelope;
                  end;
                  Report_Sample := Report_Sample + 1;
               else
                  Report := None;
               end if;
            end;
      end case;

      if Blip_Active then
         declare
            Tone_Len : constant Natural := Natural (0.07 * Float (Sample_Rate));
            Gap_Len  : constant Natural := Natural (0.03 * Float (Sample_Rate));
         begin
            if Blip_Sample < Tone_Len then
               Advance_Phase (Blip_Phase, 880.0);
               Mix := Mix + Sin (2.0 * Pi * Blip_Phase) * 5000.0;
            elsif Blip_Sample < Tone_Len + Gap_Len then
               null;
            elsif Blip_Sample < 2 * Tone_Len + Gap_Len then
               Advance_Phase (Blip_Phase, 1320.0);
               Mix := Mix + Sin (2.0 * Pi * Blip_Phase) * 5000.0;
            else
               Blip_Active := False;
            end if;
            Blip_Sample := Blip_Sample + 1;
         end;
      end if;

      if Mix > 32_000.0 then
         Mix := 32_000.0;
      elsif Mix < -32_000.0 then
         Mix := -32_000.0;
      end if;
      return Integer_16 (Mix);
   end Next_Sample;

   procedure Init is
      Want : SDL2_Thin.Audio_Spec;
      Have : SDL2_Thin.Audio_Spec;
   begin
      if SDL2_Thin.SDL_Init (SDL2_Thin.SDL_INIT_AUDIO) < 0 then
         return;
      end if;
      Want.Freq     := 22_050;
      Want.Format   := SDL2_Thin.AUDIO_S16SYS;
      Want.Channels := 1;
      Want.Samples  := 256;  --  small hardware period -- keeps the latency
                              --  floor low (verified this exact size is
                              --  honored on the real build toolchain)
      Device := SDL2_Thin.SDL_OpenAudioDevice
        (Interfaces.C.Strings.Null_Ptr, 0, Want'Address, Have'Address, 0);
      if Device /= 0 then
         SDL2_Thin.SDL_PauseAudioDevice (Device, 0);
      end if;
   end Init;

   procedure Shutdown is
   begin
      if Device /= 0 then
         SDL2_Thin.SDL_CloseAudioDevice (Device);
         Device := 0;
      end if;
   end Shutdown;

   --  Keep at most this many bytes ever queued ahead of what is actually
   --  playing -- roughly 40ms at 22050 Hz mono S16. Small enough that
   --  firing/throttle changes feel immediate, large enough to absorb
   --  ordinary frame-time jitter without an audible underrun.
   Target_Queue_Bytes : constant Unsigned_32 := 1_800;

   procedure Update (Engine_Load : Float; Track_Strain : Boolean) is
      Load   : constant Float := Float'Min (1.0, Float'Max (0.0, Engine_Load));
      Queued : Unsigned_32;
      Ignore : Interfaces.C.int;
   begin
      if Device = 0 then
         return;
      end if;

      Queued := SDL2_Thin.SDL_GetQueuedAudioSize (Device);
      if Queued >= Target_Queue_Bytes then
         return;  --  already enough buffered; do not add more latency
      end if;

      declare
         N : constant Natural := Natural (Target_Queue_Bytes - Queued) / 2;
      begin
         if N = 0 then
            return;
         end if;

         declare
            Buf : array (1 .. N) of Interfaces.Integer_16;
         begin
            for I in 1 .. N loop
               Buf (I) := Next_Sample (Load, Track_Strain);
            end loop;
            Ignore := SDL2_Thin.SDL_QueueAudio
              (Device, Buf'Address, Interfaces.Unsigned_32 (N * 2));
         end;
      end;
   end Update;

   procedure Play_Gunfire (Sound : Weapon_Sound) is
   begin
      Report        := (if Sound = Machine_Gun then Mg else Ac);
      Report_Sample := 0;
      Report_Phase  := 0.0;
   end Play_Gunfire;

   procedure Play_At_Gun_Fire is
   begin
      Report        := At_Bark;
      Report_Sample := 0;
      Report_Phase  := 0.0;
   end Play_At_Gun_Fire;

   procedure Play_Radio_Blip is
   begin
      Blip_Active := True;
      Blip_Sample := 0;
      Blip_Phase  := 0.0;
   end Play_Radio_Blip;

end Audio;
