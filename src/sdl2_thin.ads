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
   SDL_INIT_AUDIO : constant Interfaces.C.unsigned := 16;

   SDL_WINDOWPOS_UNDEFINED : constant Interfaces.C.int := 536_805_376;

   SDL_WINDOW_SHOWN : constant Interfaces.C.unsigned := 4;

   SDL_RENDERER_ACCELERATED : constant Interfaces.C.unsigned := 2;

   SDL_PIXELFORMAT_ARGB8888 : constant Interfaces.C.unsigned := 372_645_892;

   SDL_TEXTUREACCESS_STREAMING : constant Interfaces.C.int := 1;

   SDL_QUIT_EVENT    : constant Interfaces.Unsigned_32 := 256;
   SDL_KEYDOWN_EVENT : constant Interfaces.Unsigned_32 := 768;
   SDLK_ESCAPE       : constant Interfaces.Unsigned_32 := 27;
   SDLK_RETURN       : constant Interfaces.Unsigned_32 := 13;
   SDLK_Z            : constant Interfaces.Unsigned_32 := 122;
   SDLK_X            : constant Interfaces.Unsigned_32 := 120;
   SDLK_S            : constant Interfaces.Unsigned_32 := 115;
   SDLK_0            : constant Interfaces.Unsigned_32 := 48;
   SDLK_1            : constant Interfaces.Unsigned_32 := 49;
   SDLK_2            : constant Interfaces.Unsigned_32 := 50;
   SDLK_3            : constant Interfaces.Unsigned_32 := 51;
   SDLK_8            : constant Interfaces.Unsigned_32 := 56;
   SDLK_9            : constant Interfaces.Unsigned_32 := 57;

   --  Arrow keycodes use the SDLK_SCANCODE_MASK high bit rather than an
   --  ASCII-range value, unlike the letter/digit keycodes above.
   SDLK_LEFT  : constant Interfaces.Unsigned_32 := 1_073_741_904;
   SDLK_RIGHT : constant Interfaces.Unsigned_32 := 1_073_741_903;
   SDLK_UP    : constant Interfaces.Unsigned_32 := 1_073_741_906;
   SDLK_DOWN  : constant Interfaces.Unsigned_32 := 1_073_741_905;

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

   --  Live snapshot of every key up/down state, indexed by SDL_Scancode
   --  (see SC_* above). Used for continuous per-frame input (gun turning)
   --  instead of discrete events, so movement does not depend on OS key
   --  repeat timing.
   type Key_State_Array is array (0 .. 511) of Interfaces.Unsigned_8;
   type Key_State_Ptr is access all Key_State_Array;
   pragma Convention (C, Key_State_Ptr);

   function SDL_GetKeyboardState (Numkeys : System.Address) return Key_State_Ptr;
   pragma Import (C, SDL_GetKeyboardState, "SDL_GetKeyboardState");

   --  Raw audio output (milestone 10): rather than pull in SDL2_mixer or
   --  ship .wav assets (this project has no external assets at all, per
   --  DESIGN.md), Audio synthesizes tones/noise at runtime and pushes them
   --  straight to the device with SDL_QueueAudio. Struct layout/offsets
   --  verified against the actual build toolchain (sizeof(SDL_AudioSpec)
   --  is 32 bytes on x86_64 Linux/WSL).
   AUDIO_S16SYS : constant Interfaces.Unsigned_16 := 32_784;

   type Audio_Spec is record
      Freq     : Interfaces.C.int       := 0;
      Format   : Interfaces.Unsigned_16 := 0;
      Channels : Interfaces.Unsigned_8  := 0;
      Silence  : Interfaces.Unsigned_8  := 0;
      Samples  : Interfaces.Unsigned_16 := 0;
      Padding  : Interfaces.Unsigned_16 := 0;
      Size     : Interfaces.Unsigned_32 := 0;
      Callback : System.Address         := System.Null_Address;
      Userdata : System.Address         := System.Null_Address;
   end record;
   pragma Convention (C, Audio_Spec);

   type Audio_Device_ID is new Interfaces.Unsigned_32;

   function SDL_OpenAudioDevice
     (Device          : Interfaces.C.Strings.chars_ptr;
      Is_Capture      : Interfaces.C.int;
      Desired         : System.Address;
      Obtained        : System.Address;
      Allowed_Changes : Interfaces.C.int) return Audio_Device_ID;
   pragma Import (C, SDL_OpenAudioDevice, "SDL_OpenAudioDevice");

   procedure SDL_PauseAudioDevice (Dev : Audio_Device_ID; Pause_On : Interfaces.C.int);
   pragma Import (C, SDL_PauseAudioDevice, "SDL_PauseAudioDevice");

   function SDL_QueueAudio
     (Dev  : Audio_Device_ID;
      Data : System.Address;
      Len  : Interfaces.Unsigned_32) return Interfaces.C.int;
   pragma Import (C, SDL_QueueAudio, "SDL_QueueAudio");

   function SDL_GetQueuedAudioSize (Dev : Audio_Device_ID) return Interfaces.Unsigned_32;
   pragma Import (C, SDL_GetQueuedAudioSize, "SDL_GetQueuedAudioSize");

   procedure SDL_CloseAudioDevice (Dev : Audio_Device_ID);
   pragma Import (C, SDL_CloseAudioDevice, "SDL_CloseAudioDevice");

   --  Optional bitmap loading (Textures, src/textures.ads/.adb): lets the
   --  player drop their own .bmp files into an assets/ folder to replace
   --  the procedural flat-color walls/floor/ceiling/sprites -- the game
   --  looks exactly as before if assets/ is absent or a given file is
   --  missing. Deliberately BMP-only via SDL2's own built-in loader (no
   --  SDL2_image dependency): SDL_LoadBMP is itself a header macro
   --  (SDL_LoadBMP_RW (SDL_RWFromFile (file, "rb"), 1)), reimplemented here
   --  from its two underlying calls since GNAT cannot import a C macro.
   subtype RWops_Ptr is System.Address;

   function SDL_RWFromFile
     (File : Interfaces.C.Strings.chars_ptr;
      Mode : Interfaces.C.Strings.chars_ptr) return RWops_Ptr;
   pragma Import (C, SDL_RWFromFile, "SDL_RWFromFile");

   --  Mirrors only the leading fields of SDL_Surface actually needed
   --  (format/w/h/pitch/pixels); trailing fields (userdata, locked,
   --  clip_rect, ...) are never touched and omitted, same spirit as
   --  Event_Bytes above. Verified against libsdl2-dev 2.32.4's
   --  SDL_surface.h.
   type Surface_Header is record
      Flags  : Interfaces.Unsigned_32;
      Format : System.Address;
      W, H   : Interfaces.C.int;
      Pitch  : Interfaces.C.int;
      Pixels : System.Address;
   end record;
   pragma Convention (C, Surface_Header);

   type Surface_Ptr is access all Surface_Header;
   pragma Convention (C, Surface_Ptr);

   function SDL_LoadBMP_RW
     (Src : RWops_Ptr; Freesrc : Interfaces.C.int) return Surface_Ptr;
   pragma Import (C, SDL_LoadBMP_RW, "SDL_LoadBMP_RW");

   function SDL_ConvertSurfaceFormat
     (Src          : Surface_Ptr;
      Pixel_Format : Interfaces.C.unsigned;
      Flags        : Interfaces.C.unsigned) return Surface_Ptr;
   pragma Import (C, SDL_ConvertSurfaceFormat, "SDL_ConvertSurfaceFormat");

   procedure SDL_FreeSurface (Surface : Surface_Ptr);
   pragma Import (C, SDL_FreeSurface, "SDL_FreeSurface");

end SDL2_Thin;
