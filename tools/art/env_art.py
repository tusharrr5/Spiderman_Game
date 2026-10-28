"""Original layered city backgrounds, tileable surface textures and props (all procedurally drawn).

Backgrounds are 1280x1024 (displayed at 0.5 scale -> 640x512 game units) and tile horizontally.
"""
import math
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from char_renderer import hexc, shade, mix

BG_W, BG_H = 1280, 1024

THEMES = {
    # sky top, sky bottom, sun/moon (pos, radius, color) , far color, mid colors, window colors, window density, fog, extras
    "street_dusk": dict(sky=("#3b5fa8", "#f2a65e"), orb=((980, 330), 70, "#ffd27a"), far="#5a5f8f", mid=("#3b3554", "#4a3f5e", "#2f2c45"),
                        win=("#ffd88a", "#ffe9b5"), win_density=0.22, fog="#f0b27a", clouds="#f6c9a0", stars=0, seed=11),
    "rooftop_sunset": dict(sky=("#3a1f5c", "#ff7a45"), orb=((360, 520), 110, "#ffb35c"), far="#6b2f5e", mid=("#3a2140", "#46264d", "#2d1a35"),
                           win=("#ffb870", "#ffd9a0"), win_density=0.18, fog="#ff8a5c", clouds="#ff9e7a", stars=0, seed=23, cranes=True),
    "night_industrial": dict(sky=("#05070f", "#1d2a4a"), orb=((300, 200), 48, "#e8f0ff"), far="#16203a", mid=("#121a2e", "#182238", "#0e1424"),
                             win=("#7fd3ff", "#c4ecff"), win_density=0.30, fog="#2a3a66", clouds="#25304d", stars=180, seed=37, smoke=True),
    "goblin_facility": dict(sky=("#061009", "#14301f"), orb=None, far="#0f2418", mid=("#10261a", "#16301f", "#0b1c12"),
                            win=("#7dff8a", "#c8ffcf"), win_density=0.26, fog="#1f4a2c", clouds="#183823", stars=40, seed=41, pipes=True),
    "storm_finale": dict(sky=("#05040a", "#2b2140"), orb=((1000, 160), 56, "#d9e4ff"), far="#1a1630", mid=("#141026", "#1b1532", "#0d0a1a"),
                         win=("#ffcf6a", "#ff9a4a"), win_density=0.24, fog="#3c2e5c", clouds="#2a2240", stars=0, seed=53, storm=True),
}


def gradient(w, h, top, bottom):
    t, b = hexc(top), hexc(bottom)
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        c = mix(t, b, y / (h - 1))
        for x in range(w):
            px[x, y] = c
    return img


def wrap_rect(d, x0, y0, x1, y1, fill, w=BG_W):
    for off in (-w, 0, w):
        d.rectangle((x0 + off, y0, x1 + off, y1), fill=fill)


def wrap_poly(d, pts, fill, w=BG_W):
    for off in (-w, 0, w):
        d.polygon([(x + off, y) for x, y in pts], fill=fill)


def sky_layer(th):
    rnd = random.Random(th["seed"])
    img = gradient(BG_W, BG_H, *th["sky"])
    d = ImageDraw.Draw(img)
    for _ in range(th["stars"]):
        x, y = rnd.randrange(BG_W), rnd.randrange(int(BG_H * 0.55))
        a = rnd.randint(90, 230)
        d.ellipse((x, y, x + 2, y + 2), fill=(255, 255, 255, a))
    if th["orb"]:
        (cx, cy), r, col = th["orb"]
        glow = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        c = hexc(col)
        for k in range(10, 0, -1):
            rr = r * (1 + k * 0.35)
            gd.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=c[:3] + (int(14 * (11 - k) / 2),))
        glow = glow.filter(ImageFilter.GaussianBlur(18))
        img.alpha_composite(glow)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c)
        if th["sky"][0] in ("#05070f", "#05040a"):    # moon craters
            for _ in range(6):
                ox, oy, rr = rnd.randint(-r // 2, r // 2), rnd.randint(-r // 2, r // 2), rnd.randint(5, 12)
                d.ellipse((cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr), fill=shade(c, 0.88))
    # soft cloud bands
    clouds = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(clouds)
    cc = hexc(th["clouds"])
    for _ in range(26):
        x, y = rnd.randrange(BG_W), rnd.randint(60, int(BG_H * 0.5))
        w, h = rnd.randint(140, 360), rnd.randint(18, 42)
        for off in (-BG_W, 0, BG_W):
            cd.ellipse((x + off, y, x + off + w, y + h), fill=cc[:3] + (rnd.randint(40, 90),))
    clouds = clouds.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(clouds)
    return img


def building_windows(d, rnd, x0, y0, x1, y1, th, cell=(14, 18), lit_k=1.0):
    wc = [hexc(c) for c in th["win"]]
    cw, ch = cell
    for y in range(int(y0) + 14, int(y1) - 8, ch):
        for x in range(int(x0) + 8, int(x1) - 10, cw):
            if rnd.random() < th["win_density"] * lit_k:
                c = rnd.choice(wc)
                wrap_rect(d, x, y, x + cw * 0.5, y + ch * 0.55, c[:3] + (rnd.randint(170, 255),))
            elif rnd.random() < 0.35:
                wrap_rect(d, x, y, x + cw * 0.5, y + ch * 0.55, (0, 0, 0, 60))


def far_layer(th):
    rnd = random.Random(th["seed"] + 1)
    img = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = hexc(th["far"])
    x = 0
    while x < BG_W:
        w = rnd.randint(50, 130)
        h = rnd.randint(220, 520)
        top = BG_H - h - 240
        wrap_rect(d, x, top, x + w, BG_H, col)
        if rnd.random() < 0.3:     # spire / antenna
            wrap_rect(d, x + w // 2 - 3, top - rnd.randint(30, 90), x + w // 2 + 3, top, col)
        if rnd.random() < 0.25:    # stepped top
            wrap_rect(d, x + 12, top - 26, x + w - 12, top, col)
        building_windows(d, rnd, x, top, x + w, BG_H, th, cell=(10, 13), lit_k=0.5)
        x += w + rnd.randint(-10, 8)
    if th.get("cranes"):
        for cx in (260, 900):
            wrap_rect(d, cx, 260, cx + 10, BG_H, col)
            wrap_rect(d, cx - 160, 250, cx + 120, 262, col)
            for k in range(-16, 12):
                d.line((cx + k * 10, 262, cx + k * 10 + 10, 250), fill=col, width=2)
    fog = gradient(BG_W, 400, "#00000000"[:7], th["fog"])
    fog.putalpha(Image.linear_gradient("L").resize((BG_W, 400)).point(lambda v: int(v * 0.55)))
    img.alpha_composite(fog, (0, BG_H - 640))
    return img


def water_tower(d, x, base_y, col, dark):
    wrap_rect(d, x - 26, base_y - 64, x + 26, base_y - 30, col)
    wrap_poly(d, [(x - 30, base_y - 64), (x, base_y - 86), (x + 30, base_y - 64)], dark)
    for lx in (-22, -6, 6, 22):
        wrap_rect(d, x + lx - 2, base_y - 30, x + lx + 2, base_y, dark)
    d.line((x - 22, base_y - 2, x + 22, base_y - 28), fill=dark, width=2)
    d.line((x + 22, base_y - 2, x - 22, base_y - 28), fill=dark, width=2)


def mid_layer(th):
    rnd = random.Random(th["seed"] + 2)
    img = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cols = [hexc(c) for c in th["mid"]]
    x = 0
    while x < BG_W:
        w = rnd.randint(110, 220)
        h = rnd.randint(260, 470)
        top = BG_H - h - 120
        c = rnd.choice(cols)
        wrap_rect(d, x, top, x + w, BG_H, c)
        wrap_rect(d, x - 4, top - 8, x + w + 4, top, shade(c, 1.25))       # cornice
        wrap_rect(d, x, top, x + 6, BG_H, shade(c, 1.12))                   # lit edge
        building_windows(d, rnd, x + 4, top, x + w, BG_H, th)
        r = rnd.random()
        if r < 0.3:
            water_tower(d, x + rnd.randint(40, w - 40), top - 8, shade(c, 1.15), shade(c, 0.7))
        elif r < 0.5:
            ax = x + rnd.randint(20, w - 20)
            wrap_rect(d, ax - 2, top - rnd.randint(50, 110), ax + 2, top, shade(c, 0.8))
            d.ellipse((ax - 4, top - 118, ax + 4, top - 110), fill=(255, 60, 60, 255))
        elif r < 0.62 and w > 150:
            # billboard on the roof with an original fictional ad
            bx, bw = x + 20, min(150, w - 40)
            wrap_rect(d, bx, top - 70, bx + bw, top - 22, shade(c, 1.6))
            wrap_rect(d, bx + 4, top - 66, bx + bw - 4, top - 26, rnd.choice([hexc("#e04a3c"), hexc("#2f8ad8"), hexc("#e8b02a")]))
            for lx in (bx + 16, bx + bw - 16):
                wrap_rect(d, lx - 2, top - 22, lx + 2, top, shade(c, 0.7))
            try:
                f = ImageFont.load_default(size=15)
                text = rnd.choice(["BYTE BURGER", "SKYLINE FM", "NOVA COLA", "QUICK CAB"])
                tw = d.textlength(text, font=f)
                if tw <= bw - 12:
                    for off in (-BG_W, 0, BG_W):
                        d.text((bx + (bw - tw) / 2 + off, top - 56), text, fill=(255, 255, 255, 230), font=f)
            except Exception:
                pass
        # fire escape zig-zag on some facades
        if rnd.random() < 0.35:
            fx = x + rnd.randint(10, max(11, w - 60))
            for fy in range(top + 40, BG_H - 60, 70):
                wrap_rect(d, fx, fy, fx + 48, fy + 4, shade(c, 0.6))
                d.line((fx + 4, fy + 4, fx + 44, fy + 66), fill=shade(c, 0.6), width=3)
        x += w + rnd.randint(4, 30)
    if th.get("pipes"):
        for py in (BG_H - 300, BG_H - 220):
            wrap_rect(d, 0, py, BG_W, py + 14, hexc("#2d4a36"))
            for k in range(0, BG_W, 90):
                wrap_rect(d, k, py - 4, k + 10, py + 18, hexc("#1d3324"))
    fog = Image.new("RGBA", (BG_W, 260), hexc(th["fog"])[:3] + (0,))
    fog.putalpha(Image.linear_gradient("L").resize((BG_W, 260)).point(lambda v: int(v * 0.35)))
    img.alpha_composite(fog, (0, BG_H - 260))
    return img


# ------------------------------------------------------------------ tileable surfaces (64x64 -> 32 game px)
SURFACES = {
    "concrete": ("#8a8796", "#6d6a7a"),
    "brick_red": ("#9c4a3a", "#7d3a2e"),
    "brick_dark": ("#4c4660", "#3a354c"),
    "metal": ("#4f6b5a", "#3b5144"),
    "girder": ("#c8862e", "#9a6420"),
    "glass": ("#3d5a8a", "#2c4470"),
    "rooftile": ("#5a5568", "#46425a"),
}


def surface_tile(kind):
    base, dark = (hexc(c) for c in SURFACES[kind])
    img = Image.new("RGBA", (64, 64), base)
    d = ImageDraw.Draw(img)
    rnd = random.Random(hash(kind) & 0xffff)
    if kind.startswith("brick"):
        for row in range(4):
            y = row * 16
            d.line((0, y, 64, y), fill=dark, width=2)
            off = 0 if row % 2 == 0 else 16
            for bx in range(off, 64 + 32, 32):
                d.line((bx % 64, y, bx % 64, y + 16), fill=dark, width=2)
        for _ in range(40):
            x, y = rnd.randrange(64), rnd.randrange(64)
            d.point((x, y), fill=shade(base, rnd.uniform(0.85, 1.15)))
    elif kind == "concrete" or kind == "rooftile":
        for _ in range(160):
            x, y = rnd.randrange(64), rnd.randrange(64)
            d.point((x, y), fill=shade(base, rnd.uniform(0.82, 1.12)))
        d.line((0, 31, 64, 31), fill=dark, width=1)
        d.line((31, 0, 31, 64), fill=dark, width=1)
    elif kind == "metal":
        d.rectangle((1, 1, 62, 62), outline=dark, width=2)
        for cx, cy in ((6, 6), (57, 6), (6, 57), (57, 57)):
            d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=shade(base, 1.3))
        d.line((0, 32, 64, 32), fill=shade(base, 0.85), width=2)
    elif kind == "girder":
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle((0, 0, 63, 8), fill=base)
        d.rectangle((0, 55, 63, 63), fill=base)
        d.line((0, 8, 63, 55), fill=base, width=6)
        d.line((0, 55, 63, 8), fill=dark, width=4)
        d.rectangle((0, 0, 63, 2), fill=shade(base, 1.25))
    elif kind == "glass":
        d.rectangle((0, 0, 63, 63), outline=hexc("#1c2a44"), width=3)
        d.line((32, 0, 32, 64), fill=hexc("#1c2a44"), width=3)
        d.polygon([(6, 58), (24, 6), (30, 6), (12, 58)], fill=mix(base, (255, 255, 255, 255), 0.18))
    return img


def surface_cap(kind):
    """Top edge strip (64x18) drawn above a platform surface."""
    base, dark = (hexc(c) for c in SURFACES[kind])
    img = Image.new("RGBA", (64, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = mix(base, (255, 255, 255, 255), 0.28)
    d.rectangle((0, 2, 63, 13), fill=shade(base, 1.08))
    d.rectangle((0, 0, 63, 3), fill=top)
    d.rectangle((0, 13, 63, 17), fill=(0, 0, 0, 90))
    for x in range(0, 64, 16):
        d.line((x, 3, x, 13), fill=dark, width=1)
    return img


# ------------------------------------------------------------------ props
def outline_draw(fn, size):
    """Draw a prop and add a dark outline around it."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    fn(ImageDraw.Draw(img), img)
    a = img.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(5))
    ol = Image.new("RGBA", size, (18, 15, 26, 255))
    ol.putalpha(grown)
    ol.alpha_composite(img)
    return ol


def prop_images():
    P = {}

    def crate(d, img):
        d.rectangle((4, 4, 43, 43), fill=hexc("#a8743c"))
        d.rectangle((4, 4, 43, 43), outline=hexc("#6e4a24"), width=4)
        d.line((6, 6, 41, 41), fill=hexc("#6e4a24"), width=4)
        d.line((6, 12, 12, 6), fill=hexc("#d29a58"), width=2)
    P["crate"] = outline_draw(crate, (48, 48))

    def barrel(d, img):
        d.rounded_rectangle((6, 4, 37, 51), 6, fill=hexc("#3f6e9c"))
        for y in (12, 28, 44):
            d.rectangle((6, y, 37, y + 3), fill=hexc("#2b4c6e"))
        d.rectangle((10, 6, 14, 49), fill=hexc("#6a9ac8"))
    P["barrel"] = outline_draw(barrel, (44, 56))

    def ac(d, img):
        d.rectangle((4, 10, 59, 45), fill=hexc("#b7b8c2"))
        d.ellipse((30, 14, 56, 40), fill=hexc("#7d7f8c"))
        for k in range(4):
            d.line((43, 27, 43 + 11 * math.cos(k * 1.6), 27 + 11 * math.sin(k * 1.6)), fill=hexc("#4c4e58"), width=3)
        for y in range(16, 42, 6):
            d.line((8, y, 26, y), fill=hexc("#8e909c"), width=2)
    P["ac_unit"] = outline_draw(ac, (64, 50))

    def tower(d, img):
        d.rectangle((14, 20, 82, 76), fill=hexc("#8a5a3a"))
        for x in range(18, 82, 10):
            d.line((x, 22, x, 74), fill=hexc("#6e4630"), width=2)
        d.polygon([(8, 22), (48, 0), (88, 22)], fill=hexc("#5a3a28"))
        for lx in (20, 40, 56, 76):
            d.rectangle((lx - 3, 76, lx + 3, 124), fill=hexc("#4a4a52"))
        d.line((20, 120, 76, 80), fill=hexc("#4a4a52"), width=3)
        d.line((76, 120, 20, 80), fill=hexc("#4a4a52"), width=3)
    P["water_tower"] = outline_draw(tower, (96, 128))

    def lamp(d, img):
        d.rectangle((14, 20, 19, 127), fill=hexc("#3c3f4c"))
        d.rectangle((14, 16, 46, 22), fill=hexc("#3c3f4c"))
        d.polygon([(34, 22), (50, 22), (46, 30), (38, 30)], fill=hexc("#ffe7a8"))
    P["streetlight"] = outline_draw(lamp, (56, 128))

    def antenna(d, img):
        d.rectangle((10, 8, 14, 95), fill=hexc("#5a5d6a"))
        for y in (20, 40, 60):
            d.line((2, y, 22, y), fill=hexc("#5a5d6a"), width=3)
        d.ellipse((7, 2, 17, 12), fill=hexc("#ff4a4a"))
    P["antenna"] = outline_draw(antenna, (24, 96))

    def chimney(d, img):
        d.rectangle((4, 10, 35, 63), fill=hexc("#8e4a38"))
        d.rectangle((0, 4, 39, 12), fill=hexc("#6e3a2c"))
        for y in range(18, 62, 10):
            d.line((4, y, 35, y), fill=hexc("#6e3a2c"), width=2)
    P["chimney"] = outline_draw(chimney, (40, 64))

    def anchor(d, img):
        # gargoyle-style rooftop web anchor (stone hook)
        d.ellipse((10, 6, 38, 30), fill=hexc("#8f93a6"))
        d.polygon([(14, 24), (34, 24), (30, 40), (18, 40)], fill=hexc("#6d7184"))
        d.ellipse((18, 12, 22, 16), fill=hexc("#ffd34a"))
        d.ellipse((26, 12, 30, 16), fill=hexc("#ffd34a"))
        d.line((24, 40, 24, 46), fill=hexc("#cfd4e4"), width=3)
    P["web_anchor"] = outline_draw(anchor, (48, 48))

    def web(d, img):
        for k in range(8):
            a = k * math.pi / 4
            d.line((16, 12, 16 + 14 * math.cos(a), 12 + 10 * math.sin(a)), fill=(236, 246, 255, 255), width=2)
        d.ellipse((10, 7, 22, 17), outline=(236, 246, 255, 255), width=2)
    img = Image.new("RGBA", (32, 24), (0, 0, 0, 0))
    web(ImageDraw.Draw(img), img)
    P["web_projectile"] = img

    def bomb(d, img):
        d.ellipse((4, 6, 27, 29), fill=hexc("#f08a1c"))
        d.polygon([(10, 14), (14, 12), (13, 17)], fill=hexc("#3a1a0a"))
        d.polygon([(18, 12), (22, 14), (19, 17)], fill=hexc("#3a1a0a"))
        d.arc((9, 16, 23, 25), 10, 170, fill=hexc("#3a1a0a"), width=2)
        d.rectangle((14, 1, 17, 7), fill=hexc("#2a7a2a"))
    P["pumpkin_bomb"] = outline_draw(bomb, (32, 32))

    def bat(d, img):
        d.polygon([(2, 10), (10, 4), (14, 10), (18, 4), (22, 10), (30, 4), (24, 16), (16, 13), (8, 16)], fill=hexc("#c8ccd8"))
        d.ellipse((13, 7, 19, 13), fill=hexc("#5a2f86"))
    P["razor_bat"] = outline_draw(bat, (32, 20))

    img = Image.new("RGBA", (20, 10), (0, 0, 0, 0))
    dd = ImageDraw.Draw(img)
    dd.rounded_rectangle((0, 2, 19, 7), 3, fill=(255, 210, 110, 255))
    dd.rectangle((12, 3, 18, 6), fill=(255, 250, 220, 255))
    P["bullet"] = img

    img = Image.new("RGBA", (28, 16), (0, 0, 0, 0))
    dd = ImageDraw.Draw(img)
    dd.ellipse((0, 2, 27, 13), fill=(90, 255, 140, 120))
    dd.ellipse((8, 4, 27, 11), fill=(200, 255, 215, 255))
    P["energy_bolt"] = img

    def beacon(d, img, on=False):
        d.rectangle((14, 20, 19, 63), fill=hexc("#5a5d6a"))
        d.rectangle((6, 58, 27, 63), fill=hexc("#3c3f4c"))
        col = hexc("#5aff8a") if on else hexc("#ff5a5a")
        d.ellipse((7, 2, 26, 21), fill=col)
        d.ellipse((12, 6, 18, 12), fill=(255, 255, 255, 200))
    P["checkpoint_off"] = outline_draw(lambda d, i: beacon(d, i, False), (34, 64))
    P["checkpoint_on"] = outline_draw(lambda d, i: beacon(d, i, True), (34, 64))

    def cage(d, img):
        d.rectangle((6, 6, 89, 13), fill=hexc("#5a2f86"))
        d.rectangle((6, 98, 89, 107), fill=hexc("#5a2f86"))
        for x in range(10, 90, 12):
            d.rectangle((x, 13, x + 4, 98), fill=hexc("#8e93a8"))
        d.rectangle((40, 48, 56, 66), fill=hexc("#e8c04a"))
        d.ellipse((44, 52, 52, 60), fill=hexc("#3a2a10"))
    P["cage"] = outline_draw(cage, (96, 112))

    def gen(d, img, on=True):
        d.rectangle((4, 10, 43, 63), fill=hexc("#3b5144"))
        d.rectangle((10, 18, 37, 38), fill=hexc("#1a2a20"))
        col = hexc("#7dff8a") if on else hexc("#ff4a3a")
        d.ellipse((16, 22, 31, 35), fill=col)
        for y in (44, 50, 56):
            d.line((10, y, 37, y), fill=hexc("#2a3a30"), width=3)
        d.rectangle((18, 2, 29, 10), fill=hexc("#5a6b60"))
    P["generator_on"] = outline_draw(lambda d, i: gen(d, i, True), (48, 64))
    P["generator_off"] = outline_draw(lambda d, i: gen(d, i, False), (48, 64))

    def gate(d, img):
        d.rectangle((2, 0, 29, 191), fill=hexc("#2c3a32"))
        for y in range(8, 190, 24):
            d.rectangle((6, y, 25, y + 12), fill=hexc("#3f5a48"))
        d.rectangle((12, 0, 19, 191), fill=hexc("#7dff8a"))
    P["gate"] = outline_draw(gate, (32, 192))

    def hazard(d, img, on=True):
        d.rectangle((0, 8, 63, 15), fill=hexc("#3a3f4c"))
        if on:
            for x in range(4, 64, 12):
                d.line((x, 8, x + 4, 0), fill=(150, 230, 255, 255), width=2)
                d.line((x + 4, 0, x + 8, 8), fill=(220, 250, 255, 255), width=2)
        d.rectangle((0, 8, 63, 10), fill=hexc("#ffd23a") if on else hexc("#6a6a6a"))
    P["shock_on"] = hazard_img = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    hazard(ImageDraw.Draw(hazard_img), hazard_img, True)
    off_img = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    hazard(ImageDraw.Draw(off_img), off_img, False)
    P["shock_off"] = off_img

    def heal(d, img):
        # original health pickup: a takeaway hot-dog box
        d.rounded_rectangle((4, 10, 35, 29), 4, fill=hexc("#f2ece0"))
        d.rounded_rectangle((8, 6, 31, 16), 6, fill=hexc("#d89a4a"))
        d.rounded_rectangle((10, 8, 29, 14), 4, fill=hexc("#b8402a"))
        d.line((12, 10, 27, 12), fill=hexc("#f2d23a"), width=2)
    P["health_pickup"] = outline_draw(heal, (40, 34))

    def case(d, img):
        d.rounded_rectangle((4, 6, 43, 31), 4, fill=hexc("#3c4250"))
        d.rectangle((18, 2, 29, 7), fill=hexc("#2a2e38"))
        d.ellipse((18, 12, 29, 23), fill=(90, 255, 140, 255))
    P["tech_case"] = outline_draw(case, (48, 36))

    def door(d, img):
        d.rectangle((4, 4, 59, 95), fill=hexc("#5a4a3a"))
        d.rectangle((10, 10, 53, 95), fill=hexc("#7a5a3c"))
        d.rectangle((14, 14, 49, 44), fill=hexc("#ffe7a8"))
        d.ellipse((42, 56, 48, 62), fill=hexc("#e8c04a"))
        d.rectangle((0, 0, 63, 6), fill=hexc("#3a3a44"))
    P["exit_door"] = outline_draw(door, (64, 100))

    def sign(d, img):
        d.rectangle((14, 30, 19, 63), fill=hexc("#5a5d6a"))
        d.polygon([(2, 6), (40, 6), (50, 18), (40, 30), (2, 30)], fill=hexc("#2f9a5a"))
        d.polygon([(10, 12), (30, 12), (30, 8), (40, 18), (30, 28), (30, 24), (10, 24)], fill=(255, 255, 255, 255))
    P["arrow_sign"] = outline_draw(sign, (54, 64))
    return P


def icon_images():
    """White glyph icons (96x96) for touch buttons."""
    icons = {}
    W = (255, 255, 255, 255)

    def mk(fn):
        img = Image.new("RGBA", (96 * 4, 96 * 4), (0, 0, 0, 0))
        fn(ImageDraw.Draw(img))
        return img.resize((96, 96), Image.LANCZOS)

    s = 4
    icons["left"] = mk(lambda d: d.polygon([(26 * s, 48 * s), (62 * s, 22 * s), (62 * s, 74 * s)], fill=W))
    icons["right"] = mk(lambda d: d.polygon([(70 * s, 48 * s), (34 * s, 22 * s), (34 * s, 74 * s)], fill=W))
    icons["up"] = mk(lambda d: d.polygon([(48 * s, 22 * s), (22 * s, 60 * s), (74 * s, 60 * s)], fill=W))
    icons["down"] = mk(lambda d: d.polygon([(48 * s, 74 * s), (22 * s, 36 * s), (74 * s, 36 * s)], fill=W))

    def jump(d):
        d.polygon([(48 * s, 14 * s), (20 * s, 46 * s), (36 * s, 46 * s), (36 * s, 72 * s), (60 * s, 72 * s), (60 * s, 46 * s), (76 * s, 46 * s)], fill=W)
        d.rectangle((30 * s, 78 * s, 66 * s, 84 * s), fill=W)
    icons["jump"] = mk(jump)

    def fist(d):
        d.rounded_rectangle((26 * s, 30 * s, 70 * s, 70 * s), 10 * s, fill=W)
        for k in range(4):
            d.line((32 * s + k * 10 * s, 32 * s, 32 * s + k * 10 * s, 50 * s), fill=(0, 0, 0, 0), width=3 * s)
        d.rounded_rectangle((18 * s, 44 * s, 32 * s, 64 * s), 6 * s, fill=W)
    icons["punch"] = mk(fist)

    def boot(d):
        d.polygon([(30 * s, 18 * s), (50 * s, 18 * s), (50 * s, 56 * s), (78 * s, 62 * s), (78 * s, 78 * s), (30 * s, 78 * s)], fill=W)
    icons["kick"] = mk(boot)

    def webi(d):
        c = (48 * s, 48 * s)
        for k in range(8):
            a = k * math.pi / 4
            d.line((c[0], c[1], c[0] + 34 * s * math.cos(a), c[1] + 34 * s * math.sin(a)), fill=W, width=4 * s)
        for r in (12, 24):
            d.ellipse((c[0] - r * s, c[1] - r * s, c[0] + r * s, c[1] + r * s), outline=W, width=4 * s)
    icons["web"] = mk(webi)

    def star(d):
        pts = []
        for k in range(10):
            r = 36 if k % 2 == 0 else 15
            a = -math.pi / 2 + k * math.pi / 5
            pts.append((48 * s + r * s * math.cos(a), 50 * s + r * s * math.sin(a)))
        d.polygon(pts, fill=W)
    icons["special"] = mk(star)

    def dodge(d):
        d.arc((18 * s, 18 * s, 78 * s, 78 * s), 200, 520, fill=W, width=9 * s)
        d.polygon([(70 * s, 16 * s), (82 * s, 40 * s), (58 * s, 38 * s)], fill=W)
    icons["dodge"] = mk(dodge)

    def pause(d):
        d.rectangle((28 * s, 22 * s, 42 * s, 74 * s), fill=W)
        d.rectangle((54 * s, 22 * s, 68 * s, 74 * s), fill=W)
    icons["pause"] = mk(pause)

    def suit(d):
        d.polygon([(28 * s, 20 * s), (40 * s, 14 * s), (48 * s, 22 * s), (56 * s, 14 * s), (68 * s, 20 * s), (80 * s, 38 * s),
                   (68 * s, 44 * s), (66 * s, 82 * s), (30 * s, 82 * s), (28 * s, 44 * s), (16 * s, 38 * s)], fill=W)
    icons["suit"] = mk(suit)
    return icons
