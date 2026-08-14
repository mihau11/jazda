--  Milestone 8: radio report system. Once per entity, at the moment it
--  spawns into the world (all three at game start, for now), a report is
--  queued with its kind and bearing from the player's position at that
--  moment -- not when the player spots it. Reports display one at a
--  time as a banner across the bottom of the screen.

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

procedure Main is
   Fb_Width  : constant := Framebuffer.Width;
   Fb_Height : constant := Framebuffer.Height;
   Scale     : constant := 3;

   Fb     : Framebuffer.Pixel_Array;
   Depths : Raycaster.Depth_Buffer;

   Window   : Window_Ptr;
   Renderer : Renderer_Ptr;
   Texture  : Texture_Ptr;

   Title : Interfaces.C.Strings.chars_ptr :=
     Interfaces.C.Strings.New_String ("Tankette Commander - Milestone 8");

   Running           : Boolean := True;
   Player_Alive      : Boolean := True;
   Player_Hits_Taken : Natural := 0;
   Flash_Timer       : Float := 0.0;
   Event             : Event_Bytes := Empty_Event;

   Flash_Duration : constant Float := 0.25;  --  seconds

   Destroyed_Color       : constant Unsigned_32 := 16#FF3B0A0A#;
   Proximity_Kill_Radius : constant Float := 1.0;
   Frame_Dt              : constant Float := 0.016;  --  matches SDL_Delay (16)
   Max_AT_Hits           : constant := 3;  --  absorbs 3; the 4th destroys it

   --  Hull position/facing, driven by the track-declutch model. Periscope
   --  and gun each have their own independent, player-controlled facing
   --  offset, added to hull facing when rendering.
   Hull_State : Hull.State := (X => 2.5, Y => 7.5, Angle => 0.0);

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
           and then Player_Alive
         then
            Current_Mode :=
              (if Current_Mode = View.Periscope then View.Gun_Sight else View.Periscope);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_X
           and then not Key_Repeat (Event)
           and then Player_Alive
         then
            Gun.Cycle_Sensitivity (Gun_State);
         elsif Event_Type (Event) = SDL_KEYDOWN_EVENT
           and then Key_Code (Event) = SDLK_S
           and then not Key_Repeat (Event)
           and then Player_Alive
         then
            declare
               Keys_Now   : constant Key_State_Ptr :=
                 SDL_GetKeyboardState (System.Null_Address);
               Fire_Angle : constant Float := Hull_State.Angle + Gun_State.Angle;
            begin
               if Keys_Now (SC_A) /= 0 then
                  Combat.Fire (Combat.Autocannon, Hull_State.X, Hull_State.Y, Fire_Angle);
               else
                  Combat.Fire (Combat.Machine_Gun, Hull_State.X, Hull_State.Y, Fire_Angle);
               end if;
            end;
         end if;
      end loop;

      if Player_Alive then
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

            --  Hull: Q/E declutch the right/left track (turning comes
            --  only from the resulting differential, never a direct
            --  turn input); Space/C throttle forward/reverse.
            declare
               Throttle : constant Hull.Throttle_State :=
                 (if Keys (SC_SPACE) /= 0 then Hull.Forward
                  elsif Keys (SC_C) /= 0 then Hull.Back
                  else Hull.Idle);
            begin
               Hull.Update
                 (Hull_State,
                  Throttle         => Throttle,
                  Left_Declutched  => Keys (SC_E) /= 0,
                  Right_Declutched => Keys (SC_Q) /= 0);
            end;

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
                  Player_Hits_Taken := Player_Hits_Taken + New_Hits;
                  if Player_Hits_Taken > Max_AT_Hits then
                     Player_Alive := False;
                  else
                     Flash_Timer := Flash_Duration;
                  end if;
               end if;
            end;

            Radio.Check_Spawns (Hull_State.X, Hull_State.Y);
            Radio.Update (Frame_Dt);
         end;
      end if;

      if Flash_Timer > 0.0 then
         Flash_Timer := Float'Max (0.0, Flash_Timer - Frame_Dt);
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
         if Player_Alive then
            Raycaster.Render
              (Fb, Depths, Hull_State.X, Hull_State.Y, Dir_X, Dir_Y, Plane_X, Plane_Y,
               Horizon_Shift);
            Raycaster.Render_Entities
              (Fb, Depths, Hull_State.X, Hull_State.Y, Dir_X, Dir_Y, Plane_X, Plane_Y,
               Horizon_Shift);
            Hud.Draw (Fb, Effective_Angle, Relative_Angle, Player_Hits_Taken, Current_Mode);
            if Flash_Timer > 0.0 then
               Hud.Apply_Flash (Fb, Flash_Timer / Flash_Duration);
            end if;
            if Radio.Has_Message then
               Hud.Draw_Banner (Fb, Radio.Current_Text);
            end if;
         else
            Fb := (others => Destroyed_Color);
         end if;
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

   SDL_DestroyTexture (Texture);
   SDL_DestroyRenderer (Renderer);
   SDL_DestroyWindow (Window);
   SDL_Quit;
   Interfaces.C.Strings.Free (Title);
end Main;
