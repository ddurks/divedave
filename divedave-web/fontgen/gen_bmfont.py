import os
from PIL import Image, ImageDraw, ImageFont

TTF = "/Users/onlinedavid/code/divedave/divedave-ios/divedave iOS/DrawvidHandwriting.ttf"
OUT = "/Users/onlinedavid/code/divedave/divedave-web/assets/fonts"
FACE = "DrawvidHand"
PX = 64
ATLAS_W = 512
GAP = 1

VARIANTS = {
    "drawvid-handwriting-white":  (255, 255, 255),
    "drawvid-handwriting-black":  (0, 0, 0),
    "drawvid-handwriting-green":  (0, 128, 0),
    "drawvid-handwriting-yellow": (255, 255, 0),
    "drawvid-handwriting-red":    (255, 0, 0),
}

from fontTools.ttLib import TTFont
cmap = TTFont(TTF).getBestCmap()
chars = [c for c in range(32, 127) if c in cmap]

font = ImageFont.truetype(TTF, PX)
asc, desc = font.getmetrics()
cell_h = asc + desc
line_height = round(cell_h * 21 / 20)

def advance(ch):
    return max(1, round(font.getlength(ch)))

def layout():
    rects, x, y = {}, 0, 0
    for c in chars:
        w = advance(chr(c))
        if x + w > ATLAS_W:
            x, y = 0, y + cell_h + GAP
        rects[c] = (x, y, w)
        x += w + GAP
    height = y + cell_h
    return rects, height

def render(color, rects, height):
    atlas = Image.new("RGBA", (ATLAS_W, height), (0, 0, 0, 0))
    for c, (x, y, w) in rects.items():
        if c == 32:
            continue
        mask = Image.new("L", (w, cell_h), 0)
        ImageDraw.Draw(mask).text((0, asc), chr(c), font=font, fill=255, anchor="ls")
        glyph = Image.new("RGBA", (w, cell_h), color + (0,))
        glyph.putalpha(mask)
        atlas.alpha_composite(glyph, (x, y))
    return atlas

def write_xml(name, rects, height):
    lines = [
        '<?xml version="1.0"?>',
        '<font>',
        f'    <info face="{FACE}" size="{cell_h}"/>',
        f'    <common lineHeight="{line_height}" base="{asc}"/>',
        '    <pages>',
        f'        <page id="0" file="{name}.png"/>',
        '    </pages>',
        '    <chars>',
    ]
    for c, (x, y, w) in rects.items():
        lines.append(
            f'        <char id="{c}" x="{x}" y="{y}" width="{w}" height="{cell_h}" '
            f'xoffset="0" yoffset="0" xadvance="{w}" page="0"/>'
        )
    lines += ['    </chars>', '</font>', '']
    with open(os.path.join(OUT, f"{name}.xml"), "w") as f:
        f.write("\n".join(lines))

rects, height = layout()
print(f"PX={PX} cellH={cell_h} lineHeight={line_height} base={asc} chars={len(chars)} atlas={ATLAS_W}x{height}")
for name, color in VARIANTS.items():
    render(color, rects, height).save(os.path.join(OUT, f"{name}.png"))
    write_xml(name, rects, height)
    print("wrote", name)
