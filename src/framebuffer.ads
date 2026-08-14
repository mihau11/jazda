with Interfaces;

package Framebuffer is

   Width  : constant := 320;
   Height : constant := 200;

   type Pixel_Array is array (0 .. Width * Height - 1) of Interfaces.Unsigned_32;

end Framebuffer;
