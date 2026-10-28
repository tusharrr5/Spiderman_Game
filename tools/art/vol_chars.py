"""Volumetric builds of every character: anatomy primitives, suit materials and procedural patterns.

Each character turns a posed Skeleton into a list of Prim (tapered capsules / ellipsoids) grouped into
paint layers. The poses and animation sets are shared with hero_art / cast_art so gameplay timing
stays identical; only the rendering is new. All designs are original.
"""
from __future__ import annotations

import math
import numpy as np

from char_renderer import Skeleton, up, down, add
from vol_renderer import Prim, Material, rgb

DIM = {"back_leg": 0.72, "back_arm": 0.72}
LAYERS = ["glider", "behind", "back_leg", "back_arm", "torso", "head", "front_leg", "front_arm", "prop", "fx"]


# ------------------------------------------------------------------ vector helpers
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def norm(v):
    ln = math.hypot(v[0], v[1]) or 1.0
    return (v[0] / ln, v[1] / ln)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def ang_of(v):
    return math.atan2(v[1], v[0])


def front_of(d):
    """Side of a bone that faces the character's front. d points along the bone (pelvis->chest or
    shoulder->hand); for a hanging limb the front is +x, for the upright spine the front is +x."""
    if d[1] >= 0:      # pointing downward-ish
        return (d[1], -d[0])
    return (-d[1], d[0])


def bulge(a, b, t, side, off, along, across, depth, z, group, mat, tdir=None):
    """Muscle ellipsoid placed at fraction t along a->b, pushed toward `side` by `off`."""
    d = norm(sub(b, a))
    c = add(lerp(a, b, t), side, off)
    return Prim("ell", c, ra=depth, rx=along, ry=across, angle=ang_of(d if tdir is None else tdir), za=z,
                group=group, mat=mat)


def cap(a, b, ra, rb, group, mat, za=0.0, zb=None, flat=1.0, **data):
    return Prim("cap", a, b, ra=ra, rb=rb, za=za, zb=za if zb is None else zb, group=group, mat=mat, flat=flat,
                data=data)


def ell(c, rx, ry, depth, angle, group, mat, z=0.0, **data):
    return Prim("ell", c, ra=depth, rx=rx, ry=ry, angle=angle, za=z, group=group, mat=mat, data=data)


# ------------------------------------------------------------------ procedural pattern helpers
def _hash_noise(x, y, scale):
    """Cheap smooth value noise in [0,1]."""
    xs, ys = x * scale, y * scale
    xi, yi = np.floor(xs), np.floor(ys)
    xf, yf = xs - xi, ys - yi

    def h(ix, iy):
        v = np.sin(ix * 127.1 + iy * 311.7) * 43758.5453
        return v - np.floor(v)

    u = xf * xf * (3 - 2 * xf)
    v = yf * yf * (3 - 2 * yf)
    a, b = h(xi, yi), h(xi + 1, yi)
    c, d = h(xi, yi + 1), h(xi + 1, yi + 1)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def _line_dist(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy or 1.0
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / l2, 0, 1)
    return np.hypot(px - (ax + dx * t), py - (ay + dy * t))


def web_grid(line_col, width=0.07, rings=4.4, longs=6, strength=0.8):
    """Suit web seams wrapping a capsule/ellipsoid: curved rings + longitudinal seams."""
    lc = rgb(line_col)

    def f(ctx):
        v = np.clip(ctx.v, -0.999, 0.999)
        th = np.arcsin(v)
        r = ctx.prim.ra if ctx.prim.kind == "cap" else ctx.prim.ry
        ue = ctx.u + 0.55 * r * (1.0 - np.cos(th)) + 20.0
        ring = np.abs(((ue / rings) % 1.0) - 0.5) > 0.5 - width * 0.9
        lon = np.abs(((th / (math.pi / longs)) % 1.0) - 0.5) > 0.5 - width
        line = ring | lon
        col = np.where(line[:, None], ctx.color + (lc[None, :] - ctx.color) * strength, ctx.color)
        return col, None
    return f


def fabric(amount=0.06, scale=1.6, tint=None):
    def f(ctx):
        nz = _hash_noise(ctx.x, ctx.y, scale) - 0.5
        col = ctx.color * (1.0 + nz[:, None] * amount * 2)
        bump = np.zeros_like(ctx.n)
        bump[:, 0] = nz * amount * 2.5
        return np.clip(col, 0, 1), bump
    return f


def denim():
    def f(ctx):
        n1 = _hash_noise(ctx.x, ctx.y, 2.6)
        weave = 0.5 + 0.5 * np.sin((ctx.x + ctx.y) * 6.0)
        col = ctx.color * (0.9 + 0.12 * n1[:, None] + 0.05 * weave[:, None])
        return np.clip(col, 0, 1), None
    return f


def skin(freckle=0.0):
    def f(ctx):
        n1 = _hash_noise(ctx.x, ctx.y, 0.9) - 0.5
        col = ctx.color * (1.0 + n1[:, None] * 0.07)
        return np.clip(col, 0, 1), None
    return f


def scales(dark):
    dc = rgb(dark)

    def f(ctx):
        sx = ctx.u * 1.1 + 40
        sy = np.arcsin(np.clip(ctx.v, -0.999, 0.999)) * 3.0
        row = np.floor(sy)
        cx = (sx + row * 0.5) % 1.0 - 0.5
        cy = sy % 1.0 - 0.5
        d = np.hypot(cx, cy * 1.3)
        edge = np.clip((d - 0.32) * 6.0, 0, 1)
        col = ctx.color * (1.0 - edge[:, None] * 0.25) + dc * edge[:, None] * 0.25
        bump = np.zeros_like(ctx.n)
        bump[:, 0] = cx * 0.35
        bump[:, 1] = cy * 0.35
        return np.clip(col, 0, 1), bump
    return f


# ------------------------------------------------------------------ generic humanoid
class Look:
    """Material keys for each body region plus anatomy tweaks."""

    def __init__(self, **kw):
        self.head = "skin"
        self.neck = "skin"
        self.torso = "shirt"
        self.hips = "pants"
        self.arm_upper = "shirt"
        self.arm_lower = "skin"
        self.hand = "skin"
        self.leg_upper = "pants"
        self.leg_lower = "pants"
        self.foot = "boot"
        self.muscle = 1.0          # muscle definition multiplier
        self.bulk = 1.0            # overall thickness
        self.head_shape = "human"  # human | mask
        self.__dict__.update(kw)


def _shift(sk, names, d):
    for n in names:
        setattr(sk, n, add(getattr(sk, n), d, 1.0))


def three_quarter(sk: Skeleton, body, spread=1.0):
    """Fake a 3/4 camera: push the near shoulder/hip toward the viewer's front side and the far ones back,
    so both arms read on either side of a broader chest (as in modern 2.5D fighters)."""
    t = norm(sub(sk.chest, sk.pelvis))
    fr = front_of(t)
    s = body.chest_w * 0.28 * spread
    h = body.waist_w * 0.22 * spread
    _shift(sk, ("shoulder",), (0, 0))
    sk.shoulder_f = add(sk.shoulder, fr, s)
    sk.shoulder_b = add(sk.shoulder, fr, -s)
    _shift(sk, ("elbow_f", "hand_f"), (fr[0] * s, fr[1] * s))
    _shift(sk, ("elbow_b", "hand_b"), (-fr[0] * s, -fr[1] * s))
    sk.hip_f = add(sk.pelvis, fr, h)
    sk.hip_b = add(sk.pelvis, fr, -h)
    _shift(sk, ("knee_f", "foot_f"), (fr[0] * h, fr[1] * h))
    _shift(sk, ("knee_b", "foot_b"), (-fr[0] * h, -fr[1] * h))


def humanoid(sk: Skeleton, body, look: Look, prims: list):
    p = sk.pose
    m = look.muscle
    bk = look.bulk
    if not hasattr(sk, "shoulder_f"):
        three_quarter(sk, body)
    # ---- torso
    t = norm(sub(sk.chest, sk.pelvis))
    fr = front_of(t)
    tl = body.torso
    cw, ww = body.chest_w * bk, body.waist_w * bk
    prims.append(cap(sk.pelvis, lerp(sk.pelvis, sk.chest, 0.55), ww * 1.02, (ww + cw) * 0.5, "torso", look.torso,
                     kind="abdomen"))
    prims.append(Prim("ell", lerp(sk.pelvis, sk.chest, 0.68), ra=cw * 0.92, rx=tl * 0.42, ry=cw, angle=ang_of(t),
                      group="torso", mat=look.torso, data={"kind": "ribcage"}))
    # pecs / upper back / lats / abs / glutes
    prims.append(bulge(sk.pelvis, sk.chest, 0.78, fr, cw * 0.48, tl * 0.18, cw * 0.48, cw * 0.62, 1.2 * m, "torso", look.torso))
    prims.append(bulge(sk.pelvis, sk.chest, 0.80, fr, -cw * 0.5, tl * 0.22, cw * 0.45, cw * 0.6, 0.6 * m, "torso", look.torso))
    prims.append(bulge(sk.pelvis, sk.chest, 0.55, fr, -cw * 0.55, tl * 0.25, cw * 0.32, cw * 0.55, 0.4 * m, "torso", look.torso))
    for i, tt in enumerate((0.22, 0.36, 0.5)):
        prims.append(bulge(sk.pelvis, sk.chest, tt, fr, ww * 0.62 + i * 0.4, tl * 0.06, ww * 0.34, ww * 0.42,
                           (ww * 0.45) * m * 0.9, "torso", look.torso))
    prims.append(Prim("ell", add(sk.pelvis, t, -1.0), ra=ww * 1.0, rx=ww * 0.85, ry=ww * 1.12, angle=ang_of(t),
                      group="torso", mat=look.hips))
    prims.append(bulge(sk.pelvis, sk.chest, 0.02, fr, -ww * 0.55, ww * 0.62, ww * 0.6, ww * 0.7, 0.8, "torso", look.hips))
    # ---- head + neck
    hd = sk.head_dir
    f, u = up(hd + 90), up(hd)
    hr = body.head_r
    prims.append(cap(sk.chest, add(sk.head, u, -hr * 0.55), hr * 0.42 * bk, hr * 0.36, "head", look.neck))
    head_data = {"c": sk.head, "f": f, "u": u, "r": hr}
    if look.head_shape == "mask":
        prims.append(Prim("ell", add(sk.head, u, 0.3), ra=hr * 0.98, rx=hr * 0.95, ry=hr * 1.08, angle=math.radians(hd) ,
                          group="head", mat=look.head, data=head_data))
        prims.append(Prim("ell", add(add(sk.head, f, hr * 0.32), u, -hr * 0.42), ra=hr * 0.7, rx=hr * 0.55, ry=hr * 0.5,
                          angle=math.radians(hd + 20), group="head", mat=look.head, data=head_data, za=0.5))
    else:
        prims.append(Prim("ell", add(sk.head, u, 0.2), ra=hr * 0.98, rx=hr * 0.98, ry=hr * 1.04, angle=math.radians(hd),
                          group="head", mat=look.head, data=head_data))
        # jaw, nose, brow, ear
        prims.append(Prim("ell", add(add(sk.head, f, hr * 0.35), u, -hr * 0.45), ra=hr * 0.72, rx=hr * 0.6, ry=hr * 0.48,
                          angle=math.radians(hd + 15), group="head", mat=look.head, data=head_data, za=0.4))
        prims.append(Prim("ell", add(add(sk.head, f, hr * 0.93), u, -hr * 0.05), ra=hr * 0.3, rx=hr * 0.17, ry=hr * 0.24,
                          angle=math.radians(hd), group="head", mat=look.head, data=head_data, za=hr * 0.55))
        prims.append(Prim("ell", add(add(sk.head, f, hr * 0.62), u, hr * 0.3), ra=hr * 0.3, rx=hr * 0.34, ry=hr * 0.12,
                          angle=math.radians(hd + 90), group="head", mat=look.head, data=head_data, za=hr * 0.68))
        prims.append(Prim("ell", add(sk.head, f, -hr * 0.12), ra=hr * 0.25, rx=hr * 0.2, ry=hr * 0.28,
                          angle=math.radians(hd), group="head", mat=look.head, data=head_data, za=hr * 0.75))

    # ---- limbs
    def leg(hip, knee, foot_pt, foot_dir, group):
        d1 = norm(sub(knee, hip))
        fr1 = front_of(d1)
        lw = body.leg_w * bk
        prims.append(cap(hip, knee, lw * 1.18, lw * 0.82, group, look.leg_upper))
        prims.append(bulge(hip, knee, 0.42, fr1, lw * 0.35, body.thigh * 0.36, lw * 0.62, lw * 0.85, 0.6 * m, group, look.leg_upper))
        d2 = norm(sub(foot_pt, knee))
        fr2 = front_of(d2)
        prims.append(cap(knee, foot_pt, lw * 0.82, lw * 0.6, group, look.leg_lower))
        prims.append(bulge(knee, foot_pt, 0.3, fr2, -lw * 0.38, body.shin * 0.3, lw * 0.55, lw * 0.75, 0.5 * m, group, look.leg_lower))
        fwd = down(foot_dir - 90.0)
        tip = add(foot_pt, fwd, body.foot_len)
        prims.append(cap(add(foot_pt, fwd, -1.0), tip, lw * 0.78, lw * 0.6, group, look.foot, flat=0.9))

    def arm(sh, elb, hand, group, front):
        d1 = norm(sub(elb, sh))
        fr1 = front_of(d1)
        aw = body.arm_w * bk
        prims.append(Prim("ell", add(sh, d1, aw * 0.35), ra=aw * 1.3, rx=aw * 1.25, ry=aw * 1.15, angle=ang_of(d1),
                          group=group, mat=look.arm_upper, za=0.6))
        prims.append(cap(sh, elb, aw * 1.05, aw * 0.78, group, look.arm_upper))
        prims.append(bulge(sh, elb, 0.5, fr1, aw * 0.35, body.upper_arm * 0.3, aw * 0.55, aw * 0.8, 0.5 * m, group, look.arm_upper))
        prims.append(bulge(sh, elb, 0.45, fr1, -aw * 0.3, body.upper_arm * 0.32, aw * 0.5, aw * 0.75, 0.4 * m, group, look.arm_upper))
        d2 = norm(sub(hand, elb))
        prims.append(cap(elb, hand, aw * 0.85, aw * 0.62, group, look.arm_lower))
        prims.append(bulge(elb, hand, 0.25, front_of(d2), aw * 0.2, body.forearm * 0.28, aw * 0.5, aw * 0.75, 0.4 * m, group, look.arm_lower))
        prims.append(Prim("ell", add(hand, d2, body.hand_r * 0.25), ra=body.hand_r * 1.0, rx=body.hand_r * 1.12,
                          ry=body.hand_r * 0.95, angle=ang_of(d2), group=group, mat=look.hand, za=0.3))

    leg(sk.hip_b, sk.knee_b, sk.foot_b, sk.foot_dir_b, "back_leg")
    arm(sk.shoulder_b, sk.elbow_b, sk.hand_b, "back_arm", False)
    leg(sk.hip_f, sk.knee_f, sk.foot_f, sk.foot_dir_f, "front_leg")
    arm(sk.shoulder_f, sk.elbow_f, sk.hand_f, "front_arm", True)
    return {"t": t, "fr": fr, "f": f, "u": u}


def web_fx(sk, body, prims):
    """Web cocoon strands for the 'webbed' enemy pose."""
    c = add(sk.pelvis, up(sk.pose.torso), body.torso * 0.55)
    for k in range(9):
        a1 = k * 40
        prims.append(cap(add(c, up(a1), body.torso * 0.75), add(c, up(a1 + 150), body.torso * 0.8), 0.55, 0.55, "fx", "webfx",
                         za=10))
    prims.append(Prim("ell", c, ra=3, rx=3.0, ry=2.4, group="fx", mat="webfx", za=10))


def hand_prop(sk, length, r0, r1, mat, prims, offset_ang=0.0, group="prop"):
    p = sk.pose
    d = down(p.arm_f[0] + p.arm_f[1] + p.rot + offset_ang)
    end = add(sk.hand_f, d, length)
    prims.append(cap(add(sk.hand_f, d, -1.5), end, r0, r1, group, mat, za=3))
    return end, d


# ------------------------------------------------------------------ the hero
def _mask_pattern(web_col, lens_col, frame_col):
    wc, lc, fc = rgb(web_col), rgb(lens_col), rgb(frame_col)

    def f(ctx):
        d = ctx.prim.data
        if "c" not in d:
            return ctx.color, None
        c, fv, uv, r = d["c"], d["f"], d["u"], d["r"]
        px, py = ctx.x - c[0], ctx.y - c[1]
        a = px * fv[0] + py * fv[1]          # forward
        b = px * uv[0] + py * uv[1]          # up
        col = ctx.color.copy()
        # radial web from a point on the face + concentric rings
        fx, fy = a - r * 0.55, b + r * 0.05
        rho = np.hypot(fx, fy)
        phi = np.arctan2(fy, fx)
        rad = np.abs(((phi / (math.pi / 7)) % 1.0) - 0.5) > 0.42
        ring = np.abs((((rho + 0.25 * r * np.cos(phi * 7)) / (r * 0.34)) % 1.0) - 0.5) > 0.42
        web = (rad | ring) & (rho > r * 0.12)
        col[web] = wc
        # front lens (teardrop) with a dark frame
        ea, eb = r * 0.40, r * 0.16
        rot = math.radians(22)
        lx = (a - ea) * math.cos(rot) + (b - eb) * math.sin(rot)
        ly = -(a - ea) * math.sin(rot) + (b - eb) * math.cos(rot)
        lx = np.where((ly < 0) & (lx < 0), lx * 1.6, lx)
        q = (lx / (r * 0.34)) ** 2 + (ly / (r * 0.46)) ** 2
        frame = q < 1.0
        lens = q < 0.62
        col[frame] = fc
        col[lens] = lc
        # far lens peeking past the profile
        q2 = ((a - r * 0.86) / (r * 0.15)) ** 2 + ((b - r * 0.18) / (r * 0.3)) ** 2
        col[q2 < 1.0] = fc
        col[q2 < 0.45] = lc * 0.85
        return col, None
    return f


def _torso_suit(web_col, flank_col, emblem_col, big_emblem, seams=True):
    wc, flc, ec = rgb(web_col), rgb(flank_col), rgb(emblem_col)
    grid = web_grid(web_col, width=0.08, rings=4.0, longs=7)

    def f(ctx):
        col = ctx.color.copy()
        if seams:
            col = grid(ctx)[0]
        sk = ctx.prim.data.get("sk")
        # flank panel toward the back of the torso
        v = ctx.v
        col = np.where((v < -0.45)[:, None], flc[None, :] * 0.95, col)
        if sk is not None:
            chest, t, fr = sk["chest"], sk["t"], sk["fr"]
            ecx, ecy = add(add(chest, t, -4.6), fr, sk["cw"] * 0.42)
            px, py = ctx.x, ctx.y
            m = np.zeros(len(px), dtype=bool)
            base = math.degrees(math.atan2(t[0], -t[1]))
            legs = 7.0 if big_emblem else 4.4
            w = 0.75 if big_emblem else 0.5
            for side in (-1, 1):
                for k, a in enumerate((-58, -22, 22, 58)):
                    dvec = up(base + side * (90 + a * 0.6))
                    kink = add((ecx, ecy), dvec, legs * 0.55)
                    tip = add(kink, up(base + side * (90 + a * 0.9) + (25 if a > 0 else -25) * side), legs * 0.6)
                    m |= _line_dist(px, py, (ecx, ecy), kink) < w
                    m |= _line_dist(px, py, kink, tip) < w * 0.85
            bod = ((px - ecx) ** 2 + (py - ecy) ** 2) < (2.2 if big_emblem else 1.4) ** 2
            hx, hy = add((ecx, ecy), t, 2.4 if big_emblem else 1.6)
            hed = ((px - hx) ** 2 + (py - hy) ** 2) < (1.5 if big_emblem else 1.0) ** 2
            m |= bod | hed
            col[m] = ec
        return col, None
    return f


def hero_materials(dark: bool):
    if dark:
        base, blue, web, emb = "#202229", "#1a1b22", "#30333f", "#eef1f8"
        boot = "#272a35"
    else:
        base, blue, web, emb = "#c81e2a", "#2342b8", "#5a0a12", "#141018"
        boot = "#b01822"
    suit = dict(spec=0.32, shine=22, rim=0.7, wrap=0.15, sheen=0.25)
    return {
        "mask": Material(rgb(base), pattern=_mask_pattern(web, "#eef6ff", "#101018"), **suit),
        "suit_red": Material(rgb(base), pattern=web_grid(web, strength=0.35) if dark else web_grid(web), **suit),
        "suit_torso": Material(rgb(base), pattern=_torso_suit(web, blue, emb, dark, seams=not dark), **suit),
        "suit_blue": Material(rgb(blue), pattern=fabric(0.05, 1.2), **suit),
        "boot": Material(rgb(boot), pattern=web_grid(web, rings=3.0), spec=0.4, shine=26, rim=0.7, wrap=0.1, sheen=0.2),
        "webfx": Material(rgb("#eef4ff"), spec=0.6, shine=30, rim=0.4, emissive=False),
        "webglow": Material(rgb("#e8f2ff"), emissive=True),
    }


HERO_LOOK = Look(head="mask", neck="suit_red", torso="suit_torso", hips="suit_blue", arm_upper="suit_blue",
                 arm_lower="suit_red", hand="suit_red", leg_upper="suit_blue", leg_lower="suit_red", foot="boot",
                 head_shape="mask", muscle=1.15)
HERO_LOOK_DARK = Look(**{**HERO_LOOK.__dict__})
HERO_LOOK_DARK.arm_upper = "suit_red"
HERO_LOOK_DARK.leg_upper = "suit_red"
HERO_LOOK_DARK.hips = "suit_red"


def build_hero(sk, body, dark=False):
    prims = []
    look = HERO_LOOK_DARK if dark else HERO_LOOK
    info = humanoid(sk, body, look, prims)
    tdata = {"sk": {"chest": sk.chest, "t": info["t"], "fr": info["fr"], "cw": body.chest_w}}
    for pr in prims:
        if pr.mat == "suit_torso":
            pr.data.update(tdata)
    ex = sk.pose.extras
    if ex.get("web_line"):
        a, ln = ex["web_line"]
        prims.append(cap(sk.hand_f, add(sk.hand_f, up(a), ln), 0.55, 0.45, "fx", "webglow", za=8))
    if ex.get("web_ball"):
        c = add(sk.hand_f, down(sk.pose.arm_f[0] + sk.pose.arm_f[1]), 5.0)
        prims.append(Prim("ell", c, ra=2.6, rx=3.0, ry=2.6, group="fx", mat="webglow", za=8))
        for k in range(6):
            prims.append(cap(c, add(c, up(k * 60 + 15), 5.2), 0.45, 0.3, "fx", "webglow", za=8))
    return prims


# ------------------------------------------------------------------ supporting cast
def _face_pattern(eye_col="#1a1a24", brow_col=None, mouth=True, grin=0.0, glow_eye=None, slit=None):
    ec = rgb(eye_col)
    bc = rgb(brow_col) if brow_col else None
    ge = rgb(glow_eye) if glow_eye else None
    skn = skin()

    def f(ctx):
        col = skn(ctx)[0]
        d = ctx.prim.data
        if "c" not in d:
            return col, None
        c, fv, uv, r = d["c"], d["f"], d["u"], d["r"]
        px, py = ctx.x - c[0], ctx.y - c[1]
        a = px * fv[0] + py * fv[1]
        b = px * uv[0] + py * uv[1]
        emis = np.zeros(len(a), dtype=bool)
        if slit is not None:
            sc = rgb(slit)
            band = (np.abs(b - r * 0.12) < r * 0.2) & (a > r * 0.05)
            col = np.where(band[:, None], col, sc[None, :] * (0.9 + 0.1 * _hash_noise(ctx.x, ctx.y, 2.0)[:, None]))
        e = ((a - r * 0.56) / (r * 0.13)) ** 2 + ((b - r * 0.14) / (r * 0.17)) ** 2
        if ge is not None:
            ee = ((a - r * 0.55) / (r * 0.22)) ** 2 + ((b - r * 0.16) / (r * 0.12)) ** 2
            col[ee < 1.0] = ge
            emis |= ee < 1.0
        else:
            col[e < 1.0] = np.array([0.92, 0.9, 0.86])
            col[(e < 1.0) & (a > r * 0.56)] = ec
        if bc is not None:
            br = (np.abs(b - r * 0.36) < r * 0.07) & (a > r * 0.3) & (a < r * 0.82)
            col[br] = bc
        if mouth:
            mw = r * (0.05 + 0.06 * grin)
            mo = (np.abs(b + r * 0.42 + (a - r * 0.6) * 0.2 * grin) < mw) & (a > r * 0.38) & (a < r * 0.8)
            col[mo] = np.array([0.25, 0.08, 0.1]) if grin <= 0 else np.array([0.95, 0.94, 0.85])
        return col, None, emis
    return f


def mats_common():
    return {
        "webfx": Material(rgb("#eef4ff"), spec=0.6, shine=30, rim=0.4),
        "metal": Material(rgb("#5a6170"), spec=0.9, shine=40, rim=0.8),
        "gunmetal": Material(rgb("#2a2d35"), spec=0.8, shine=50, rim=0.7),
        "wood": Material(rgb("#8a5a32"), spec=0.2, shine=10, pattern=fabric(0.1, 3.0)),
        "boot": Material(rgb("#2a231d"), spec=0.5, shine=28, rim=0.5),
        "sneaker": Material(rgb("#e6e2da"), spec=0.3, shine=14, wrap=0.2),
        "glass": Material(rgb("#111218"), spec=1.4, shine=70, rim=0.9),
    }


def skin_mat(col):
    return Material(rgb(col), spec=0.18, shine=14, rim=0.5, wrap=0.35, sss=rgb("#b2402a"), pattern=skin())


def build_thug(sk, body, kind="thug"):
    prims = []
    if kind == "captain":
        look = Look(head="face", neck="skin", torso="uniform", hips="slacks", arm_upper="uniform", arm_lower="uniform",
                    hand="skin", leg_upper="slacks", leg_lower="slacks", foot="boot", muscle=0.6)
        humanoid(sk, body, look, prims)
        h, f, u, r = sk.head, up(sk.head_dir + 90), up(sk.head_dir), body.head_r
        prims.append(Prim("ell", add(add(h, u, r * 0.62), f, -r * 0.05), ra=r * 0.9, rx=r * 0.5, ry=r * 1.1,
                          angle=math.radians(sk.head_dir + 90), group="head", mat="cap", za=0.6))
        prims.append(Prim("ell", add(add(h, u, r * 0.38), f, r * 0.75), ra=r * 0.3, rx=r * 0.14, ry=r * 0.5,
                          angle=math.radians(sk.head_dir + 90), group="head", mat="glass", za=r * 0.8))
        t = norm(sub(sk.chest, sk.pelvis))
        prims.append(Prim("ell", add(add(sk.chest, t, -4.0), front_of(t), body.chest_w * 0.55), ra=1.2, rx=1.3, ry=1.3,
                          group="torso", mat="gold", za=body.chest_w * 0.8))
        return prims
    if kind == "gunner":
        look = Look(head="face", neck="skin", torso="vest", hips="pants", arm_upper="hoodie", arm_lower="hoodie",
                    hand="glove", leg_upper="pants", leg_lower="pants", foot="boot", muscle=0.7, bulk=1.0)
    else:
        look = Look(head="face", neck="skin", torso="jacket", hips="jeans", arm_upper="jacket", arm_lower="jacket",
                    hand="skin", leg_upper="jeans", leg_lower="jeans", foot="sneaker", muscle=0.8, bulk=1.02)
    humanoid(sk, body, look, prims)
    h, f, u, r = sk.head, up(sk.head_dir + 90), up(sk.head_dir), body.head_r
    if kind == "gunner":
        # hood over the head + glossy visor
        prims.append(Prim("ell", add(add(h, u, r * 0.25), f, -r * 0.28), ra=r * 1.05, rx=r * 1.12, ry=r * 1.12,
                          angle=math.radians(sk.head_dir), group="head", mat="hoodie", za=0.3))
        prims.append(Prim("ell", add(add(h, f, r * 0.62), u, r * 0.12), ra=r * 0.55, rx=r * 0.18, ry=r * 0.5,
                          angle=math.radians(sk.head_dir + 90), group="head", mat="glass", za=r * 0.7))
        end, d = hand_prop(sk, 8.5, 1.9, 1.6, "gunmetal", prims)
        prims.append(cap(add(sk.hand_f, d, 1.0), add(add(sk.hand_f, d, 1.0), down(sk.pose.arm_f[0] + sk.pose.arm_f[1] + sk.pose.rot + 90), 3.5),
                         1.3, 1.2, "prop", "gunmetal", za=3))
        if sk.pose.arm_f[0] > 95:
            prims.append(Prim("ell", end, ra=2.2, rx=2.6, ry=2.0, angle=ang_of(d), group="fx", mat="flash", za=9))
    else:
        # beanie + white tee + baseball bat
        prims.append(Prim("ell", add(add(h, u, r * 0.42), f, -r * 0.08), ra=r * 0.95, rx=r * 0.72, ry=r * 1.04,
                          angle=math.radians(sk.head_dir + 90), group="head", mat="beanie", za=0.6))
        t = norm(sub(sk.chest, sk.pelvis))
        fr = front_of(t)
        prims.append(cap(add(sk.pelvis, fr, body.waist_w * 0.72), add(add(sk.chest, fr, body.chest_w * 0.62), t, -1.5),
                         body.waist_w * 0.42, body.chest_w * 0.5, "torso", "tee", za=1.5))
        hand_prop(sk, 19, 1.0, 1.9, "wood", prims)
    if sk.pose.extras.get("webbed"):
        web_fx(sk, body, prims)
    return prims


def thug_materials():
    m = mats_common()
    m.update({
        "face": Material(rgb("#c98c62"), spec=0.18, shine=14, rim=0.5, wrap=0.35, sss=rgb("#b2402a"),
                         pattern=_face_pattern(brow_col="#2a1a12")),
        "skin": skin_mat("#c98c62"),
        "jacket": Material(rgb("#2c2224"), spec=0.7, shine=30, rim=0.6, wrap=0.1, pattern=fabric(0.07, 1.8)),
        "tee": Material(rgb("#e4e0d8"), spec=0.1, wrap=0.3, pattern=fabric(0.05, 2.5)),
        "jeans": Material(rgb("#34466e"), spec=0.12, wrap=0.2, pattern=denim()),
        "beanie": Material(rgb("#a8302a"), spec=0.08, wrap=0.3, pattern=fabric(0.12, 3.5)),
    })
    return m


def captain_materials():
    m = mats_common()
    m.update({
        "face": Material(rgb("#8f5f45"), spec=0.2, shine=14, rim=0.5, wrap=0.35, sss=rgb("#a03a22"),
                         pattern=_face_pattern(brow_col="#1a1410")),
        "skin": skin_mat("#8f5f45"),
        "uniform": Material(rgb("#22325a"), spec=0.2, wrap=0.2, pattern=fabric(0.06, 2.0), sheen=0.3),
        "slacks": Material(rgb("#1b2747"), spec=0.15, wrap=0.2, pattern=fabric(0.05, 2.0)),
        "cap": Material(rgb("#1b2747"), spec=0.3, shine=20, wrap=0.2),
        "gold": Material(rgb("#e2b33e"), spec=1.2, shine=50, rim=0.6),
    })
    return m


def gunner_materials():
    m = mats_common()
    m.update({
        "face": Material(rgb("#b07a5c"), spec=0.18, shine=14, rim=0.5, wrap=0.35, sss=rgb("#b2402a"),
                         pattern=_face_pattern(brow_col="#1a1410")),
        "skin": skin_mat("#b07a5c"),
        "hoodie": Material(rgb("#3e3456"), spec=0.08, wrap=0.3, pattern=fabric(0.08, 2.2), sheen=0.3),
        "vest": Material(rgb("#2c3038"), spec=0.45, shine=20, rim=0.6, pattern=fabric(0.1, 1.2)),
        "pants": Material(rgb("#3a3c46"), spec=0.1, wrap=0.2, pattern=fabric(0.06, 2.0)),
        "glove": Material(rgb("#22232a"), spec=0.5, shine=24),
        "flash": Material(rgb("#ffd88a"), emissive=True),
    })
    return m


def build_thief(sk, body):
    prims = []
    look = Look(head="mask", neck="suit", torso="suit", hips="suit", arm_upper="suit", arm_lower="suit",
                hand="glove", leg_upper="suit", leg_lower="suit", foot="boot_brown", muscle=0.9)
    humanoid(sk, body, look, prims)
    p = sk.pose
    # tech case on the back with a glowing core
    t = norm(sub(sk.chest, sk.pelvis))
    fr = front_of(t)
    back = add(lerp(sk.pelvis, sk.chest, 0.6), fr, -body.chest_w * 0.95)
    prims.append(Prim("ell", back, ra=4.2, rx=9.5, ry=5.0, angle=ang_of(t), group="behind", mat="metal", flat=0.8))
    prims.append(Prim("ell", add(back, fr, -1.0), ra=2.0, rx=2.6, ry=2.3, group="behind", mat="core", za=3.6))
    # utility belt
    prims.append(cap(add(sk.pelvis, fr, -body.waist_w), add(sk.pelvis, fr, body.waist_w), 1.6, 1.6, "torso", "belt",
                     za=body.waist_w * 0.6))
    if p.arm_f[0] > 70:
        end, d = hand_prop(sk, 6, 2.6, 2.2, "metal", prims)
        prims.append(Prim("ell", end, ra=2.4, rx=2.6, ry=2.6, group="fx", mat="core", za=9))
    if p.extras.get("webbed"):
        web_fx(sk, body, prims)
    return prims


def thief_materials():
    m = mats_common()
    m.update({
        "mask": Material(rgb("#1d1e26"), spec=0.2, wrap=0.2, rim=0.7,
                         pattern=_face_pattern(slit="#1d1e26", mouth=False)),
        "suit": Material(rgb("#23252e"), spec=0.35, shine=26, rim=0.8, wrap=0.1, pattern=fabric(0.07, 1.5), sheen=0.25),
        "glove": Material(rgb("#18191f"), spec=0.6, shine=30, rim=0.7),
        "boot_brown": Material(rgb("#4a2c1c"), spec=0.5, shine=24),
        "belt": Material(rgb("#3a3328"), spec=0.5, shine=24),
        "core": Material(rgb("#6dffa0"), emissive=True),
    })
    # the balaclava's eye slit shows skin
    m["mask"].color = rgb("#c99070")
    return m


def build_brick(sk, body):
    prims = []
    look = Look(head="face", neck="skin", torso="tank", hips="cargo", arm_upper="skin", arm_lower="skin",
                hand="glove", leg_upper="cargo", leg_lower="cargo", foot="boot", muscle=1.6, bulk=1.0)
    humanoid(sk, body, look, prims)
    h, f, u, r = sk.head, up(sk.head_dir + 90), up(sk.head_dir), body.head_r
    # shades
    prims.append(Prim("ell", add(add(h, f, r * 0.6), u, r * 0.15), ra=r * 0.55, rx=r * 0.16, ry=r * 0.56,
                      angle=math.radians(sk.head_dir + 90), group="head", mat="glass", za=r * 0.7))
    # gold chain
    t = norm(sub(sk.chest, sk.pelvis))
    fr = front_of(t)
    c = add(add(sk.chest, t, -4.0), fr, body.chest_w * 0.55)
    for k in range(-3, 4):
        prims.append(Prim("ell", add(add(c, t, -abs(k) * 0.9), fr, k * 0.7), ra=0.9, rx=1.0, ry=1.0, group="torso",
                          mat="gold", za=body.chest_w * 0.8))
    if sk.pose.extras.get("webbed"):
        web_fx(sk, body, prims)
    return prims


def brick_materials():
    m = mats_common()
    m.update({
        "face": Material(rgb("#9c6a4a"), spec=0.3, shine=22, rim=0.5, wrap=0.3, sss=rgb("#a03a22"),
                         pattern=_face_pattern(brow_col="#1a1410")),
        "skin": Material(rgb("#9c6a4a"), spec=0.32, shine=22, rim=0.55, wrap=0.3, sss=rgb("#a03a22"), pattern=skin()),
        "tank": Material(rgb("#dcd8ce"), spec=0.08, wrap=0.3, pattern=fabric(0.06, 2.5)),
        "cargo": Material(rgb("#56573f"), spec=0.1, wrap=0.2, pattern=fabric(0.09, 1.6)),
        "glove": Material(rgb("#26262a"), spec=0.55, shine=26),
        "gold": Material(rgb("#e2b33e"), spec=1.2, shine=50, rim=0.6),
    })
    return m


def build_goblin(sk, body):
    prims = []
    p = sk.pose
    look = Look(head="gface", neck="gskin", torso="tunic", hips="tunic", arm_upper="gskin", arm_lower="gskin",
                hand="tunic", leg_upper="gskin", leg_lower="gskin", foot="tunic", muscle=1.1)
    humanoid(sk, body, look, prims)
    h, hd = sk.head, sk.head_dir
    f, u, r = up(hd + 90), up(hd), body.head_r
    # pointed hood sweeping back, pointed ear
    prims.append(Prim("ell", add(add(h, u, r * 0.55), f, -r * 0.55), ra=r * 0.85, rx=r * 1.55, ry=r * 0.62,
                      angle=math.radians(hd - 90 - 35), group="head", mat="hood", za=0.5))
    prims.append(Prim("ell", add(add(h, u, r * 0.35), f, -r * 0.05), ra=r * 0.9, rx=r * 1.0, ry=r * 0.72,
                      angle=math.radians(hd + 90), group="head", mat="hood", za=0.8))
    prims.append(Prim("ell", add(add(h, u, r * 0.2), f, -r * 0.35), ra=r * 0.3, rx=r * 0.75, ry=r * 0.22,
                      angle=math.radians(hd - 90 - 40), group="head", mat="gskin", za=r * 0.7))
    # satchel strap
    t = norm(sub(sk.chest, sk.pelvis))
    fr = front_of(t)
    prims.append(cap(add(sk.chest, fr, -body.chest_w * 0.7), add(sk.pelvis, fr, body.waist_w * 0.6), 0.9, 0.9, "torso",
                     "strap", za=body.chest_w * 0.75))
    if p.extras.get("glider", True):
        tilt = p.extras.get("tilt", 0.0)
        c = add(((sk.foot_f[0] + sk.foot_b[0]) / 2, max(sk.foot_f[1], sk.foot_b[1])), (0, 1), 2.5)
        gf, gd = up(90 + tilt), up(180 + tilt)
        a = math.radians(tilt)
        prims.append(Prim("ell", c, ra=4.0, rx=38, ry=4.2, angle=a, group="glider", mat="glider", flat=0.9))
        for s in (-1, 1):
            prims.append(Prim("ell", add(add(c, gf, s * 24), gd, -1.5), ra=3.0, rx=10, ry=3.2, angle=a - s * 0.18,
                              group="glider", mat="glider", za=1.5))
        prims.append(Prim("ell", add(c, gd, -1.5), ra=3.6, rx=7, ry=3.6, angle=a, group="glider", mat="glider_dark", za=2))
        prims.append(Prim("ell", add(add(c, gf, 2), gd, -2.6), ra=1.6, rx=1.8, ry=1.4, group="glider", mat="eyeglow", za=5))
        flame = p.extras.get("flame", 1.0)
        jet = add(add(c, gf, -30), gd, 1.5)
        prims.append(cap(add(jet, gf, 5), jet, 2.4, 2.0, "glider", "glider_dark", za=1))
        prims.append(Prim("ell", add(jet, gf, -(3 + 2.5 * flame)), ra=2.0, rx=4.5 * flame, ry=1.8,
                          angle=a, group="glider", mat="flame", za=2))
    bomb = p.extras.get("bomb")
    if bomb:
        c = add(sk.hand_f, down(p.arm_f[0] + p.arm_f[1] + p.rot), 3.0)
        prims.append(Prim("ell", c, ra=4.0, rx=4.0, ry=4.0, group="prop", mat="bomb", za=4))
        prims.append(cap(add(c, (0, -1), 3.5), add(c, (0.8, -1), 6.0), 0.5, 0.5, "prop", "strap", za=4))
        prims.append(Prim("ell", add(c, (0.8, -1), 6.3), ra=1.2, rx=1.2, ry=1.2, group="fx", mat="flame", za=8))
    return prims


def goblin_materials(grin=1.0):
    m = mats_common()
    m.update({
        "gface": Material(rgb("#4c9e38"), spec=0.45, shine=26, rim=0.6, wrap=0.2,
                          pattern=_face_pattern(glow_eye="#ffe14a", grin=grin, brow_col="#24501c")),
        "gskin": Material(rgb("#469a34"), spec=0.5, shine=30, rim=0.6, wrap=0.15, pattern=scales("#1e4a18")),
        "tunic": Material(rgb("#5a2f86"), spec=0.2, wrap=0.25, pattern=fabric(0.08, 2.0), sheen=0.4),
        "hood": Material(rgb("#4a2670"), spec=0.15, wrap=0.25, pattern=fabric(0.1, 2.4), sheen=0.4),
        "strap": Material(rgb("#7a5a2c"), spec=0.4, shine=20),
        "glider": Material(rgb("#3d5242"), spec=0.9, shine=44, rim=0.8),
        "glider_dark": Material(rgb("#262f2a"), spec=0.8, shine=40, rim=0.7),
        "eyeglow": Material(rgb("#8aff7a"), emissive=True),
        "flame": Material(rgb("#ffb24a"), emissive=True),
        "bomb": Material(rgb("#f07e1a"), spec=0.9, shine=40, rim=0.5),
    })
    return m


def build_mj(sk, body):
    prims = []
    look = Look(head="face", neck="skin", torso="top", hips="jeans", arm_upper="top", arm_lower="skin",
                hand="skin", leg_upper="jeans", leg_lower="jeans", foot="boot_brown", muscle=0.25, bulk=0.95)
    humanoid(sk, body, look, prims)
    h, hd = sk.head, sk.head_dir
    f, u, r = up(hd + 90), up(hd), body.head_r
    # voluminous hair: crown + long fall behind the shoulders
    prims.append(Prim("ell", add(add(h, u, r * 0.3), f, -r * 0.15), ra=r * 1.05, rx=r * 1.12, ry=r * 1.0,
                      angle=math.radians(hd), group="head", mat="hair", za=0.6))
    top = add(h, f, -r * 0.45)
    prims.append(cap(add(top, u, r * 0.2), add(add(top, u, -r * 2.3), f, -r * 0.35), r * 0.85, r * 0.55, "behind", "hair"))
    prims.append(Prim("ell", add(add(h, f, r * 0.55), u, r * 0.62), ra=r * 0.5, rx=r * 0.55, ry=r * 0.3,
                      angle=math.radians(hd + 100), group="head", mat="hair", za=r * 0.55))
    return prims


def mj_materials():
    m = mats_common()
    m.update({
        "face": Material(rgb("#efc2a0"), spec=0.2, shine=16, rim=0.5, wrap=0.4, sss=rgb("#c0503a"),
                         pattern=_face_pattern(eye_col="#2e6a3a", brow_col="#8a2a14")),
        "skin": skin_mat("#efc2a0"),
        "top": Material(rgb("#2f8a5c"), spec=0.15, wrap=0.3, pattern=fabric(0.06, 2.2), sheen=0.3),
        "jeans": Material(rgb("#3a5ea8"), spec=0.12, wrap=0.2, pattern=denim()),
        "hair": Material(rgb("#c23c1c"), spec=0.55, shine=20, rim=0.8, wrap=0.2, pattern=_hair()),
        "boot_brown": Material(rgb("#6b3b24"), spec=0.5, shine=24),
    })
    return m


def _hair():
    def f(ctx):
        strands = 0.5 + 0.5 * np.sin(ctx.x * 2.2 + ctx.y * 0.6 + _hash_noise(ctx.x, ctx.y, 0.8) * 6)
        col = ctx.color * (0.82 + 0.25 * strands[:, None])
        return np.clip(col, 0, 1), None
    return f


def build_drone(state):
    """Bomb drone (frame 64 units): metal pod, bat wings, glowing eye, bomb hatch."""
    flap, eye, tilt = state
    prims = []
    c = (32.0, 30.0)
    wy = -10 if flap else 6
    for s in (-1, 1):
        root = (c[0] + s * 7, c[1] - 2)
        tip = (c[0] + s * 29, c[1] + wy)
        prims.append(cap(root, tip, 3.2, 1.2, "glider", "wing", flat=0.4))
        prims.append(cap(lerp(root, tip, 0.5), (c[0] + s * 18, c[1] + 6), 2.0, 0.9, "glider", "wing", flat=0.4))
    prims.append(Prim("ell", c, ra=11, rx=11, ry=12, angle=math.pi / 2, group="torso", mat="pod"))
    prims.append(Prim("ell", (c[0] + 2.5, c[1] - 1), ra=4.5, rx=4.5, ry=4.5, group="head", mat="eye_" + eye, za=7))
    prims.append(cap((c[0], c[1] + 11), (c[0], c[1] + 17), 3.2, 2.8, "prop", "bomb"))
    return prims, tilt


def drone_materials():
    m = mats_common()
    m.update({
        "pod": Material(rgb("#4a2670"), spec=0.9, shine=40, rim=0.8),
        "wing": Material(rgb("#34433a"), spec=0.6, shine=30, rim=0.7),
        "bomb": Material(rgb("#f07e1a"), spec=0.9, shine=40),
        "eye_green": Material(rgb("#7dff8a"), emissive=True),
        "eye_red": Material(rgb("#ff4a3a"), emissive=True),
        "eye_white": Material(rgb("#ffffff"), emissive=True),
        "eye_dead": Material(rgb("#3a3a3a"), spec=0.5, shine=30),
    })
    return m


# ------------------------------------------------------------------ registry used by build_all
from char_renderer import Body  # noqa: E402

THUG_VOL = Body(torso=23.5, neck=3.5, head_r=7.4, upper_arm=13.0, forearm=12.5, thigh=17.0, shin=16.5,
                chest_w=10.4, waist_w=7.6, arm_w=3.8, leg_w=4.8, hand_r=3.1, foot_len=7.5)
THIEF_VOL = Body(torso=23.0, neck=3.5, head_r=7.0, upper_arm=13.0, forearm=12.5, thigh=17.5, shin=17.0,
                 chest_w=8.8, waist_w=6.0, arm_w=3.3, leg_w=4.3, hand_r=2.9, foot_len=7.5)
BRICK_VOL = Body(torso=29.0, neck=4.0, head_r=8.4, upper_arm=16.0, forearm=15.0, thigh=18.5, shin=18.0,
                 chest_w=16.0, waist_w=11.0, arm_w=6.0, leg_w=6.6, hand_r=4.8, foot_len=9.0)
GOBLIN_VOL = Body(torso=24.0, neck=3.5, head_r=7.6, upper_arm=13.5, forearm=13.0, thigh=16.5, shin=16.5,
                  chest_w=10.0, waist_w=6.8, arm_w=3.7, leg_w=4.5, hand_r=3.2, foot_len=7.5)
MJ_VOL = Body(torso=21.5, neck=3.5, head_r=7.0, upper_arm=12.0, forearm=11.5, thigh=16.5, shin=16.0,
              chest_w=7.8, waist_w=5.4, arm_w=2.7, leg_w=3.7, hand_r=2.6, foot_len=6.5)
