"""Procedural cel-shaded character renderer for Web-Slinger: Night Patrol.

Every character is an original design drawn from a jointed skeleton (forward kinematics),
rendered at 4x supersampling and downsampled for smooth anti-aliased edges. Frames are
96x96 px and displayed in-game at scale 0.5, so they map 1:1 onto a 1280x720 window.

Angle conventions (degrees, sprite faces +x / right):
  torso / head : 0 = upright, positive leans forward
  arms / legs  : world-relative, 0 = hanging straight down, positive swings forward
  elbow        : added to the shoulder angle (positive flexes the forearm forward/up)
  knee         : added to the hip angle (negative flexes the shin backward)
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from PIL import Image, ImageDraw

SS = 4                 # supersampling factor
FRAME = 96             # output frame size
GROUND_Y = 90.0        # feet line for grounded poses
AIR_PELVIS = (48.0, 54.0)


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3)) + ((c1[3] if len(c1) > 3 else 255),)


def shade(c, k):
    return tuple(max(0, min(255, int(c[i] * k))) for i in range(3)) + (255,)


def hexc(h: str):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def down(a):
    r = math.radians(a)
    return (math.sin(r), math.cos(r))


def up(a):
    r = math.radians(a)
    return (math.sin(r), -math.cos(r))


def add(p, d, s):
    return (p[0] + d[0] * s, p[1] + d[1] * s)


def rot_about(p, c, a):
    r = math.radians(a)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(r) - y * math.sin(r), c[1] + x * math.sin(r) + y * math.cos(r))


@dataclass
class Body:
    torso: float = 21.0
    neck: float = 3.0
    head_r: float = 8.5
    upper_arm: float = 12.0
    forearm: float = 11.5
    thigh: float = 14.5
    shin: float = 14.5
    chest_w: float = 7.0
    waist_w: float = 5.0
    arm_w: float = 2.9
    leg_w: float = 3.4
    hand_r: float = 3.0
    foot_len: float = 6.5
    outline: float = 1.15


@dataclass
class Pose:
    torso: float = 0.0
    head: float = 0.0
    arm_f: tuple = (10.0, 20.0)
    arm_b: tuple = (-10.0, 20.0)
    leg_f: tuple = (5.0, -5.0)
    leg_b: tuple = (-5.0, -5.0)
    rot: float = 0.0
    grounded: bool = True
    pelvis: tuple | None = None     # explicit pelvis position (overrides grounding)
    dx: float = 0.0
    dy: float = 0.0
    flip_v: bool = False
    extras: dict = field(default_factory=dict)


class Skeleton:
    """Forward kinematics for one pose."""

    def __init__(self, body: Body, pose: Pose, frame: int = FRAME):
        b, p = body, pose
        self.body, self.pose = b, p
        pel = (0.0, 0.0)
        self.pelvis = pel
        self.chest = add(pel, up(p.torso), b.torso)
        self.neck = add(self.chest, up(p.torso + p.head * 0.5), b.neck)
        self.head = add(self.neck, up(p.torso + p.head), b.head_r * 0.9)
        self.head_dir = p.torso + p.head
        sh_off = up(p.torso)
        self.shoulder = add(self.chest, (-sh_off[0], -sh_off[1]), 2.0)
        self.elbow_f = add(self.shoulder, down(p.arm_f[0]), b.upper_arm)
        self.hand_f = add(self.elbow_f, down(p.arm_f[0] + p.arm_f[1]), b.forearm)
        self.elbow_b = add(self.shoulder, down(p.arm_b[0]), b.upper_arm)
        self.hand_b = add(self.elbow_b, down(p.arm_b[0] + p.arm_b[1]), b.forearm)
        self.knee_f = add(pel, down(p.leg_f[0]), b.thigh)
        self.foot_f = add(self.knee_f, down(p.leg_f[0] + p.leg_f[1]), b.shin)
        self.knee_b = add(pel, down(p.leg_b[0]), b.thigh)
        self.foot_b = add(self.knee_b, down(p.leg_b[0] + p.leg_b[1]), b.shin)
        self.foot_dir_f = p.leg_f[0] + p.leg_f[1]
        self.foot_dir_b = p.leg_b[0] + p.leg_b[1]
        names = ["pelvis", "chest", "neck", "head", "shoulder", "elbow_f", "hand_f", "elbow_b", "hand_b",
                 "knee_f", "foot_f", "knee_b", "foot_b"]
        # global rotation about pelvis
        if abs(p.rot) > 0.01:
            for n in names:
                setattr(self, n, rot_about(getattr(self, n), pel, p.rot))
            self.head_dir += p.rot
            self.foot_dir_f += p.rot
            self.foot_dir_b += p.rot
        # placement
        if p.pelvis is not None:
            off = p.pelvis
        elif p.grounded:
            lowest = max(self.foot_f[1], self.foot_b[1], self.hand_f[1] - 1.0, self.hand_b[1] - 1.0,
                         self.knee_f[1] + 1.0, self.knee_b[1] + 1.0, self.head[1] + b.head_r - 1.0)
            off = (frame / 2.0, frame - 6.0 - 1.0 - lowest)
        else:
            off = (frame / 2.0, AIR_PELVIS[1] * frame / FRAME)
        off = (off[0] + p.dx, off[1] + p.dy)
        for n in names:
            q = getattr(self, n)
            setattr(self, n, (q[0] + off[0], q[1] + off[1]))


class Canvas:
    def __init__(self, size=FRAME, out_scale=1):
        self.size = size
        self.out_scale = out_scale
        self.k = SS * out_scale
        self.img = Image.new("RGBA", (size * self.k, size * self.k), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def s(self, p):
        return (p[0] * self.k, p[1] * self.k)

    def circle(self, c, r, fill):
        x, y = self.s(c)
        rr = r * self.k
        self.d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=fill)

    def capsule(self, a, b, r, fill):
        self.d.line([self.s(a), self.s(b)], fill=fill, width=max(1, int(round(r * 2 * self.k))))
        self.circle(a, r, fill)
        self.circle(b, r, fill)

    def poly(self, pts, fill):
        self.d.polygon([self.s(p) for p in pts], fill=fill)

    def line(self, a, b, w, fill):
        self.d.line([self.s(a), self.s(b)], fill=fill, width=max(1, int(round(w * self.k))))

    def finish(self):
        n = self.size * self.out_scale
        return self.img.resize((n, n), Image.LANCZOS)


def limb(cv: Canvas, a, b, r, base, shadow, light, outline, ow):
    cv.capsule(a, b, r + ow, outline)
    cv.capsule(a, b, r, shadow)
    # light side shifted toward the upper-left light source
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln, dx / ln
    if nx + ny > 0:
        nx, ny = -nx, -ny
    off = r * 0.28
    cv.capsule((a[0] + nx * off, a[1] + ny * off), (b[0] + nx * off, b[1] + ny * off), r * 0.72, base)
    off2 = r * 0.55
    cv.capsule((a[0] + nx * off2, a[1] + ny * off2), (b[0] + nx * off2, b[1] + ny * off2), r * 0.22, light)


def quad_torso(sk: Skeleton, body: Body, widen=1.0):
    a, b = sk.pelvis, sk.chest
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln, dx / ln
    cw, ww = body.chest_w * widen, body.waist_w * widen
    top = add(b, (dx / ln, dy / ln), 1.5)
    return [
        (top[0] + nx * cw, top[1] + ny * cw),
        (top[0] - nx * cw, top[1] - ny * cw),
        (a[0] - nx * ww, a[1] - ny * ww),
        (a[0] + nx * ww, a[1] + ny * ww),
    ], (nx, ny)


def expand_poly(pts, amount):
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    out = []
    for x, y in pts:
        dx, dy = x - cx, y - cy
        ln = math.hypot(dx, dy) or 1.0
        out.append((x + dx / ln * amount, y + dy / ln * amount))
    return out


def foot(cv, sk_knee, sk_foot, foot_dir, body, color, outline, ow):
    # foot points forward relative to the shin direction
    fwd = down(foot_dir - 90.0)
    tip = add(sk_foot, (fwd[0], fwd[1]), body.foot_len)
    cv.capsule(sk_foot, tip, body.leg_w * 0.8 + ow, outline)
    cv.capsule(sk_foot, tip, body.leg_w * 0.8, color)


class Style:
    """Palette + decoration hooks for one character."""

    def __init__(self, **kw):
        self.outline = hexc("#120f1a")
        self.skin = hexc("#e2a679")
        self.__dict__.update(kw)

    # default palette accessors (override via kw)
    def part(self, name):
        return getattr(self, name)


def draw_character(body: Body, pose: Pose, style: Style, decorate=None, frame: int = FRAME, out_scale: int = 1) -> Image.Image:
    sk = Skeleton(body, pose, frame)
    cv = Canvas(frame, out_scale)
    ol, ow = style.outline, body.outline
    back_k = 0.72

    def tri(c):
        return c, shade(c, 0.70), mix(c, (255, 255, 255, 255), 0.35)

    def back(c):
        return shade(c, back_k)

    if decorate:
        decorate(cv, sk, body, style, "behind")

    # ---- back limbs (darker for depth)
    b_leg = style.leg_upper
    limb(cv, sk.pelvis, sk.knee_b, body.leg_w, *tri(back(b_leg)), ol, ow)
    limb(cv, sk.knee_b, sk.foot_b, body.leg_w * 0.92, *tri(back(style.leg_lower)), ol, ow)
    foot(cv, sk.knee_b, sk.foot_b, sk.foot_dir_b, body, back(style.boot), ol, ow)
    limb(cv, sk.shoulder, sk.elbow_b, body.arm_w, *tri(back(style.arm_upper)), ol, ow)
    limb(cv, sk.elbow_b, sk.hand_b, body.arm_w * 0.92, *tri(back(style.arm_lower)), ol, ow)
    cv.circle(sk.hand_b, body.hand_r + ow, ol)
    cv.circle(sk.hand_b, body.hand_r, back(style.glove))
    if decorate:
        decorate(cv, sk, body, style, "back_hand")

    # ---- torso
    pts, n = quad_torso(sk, body)
    cv.poly(expand_poly(pts, ow), ol)
    cv.poly(pts, shade(style.torso, 0.72))
    inner, _ = quad_torso(sk, body, widen=0.74)
    inner = [(x + n[0] * 0.0 - 0.6, y - 0.6) for x, y in inner]
    cv.poly(inner, style.torso)
    if decorate:
        decorate(cv, sk, body, style, "torso")
    # hips / belt
    cv.capsule(add(sk.pelvis, n, -body.waist_w * 0.9), add(sk.pelvis, n, body.waist_w * 0.9), body.leg_w * 0.95 + ow, ol)
    cv.capsule(add(sk.pelvis, n, -body.waist_w * 0.9), add(sk.pelvis, n, body.waist_w * 0.9), body.leg_w * 0.95, style.hips)

    # ---- head
    cv.circle(sk.head, body.head_r + ow, ol)
    cv.circle(sk.head, body.head_r, shade(style.head, 0.75))
    hd = up(sk.head_dir)
    cv.circle((sk.head[0] - 0.9 + hd[0] * 0.6, sk.head[1] - 1.0), body.head_r * 0.82, style.head)
    if decorate:
        decorate(cv, sk, body, style, "head")

    # ---- front leg
    limb(cv, sk.pelvis, sk.knee_f, body.leg_w, *tri(style.leg_upper), ol, ow)
    limb(cv, sk.knee_f, sk.foot_f, body.leg_w * 0.92, *tri(style.leg_lower), ol, ow)
    foot(cv, sk.knee_f, sk.foot_f, sk.foot_dir_f, body, style.boot, ol, ow)
    if decorate:
        decorate(cv, sk, body, style, "front_leg")

    # ---- front arm
    limb(cv, sk.shoulder, sk.elbow_f, body.arm_w, *tri(style.arm_upper), ol, ow)
    limb(cv, sk.elbow_f, sk.hand_f, body.arm_w * 0.92, *tri(style.arm_lower), ol, ow)
    cv.circle(sk.hand_f, body.hand_r + ow, ol)
    cv.circle(sk.hand_f, body.hand_r, style.glove)
    if decorate:
        decorate(cv, sk, body, style, "front_hand")
        decorate(cv, sk, body, style, "overlay")

    img = cv.finish()
    if pose.flip_v:
        img = img.transpose(Image.FLIP_TOP_BOTTOM)
    return img


def sheet(frames: list[Image.Image]) -> Image.Image:
    fw, fh = frames[0].size
    out = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * fw, 0))
    return out
