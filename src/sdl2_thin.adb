package body SDL2_Thin is

   function Get_U32 (E : Event_Bytes; Offset : Natural) return Interfaces.Unsigned_32 is
      use Interfaces;
   begin
      return Unsigned_32 (E (Offset))
        or Shift_Left (Unsigned_32 (E (Offset + 1)), 8)
        or Shift_Left (Unsigned_32 (E (Offset + 2)), 16)
        or Shift_Left (Unsigned_32 (E (Offset + 3)), 24);
   end Get_U32;

   function Event_Type (E : Event_Bytes) return Interfaces.Unsigned_32 is
   begin
      return Get_U32 (E, 0);
   end Event_Type;

   function Key_Code (E : Event_Bytes) return Interfaces.Unsigned_32 is
   begin
      --  offsetof(SDL_KeyboardEvent, keysym) + offsetof(SDL_Keysym, sym)
      return Get_U32 (E, 20);
   end Key_Code;

   function Key_Repeat (E : Event_Bytes) return Boolean is
      use Interfaces;
   begin
      --  offsetof(SDL_KeyboardEvent, repeat)
      return E (13) /= 0;
   end Key_Repeat;

end SDL2_Thin;
