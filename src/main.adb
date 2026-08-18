--  Milestone 9: mission structure. A pre-game map editor (size select,
--  then terrain placement) computes a 1-11 difficulty from remaining free
--  space; Mission then spawns that many contacts over time based on
--  difficulty, and the mission is won once every spawned contact is dead
--  (or lost, as before, on player destruction).

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Interfaces; use Interfaces;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;
with System; use System;
with SDL2_Thin; use SDL2_Thin;
with Framebuffer;
with Raycaster;
with View; use View;
with Hud;
with Gun;
with Hull;
with Combat;
with Entities; use Entities;
with At_Gun_Ai;
with Radio;
with Map_Editor;
with Mission;
with Audio;
with Infantry_Ai;
with Textures;

procedure Main is

   type Game_Phase is (Main_Menu, Editor_Size, Editor_Grid, Playing, Won, Lost);
   type Mode_Kind is (Normal, Test_Drive, Trolling);
   --  "Normal" rather than "Mission" to avoid clashing with the Mission
   --  package name (with-ed, not use-d, but a local enumeration literal
   --  of the same name would still conflict with it).
   --  Trolling is a dumping ground for whatever weird one-off idea comes
   --  up next -- deliberately not fleshed out yet, gate anything odd on
   --  Mode = Trolling as it's dreamed up, rather than touching Mission
   --  or Test Drive's behavior.
   Fb_Width  : constant := Framebuffer.Width;
   Fb_Height : constant := Framebuffer.Height;
   Scale     : constant := 3;

   Fb     : Framebuffer.Pixel_Array;
   Depths : Raycaster.Depth_Buffer;

   Window   : Window_Ptr;
   Renderer : Renderer_Ptr;
   Texture  : Texture_Ptr;

   Title : Interfaces.C.Strings.chars_ptr :=
     Interfaces.C.Strings.New_String ("Tankette Commander - Milestone 10");

   Running           : Boolean := True;
   Phase             : Game_Phase := Main_Menu;
   Mode              : Mode_Kind := Normal;  --  chosen from the main menu
   Player_Alive      : Boolean := True;
   Player_Hits_Taken : Natural := 0;
   Flash_Timer       : Float := 0.0;
   Muzzle_Flash_Timer : Float := 0.0;
   Engine_RPM         : Float := 0.15;
   Prev_Radio_Message : Boolean := False;
   Event             : Event_Bytes := Empty_Event;

   Flash_Duration        : constant Float := 0.25;  --  seconds
   Muzzle_Flash_Duration : constant Float := 0.10;  --  a quick blink, not a wash

   Destroyed_Color       : constant Unsigned_32 := 16#FF3B0A0A#;
   Won_Color             : constant Unsigned_32 := 16#FF1E7A3C#;
   Proximity_Kill_Radius : constant Float := 1.5;  --  widened per feedback
   Frame_Dt              : constant Float := 0.016;  --  matches SDL_Delay (16)
   Max_AT_Hits           : constant := 3;  --  absorbs 3; the 4th destroys it

   --  Hull position/facing, driven by the track-declutch model. Periscope
   --  and gun each have their own independent, player-controlled facing
   --  offset, added to hull facing when rendering. Placeholder until the
   --  map editor picks a real spawn point when Phase moves to Playing.
   Hull_State : Hull.State;

   --  Steering levers, one per track: sticky/absolute state (a real lever
   --  stays where you put it), set edge-triggered from the number-key
   --  event handlers below rather than read as held-key state. Defaults
   --  to Drive/Drive, matching a stationary tank ready to move off.
   Left_Lever  : Hull.Lever_Position := Hull.Drive;
   Right_Lever : Hull.Lever_Position := Hull.Drive;

   Periscope_Angle : Float := 0.0;

   --  Coarse (arrow-key) rates -- the original feel gun aiming had before
   --  I/J/K/L took over as the slow, precise fine-aim controls.
   Coarse_Turn_Rate      : constant Float := 0.022;
   Coarse_Elevation_Rate : constant Float := 0.30;

   Gun_State : Gun.State;

   Current_Mode : View.Mode := View.Periscope;

   Degrees_Per_Pixel : constant Float := 2.5;
begin
   if SDL_Init (SDL_INIT_VIDEO) < 0 then
      Put_Line ("SDL_Init failed: " & Interfaces.C.Strings.Value (SDL_GetError));
      return;
   end if;

   Window := SDL_CreateWindow
     (Title,
      SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
      int (Fb_Width * Scale), int (Fb_Height * Scale),
      SDL_WINDOW_SHOWN);

   if Window = System.Null_Address then
      Put_Line ("SDL_CreateWindow failed: " & Interfaces.C.Strings.Value (SDL_GetError));
      return;
   end if;

   Renderer := SDL_CreateRenderer (Window, -1, SDL_RENDERER_ACCELERATED);
   if Renderer = System.Null_Address then
      Put_Line ("SDL_CreateRenderer failed: " & Interfaces.C.Strings.Value (SDL_GetError));
      return;
   end if;

   Texture := SDL_CreateTexture
     (Renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
      int (Fb_Width), int (Fb_Height));
   if Texture = System.Null_Address then
      Put_Line ("SDL_CreateTexture failed: " & Interfaces.C.Strings.Value (SDL_GetError));
      return;
   end if;

   Audio.Init;
   Textures.Load_All;

   while Running loop
      while SDL_PollEvent (Event'Address) /= 0 loop
         if Event_Type (Event) = SDL_QUIT_EVENT then
            Running := False;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_ESCAPE
         then
            Running := False;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_Z
           and then not Key_Repeat (Event)
           and then Phase = Playing
           and then Player_Alive
         then
            Current_Mode :=
              (if Current_Mode = View.Periscope then View.Gun_Sight else View.Periscope);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_X
           and then not Key_Repeat (Event)
           and then Phase = Playing
           and then Player_Alive
         then
            Gun.Cycle_Sensitivity (Gun_State);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_S
           and then not Key_Repeat (Event)
           and then Phase = Playing
           and then Player_Alive
         then
            declare
               Keys_Now   : constant Key_State_Ptr :=
                 SDL_GetKeyboardState (System.Null_Address);
               Fire_Angle : constant Float := Hull_State.Angle + Gun_State.Angle;
            begin
               if Keys_Now (SC_A) /= 0 then
                  Combat.Fire (Combat.Autocannon, Hull_State.X, Hull_State.Y, Fire_Angle);
                  Audio.Play_Gunfire (Audio.Autocannon);
               else
                  Combat.Fire (Combat.Machine_Gun, Hull_State.X, Hull_State.Y, Fire_Angle);
                  Audio.Play_Gunfire (Audio.Machine_Gun);
               end if;
               Muzzle_Flash_Timer := Muzzle_Flash_Duration;
            end;

         --  Main menu: pick Mission (normal play), Test Drive (same map
         --  editor flow, but no mission/contacts get spawned), or
         --  Trolling (same as Test Drive for now -- a reserved slot for
         --  whatever gets bolted on next).
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_1
           and then not Key_Repeat (Event)
           and then Phase = Main_Menu
         then
            Mode := Normal;
            Phase := Editor_Size;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_2
           and then not Key_Repeat (Event)
           and then Phase = Main_Menu
         then
            Mode := Test_Drive;
            Phase := Editor_Size;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_3
           and then not Key_Repeat (Event)
           and then Phase = Main_Menu
         then
            Mode := Trolling;
            Phase := Editor_Size;

         --  Steering levers: absolute-position number keys, not held
         --  state -- each press latches that track's lever straight to
         --  the given position, where it stays until the next press.
         --  Left track: 1=Drive 2=Declutched 3=Brake. Right track:
         --  0=Drive 9=Declutched 8=Brake (deliberately inverted from the
         --  left track's 1/2/3 order per feedback).
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_1
           and then Phase = Playing
           and then Player_Alive
         then
            Left_Lever := Hull.Drive;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_2
           and then Phase = Playing
           and then Player_Alive
         then
            Left_Lever := Hull.Declutched;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_3
           and then Phase = Playing
           and then Player_Alive
         then
            Left_Lever := Hull.Brake;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_8
           and then Phase = Playing
           and then Player_Alive
         then
            Right_Lever := Hull.Brake;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_9
           and then Phase = Playing
           and then Player_Alive
         then
            Right_Lever := Hull.Declutched;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_0
           and then Phase = Playing
           and then Player_Alive
         then
            Right_Lever := Hull.Drive;

         --  Pre-game map editor: pick map size, then place terrain.
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_LEFT
           and then not Key_Repeat (Event)
           and then Phase = Editor_Size
         then
            Map_Editor.Adjust_Width (-1);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_RIGHT
           and then not Key_Repeat (Event)
           and then Phase = Editor_Size
         then
            Map_Editor.Adjust_Width (1);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_UP
           and then not Key_Repeat (Event)
           and then Phase = Editor_Size
         then
            Map_Editor.Adjust_Height (1);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_DOWN
           and then not Key_Repeat (Event)
           and then Phase = Editor_Size
         then
            Map_Editor.Adjust_Height (-1);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_RETURN
           and then not Key_Repeat (Event)
           and then Phase = Editor_Size
         then
            Map_Editor.Begin_Grid_Edit;
            Phase := Editor_Grid;
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_LEFT
           and then not Key_Repeat (Event)
           and then Phase = Editor_Grid
         then
            Map_Editor.Move_Cursor (-1, 0);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_RIGHT
           and then not Key_Repeat (Event)
           and then Phase = Editor_Grid
         then
            Map_Editor.Move_Cursor (1, 0);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_UP
           and then not Key_Repeat (Event)
           and then Phase = Editor_Grid
         then
            Map_Editor.Move_Cursor (0, -1);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_DOWN
           and then not Key_Repeat (Event)
           and then Phase = Editor_Grid
         then
            Map_Editor.Move_Cursor (0, 1);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_0
           and then Phase = Editor_Grid
         then
            Map_Editor.Stamp (0);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_1
           and then Phase = Editor_Grid
         then
            Map_Editor.Stamp (1);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_2
           and then Phase = Editor_Grid
         then
            Map_Editor.Stamp (2);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_3
           and then Phase = Editor_Grid
         then
            Map_Editor.Stamp (3);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_RETURN
           and then not Key_Repeat (Event)
           and then Phase = Editor_Grid
         then
            Map_Editor.Finish_Grid_Edit;
            if Mode = Normal then
               Mission.Begin_Mission (Map_Editor.Difficulty);
            else
               Entities.Reset;  --  Test_Drive/Trolling: no mission, no contacts
            end if;
            Hull_State :=
              (X => Map_Editor.Spawn_X, Y => Map_Editor.Spawn_Y, Angle => 0.0,
               Left_Speed => 0.0, Right_Speed => 0.0);
            Left_Lever  := Hull.Drive;
            Right_Lever := Hull.Drive;
            Phase := Playing;
         end if;
      end loop;

      if Phase = Playing and then Player_Alive then
         declare
            Keys        : constant Key_State_Ptr :=
              SDL_GetKeyboardState (System.Null_Address);
            --  Gun-sight controls (traverse and elevation alike) run at
            --  half speed compared to the periscope -- the narrow zoomed
            --  picture needs finer handling.
            Speed       : constant Float :=
              (if Current_Mode = View.Gun_Sight then 0.25 else 1.0);
            Turn_Coarse : constant Float := Coarse_Turn_Rate * Speed;
            Elev_Coarse : constant Float := Coarse_Elevation_Rate * Speed;
            Fine_Turn   : constant Float := Gun.Turn_Rate (Gun_State.Sensitivity) * Speed;
            Fine_Elev   : constant Float := Gun.Elevation_Rate (Gun_State.Sensitivity) * Speed;
         begin
            --  Traverse: arrows (coarse) and J/L (fine) both drive
            --  whichever sight is currently on screen.
            if Current_Mode = View.Periscope then
               if Keys (SC_LEFT) /= 0 then
                  Periscope_Angle := Periscope_Angle - Turn_Coarse;
               end if;
               if Keys (SC_RIGHT) /= 0 then
                  Periscope_Angle := Periscope_Angle + Turn_Coarse;
               end if;
               if Keys (SC_J) /= 0 then
                  Periscope_Angle := Periscope_Angle - Fine_Turn;
               end if;
               if Keys (SC_L) /= 0 then
                  Periscope_Angle := Periscope_Angle + Fine_Turn;
               end if;
            else
               if Keys (SC_LEFT) /= 0 then
                  Gun_State.Angle := Gun_State.Angle - Turn_Coarse;
               end if;
               if Keys (SC_RIGHT) /= 0 then
                  Gun_State.Angle := Gun_State.Angle + Turn_Coarse;
               end if;
               if Keys (SC_J) /= 0 then
                  Gun_State.Angle := Gun_State.Angle - Fine_Turn;
               end if;
               if Keys (SC_L) /= 0 then
                  Gun_State.Angle := Gun_State.Angle + Fine_Turn;
               end if;
               Gun_State.Angle :=
                 Float'Max (-Gun.Max_Traverse, Float'Min (Gun.Max_Traverse, Gun_State.Angle));
            end if;

            --  Elevation: the gun stays laid regardless of what's
            --  currently on screen, so Up/Down (coarse) and I/K (fine)
            --  always adjust it, even while the periscope is active (at
            --  full speed there, since you're not looking through the
            --  sight).
            if Keys (SC_UP) /= 0 then
               Gun_State.Elevation :=
                 Float'Min (Gun.Max_Elevation, Gun_State.Elevation + Elev_Coarse);
            end if;
            if Keys (SC_DOWN) /= 0 then
               Gun_State.Elevation :=
                 Float'Max (Gun.Min_Elevation, Gun_State.Elevation - Elev_Coarse);
            end if;
            if Keys (SC_I) /= 0 then
               Gun_State.Elevation :=
                 Float'Min (Gun.Max_Elevation, Gun_State.Elevation + Fine_Elev);
            end if;
            if Keys (SC_K) /= 0 then
               Gun_State.Elevation :=
                 Float'Max (Gun.Min_Elevation, Gun_State.Elevation - Fine_Elev);
            end if;

            --  Hull: two 3-position steering levers (Left_Lever/
            --  Right_Lever, set edge-triggered above) decide whether
            --  each track follows the throttle (Drive), freewheels
            --  (Declutched), or is actively held (Brake); turning comes
            --  only from the resulting per-track speed differential,
            --  never a direct turn input. Space/C throttle forward/reverse.
            declare
               use type Hull.Lever_Position;
               Throttle : constant Hull.Throttle_State :=
                 (if Keys (SC_SPACE) /= 0 then Hull.Forward
                  elsif Keys (SC_C) /= 0 then Hull.Back
                  else Hull.Idle);
               RPM_Target : constant Float :=
                 (if Keys (SC_SPACE) /= 0 or else Keys (SC_C) /= 0 then 1.0 else 0.15);
            begin
               Hull.Update
                 (Hull_State,
                  Throttle    => Throttle,
                  Left_Lever  => Left_Lever,
                  Right_Lever => Right_Lever);

               Engine_RPM := Engine_RPM + (RPM_Target - Engine_RPM) * Float'Min (1.0, 4.0 * Frame_Dt);
               Audio.Update
                 (Engine_RPM,
                  Track_Strain =>
                    (Keys (SC_SPACE) /= 0 or else Keys (SC_C) /= 0)
                    and then (Left_Lever = Hull.Brake or else Right_Lever = Hull.Brake));
            end;

            Infantry_Ai.Update (Hull_State.X, Hull_State.Y, Frame_Dt);

            --  Proximity kill: an alive infantry contact that closes to
            --  point-blank range destroys the tank instantly.
            for E of Entities.List loop
               if E.Alive and then E.Kind = Entities.Infantry then
                  declare
                     Dx : constant Float := E.X - Hull_State.X;
                     Dy : constant Float := E.Y - Hull_State.Y;
                  begin
                     if Dx * Dx + Dy * Dy <= Proximity_Kill_Radius * Proximity_Kill_Radius then
                        Player_Alive := False;
                        Phase := Lost;
                     end if;
                  end;
               end if;
            end loop;

            --  AT guns: 3s continuous line-of-sight to aim, then a hit,
            --  then a 3s reload before aiming again.
            declare
               New_Hits : constant Natural :=
                 At_Gun_Ai.Update (Hull_State.X, Hull_State.Y, Frame_Dt);
            begin
               if New_Hits > 0 then
                  Audio.Play_At_Gun_Fire;
                  Player_Hits_Taken := Player_Hits_Taken + New_Hits;
                  if Player_Hits_Taken > Max_AT_Hits then
                     Player_Alive := False;
                     Phase := Lost;
                  else
                     Flash_Timer := Flash_Duration;
                  end if;
               end if;
            end;

            Mission.Update (Hull_State.X, Hull_State.Y, Frame_Dt);
            Radio.Check_Spawns (Hull_State.X, Hull_State.Y);
            Radio.Update (Frame_Dt);

            if Radio.Has_Message and then not Prev_Radio_Message then
               Audio.Play_Radio_Blip;
            end if;
            Prev_Radio_Message := Radio.Has_Message;

            if Mission.Is_Won then
               Phase := Won;
            end if;
         end;
      end if;

      if Flash_Timer > 0.0 then
         Flash_Timer := Float'Max (0.0, Flash_Timer - Frame_Dt);
      end if;
      if Muzzle_Flash_Timer > 0.0 then
         Muzzle_Flash_Timer := Float'Max (0.0, Muzzle_Flash_Timer - Frame_Dt);
      end if;

      declare
         Relative_Angle : constant Float :=
           (if Current_Mode = View.Gun_Sight then Gun_State.Angle else Periscope_Angle);
         Effective_Angle : constant Float := Hull_State.Angle + Relative_Angle;
         Horizon_Shift    : constant Integer :=
           (if Current_Mode = View.Gun_Sight
              then Integer (Gun_State.Elevation * Degrees_Per_Pixel)
              else 0);
         Dir_X     : constant Float := Cos (Effective_Angle);
         Dir_Y     : constant Float := Sin (Effective_Angle);
         Plane_Len : constant Float := View.Plane_Length (Current_Mode);
         Plane_X   : constant Float := -Dir_Y * Plane_Len;
         Plane_Y   : constant Float := Dir_X * Plane_Len;
      begin
         case Phase is
            when Main_Menu =>
               Map_Editor.Draw_Main_Menu (Fb);
            when Editor_Size =>
               Map_Editor.Draw_Size_Select (Fb);
            when Editor_Grid =>
               Map_Editor.Draw_Grid_Edit (Fb);
            when Playing =>
               Raycaster.Render
                 (Fb, Depths, Hull_State.X, Hull_State.Y, Dir_X, Dir_Y, Plane_X, Plane_Y,
                  Horizon_Shift);
               Raycaster.Render_Entities
                 (Fb, Depths, Hull_State.X, Hull_State.Y, Dir_X, Dir_Y, Plane_X, Plane_Y,
                  Horizon_Shift);
               --  Muzzle flash is a light in the world (from the gun
               --  itself), so it belongs on the raw scene, before the
               --  vignette/binoculars mask and header are painted on top --
               --  that way the mask's black surround stays solid and the
               --  flash only shows through the actual sight picture,
               --  rather than bleeding onto the eyepiece housing.
               if Muzzle_Flash_Timer > 0.0 then
                  Hud.Apply_Muzzle_Flash (Fb, Muzzle_Flash_Timer / Muzzle_Flash_Duration);
               end if;
               Hud.Draw
                 (Fb, Effective_Angle, Relative_Angle, Player_Hits_Taken, Current_Mode,
                  Left_Lever, Right_Lever);
               --  The hit-taken flash is a UI jolt cue, not a light in the
               --  world, so it stays full-screen (including the vignette).
               if Flash_Timer > 0.0 then
                  Hud.Apply_Flash (Fb, Flash_Timer / Flash_Duration);
               end if;
               if Radio.Has_Message then
                  Hud.Draw_Banner (Fb, Radio.Current_Text);
               end if;
            when Lost =>
               Fb := (others => Destroyed_Color);
            when Won =>
               Fb := (others => Won_Color);
               Hud.Draw_Banner (Fb, "MISSION COMPLETE");
         end case;
      end;

      declare
         Ignore : int;
      begin
         Ignore := SDL_UpdateTexture
           (Texture, System.Null_Address, Fb'Address, int (Fb_Width * 4));
         Ignore := SDL_RenderClear (Renderer);
         Ignore := SDL_RenderCopy
           (Renderer, Texture, System.Null_Address, System.Null_Address);
      end;

      SDL_RenderPresent (Renderer);
      SDL_Delay (16);
   end loop;

   Audio.Shutdown;
   SDL_DestroyTexture (Texture);
   SDL_DestroyRenderer (Renderer);
   SDL_DestroyWindow (Window);
   SDL_Quit;
   Interfaces.C.Strings.Free (Title);
end Main;
