--  Thin, hand-written Ada binding to the subset of SDL2 needed to open a
--  window and push a raw ARGB8888 framebuffer to it. Deliberately not a
--  general-purpose SDL2 binding: only what this project uses.
--  Constants and struct offsets verified against libsdl2-dev 2.32.4 headers.

with Interfaces.C;
with Interfaces.C.Strings;
with Interfaces;
with System;

package SDL2_Thin is

   subtype Window_Ptr   is System.Address;
   subtype Renderer_Ptr is System.Address;
   subtype Texture_Ptr  is System.Address;

   SDL_INIT_VIDEO : constant Interfaces.C.unsigned := 32;

   SDL_WINDOWPOS_UNDEFINED : constant Interfaces.C.int := 536_805_376;

   SDL_WINDOW_SHOWN : constant Interfaces.C.unsigned := 4;

   SDL_RENDERER_ACCELERATED : constant Interfaces.C.unsigned := 2;

   SDL_PIXELFORMAT_ARGB8888 : constant Interfaces.C.unsigned := 372_645_892;

   SDL_TEXTUREACCESS_STREAMING : constant Interfaces.C.int := 1;

   SDL_QUIT_EVENT    : constant Interfaces.Unsigned_32 := 256;
   SDL_KEYDOWN_EVENT : constant Interfaces.Unsigned_32 := 768;
   SDLK_ESCAPE       : constant Interfaces.Unsigned_32 := 27;
   SDLK_Z            : constant Interfaces.Unsigned_32 := 122;
   SDLK_X            : constant Interfaces.Unsigned_32 := 120;
   SDLK_S            : constant Interfaces.Unsigned_32 := 115;

   --  SDL_Scancode values for continuous (held-key) input, read via
   --  SDL_GetKeyboardState rather than discrete keydown/keyup events.
   SC_LEFT  : constant := 80;
   SC_RIGHT : constant := 79;
   SC_UP    : constant := 82;
   SC_DOWN  : constant := 81;
   SC_I     : constant := 12;
   SC_J     : constant := 13;
   SC_K     : constant := 14;
   SC_L     : constant := 15;
   SC_Q     : constant := 20;
   SC_E     : constant := 8;
   SC_SPACE : constant := 44;
   SC_C     : constant := 6;
   SC_A     : constant := 4;

   function SDL_Init (Flags : Interfaces.C.unsigned) return Interfaces.C.int;
   pragma Import (C, SDL_Init, "SDL_Init");

   function SDL_CreateWindow
     (Title : Interfaces.C.Strings.chars_ptr;
      X, Y  : Interfaces.C.int;
      W, H  : Interfaces.C.int;
      Flags : Interfaces.C.unsigned) return Window_Ptr;
   pragma Import (C, SDL_CreateWindow, "SDL_CreateWindow");

   function SDL_CreateRenderer
     (Window : Window_Ptr;
      Index  : Interfaces.C.int;
      Flags  : Interfaces.C.unsigned) return Renderer_Ptr;
   pragma Import (C, SDL_CreateRenderer, "SDL_CreateRenderer");

   function SDL_CreateTexture
     (Renderer : Renderer_Ptr;
      Format   : Interfaces.C.unsigned;
      Access_K : Interfaces.C.int;
      W, H     : Interfaces.C.int) return Texture_Ptr;
   pragma Import (C, SDL_CreateTexture, "SDL_CreateTexture");

   function SDL_UpdateTexture
     (Texture : Texture_Ptr;
      Rect    : System.Address;
      Pixels  : System.Address;
      Pitch   : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, SDL_UpdateTexture, "SDL_UpdateTexture");

   function SDL_RenderClear (Renderer : Renderer_Ptr) return Interfaces.C.int;
   pragma Import (C, SDL_RenderClear, "SDL_RenderClear");

   function SDL_RenderCopy
     (Renderer : Renderer_Ptr;
      Texture  : Texture_Ptr;
      Src_Rect : System.Address;
      Dst_Rect : System.Address) return Interfaces.C.int;
   pragma Import (C, SDL_RenderCopy, "SDL_RenderCopy");

   procedure SDL_RenderPresent (Renderer : Renderer_Ptr);
   pragma Import (C, SDL_RenderPresent, "SDL_RenderPresent");

   procedure SDL_DestroyTexture (Texture : Texture_Ptr);
   pragma Import (C, SDL_DestroyTexture, "SDL_DestroyTexture");

   procedure SDL_DestroyRenderer (Renderer : Renderer_Ptr);
   pragma Import (C, SDL_DestroyRenderer, "SDL_DestroyRenderer");

   procedure SDL_DestroyWindow (Window : Window_Ptr);
   pragma Import (C, SDL_DestroyWindow, "SDL_DestroyWindow");

   procedure SDL_Quit;
   pragma Import (C, SDL_Quit, "SDL_Quit");

   function SDL_GetError return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, SDL_GetError, "SDL_GetError");

   procedure SDL_Delay (Ms : Interfaces.C.unsigned);
   pragma Import (C, SDL_Delay, "SDL_Delay");

   --  SDL_Event is a 56-byte C union. We only ever need the leading
   --  event-type tag and, for keydown events, the keysym at a fixed offset.
   type Event_Bytes is array (0 .. 55) of Interfaces.Unsigned_8;
   Empty_Event : constant Event_Bytes := (others => 0);

   function SDL_PollEvent (Event : System.Address) return Interfaces.C.int;
   pragma Import (C, SDL_PollEvent, "SDL_PollEvent");

   function Event_Type (E : Event_Bytes) return Interfaces.Unsigned_32;
   function Key_Code   (E : Event_Bytes) return Interfaces.Unsigned_32;

   --  True if this SDL_KEYDOWN is an OS auto-repeat (key held down), not the
   --  original key press. Callers that want an edge-triggered toggle (like
   --  the view-mode switch) must ignore repeats.
   function Key_Repeat (E : Event_Bytes) return Boolean;

   --  Live snapshot of every key's up/down state, indexed by SDL_Scancode
   --  (see SC_* above). Used for continuous per-frame input (gun turning)
   --  instead of discrete events, so movement doesn't depend on OS key
   --  repeat timing.
   type Key_State_Array is array (0 .. 511) of Interfaces.Unsigned_8;
   type Key_State_Ptr is access all Key_State_Array;
   pragma Convention (C, Key_State_Ptr);

   function SDL_GetKeyboardState (Numkeys : System.Address) return Key_State_Ptr;
   pragma Import (C, SDL_GetKeyboardState, "SDL_GetKeyboardState");

end SDL2_Thin;
