"""Generates Content/atlas.png: a 4x3 grid of 64x64 WW2 (Battle of Stalingrad)
themed pixel-art tiles. See the texture reskin plan for the tile index layout.

Usage: pip install pillow && python scripts/generate_atlas.py
"""
import random

from PIL import Image

TILE = 64
COLS = 4
ROWS = 3

random.seed(1942)


def new_tile():
    return Image.new("RGB", (TILE, TILE))


def speckle(img, color, count, size=1):
    px = img.load()
    for _ in range(count):
        x = random.randint(0, TILE - size)
        y = random.randint(0, TILE - size)
        for dx in range(size):
            for dy in range(size):
                px[x + dx, y + dy] = color


def fill(img, color):
    px = img.load()
    for x in range(TILE):
        for y in range(TILE):
            px[x, y] = color


def tile_grass_top():
    img = new_tile()
    fill(img, (74, 82, 42))
    speckle(img, (95, 100, 55), 220)
    speckle(img, (58, 44, 30), 90)
    px = img.load()
    for _ in range(40):
        x = random.randint(0, TILE - 1)
        y = random.randint(0, TILE - 4)
        h = random.randint(2, 4)
        c = (110, 118, 60) if random.random() < 0.5 else (60, 68, 34)
        for dy in range(h):
            if 0 <= y + dy < TILE:
                px[x, y + dy] = c
    return img


def tile_grass_side():
    img = new_tile()
    fill(img, (86, 63, 40))
    speckle(img, (70, 50, 32), 150)
    speckle(img, (50, 36, 22), 80)
    px = img.load()
    for x in range(TILE):
        band = random.randint(6, 11)
        for y in range(band):
            c = (95, 100, 55) if random.random() < 0.7 else (74, 82, 42)
            px[x, y] = c
    return img


def tile_frozen_mud():
    img = new_tile()
    fill(img, (54, 40, 28))
    speckle(img, (40, 29, 20), 140)
    speckle(img, (210, 214, 220), 90)
    speckle(img, (170, 176, 185), 60)
    return img


def tile_rubble_concrete():
    img = new_tile()
    fill(img, (120, 118, 112))
    speckle(img, (100, 98, 93), 200)
    speckle(img, (140, 138, 132), 120)
    px = img.load()
    for _ in range(14):
        x0 = random.randint(0, TILE - 1)
        y0 = random.randint(0, TILE - 1)
        length = random.randint(8, 22)
        horiz = random.random() < 0.5
        for i in range(length):
            x = x0 + i if horiz else x0
            y = y0 if horiz else y0 + i
            if 0 <= x < TILE and 0 <= y < TILE:
                px[x, y] = (55, 53, 50)
    return img


def tile_wood_planks():
    img = new_tile()
    fill(img, (96, 62, 34))
    px = img.load()
    for x in range(TILE):
        shade = 10 if (x // 8) % 2 == 0 else -8
        for y in range(TILE):
            r, g, b = px[x, y]
            px[x, y] = (max(0, min(255, r + shade)), max(0, min(255, g + shade)), max(0, min(255, b + shade)))
        if x % 8 == 0:
            for y in range(TILE):
                px[x, y] = (60, 38, 20)
    speckle(img, (30, 18, 10), 30, size=1)
    return img


def tile_camo_netting():
    img = new_tile()
    fill(img, (58, 60, 38))
    speckle(img, (40, 45, 28), 160)
    speckle(img, (78, 70, 45), 120)
    speckle(img, (30, 32, 20), 80)
    return img


def tile_sandbags():
    img = new_tile()
    fill(img, (168, 148, 104))
    px = img.load()
    for y in range(0, TILE, 16):
        offset = 8 if (y // 16) % 2 == 0 else 0
        for x in range(TILE):
            if (x + offset) % 16 < 2:
                for dy in range(16):
                    if y + dy < TILE:
                        px[x, y + dy] = (120, 104, 70)
        for x in range(TILE):
            if y < TILE:
                px[x, y] = (140, 122, 84)
    speckle(img, (150, 130, 90), 100)
    return img


def tile_brick_rubble():
    img = new_tile()
    fill(img, (150, 58, 40))
    px = img.load()
    row_h = 8
    for ry, y0 in enumerate(range(0, TILE, row_h)):
        offset = 8 if ry % 2 == 0 else 0
        for x in range(TILE):
            if (x + offset) % 16 == 0:
                for dy in range(row_h):
                    if y0 + dy < TILE:
                        px[x, y0 + dy] = (90, 40, 28)
        for x in range(TILE):
            if y0 < TILE:
                px[x, y0] = (90, 40, 28)
    for _ in range(10):
        x = random.randint(0, TILE - 6)
        y = random.randint(0, TILE - 6)
        for dx in range(random.randint(4, 7)):
            for dy in range(random.randint(4, 7)):
                if x + dx < TILE and y + dy < TILE:
                    px[x + dx, y + dy] = (60, 55, 50)
    speckle(img, (170, 80, 60), 60)
    return img


def tile_snow():
    img = new_tile()
    fill(img, (235, 238, 242))
    speckle(img, (210, 216, 224), 160)
    speckle(img, (190, 198, 210), 80)
    speckle(img, (250, 250, 252), 60)
    return img


def tile_barbed_wire():
    img = new_tile()
    fill(img, (74, 58, 40))
    speckle(img, (58, 44, 30), 130)
    px = img.load()
    for x0 in range(-TILE, TILE, 10):
        for i in range(TILE):
            x = x0 + i
            y = i
            if 0 <= x < TILE and 0 <= y < TILE:
                px[x, y] = (150, 150, 150)
            x2 = x0 + (TILE - i)
            if 0 <= x2 < TILE and 0 <= y < TILE:
                px[x2, y] = (150, 150, 150)
    speckle(img, (190, 190, 195), 20)
    return img


def tile_scorched_ground():
    img = new_tile()
    fill(img, (28, 24, 22))
    speckle(img, (18, 15, 14), 150)
    speckle(img, (60, 50, 40), 60)
    speckle(img, (210, 110, 40), 40)
    speckle(img, (240, 160, 60), 18)
    return img


def tile_metal_wreckage():
    img = new_tile()
    fill(img, (98, 96, 92))
    px = img.load()
    for x in range(TILE):
        if x % 6 < 3:
            for y in range(TILE):
                r, g, b = px[x, y]
                px[x, y] = (r - 14, g - 14, b - 14)
    speckle(img, (150, 90, 50), 70)
    speckle(img, (170, 110, 60), 40)
    speckle(img, (60, 58, 55), 80)
    return img


TILES = [
    tile_grass_top(),
    tile_grass_side(),
    tile_frozen_mud(),
    tile_rubble_concrete(),
    tile_wood_planks(),
    tile_camo_netting(),
    tile_sandbags(),
    tile_brick_rubble(),
    tile_snow(),
    tile_barbed_wire(),
    tile_scorched_ground(),
    tile_metal_wreckage(),
]

atlas = Image.new("RGB", (TILE * COLS, TILE * ROWS))
for idx, tile in enumerate(TILES):
    tx = idx % COLS
    ty = idx // COLS
    atlas.paste(tile, (tx * TILE, ty * TILE))

atlas.save("Content/atlas.png")
print(f"Wrote Content/atlas.png ({atlas.width}x{atlas.height}, {len(TILES)} tiles)")
