"""The keyboard drawing's diamonds (Bindings tab): a white fill and a white
edge, tinted in game (ic_key_diamond, ic_key_diamond_line), 64 x 64.

Run: python3 tools/make_key_diamond.py   (standard library only)
"""
import os
import struct

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures")
N, SS, C, R, EDGE = 64, 4, 32.0, 31.0, 3.0


def coverage(px, py, inner, outer):
    hit = 0
    for sy in range(SS):
        for sx in range(SS):
            x = px + (sx + 0.5) / SS - C
            y = py + (sy + 0.5) / SS - C
            d = abs(x) + abs(y)
            if inner <= d <= outer:
                hit += 1
    return hit / (SS * SS)


def write(name, inner, outer):
    rows = bytearray()
    for py in range(N):
        for px in range(N):
            a = int(round(255 * coverage(px, py, inner, outer)))
            rows += bytes((255, 255, 255, a))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 0x28)
    with open(os.path.join(OUT, name + ".tga"), "wb") as f:
        f.write(header + bytes(rows))
    print("wrote", name)


write("ic_key_diamond", 0, R)
write("ic_key_diamond_line", R - EDGE * 1.414, R)
