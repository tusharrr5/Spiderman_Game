"""Versus-mode roster: 20 Spider-Verse-inspired variants built on the volumetric renderer.

Every variant is an original procedural rendition (fan project): a body type, a material palette and a
few extra shapes (hoods, coats, hats, goggles, mohawks, mech parts, snouts, waldo legs...). They all
share the hero's animation set, so every fighter has the full moveset. Classic and Symbiote reuse the
story-mode hero sheets.
"""
from __future__ import annotations

import math
import numpy as np

from char_renderer import Body, up, down, add
from vol_renderer import Prim, Material, rgb
import vol_chars as vc
from vol_chars import (Look, humanoid, cap, sub, norm, lerp, front_of, web_grid, fabric, _mask_pattern, _torso_suit,
                       _face_pattern, _hash_noise, _line_dist, skin_mat)
import hero_art

SUIT = dict(spec=0.32, shine=22, rim=0.7, wrap=0.15, sheen=0.25)

MALE = hero_art.HERO_BODY_VOL
BULKY = Body(torso=24.0, neck=3.5, head_r=7.5, upper_arm=13.5, forearm=12.8, thigh=17.0, shin=16.8,
             chest_w=10.4, waist_w=8.6, arm_w=3.7, leg_w=4.8, hand_r=3.1, foot_len=7.2)
FEMALE = Body(torso=22.5, neck=3.5, head_r=7.0, upper_arm=12.8, forearm=12.0, thigh=17.5, shin=17.0,
              chest_w=8.4, waist_w=5.4, arm_w=3.0, leg_w=4.1, hand_r=2.7, foot_len=6.8)
TOON = Body(torso=18.0, neck=2.5, head_r=10.5, upper_arm=11.0, forearm=10.5, thigh=12.5, shin=12.0,
            chest_w=10.5, waist_w=9.5, arm_w=3.4, leg_w=4.4, hand_r=3.2, foot_len=6.5)
MECH = Body(torso=24.0, neck=3.0, head_r=9.5, upper_arm=13.5, forearm=13.0, thigh=15.5, shin=15.0,
            chest_w=14.0, waist_w=10.0, arm_w=5.0, leg_w=5.5, hand_r=4.4, foot_len=8.5)


def suit_mats(base, second, web, emblem, lens="#eef6ff", frame="#101018", big=False, seams=True, web_strength=0.8,
              boot=None, extra=None, **mat):
    kw = dict(SUIT)
    kw.update(mat)
    m = {
        "mask": Material(rgb(base), pattern=_mask_pattern(web, lens, frame), **kw),
        "suit_main": Material(rgb(base), pattern=web_grid(web, strength=web_strength) if seams else fabric(0.05, 1.2), **kw),
        "suit_torso": Material(rgb(base), pattern=_torso_suit(web, second, emblem, big, seams=seams), **kw),
        "suit_second": Material(rgb(second), pattern=fabric(0.05, 1.2), **kw),
        "boot": Material(rgb(boot or base), pattern=web_grid(web, rings=3.0, strength=web_strength) if seams else None,
                         spec=0.4, shine=26, rim=0.7, wrap=0.1, sheen=0.2),
        "webfx": Material(rgb("#eef4ff"), spec=0.6, shine=30, rim=0.4),
        "webglow": Material(rgb("#e8f2ff"), emissive=True),
        "metal": Material(rgb("#9aa3b2"), spec=1.0, shine=50, rim=0.9),
        "gold": Material(rgb("#e2b33e"), spec=1.2, shine=50, rim=0.6),
        "glass": Material(rgb("#111218"), spec=1.4, shine=70, rim=0.9),
    }
    if extra:
        m.update(extra)
    return m


def look(**kw):
    base = dict(head="mask", neck="suit_main", torso="suit_torso", hips="suit_second", arm_upper="suit_second",
                arm_lower="suit_main", hand="suit_main", leg_upper="suit_second", leg_lower="suit_main", foot="boot",
                head_shape="mask", muscle=1.15)
    base.update(kw)
    return Look(**base)


# ------------------------------------------------------------------ extra shapes
def hood(mat, inner=None):
    def f(sk, body, prims, info):
        h, f_, u, r = sk.head, info["f"], info["u"], body.head_r
        prims.append(Prim("ell", add(add(h, u, r * 0.22), f_, -r * 0.3), ra=r * 1.12, rx=r * 1.2, ry=r * 1.18,
                          angle=math.radians(sk.head_dir), group="behind", mat=mat))
        prims.append(Prim("ell", add(add(h, u, r * 0.5), f_, -r * 0.12), ra=r * 1.0, rx=r * 0.62, ry=r * 1.15,
                          angle=math.radians(sk.head_dir + 90), group="head", mat=mat, za=0.8))
        if inner:
            prims.append(Prim("ell", add(add(h, u, r * 0.55), f_, r * 0.45), ra=r * 0.3, rx=r * 0.2, ry=r * 0.75,
                              angle=math.radians(sk.head_dir + 70), group="head", mat=inner, za=r * 0.72))
    return f


def hood_down(mat):
    def f(sk, body, prims, info):
        c = add(sk.chest, info["fr"], -body.chest_w * 0.55)
        prims.append(Prim("ell", add(c, info["t"], 1.5), ra=4.0, rx=5.0, ry=4.2, angle=math.atan2(info["t"][1], info["t"][0]),
                          group="behind", mat=mat))
    return f


def vest(mat, collar=True):
    def f(sk, body, prims, info):
        t, fr = info["t"], info["fr"]
        prims.append(cap(add(sk.pelvis, t, 2.0), add(sk.chest, t, 0.5), body.waist_w * 1.12, body.chest_w * 1.08, "torso",
                         mat, za=0.8))
        prims.append(Prim("ell", lerp(sk.pelvis, sk.chest, 0.72), ra=body.chest_w * 1.0, rx=body.torso * 0.42,
                          ry=body.chest_w * 1.08, angle=math.atan2(t[1], t[0]), group="torso", mat=mat, za=0.9))
    return f


def coat(mat):
    def f(sk, body, prims, info):
        t, fr = info["t"], info["fr"]
        low = add(sk.pelvis, t, -16.0)
        prims.append(cap(sk.chest, low, body.chest_w * 1.08, body.waist_w * 1.55, "torso", mat, za=0.5))
        prims.append(cap(add(sk.pelvis, fr, -body.waist_w * 0.9), add(low, fr, -body.waist_w * 1.6), body.waist_w * 0.9,
                         body.waist_w * 0.8, "behind", mat))
        prims.append(Prim("ell", add(sk.chest, t, -1.0), ra=body.chest_w * 0.6, rx=3.0, ry=body.chest_w * 0.95,
                          angle=math.atan2(t[1], t[0]), group="torso", mat=mat, za=body.chest_w * 0.7))
    return f


def fedora(mat):
    def f(sk, body, prims, info):
        h, f_, u, r = sk.head, info["f"], info["u"], body.head_r
        a = math.atan2(f_[1], f_[0])
        prims.append(Prim("ell", add(h, u, r * 0.6), ra=r * 0.45, rx=r * 1.65, ry=r * 0.2, angle=a, group="head", mat=mat,
                          za=r * 0.35))
        prims.append(Prim("ell", add(add(h, u, r * 0.95), f_, -r * 0.05), ra=r * 0.95, rx=r * 0.92, ry=r * 0.48, angle=a,
                          group="head", mat=mat, za=0.6))
    return f


def goggles(rim_mat, lens_mat):
    def f(sk, body, prims, info):
        h, f_, u, r = sk.head, info["f"], info["u"], body.head_r
        for k, off in enumerate((0.62, 0.95)):
            c = add(add(h, f_, r * off), u, r * 0.16)
            prims.append(Prim("ell", c, ra=r * 0.3, rx=r * 0.3, ry=r * 0.3, group="head", mat=rim_mat, za=r * (0.75 - k * 0.2)))
            prims.append(Prim("ell", c, ra=r * 0.26, rx=r * 0.22, ry=r * 0.22, group="head", mat=lens_mat, za=r * (0.85 - k * 0.2)))
    return f


def mohawk(mat):
    def f(sk, body, prims, info):
        h, f_, u, r = sk.head, info["f"], info["u"], body.head_r
        for i in range(5):
            ang = sk.head_dir - 60 + i * 30
            base = add(h, up(ang), r * 0.92)
            tip = add(base, up(ang), r * 0.95)
            prims.append(cap(base, tip, r * 0.22, r * 0.04, "head", mat, za=0.2))
    return f


def snout(skin_mat_key, ear_mat):
    def f(sk, body, prims, info):
        h, f_, u, r = sk.head, info["f"], info["u"], body.head_r
        prims.append(Prim("ell", add(add(h, f_, r * 1.0), u, -r * 0.2), ra=r * 0.42, rx=r * 0.3, ry=r * 0.38,
                          angle=math.radians(sk.head_dir), group="head", mat=skin_mat_key, za=r * 0.55))
        prims.append(Prim("ell", add(add(h, f_, -r * 0.1), u, r * 0.95), ra=r * 0.3, rx=r * 0.22, ry=r * 0.42,
                          angle=math.radians(sk.head_dir - 20), group="head", mat=ear_mat, za=0.3))
    return f


def waldo_legs(mat):
    def f(sk, body, prims, info):
        t, fr = info["t"], info["fr"]
        root = add(lerp(sk.pelvis, sk.chest, 0.75), fr, -body.chest_w * 0.6)
        for k, ang in enumerate((-150, -120, -60, -30)):
            d = up(math.degrees(math.atan2(t[0], -t[1])) + ang)
            knee = add(root, d, 13.0)
            tip = add(knee, up(math.degrees(math.atan2(d[0], -d[1])) + (40 if ang < -90 else -40)), 11.0)
            prims.append(cap(root, knee, 1.3, 1.0, "behind", mat))
            prims.append(cap(knee, tip, 1.0, 0.5, "behind", mat))
    return f


def hair(mat, length=2.2):
    def f(sk, body, prims, info):
        h, f_, u, r = sk.head, info["f"], info["u"], body.head_r
        top = add(h, f_, -r * 0.45)
        prims.append(Prim("ell", add(add(h, u, r * 0.28), f_, -r * 0.18), ra=r * 1.05, rx=r * 1.1, ry=r * 1.0,
                          angle=math.radians(sk.head_dir), group="behind", mat=mat))
        prims.append(cap(add(top, u, r * 0.1), add(add(top, u, -r * length), f_, -r * 0.3), r * 0.8, r * 0.5, "behind", mat))
    return f


def fins(mat):
    def f(sk, body, prims, info):
        for elb, hand, g in ((sk.elbow_f, sk.hand_f, "front_arm"), (sk.elbow_b, sk.hand_b, "back_arm")):
            d = norm(sub(hand, elb))
            c = add(lerp(elb, hand, 0.45), front_of(d), -body.arm_w * 0.9)
            prims.append(Prim("ell", c, ra=1.2, rx=5.0, ry=1.6, angle=math.atan2(d[1], d[0]), group=g, mat=mat, za=0.8))
    return f


def bands(mat):
    def f(sk, body, prims, info):
        t, fr = info["t"], info["fr"]
        prims.append(cap(add(sk.pelvis, fr, -body.waist_w), add(sk.pelvis, fr, body.waist_w), 1.4, 1.4, "torso", mat,
                         za=body.waist_w * 0.62))
        for elb, hand, g in ((sk.elbow_f, sk.hand_f, "front_arm"), (sk.elbow_b, sk.hand_b, "back_arm")):
            c = lerp(elb, hand, 0.8)
            prims.append(Prim("ell", c, ra=body.arm_w * 0.9, rx=1.2, ry=body.arm_w * 0.95, angle=math.atan2(*reversed(sub(hand, elb))),
                              group=g, mat=mat, za=0.6))
    return f


def metal_limbs(mat):
    def f(sk, body, prims, info):
        for p in prims:
            if p.group == "front_arm":
                p.mat = mat
            if p.group == "back_leg" and p.mat == "suit_main":
                p.mat = mat
    return f


def mech_extras(eye_mat, leg_mat):
    def f(sk, body, prims, info):
        h, f_, u, r = sk.head, info["f"], info["u"], body.head_r
        prims.append(Prim("ell", add(add(h, f_, r * 0.55), u, r * 0.1), ra=r * 0.28, rx=r * 0.25, ry=r * 0.25, group="head",
                          mat=eye_mat, za=r * 0.8))
        waldo_legs(leg_mat)(sk, body, prims, info)
    return f


# ------------------------------------------------------------------ patterns unique to some variants
def uk_torso(base, red, white):
    b, rr, w = rgb(base), rgb(red), rgb(white)

    def f(ctx):
        col = ctx.color.copy()
        diag = ((ctx.x + ctx.y) % 14.0) < 2.4
        diag2 = ((ctx.x - ctx.y) % 14.0) < 2.4
        band = np.abs(ctx.v) < 0.18
        col[diag | diag2] = w
        col[(diag | diag2) & (((ctx.x + ctx.y) % 14.0) < 1.2)] = rr
        col[band] = rr
        return col, None
    return f


def glitch_grid(line):
    lc = rgb(line)
    g = web_grid(line, width=0.06, strength=1.0)

    def f(ctx):
        col = g(ctx)[0]
        emis = np.all(np.isclose(col, lc[None, :], atol=0.02), axis=1)
        flick = _hash_noise(ctx.x * 0.3, ctx.y * 2.0, 1.0) > 0.86
        col[flick] = lc * 0.8 + 0.2
        return col, None, emis | flick
    return f


def paper_bag(base):
    def f(ctx):
        d = ctx.prim.data
        col = ctx.color * (0.92 + 0.12 * _hash_noise(ctx.x, ctx.y, 1.6)[:, None])
        if "c" in d:
            c, fv, uv, r = d["c"], d["f"], d["u"], d["r"]
            px, py = ctx.x - c[0], ctx.y - c[1]
            a = px * fv[0] + py * fv[1]
            b = px * uv[0] + py * uv[1]
            hole = (((a - r * 0.5) / (r * 0.16)) ** 2 + ((b - r * 0.15) / (r * 0.2)) ** 2) < 1.0
            col[hole] = np.array([0.05, 0.04, 0.04])
            crease = np.abs(b + r * 0.55) < r * 0.04
            col[crease] *= 0.7
        return np.clip(col, 0, 1), None
    return f


# ------------------------------------------------------------------ the roster
FX = Material  # alias for readability below


def _variants():
    V = {}
    V["miles"] = dict(body=MALE, look=look(arm_upper="suit_second", leg_upper="suit_second", leg_lower="suit_second"),
                      mats=suit_mats("#17171d", "#17171d", "#b3121d", "#d81b27", big=True, boot="#17171d"),
                      extras=[])
    V["peter_b"] = dict(body=BULKY, look=look(hips="sweats", leg_upper="sweats", leg_lower="sweats", foot="sneaker", muscle=0.7),
                        mats=suit_mats("#c21d29", "#2441ad", "#560a12", "#141018", extra={
                            "sweats": FX(rgb("#6c6e78"), spec=0.08, wrap=0.3, pattern=fabric(0.07, 2.2)),
                            "sneaker": FX(rgb("#d9d5cc"), spec=0.3, shine=14, wrap=0.2)}), extras=[])
    V["gwen"] = dict(body=FEMALE, look=look(torso="suit_torso", hips="suit_second", arm_upper="suit_main", arm_lower="suit_second",
                                            hand="suit_second", leg_upper="suit_second", leg_lower="suit_second", foot="shoe", muscle=0.5),
                     mats=suit_mats("#f1f1f5", "#19191f", "#e05582", "#19191f", lens="#e0f8ff", seams=False, extra={
                         "hood": FX(rgb("#f4f4f7"), spec=0.1, wrap=0.3, pattern=fabric(0.06, 2.0), sheen=0.3),
                         "hood_in": FX(rgb("#e05582"), spec=0.1, wrap=0.3),
                         "shoe": FX(rgb("#3fc6c9"), spec=0.5, shine=24)}), extras=[hood("hood", "hood_in")])
    V["noir"] = dict(body=MALE, look=look(foot="boot_n", hand="glove_n"),
                     mats=suit_mats("#1c1c20", "#26262b", "#1c1c20", "#1c1c20", lens="#1c1c20", frame="#1c1c20", seams=False,
                                    extra={"coat": FX(rgb("#2c2c31"), spec=0.55, shine=26, rim=0.6, pattern=fabric(0.05, 1.4)),
                                           "hat": FX(rgb("#1f1f23"), spec=0.2, wrap=0.2),
                                           "boot_n": FX(rgb("#161618"), spec=0.6, shine=30),
                                           "glove_n": FX(rgb("#161618"), spec=0.5, shine=26),
                                           "lens_g": FX(rgb("#b9c2cc"), spec=1.5, shine=80, rim=0.9)}),
                     extras=[coat("coat"), fedora("hat"), goggles("metal", "lens_g")])
    V["peni"] = dict(body=MECH, look=look(head="dome", neck="mech_white", torso="mech_pink", hips="mech_blue", arm_upper="mech_white",
                                          arm_lower="mech_pink", hand="mech_white", leg_upper="mech_white", leg_lower="mech_pink",
                                          foot="mech_blue", head_shape="human", muscle=0.4),
                     mats=suit_mats("#e8e8ee", "#3a6fd8", "#e8e8ee", "#e8e8ee", extra={
                         "dome": FX(rgb("#9fe9ff"), spec=1.4, shine=70, rim=1.0, pattern=None),
                         "mech_white": FX(rgb("#e9e9ef"), spec=0.9, shine=44, rim=0.8),
                         "mech_pink": FX(rgb("#e85a9a"), spec=0.9, shine=44, rim=0.8),
                         "mech_blue": FX(rgb("#3a6fd8"), spec=0.9, shine=44, rim=0.8),
                         "eye_red": FX(rgb("#ff3b4a"), emissive=True)}), extras=[mech_extras("eye_red", "mech_pink")])
    V["ham"] = dict(body=TOON, look=look(muscle=0.3),
                    mats=suit_mats("#d0212c", "#2649b5", "#5a0a12", "#141018", extra={
                        "snout": FX(rgb("#f2a3b5"), spec=0.3, shine=18, wrap=0.4, sss=rgb("#c0503a"))}),
                    extras=[snout("snout", "mask")])
    V["2099"] = dict(body=MALE, look=look(arm_upper="suit_main", leg_upper="suit_main"),
                     mats=suit_mats("#141b3d", "#0e1330", "#c8202a", "#d8262e", lens="#ff4a4a", big=True, seams=False,
                                    extra={"fin": FX(rgb("#d8262e"), spec=0.6, shine=30, rim=0.6)}), extras=[fins("fin")])
    V["punk"] = dict(body=MALE, look=look(arm_upper="suit_main", leg_upper="jeans_b", leg_lower="jeans_b", hips="jeans_b", foot="boot_p"),
                     mats=suit_mats("#c21d29", "#141414", "#0d0d0d", "#141414", extra={
                         "denim": FX(rgb("#3b5fa3"), spec=0.12, wrap=0.2, pattern=vc.denim()),
                         "jeans_b": FX(rgb("#1b1b1f"), spec=0.12, wrap=0.2, pattern=vc.denim()),
                         "spike": FX(rgb("#141414"), spec=0.6, shine=30, rim=0.8),
                         "boot_p": FX(rgb("#2a1e1a"), spec=0.6, shine=30)}), extras=[vest("denim"), mohawk("spike")])
    V["india"] = dict(body=MALE, look=look(),
                      mats=suit_mats("#d2232a", "#24409e", "#e9b23c", "#e9b23c"), extras=[bands("gold")])
    V["jess"] = dict(body=FEMALE, look=look(arm_upper="suit_main", hips="suit_second", hand="suit_second", foot="suit_second",
                                            leg_upper="suit_main", leg_lower="suit_main", muscle=0.5),
                     mats=suit_mats("#cc1f2e", "#f2c230", "#cc1f2e", "#f2c230", seams=False, big=True, extra={
                         "hair": FX(rgb("#1e1a1a"), spec=0.55, shine=20, rim=0.8, wrap=0.2, pattern=vc._hair())}),
                      extras=[hair("hair", 2.6)])
    V["scarlet"] = dict(body=MALE, look=look(arm_upper="suit_main", leg_upper="suit_main", hips="suit_main"),
                        mats=suit_mats("#d5162a", "#2c55b8", "#5a0a12", "#141018", extra={
                            "hoodie": FX(rgb("#2c55b8"), spec=0.1, wrap=0.3, pattern=fabric(0.08, 2.0), sheen=0.3)}),
                        extras=[vest("hoodie"), hood_down("hoodie")])
    m_uk = suit_mats("#c8202a", "#22359e", "#5a0a12", "#ffffff")
    m_uk["suit_torso"] = FX(rgb("#22359e"), pattern=uk_torso("#22359e", "#c8202a", "#f4f4f4"), **SUIT)
    V["uk"] = dict(body=MALE, look=look(arm_lower="suit_second", leg_lower="suit_second", hand="suit_main"), mats=m_uk, extras=[])
    m_byte = suit_mats("#a12a9b", "#3a1450", "#55f0ff", "#55f0ff", lens="#55f0ff")
    m_byte["suit_main"] = FX(rgb("#a12a9b"), pattern=glitch_grid("#55f0ff"), **SUIT)
    V["byte"] = dict(body=FEMALE, look=look(arm_upper="suit_main", leg_upper="suit_main", muscle=0.5), mats=m_byte,
                     extras=[hair("hairb", 1.2)])
    m_byte["hairb"] = FX(rgb("#3a1450"), spec=0.5, shine=20, rim=0.8, pattern=vc._hair())
    V["iron"] = dict(body=MALE, look=look(arm_upper="suit_main", leg_upper="suit_second", hips="suit_second"),
                     mats=suit_mats("#b8141e", "#e2b33e", "#e2b33e", "#e2b33e", big=True, seams=False, spec=0.9, shine=46),
                     extras=[waldo_legs("gold")])
    m_bag = suit_mats("#2f4f9e", "#141418", "#2f4f9e", "#2f4f9e", seams=False)
    m_bag["bag"] = FX(rgb("#b88a55"), spec=0.05, wrap=0.4, pattern=paper_bag("#b88a55"))
    V["bagman"] = dict(body=BULKY, look=look(head="bag", head_shape="mask", hand="suit_second", foot="suit_second", muscle=0.6),
                       mats=m_bag, extras=[])
    V["1967"] = dict(body=MALE, look=look(), mats=suit_mats("#e0202a", "#2a4fd0", "#000000", "#000000", web_strength=1.0,
                                                           spec=0.05, rim=0.2, sheen=0.0, wrap=0.4), extras=[])
    V["advanced"] = dict(body=MALE, look=look(hand="glove_w"),
                         mats=suit_mats("#c81e2a", "#1f3c9e", "#5a0a12", "#f2f2f2", big=True, extra={
                             "glove_w": FX(rgb("#c81e2a"), spec=0.4, shine=24)}), extras=[])
    V["cyborg"] = dict(body=FEMALE, look=look(arm_upper="suit_main", leg_upper="suit_main", muscle=0.5),
                       mats=suit_mats("#5b2a86", "#e8e8f0", "#e8e8f0", "#e8e8f0", seams=False, extra={
                           "chrome": FX(rgb("#a8b0bf"), spec=1.3, shine=60, rim=1.0),
                           "hairw": FX(rgb("#e8e8f0"), spec=0.5, shine=20, rim=0.8, pattern=vc._hair())}),
                       extras=[hair("hairw", 1.0), metal_limbs("chrome")])
    return V


VARIANTS = _variants()


def builder(key):
    v = VARIANTS[key]

    def build(sk, body):
        prims = []
        info = humanoid(sk, body, v["look"], prims)
        tdata = {"sk": {"chest": sk.chest, "t": info["t"], "fr": info["fr"], "cw": body.chest_w}}
        for p in prims:
            if p.mat == "suit_torso":
                p.data.update(tdata)
        for ex in v["extras"]:
            ex(sk, body, prims, info)
        e = sk.pose.extras
        if e.get("web_line"):
            a, ln = e["web_line"]
            prims.append(cap(sk.hand_f, add(sk.hand_f, up(a), ln), 0.55, 0.45, "fx", "webglow", za=8))
        if e.get("web_ball"):
            c = add(sk.hand_f, down(sk.pose.arm_f[0] + sk.pose.arm_f[1]), 5.0)
            prims.append(Prim("ell", c, ra=2.6, rx=3.0, ry=2.6, group="fx", mat="webglow", za=8))
        return prims
    return build
