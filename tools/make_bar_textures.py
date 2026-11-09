"""Generates the stripes of the predictions on the health and power lines
along the screen's bottom (ImprovedForever_Immersion/PlayerHealth.lua: the
heals coming to you, a spell's cost), striped bands with square ends:

  ic_bar_stripes.tga  45 degree stripes, white, tiling both ways (16 px,
                      a stripe every 8 px); tinted in game

Run: uv run --with pillow python tools/make_bar_textures.py
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures")
SS = 4


def stripes():
    n, period, width = 16, 8, 3.5
    big = Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))
    for y in range(n * SS):
        for x in range(n * SS):
            d = ((x + y) / SS) % period
            if d < width:
                big.putpixel((x, y), (255, 255, 255, 255))
    big.resize((n, n), Image.LANCZOS).save(os.path.join(OUT, "ic_bar_stripes.tga"))


if __name__ == "__main__":
    stripes()
    print("wrote ic_bar_stripes to", os.path.normpath(OUT))
