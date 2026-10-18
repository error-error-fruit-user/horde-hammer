#!/usr/bin/env python3
"""Write test/maps/hhtest.wad, a one-room UDMF map with every Horde Hammer map thing.

usage: python3 tools/testmap.py

Dependency-free Python 3.8+. The room is 2048x1024 with four player starts, two spawners in zone 0
and one in zone 1 behind a door, two mystery box locations (the first always starts), the four perk
machines, debris, a spectator spot, a game over camera and two respawn spots (one for the first
player, one shared). The engine builds the nodes itself.
"""

import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "test", "maps", "hhtest.wad")

WIDTH, HEIGHT = 2048, 1024

THINGS = [
    # type, x, y, angle, args
    (1, 128, 384, 0, ()), (2, 128, 512, 0, ()), (3, 128, 640, 0, ()), (4, 256, 512, 0, ()),
    (27000, 1900, 128, 180, (0,)), (27000, 1900, 896, 180, (0,)), (27000, 1000, 960, 270, (1,)),
    (27001, 640, 64, 90, (1,)), (27001, 1400, 64, 90, (0,)),
    (27004, 400, 990, 270, ()), (27005, 560, 990, 270, ()), (27006, 720, 990, 270, ()), (27007, 880, 990, 270, ()),
    (27002, 1000, 800, 0, (1, 0, 0, 0, 0)),
    (27003, 1200, 512, 0, ()),
    (27008, 64, 64, 0, ()),
    (27009, 1024, 512, 90, (0,)),
    (27011, 512, 300, 0, (1,)), (27011, 512, 700, 0, (0,)),
]


def textmap():
    corners = [(0, 0), (WIDTH, 0), (WIDTH, HEIGHT), (0, HEIGHT)]
    out = ['namespace = "zdoom";']
    for x, y in corners:
        out.append(f"vertex {{ x = {x}.0; y = {y}.0; }}")
    # Lines go clockwise around the room so their front faces in
    for index in range(4):
        out.append(f"linedef {{ v1 = {(index + 1) % 4}; v2 = {index}; sidefront = {index}; blocking = true; }}")
        out.append('sidedef { sector = 0; texturemiddle = "STARTAN3"; }')
    out.append('sector { heightfloor = 0; heightceiling = 192; texturefloor = "FLOOR0_1"; '
               'textureceiling = "CEIL1_1"; lightlevel = 192; }')
    for number, (kind, x, y, angle, args) in enumerate(THINGS):
        fields = [f"x = {x}.0;", f"y = {y}.0;", f"type = {kind};", f"angle = {angle};", f"id = {number + 1};"]
        fields += [f"skill{level} = true;" for level in range(1, 6)]
        fields += ["single = true;", "coop = true;", "dm = true;", "class1 = true;", "class2 = true;", "class3 = true;"]
        fields += [f"arg{i} = {value};" for i, value in enumerate(args)]
        out.append("thing { " + " ".join(fields) + " }")
    return ("\n".join(out) + "\n").encode()


def wad(lumps):
    data = b""
    directory = b""
    offset = 12
    for name, content in lumps:
        directory += struct.pack("<ii8s", offset, len(content), name.encode())
        data += content
        offset += len(content)
    return struct.pack("<4sii", b"PWAD", len(lumps), offset) + data + directory


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(wad([("HHTEST", b""), ("TEXTMAP", textmap()), ("ENDMAP", b"")]))


if __name__ == "__main__":
    main()
