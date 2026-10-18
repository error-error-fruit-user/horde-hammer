#!/usr/bin/env python3
"""Draw the library's placeholder sprites and HUD pictures into hh/.

usage: python3 tools/placeholders.py

Dependency-free Python 3.8+. Every picture is a flat shape with a short label in a tiny pixel
font, so a map built on Horde Hammer is playable before it has art; a game replaces them by
shipping files with the same names (the game's pk3 loads after the library, so its files win)
or by using its own sprites in its subclasses. The output is reproducible: running it again
writes the same bytes, so only real changes show up in version control.

Sprites get offsets (a grAb chunk): things stand on their bottom center, and the first-person
pictures (the drink and the kick) sit at the bottom of a 320x200 screen.
"""

import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "hh")

# 3x5 pixel font, rows top to bottom, for the labels
FONT = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "110", "100", "110", "101"], "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"], "N": ["110", "101", "101", "101", "101"],
    "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"], "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"], "$": ["011", "110", "010", "011", "110"],
    "?": ["110", "001", "010", "000", "010"], "+": ["000", "010", "111", "010", "000"],
    " ": ["000", "000", "000", "000", "000"],
}


class Picture:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.pixels = [[(0, 0, 0, 0)] * width for _ in range(height)]

    def rect(self, x, y, w, h, color):
        for row in range(max(0, y), min(self.height, y + h)):
            for column in range(max(0, x), min(self.width, x + w)):
                self.pixels[row][column] = color

    def frame(self, x, y, w, h, color, thickness=1):
        self.rect(x, y, w, thickness, color)
        self.rect(x, y + h - thickness, w, thickness, color)
        self.rect(x, y, thickness, h, color)
        self.rect(x + w - thickness, y, thickness, h, color)

    def text(self, label, color, scale=1, center_y=None):
        """Write label centered horizontally, at center_y (default: the middle)."""
        width = (len(label) * 4 - 1) * scale
        x = (self.width - width) // 2
        y = (self.height - 5 * scale) // 2 if center_y is None else center_y - 5 * scale // 2
        for letter in label:
            for row, bits in enumerate(FONT[letter]):
                for column, bit in enumerate(bits):
                    if bit == "1":
                        self.rect(x + column * scale, y + row * scale, scale, scale, color)
            x += 4 * scale

    def png(self, offsets=None):
        raw = b"".join(b"\0" + b"".join(bytes(p) for p in row) for row in self.pixels)
        chunks = [chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0))]
        if offsets is not None:
            chunks.append(chunk(b"grAb", struct.pack(">ii", *offsets)))
        chunks.append(chunk(b"IDAT", zlib.compress(raw, 9)))
        chunks.append(chunk(b"IEND", b""))
        return b"\x89PNG\r\n\x1a\n" + b"".join(chunks)


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def write(path, picture, offsets=None):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(picture.png(offsets))


def thing(path, picture):
    """A sprite standing on its bottom center."""
    write(path, picture, (picture.width // 2, picture.height))


def first_person(path, picture, left):
    """A first-person sprite with its left edge at `left` and its bottom at the bottom of a
    320x200 screen, for a layer at the usual weapon height (y 32)."""
    write(path, picture, (-left, picture.height - 168))


WHITE = (255, 255, 255, 255)
BLACK = (16, 16, 16, 255)


def box(width, height, fill, label, ink=WHITE, scale=2):
    picture = Picture(width, height)
    picture.rect(0, 0, width, height, fill)
    picture.frame(0, 0, width, height, BLACK, 2)
    picture.text(label, ink, scale)
    return picture


def main():
    # Map things
    thing("sprites/hh/door/hhdra0.png", box(64, 128, (120, 78, 40, 255), "DOOR", scale=3))
    thing("sprites/hh/door/hhdba0.png", box(64, 48, (100, 100, 100, 255), "DEBRIS", scale=1))
    thing("sprites/hh/wall_buy/hhwba0.png", box(48, 32, (40, 40, 40, 255), "BUY $", scale=1))
    thing("sprites/hh/box/hhbxa0.png", box(80, 40, (90, 60, 30, 255), "BOX", scale=3))
    opened = box(80, 40, (90, 60, 30, 255), "BOX", scale=3)
    opened.rect(4, 0, 72, 8, (255, 230, 120, 255))
    thing("sprites/hh/box/hhbxb0.png", opened)
    # The lock the box shows before it moves: a padlock, shackle on top
    lock = Picture(24, 32)
    steel, gold = (170, 170, 180, 255), (220, 180, 40, 255)
    lock.frame(5, 0, 14, 16, steel, 3)
    lock.rect(0, 13, 24, 19, gold)
    lock.frame(0, 13, 24, 19, BLACK, 2)
    lock.rect(10, 18, 4, 5, BLACK)
    lock.rect(11, 22, 2, 5, BLACK)
    thing("sprites/hh/box/hhlka0.png", lock)
    thing("sprites/hh/pickup/hhnla0.png", box(20, 20, (60, 60, 60, 255), "?", scale=2))
    for name, color, label in [("hhqr", (40, 90, 220, 255), "QR"), ("hhjg", (200, 30, 30, 255), "JG"),
                               ("hhsc", (30, 160, 60, 255), "SC"), ("hhdt", (230, 150, 20, 255), "DT")]:
        thing(f"sprites/hh/perks/{name}a0.png", box(40, 80, color, label, scale=3))
    bottle = Picture(8, 16)
    bottle.rect(3, 0, 2, 5, (180, 180, 180, 255))
    bottle.rect(1, 5, 6, 11, (120, 200, 255, 255))
    thing("sprites/hh/perks/hhbta0.png", bottle)
    for name, color, label in [("hhik", (180, 20, 20, 255), "IK"), ("hhdp", (230, 190, 30, 255), "X2"),
                               ("hhma", (40, 150, 40, 255), "MA"), ("hhnk", (60, 60, 60, 255), "NK"),
                               ("hhfs", (240, 100, 20, 255), "FS")]:
        thing(f"sprites/hh/drops/{name}a0.png", box(24, 24, color, label))
    # Editor-only markers (invisible in the game)
    for name, color, label in [("hhsp", (200, 40, 40, 255), "Z"), ("hhbl", (90, 60, 30, 255), "B"),
                               ("hhss", (40, 40, 200, 255), "S"), ("hhgc", (120, 0, 120, 255), "C")]:
        thing(f"sprites/hh/editor/{name}a0.png", box(16, 16, color, label))

    # First person: the drink (four frames, the bottle tipping up) and the kick (four frames,
    # the boot coming up)
    for index, frame in enumerate("abcd"):
        drink = Picture(64, 96)
        top = 40 - index * 10
        drink.rect(26, top, 12, 16, (180, 180, 180, 255))
        drink.rect(18, top + 16, 28, 96 - top - 16, (120, 200, 255, 255))
        drink.frame(18, top + 16, 28, 96 - top - 16, BLACK)
        first_person(f"sprites/hh/perks/hhdk{frame}0.png", drink, 128)
    for index, frame in enumerate("abcd"):
        kick = Picture(96, 80)
        top = 60 - index * 18
        kick.rect(30, top, 30, 80 - top, (70, 70, 60, 255))
        kick.rect(20, top, 60, 18, (40, 30, 20, 255))
        kick.frame(20, top, 60, 18, BLACK)
        first_person(f"sprites/hh/kick/hhkk{frame}0.png", kick, 180)

    # HUD pictures (no offsets)
    for name, color, label in [("hhiqr", (40, 90, 220, 255), "QR"), ("hhijg", (200, 30, 30, 255), "JG"),
                               ("hhisc", (30, 160, 60, 255), "SC"), ("hhidt", (230, 150, 20, 255), "DT"),
                               ("hhiik", (180, 20, 20, 255), "IK"), ("hhidp", (230, 190, 30, 255), "X2"),
                               ("hhifs", (240, 100, 20, 255), "FS")]:
        write(f"graphics/hh/{name}.png", box(32, 32, color, label, scale=3))
    back = Picture(82, 6)
    back.rect(0, 0, 82, 6, (30, 30, 30, 200))
    back.frame(0, 0, 82, 6, WHITE)
    write("graphics/hh/hhrvback.png", back)
    fore = Picture(82, 6)
    fore.rect(1, 1, 80, 4, (240, 240, 240, 255))
    write("graphics/hh/hhrvfore.png", fore)


if __name__ == "__main__":
    main()
