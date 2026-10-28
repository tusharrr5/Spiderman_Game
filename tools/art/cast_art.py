"""Original supporting cast: street thug, gunner, thief, gang boss 'Brick', the Goblin on his glider, and MJ."""
import math
from char_renderer import (Body, Pose, Style, hexc, shade, mix, up, down, add, draw_character, expand_poly)

P = Pose


# ------------------------------------------------------------------ shared face / prop helpers
def face(cv, sk, body, st, eye=(20, 20, 30, 255), brow=True, mouth=True, ear=True):
    h, hd = sk.head, sk.head_dir
    f, u = up(hd + 90), up(hd)
    if ear:
        cv.circle(add(h, f, -body.head_r * 0.15), body.head_r * 0.22, shade(st.head, 0.8))
    e = add(add(h, f, body.head_r * 0.55), u, body.head_r * 0.12)
    cv.circle(e, body.head_r * 0.13, eye)
    if brow:
        cv.line(add(e, u, body.head_r * 0.25), add(add(e, u, body.head_r * 0.3), f, -body.head_r * 0.3), body.head_r * 0.09, st.outline)
    if mouth:
        m = add(add(h, f, body.head_r * 0.62), u, -body.head_r * 0.42)
        cv.line(m, add(m, f, -body.head_r * 0.28), body.head_r * 0.07, shade(st.head, 0.45))
    # nose bump
    cv.circle(add(add(h, f, body.head_r * 0.92), u, -body.head_r * 0.05), body.head_r * 0.14, st.head)


def hand_prop(cv, sk, body, st, length, width, color, glow=None, along_arm=True, offset_ang=0.0):
    p = sk.pose
    ang = p.arm_f[0] + p.arm_f[1] + p.rot + offset_ang
    d = down(ang)
    end = add(sk.hand_f, d, length)
    cv.line(sk.hand_f, end, width + 1.2, st.outline)
    cv.line(sk.hand_f, end, width, color)
    if glow:
        cv.circle(end, width * 1.2, glow)
    return end


def cap_hat(cv, sk, body, color, brim=True):
    h, hd = sk.head, sk.head_dir
    f, u = up(hd + 90), up(hd)
    pts = []
    for i in range(13):
        a = math.radians(hd - 90 - 10 + i * 200 / 12)
        pts.append((h[0] + math.cos(a - math.pi / 2) * body.head_r * 1.04, h[1] + math.sin(a - math.pi / 2) * body.head_r * 1.04))
    pts.append(add(h, u, body.head_r * 0.15))
    cv.poly(expand_poly(pts, 0.9), (18, 15, 26, 255))
    cv.poly(pts, color)
    if brim:
        b0 = add(add(h, u, body.head_r * 0.25), f, body.head_r * 0.2)
        cv.line(b0, add(b0, f, body.head_r * 1.0), body.head_r * 0.28, (18, 15, 26, 255))
        cv.line(b0, add(b0, f, body.head_r * 0.95), body.head_r * 0.16, shade(color, 0.8))


# ------------------------------------------------------------------ generic humanoid animation set
def human_anims(kind):
    a = []
    a.append(("idle", 4, True, [
        P(torso=4, head=-2, arm_f=(12, 30), arm_b=(-10, 25), leg_f=(10, -6), leg_b=(-8, -4)),
        P(torso=5, head=-3, arm_f=(14, 34), arm_b=(-8, 28), leg_f=(10, -8), leg_b=(-8, -6)),
    ]))
    walk = []
    for i in range(6):
        t = i / 6 * math.tau
        walk.append(P(torso=8, head=-6, arm_f=(-28 * math.sin(t), 35), arm_b=(28 * math.sin(t), 35),
                      leg_f=(26 * math.sin(t), -8 - 40 * max(0.0, math.cos(t - 0.4))),
                      leg_b=(26 * math.sin(t + math.pi), -8 - 40 * max(0.0, math.cos(t + math.pi - 0.4)))))
    a.append(("walk", 9, True, walk))
    run = []
    for i in range(6):
        t = i / 6 * math.tau
        run.append(P(torso=16, head=-12, arm_f=(-40 * math.sin(t), 80), arm_b=(40 * math.sin(t), 80),
                     leg_f=(34 * math.sin(t), -12 - 60 * max(0.0, math.cos(t - 0.35))),
                     leg_b=(34 * math.sin(t + math.pi), -12 - 60 * max(0.0, math.cos(t + math.pi - 0.35)))))
    a.append(("run", 13, True, run))
    a.append(("jump", 6, True, [P(torso=8, head=-8, arm_f=(120, 30), arm_b=(-60, 40), leg_f=(50, -70), leg_b=(5, -40), grounded=False)]))
    if kind == "melee":
        a.append(("telegraph", 8, True, [
            P(torso=-12, head=-4, arm_f=(-150, 40), arm_b=(-60, 60), leg_f=(24, -14), leg_b=(-20, -4)),
            P(torso=-14, head=-4, arm_f=(-160, 40), arm_b=(-65, 60), leg_f=(24, -14), leg_b=(-20, -4)),
        ]))
        a.append(("attack", 14, False, [
            P(torso=10, head=-6, arm_f=(30, 10), arm_b=(-30, 60), leg_f=(30, -10), leg_b=(-26, -2)),
            P(torso=22, head=-10, arm_f=(95, 0), arm_b=(-40, 60), leg_f=(34, -8), leg_b=(-30, 0)),
            P(torso=24, head=-12, arm_f=(130, -10), arm_b=(-45, 60), leg_f=(34, -8), leg_b=(-30, 0)),
        ]))
    elif kind == "ranged":
        a.append(("telegraph", 8, True, [
            P(torso=2, head=-6, arm_f=(90, 0), arm_b=(70, 30), leg_f=(20, -8), leg_b=(-18, -4)),
        ]))
        a.append(("attack", 14, False, [
            P(torso=-4, head=-2, arm_f=(100, -10), arm_b=(72, 25), leg_f=(20, -8), leg_b=(-18, -4)),
            P(torso=0, head=-4, arm_f=(92, -2), arm_b=(70, 28), leg_f=(20, -8), leg_b=(-18, -4)),
        ]))
    elif kind == "thief":
        a.append(("telegraph", 8, True, [P(torso=6, head=-8, arm_f=(85, 20), arm_b=(-30, 40), leg_f=(22, -12), leg_b=(-20, -4))]))
        a.append(("attack", 14, False, [
            P(torso=10, head=-10, arm_f=(92, 0), arm_b=(-35, 40), leg_f=(26, -10), leg_b=(-22, -2)),
            P(torso=6, head=-8, arm_f=(96, -6), arm_b=(-35, 40), leg_f=(26, -10), leg_b=(-22, -2)),
        ]))
        a.append(("taunt", 4, True, [
            P(torso=-6, head=-14, arm_f=(150, 40), arm_b=(-30, 60), leg_f=(16, -6), leg_b=(-14, -4)),
            P(torso=-8, head=-16, arm_f=(160, 30), arm_b=(-35, 60), leg_f=(16, -6), leg_b=(-14, -4)),
        ]))
    elif kind == "brute":
        a.append(("telegraph", 8, True, [
            P(torso=34, head=-28, arm_f=(30, 40), arm_b=(-10, 40), leg_f=(45, -70), leg_b=(-30, -40)),
            P(torso=38, head=-30, arm_f=(32, 44), arm_b=(-8, 44), leg_f=(48, -74), leg_b=(-32, -44)),
        ]))
        a.append(("attack", 10, True, [
            P(torso=40, head=-30, arm_f=(70, 20), arm_b=(40, 30), leg_f=(40, -40), leg_b=(-35, -10)),
            P(torso=40, head=-30, arm_f=(74, 18), arm_b=(44, 28), leg_f=(-10, -50), leg_b=(30, -20)),
        ]))
        a.append(("slam_air", 6, True, [P(torso=0, head=-12, arm_f=(170, 10), arm_b=(165, 10), leg_f=(40, -70), leg_b=(10, -50), grounded=False)]))
        a.append(("slam_impact", 6, False, [P(torso=50, head=-40, arm_f=(20, 0), arm_b=(10, 0), leg_f=(70, -100), leg_b=(-35, -60))]))
        a.append(("vulnerable", 4, True, [
            P(torso=40, head=-10, arm_f=(30, 0), arm_b=(20, 0), leg_f=(25, -30), leg_b=(-20, -20)),
            P(torso=44, head=-6, arm_f=(32, 0), arm_b=(22, 0), leg_f=(25, -32), leg_b=(-20, -22)),
        ]))
    a.append(("hurt", 8, False, [P(torso=-20, head=-20, arm_f=(-40, 40), arm_b=(-70, 30), leg_f=(28, -28), leg_b=(-22, -10))]))
    a.append(("webbed", 2, True, [P(torso=0, head=-4, arm_f=(4, 6), arm_b=(-4, 6), leg_f=(3, -2), leg_b=(-3, -2), extras={"webbed": True})]))
    a.append(("ko", 6, False, [
        P(torso=-30, head=-20, arm_f=(-80, 20), arm_b=(-110, 20), leg_f=(30, -20), leg_b=(-10, -10), grounded=False),
        P(torso=0, head=-14, arm_f=(-160, 5), arm_b=(-175, 5), leg_f=(10, -10), leg_b=(-4, -4), rot=-90),
    ]))
    return a


def webbed_overlay(cv, sk, body):
    if not sk.pose.extras.get("webbed"):
        return
    c = add(sk.pelvis, up(sk.pose.torso), body.torso * 0.55)
    for k in range(9):
        a1 = k * 40
        cv.line(add(c, up(a1), body.torso * 0.75), add(c, up(a1 + 150), body.torso * 0.8), 0.7, (235, 245, 255, 210))
    cv.circle(c, 2.5, (235, 245, 255, 200))


# ------------------------------------------------------------------ characters
THUG_BODY = Body(torso=22, head_r=9.2, upper_arm=12.5, forearm=12, thigh=15.5, shin=15.5,
                 chest_w=10.0, waist_w=7.5, arm_w=4.2, leg_w=4.9, hand_r=3.6, foot_len=7.5, outline=1.25)
THUG = Style(head=hexc("#d39a6e"), torso=hexc("#7a4a2b"), hips=hexc("#2f3a55"), arm_upper=hexc("#7a4a2b"),
             arm_lower=hexc("#6c4126"), glove=hexc("#d39a6e"), leg_upper=hexc("#35456b"), leg_lower=hexc("#35456b"),
             boot=hexc("#e8e4dc"), hat=hexc("#b8342c"))


def thug_decorate(cv, sk, body, st, layer):
    if layer == "head":
        face(cv, sk, body, st)
        cap_hat(cv, sk, body, st.hat, brim=False)
    elif layer == "torso":
        # open jacket with a white tee stripe
        c = add(sk.pelvis, up(sk.pose.torso + sk.pose.rot), body.torso * 0.5)
        n = up(sk.pose.torso + sk.pose.rot + 90)
        cv.line(add(add(sk.chest, n, 3.5), up(sk.pose.torso + sk.pose.rot), 1), add(add(sk.pelvis, n, 3.0), up(sk.pose.torso), 2), 3.0, hexc("#e9e6df"))
    elif layer == "front_hand":
        hand_prop(cv, sk, body, st, 19, 2.6, hexc("#9a6b3c"))
    elif layer == "overlay":
        webbed_overlay(cv, sk, body)


GUNNER = Style(head=hexc("#b98163"), torso=hexc("#4c3f6e"), hips=hexc("#252836"), arm_upper=hexc("#4c3f6e"),
               arm_lower=hexc("#4c3f6e"), glove=hexc("#2c2c34"), leg_upper=hexc("#3b3d48"), leg_lower=hexc("#3b3d48"),
               boot=hexc("#20212a"), hood=hexc("#3f3460"))


def gunner_decorate(cv, sk, body, st, layer):
    if layer == "behind":
        # hood draped behind the head
        cv.circle(add(sk.head, up(sk.head_dir + 90), -2.0), body.head_r * 1.12, st.outline)
        cv.circle(add(sk.head, up(sk.head_dir + 90), -2.0), body.head_r * 1.02, st.hood)
    elif layer == "head":
        face(cv, sk, body, st)
        cap_hat(cv, sk, body, st.hood, brim=False)
        # visor shades
        e = add(add(sk.head, up(sk.head_dir + 90), body.head_r * 0.5), up(sk.head_dir), body.head_r * 0.1)
        cv.line(add(e, up(sk.head_dir + 90), -3), add(e, up(sk.head_dir + 90), 3.5), 2.4, hexc("#1a1a22"))
    elif layer == "front_hand":
        end = hand_prop(cv, sk, body, st, 9, 3.0, hexc("#30333d"))
        if sk.pose.arm_f[0] > 95:
            cv.circle(end, 3.0, (255, 220, 120, 230))
    elif layer == "overlay":
        webbed_overlay(cv, sk, body)


THIEF_BODY = Body(torso=21, head_r=8.8, upper_arm=12.5, forearm=12, thigh=16, shin=16,
                  chest_w=8.4, waist_w=6.0, arm_w=3.6, leg_w=4.3, hand_r=3.4, foot_len=7.5, outline=1.25)
THIEF = Style(head=hexc("#1f2028"), torso=hexc("#24262f"), hips=hexc("#1a1b22"), arm_upper=hexc("#24262f"),
              arm_lower=hexc("#2b2d38"), glove=hexc("#1a1b22"), leg_upper=hexc("#2b2d38"), leg_lower=hexc("#2b2d38"),
              boot=hexc("#40281c"), skin=hexc("#c99070"))


def thief_decorate(cv, sk, body, st, layer):
    if layer == "behind":
        # stolen tech case strapped to the back, glowing green
        back = add(add(sk.pelvis, up(sk.pose.torso + sk.pose.rot), body.torso * 0.6), up(sk.pose.torso + sk.pose.rot + 90), -6.5)
        pts = [add(add(back, up(sk.pose.torso + sk.pose.rot), dy), up(sk.pose.torso + sk.pose.rot + 90), dx)
               for dx, dy in ((-5, 9), (5, 9), (5, -9), (-5, -9))]
        cv.poly(expand_poly(pts, 1.0), st.outline)
        cv.poly(pts, hexc("#3c4250"))
        cv.circle(back, 2.8, (90, 255, 140, 255))
        cv.circle(back, 4.5, (90, 255, 140, 70))
    elif layer == "head":
        # balaclava with an eye slit
        e = add(add(sk.head, up(sk.head_dir + 90), body.head_r * 0.5), up(sk.head_dir), body.head_r * 0.1)
        cv.line(add(e, up(sk.head_dir + 90), -3.5), add(e, up(sk.head_dir + 90), 4.0), 3.0, st.skin)
        cv.circle(add(e, up(sk.head_dir + 90), 1.2), 1.1, hexc("#141418"))
    elif layer == "front_hand":
        if sk.pose.arm_f[0] > 70:
            hand_prop(cv, sk, body, st, 7, 3.2, hexc("#5a6170"), glow=(110, 255, 160, 230))
    elif layer == "overlay":
        webbed_overlay(cv, sk, body)


BRICK_BODY = Body(torso=27, head_r=10.5, upper_arm=15, forearm=14, thigh=17, shin=17,
                  chest_w=15.5, waist_w=11.5, arm_w=6.2, leg_w=6.6, hand_r=5.4, foot_len=9, outline=1.4)
BRICK = Style(head=hexc("#a8724f"), torso=hexc("#d8d4cb"), hips=hexc("#3a3a30"), arm_upper=hexc("#a8724f"),
              arm_lower=hexc("#a8724f"), glove=hexc("#2a2a2e"), leg_upper=hexc("#56573f"), leg_lower=hexc("#56573f"),
              boot=hexc("#2a231d"))


def brick_decorate(cv, sk, body, st, layer):
    if layer == "head":
        face(cv, sk, body, st, mouth=True)
        e = add(add(sk.head, up(sk.head_dir + 90), body.head_r * 0.48), up(sk.head_dir), body.head_r * 0.12)
        cv.line(add(e, up(sk.head_dir + 90), -4.5), add(e, up(sk.head_dir + 90), 5.0), 3.0, hexc("#141418"))
    elif layer == "torso":
        # gold chain
        c = add(sk.chest, up(sk.pose.torso + sk.pose.rot), -3)
        for k in range(-3, 4):
            cv.circle(add(add(c, up(sk.pose.torso + sk.pose.rot + 90), k * 2.2), up(sk.pose.torso + sk.pose.rot), -abs(k) * 0.9), 1.1, hexc("#e8c04a"))
    elif layer == "overlay":
        webbed_overlay(cv, sk, body)


GOBLIN_BODY = Body(torso=23, head_r=9.6, upper_arm=13, forearm=12.5, thigh=15.5, shin=15.5,
                   chest_w=9.6, waist_w=6.8, arm_w=4.0, leg_w=4.7, hand_r=3.9, foot_len=7.5, outline=1.3)
GOBLIN = Style(head=hexc("#4fae3a"), torso=hexc("#5a2f86"), hips=hexc("#3d1f5e"), arm_upper=hexc("#3f9a32"),
               arm_lower=hexc("#3f9a32"), glove=hexc("#5a2f86"), leg_upper=hexc("#3f9a32"), leg_lower=hexc("#3f9a32"),
               boot=hexc("#5a2f86"), hood=hexc("#4a2670"))


def goblin_decorate(cv, sk, body, st, layer):
    p = sk.pose
    if layer == "behind":
        if p.extras.get("glider", True):
            tilt = p.extras.get("tilt", 0.0)
            c = add(((sk.foot_f[0] + sk.foot_b[0]) / 2, max(sk.foot_f[1], sk.foot_b[1])), (0, 1), 2.5)
            f, d = up(90 + tilt), up(180 + tilt)
            wing = []
            for x, y in ((-26, 0), (-20, -4), (-12, 1), (-6, -3), (0, 2), (6, -3), (12, 1), (20, -4), (26, 0), (18, 4), (0, 6), (-18, 4)):
                wing.append(add(add(c, f, x * 1.45), d, y * 1.3))
            cv.poly(expand_poly(wing, 1.2), st.outline)
            cv.poly(wing, hexc("#3b4a3f"))
            cv.line(add(c, f, -29), add(c, f, 29), 1.4, hexc("#6f8b74"))
            # jet glow
            jet = add(add(c, f, -22), d, 7)
            flame = p.extras.get("flame", 1.0)
            cv.circle(jet, 3.4 * flame, (255, 180, 60, 200))
            cv.circle(add(jet, d, 3 * flame), 2.2 * flame, (255, 240, 160, 220))
            cv.circle(add(c, f, 2), 2.4, (130, 255, 120, 255))
        # cape/hood tail
        tail = add(add(sk.chest, up(p.torso + p.rot + 90), -6), up(p.torso + p.rot), -10)
        cv.poly([add(sk.chest, up(p.torso + p.rot + 90), -7), add(sk.neck, up(p.torso + p.rot + 90), -3), tail,
                 add(tail, up(p.torso + p.rot + 90), -6)], st.hood)
    elif layer == "head":
        h, hd = sk.head, sk.head_dir
        f, u = up(hd + 90), up(hd)
        # pointed ear
        ear = add(h, f, -body.head_r * 0.2)
        cv.poly([add(ear, u, 3), add(add(ear, u, 9), f, -6), add(ear, u, -3)], shade(st.head, 0.85))
        # pointed purple hood
        hood = [add(add(h, u, body.head_r * 0.6), f, -body.head_r * 1.0), add(add(h, u, body.head_r * 1.9), f, -body.head_r * 1.6),
                add(add(h, u, body.head_r * 0.95), f, body.head_r * 0.4), add(h, u, body.head_r * 0.6)]
        cv.poly(expand_poly(hood, 1.0), st.outline)
        cv.poly(hood, st.hood)
        # glowing yellow eye + toothy grin
        e = add(add(h, f, body.head_r * 0.5), u, body.head_r * 0.15)
        cv.poly([add(e, f, -2.8), add(add(e, f, 3), u, 1.6), add(add(e, f, 2.2), u, -1.4)], hexc("#ffe14a"))
        m = add(add(h, f, body.head_r * 0.45), u, -body.head_r * 0.45)
        grin = p.extras.get("grin", 1.0)
        cv.line(add(m, f, -2.5), add(m, f, 4.5), 2.4 * grin, hexc("#2a0e1e"))
        cv.line(add(m, f, -2.0), add(m, f, 4.0), 0.8 * grin, hexc("#f2f0d8"))
    elif layer == "torso":
        # bag strap across the chest
        cv.line(add(sk.chest, up(p.torso + p.rot + 90), -6), add(sk.pelvis, up(p.torso + p.rot + 90), 5), 1.6, hexc("#7a5a2c"))
    elif layer == "front_hand":
        bomb = p.extras.get("bomb")
        if bomb:
            c = add(sk.hand_f, down(p.arm_f[0] + p.arm_f[1] + p.rot), 3.0)
            cv.circle(c, 4.8, st.outline)
            cv.circle(c, 4.0, hexc("#f08a1c"))
            cv.line(add(c, (0, -1), 0), add(c, (0, -1), 3.5), 1.0, hexc("#2a7a2a"))
            cv.circle(add(c, (-1, -1), 1.4), 1.0, hexc("#ffd890"))


def goblin_anims():
    a = []
    hov = []
    for i in range(4):
        b = math.sin(i / 4 * math.tau)
        hov.append(P(torso=6, head=-6, arm_f=(30 + b * 4, 70), arm_b=(-20, 60), leg_f=(16, -24), leg_b=(-14, -14),
                     grounded=False, pelvis=(64, 58 + b * 1.5), extras={"flame": 1.0 + 0.15 * b}))
    a.append(("hover", 8, True, hov))
    a.append(("throw", 12, False, [
        P(torso=-8, head=-4, arm_f=(-140, 30), arm_b=(30, 50), leg_f=(16, -24), leg_b=(-14, -14), grounded=False, pelvis=(64, 58), extras={"bomb": True}),
        P(torso=18, head=-12, arm_f=(70, 0), arm_b=(-30, 60), leg_f=(18, -24), leg_b=(-14, -14), grounded=False, pelvis=(64, 58)),
        P(torso=12, head=-8, arm_f=(50, 30), arm_b=(-25, 60), leg_f=(16, -24), leg_b=(-14, -14), grounded=False, pelvis=(64, 58)),
    ]))
    a.append(("dive", 10, True, [
        P(torso=40, head=-30, arm_f=(70, 10), arm_b=(40, 30), leg_f=(30, -40), leg_b=(5, -30), grounded=False, pelvis=(64, 58),
          extras={"tilt": 28, "flame": 1.6}),
        P(torso=42, head=-30, arm_f=(72, 10), arm_b=(42, 30), leg_f=(30, -42), leg_b=(5, -32), grounded=False, pelvis=(64, 58),
          extras={"tilt": 28, "flame": 1.9}),
    ]))
    a.append(("telegraph", 8, True, [
        P(torso=-10, head=-20, arm_f=(150, 20), arm_b=(-60, 40), leg_f=(16, -24), leg_b=(-14, -14), grounded=False, pelvis=(64, 58), extras={"grin": 1.4}),
        P(torso=-12, head=-24, arm_f=(158, 16), arm_b=(-64, 40), leg_f=(16, -24), leg_b=(-14, -14), grounded=False, pelvis=(64, 58), extras={"grin": 1.5}),
    ]))
    a.append(("stunned", 6, True, [
        P(torso=30, head=10, arm_f=(10, 10), arm_b=(-10, 10), leg_f=(20, -30), leg_b=(-10, -20), grounded=False, pelvis=(64, 70),
          extras={"tilt": -18, "flame": 0.3, "grin": 0.4}),
        P(torso=34, head=14, arm_f=(14, 10), arm_b=(-8, 10), leg_f=(20, -30), leg_b=(-10, -20), grounded=False, pelvis=(64, 71),
          extras={"tilt": -20, "flame": 0.2, "grin": 0.4}),
    ]))
    a.append(("hurt", 8, False, [
        P(torso=-24, head=-24, arm_f=(-50, 40), arm_b=(-80, 30), leg_f=(24, -30), leg_b=(-14, -16), grounded=False, pelvis=(64, 58), extras={"tilt": -12}),
    ]))
    a.append(("laugh", 6, True, [
        P(torso=-14, head=-30, arm_f=(40, 100), arm_b=(-30, 90), leg_f=(16, -24), leg_b=(-14, -14), grounded=False, pelvis=(64, 58), extras={"grin": 1.6}),
        P(torso=-16, head=-34, arm_f=(42, 104), arm_b=(-28, 92), leg_f=(16, -24), leg_b=(-14, -14), grounded=False, pelvis=(64, 57), extras={"grin": 1.7}),
    ]))
    a.append(("defeated", 6, False, [
        P(torso=-30, head=-20, arm_f=(-90, 20), arm_b=(-120, 20), leg_f=(40, -20), leg_b=(10, -10), grounded=False, pelvis=(64, 60), extras={"glider": False}),
        P(torso=0, head=-14, arm_f=(-160, 5), arm_b=(-175, 5), leg_f=(10, -10), leg_b=(-4, -4), rot=-90, extras={"glider": False}),
    ]))
    return a


MJ_BODY = Body(torso=20, head_r=8.8, upper_arm=11.5, forearm=11, thigh=15, shin=15,
               chest_w=7.6, waist_w=5.6, arm_w=3.0, leg_w=3.8, hand_r=3.0, foot_len=6.5, outline=1.2)
MJ = Style(head=hexc("#f0c4a0"), torso=hexc("#2f8a5c"), hips=hexc("#2f4f8a"), arm_upper=hexc("#2f8a5c"),
           arm_lower=hexc("#f0c4a0"), glove=hexc("#f0c4a0"), leg_upper=hexc("#3a5ea8"), leg_lower=hexc("#3a5ea8"),
           boot=hexc("#6b3b24"), hair=hexc("#c8401f"))


def mj_decorate(cv, sk, body, st, layer):
    h, hd = sk.head, sk.head_dir
    f, u = up(hd + 90), up(hd)
    if layer == "behind":
        # long hair falling behind the shoulders
        top = add(h, f, -body.head_r * 0.2)
        pts = [add(add(top, u, body.head_r * 0.9), f, -body.head_r * 0.6), add(top, f, -body.head_r * 1.25),
               add(add(top, u, -body.head_r * 2.4), f, -body.head_r * 1.05), add(add(top, u, -body.head_r * 2.6), f, body.head_r * 0.1),
               add(add(top, u, -body.head_r * 1.0), f, body.head_r * 0.2)]
        cv.poly(expand_poly(pts, 1.0), st.outline)
        cv.poly(pts, shade(st.hair, 0.85))
    elif layer == "head":
        face(cv, sk, body, st, eye=(40, 70, 40, 255))
        # fringe on top
        pts = []
        for i in range(11):
            a = math.radians(hd - 100 + i * 190 / 10)
            pts.append((h[0] + math.cos(a - math.pi / 2) * body.head_r * 1.07, h[1] + math.sin(a - math.pi / 2) * body.head_r * 1.07))
        pts.append(add(add(h, u, body.head_r * 0.25), f, body.head_r * 0.5))
        pts.append(add(h, f, -body.head_r * 0.6))
        cv.poly(expand_poly(pts, 0.9), st.outline)
        cv.poly(pts, st.hair)


def mj_anims():
    a = []
    a.append(("idle", 3, True, [
        P(torso=2, head=-2, arm_f=(8, 20), arm_b=(-6, 18), leg_f=(6, -4), leg_b=(-6, -2)),
        P(torso=3, head=-3, arm_f=(10, 24), arm_b=(-5, 20), leg_f=(6, -5), leg_b=(-6, -3)),
    ]))
    a.append(("worried", 4, True, [
        P(torso=10, head=10, arm_f=(70, 120), arm_b=(55, 125), leg_f=(8, -6), leg_b=(-6, -4)),
        P(torso=12, head=12, arm_f=(72, 122), arm_b=(57, 127), leg_f=(8, -6), leg_b=(-6, -4)),
    ]))
    a.append(("cheer", 5, True, [
        P(torso=-2, head=-12, arm_f=(165, 10), arm_b=(150, 20), leg_f=(10, -6), leg_b=(-8, -4)),
        P(torso=-2, head=-14, arm_f=(170, 6), arm_b=(158, 14), leg_f=(10, -6), leg_b=(-8, -4), dy=-2),
    ]))
    run = []
    for i in range(6):
        t = i / 6 * math.tau
        run.append(P(torso=12, head=-8, arm_f=(-34 * math.sin(t), 75), arm_b=(34 * math.sin(t), 75),
                     leg_f=(30 * math.sin(t), -10 - 55 * max(0.0, math.cos(t - 0.35))),
                     leg_b=(30 * math.sin(t + math.pi), -10 - 55 * max(0.0, math.cos(t + math.pi - 0.35)))))
    a.append(("run", 12, True, run))
    a.append(("held", 4, True, [P(torso=-6, head=-6, arm_f=(150, 20), arm_b=(140, 30), leg_f=(30, -50), leg_b=(10, -40), grounded=False)]))
    return a


CAST = {
    # name: (body, style, decorate, anims, frame)
    "thug": (THUG_BODY, THUG, thug_decorate, lambda: human_anims("melee"), 96),
    "gunner": (THUG_BODY, GUNNER, gunner_decorate, lambda: human_anims("ranged"), 96),
    "thief": (THIEF_BODY, THIEF, thief_decorate, lambda: human_anims("thief"), 96),
    "brick": (BRICK_BODY, BRICK, brick_decorate, lambda: human_anims("brute"), 128),
    "goblin": (GOBLIN_BODY, GOBLIN, goblin_decorate, goblin_anims, 128),
    "mj": (MJ_BODY, MJ, mj_decorate, mj_anims, 96),
}


def render_cast(name):
    body, style, deco, anim_fn, frame = CAST[name]
    frames, manifest, idx = [], {}, 0
    for an, fps, loop, poses in anim_fn():
        manifest[an] = [idx, len(poses), fps, loop]
        for p in poses:
            frames.append(draw_character(body, p, style, deco, frame=frame))
            idx += 1
    return frames, manifest, frame
