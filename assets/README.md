# Custom textures

Drop `.bmp` files in this folder to replace the game's procedural flat-color
walls, floor, ceiling, and entity sprites. Anything you don't provide keeps
rendering exactly as it did before this feature existed -- this whole folder
is optional.

Recognized filenames (one texture per slot, `World_Map.Cell_Value` 1/2/3
matching the map editor's wall/pillar/barrier stamps):

| File            | Used for                          |
|-----------------|------------------------------------|
| `infantry.bmp`  | Infantry sprite                    |
| `at_gun.bmp`    | AT gun sprite                      |
| `wall_1.bmp`    | Concrete wall (stamp `1`)          |
| `wall_2.bmp`    | Pillar (stamp `2`)                 |
| `wall_3.bmp`    | Low barrier wall (stamp `3`)       |
| `floor.bmp`     | Ground plane                       |
| `ceiling.bmp`   | Sky/ceiling plane                  |

Notes:

- Must be `.bmp` (Windows Bitmap) -- loaded via SDL2's own built-in loader,
  no extra library required. Any image editor, or ImageMagick
  (`convert in.png out.bmp`), can export one.
- Any size up to 512x512 per side; small (e.g. 16x16-64x64) pixel-art tiles
  look best given the game's 320x200 internal resolution.
- Wall/floor/ceiling textures tile seamlessly across their surface, so
  design them as repeating tiles.
- Sprite textures (`infantry.bmp`, `at_gun.bmp`) treat their top-left
  pixel's color as transparent -- draw the figure on a solid background
  in that color and it becomes a cutout instead of a rectangle.
- A missing, unreadable, or oversized file just leaves that one slot
  unchanged (flat color) -- check the game's console output for a note if
  a file you added doesn't seem to take effect.
