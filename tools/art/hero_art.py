"""Original hero design: masked web-slinger in two suit palettes, with the full animation pose set."""
import math
from char_renderer import Body, Pose, Style, hexc, shade, mix, up, down, add, draw_character

# proportions for the volumetric renderer: smaller head, longer limbs (same overall height)
HERO_BODY_VOL = Body(torso=24.0, neck=3.5, head_r=7.4, upper_arm=13.5, forearm=12.8, thigh=17.5, shin=17.0,
                     chest_w=9.8, waist_w=6.3, arm_w=3.5, leg_w=4.5, hand_r=3.0, foot_len=7.0, outline=1.25)
HERO_BODY = Body(torso=23.0, neck=3.0, head_r=9.6, upper_arm=13.0, forearm=12.5, thigh=16.0, shin=16.0,
                 chest_w=9.2, waist_w=6.4, arm_w=3.9, leg_w=4.7, hand_r=3.9, foot_len=7.5, outline=1.25)

CLASSIC = Style(
    head=hexc("#d3242c"), torso=hexc("#d3242c"), hips=hexc("#2747c9"),
    arm_upper=hexc("#2747c9"), arm_lower=hexc("#d3242c"), glove=hexc("#d3242c"),
    leg_upper=hexc("#2747c9"), leg_lower=hexc("#d3242c"), boot=hexc("#b81c25"),
    web=hexc("#5b0b14"), flank=hexc("#2747c9"), emblem=hexc("#16121c"), eye=hexc("#f4f8ff"),
)
DARK = Style(
    head=hexc("#262833"), torso=hexc("#262833"), hips=hexc("#1b1c24"),
    arm_upper=hexc("#1f2029"), arm_lower=hexc("#262833"), glove=hexc("#2e3140"),
    leg_upper=hexc("#1f2029"), leg_lower=hexc("#262833"), boot=hexc("#2e3140"),
    web=hexc("#454a60"), flank=hexc("#1b1c24"), emblem=hexc("#f2f4fa"), eye=hexc("#f4f8ff"),
)


def hero_decorate(cv, sk, body, st, layer):
    if layer == "head":
        h = sk.head
        hd = sk.head_dir
        f = up(hd + 90)   # forward direction of the face
        u = up(hd)
        # web lines radiating from the front of the face
        c = add(h, f, body.head_r * 0.35)
        for k in range(7):
            a = hd + 90 + 180 + (k - 3) * 30
            e = add(h, up(a), body.head_r * 0.93)
            cv.line(c, e, 0.45, st.web)
        # front eye: big teardrop lens
        ec = add(add(h, f, body.head_r * 0.42), u, body.head_r * 0.12)
        pts = []
        for i in range(14):
            t = i / 14 * math.tau
            rx, ry = 3.1, 4.2
            x, y = math.cos(t) * rx, math.sin(t) * ry
            # pull the bottom-inner corner into a point
            if math.sin(t) > 0.3 and math.cos(t) < 0:
                x *= 0.55
            px = ec[0] + x * math.cos(math.radians(hd + 18)) - y * math.sin(math.radians(hd + 18))
            py = ec[1] + x * math.sin(math.radians(hd + 18)) + y * math.cos(math.radians(hd + 18))
            pts.append((px, py))
        from char_renderer import expand_poly
        cv.poly(expand_poly(pts, 0.9), st.outline)
        cv.poly(pts, st.eye)
        # back eye peeking at the face edge
        be = add(add(h, f, body.head_r * 0.82), u, body.head_r * 0.16)
        cv.circle(be, 1.9, st.outline)
        cv.circle(add(be, f, -0.2), 1.25, shade(st.eye, 0.85))
    elif layer == "torso":
        a, b = sk.pelvis, sk.chest
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1.0
        t = (dx / ln, dy / ln)
        n = (-t[1], t[0])
        top = add(b, t, 1.2)
        cw, ww = body.chest_w, body.waist_w
        # side panel toward the back of the body
        flank = [add(top, n, -cw * 0.98), add(top, n, -cw * 0.25), add(a, n, -ww * 0.2), add(a, n, -ww * 0.98)]
        cv.poly(flank, shade(st.flank, 0.9))
        # chest emblem (small spider)
        ec = add(add(b, t, -4.5), n, 2.6)
        if st.emblem[0] > 200:     # dark suit: big white emblem
            for side in (-1, 1):
                for k, ang in enumerate((-60, -25, 25, 60)):
                    leg = up(math.degrees(math.atan2(t[0], -t[1])) + side * (90 + ang * 0.6))
                    cv.line(ec, add(ec, leg, 5.0 + (1 if k in (1, 2) else 0)), 0.75, st.emblem)
            cv.circle(ec, 1.8, st.emblem)
            cv.circle(add(ec, t, -2.0), 1.4, st.emblem)
        else:
            for side in (-1, 1):
                for ang in (-50, -15, 15, 50):
                    leg = up(math.degrees(math.atan2(t[0], -t[1])) + side * (90 + ang * 0.5))
                    cv.line(ec, add(ec, leg, 2.6), 0.42, st.emblem)
            cv.circle(ec, 1.0, st.emblem)
            # web seams across the chest
            for k in range(4):
                e = add(add(top, n, cw * (0.9 - k * 0.45)), t, -1.0)
                cv.line(ec, e, 0.35, st.web)
    elif layer == "overlay":
        # web line shooting from the front hand for web poses
        web = sk.pose.extras.get("web_line")
        if web:
            d = up(web[0])
            end = add(sk.hand_f, d, web[1])
            cv.line(sk.hand_f, end, 0.9, (235, 245, 255, 235))
        spark = sk.pose.extras.get("web_ball")
        if spark:
            c = add(sk.hand_f, down(sk.pose.arm_f[0] + sk.pose.arm_f[1]), 5.0)
            cv.circle(c, 3.2, (235, 245, 255, 220))
            for k in range(6):
                cv.line(c, add(c, up(k * 60), 5.0), 0.5, (235, 245, 255, 200))


def P(**kw):
    return Pose(**kw)


def hero_animations():
    """Returns ordered list of (anim_name, fps, loop, [Pose...])."""
    anims = []
    # idle: heroic ready stance with breathing
    idle = []
    for i in range(4):
        b = math.sin(i / 4 * math.tau)
        idle.append(P(torso=8 + b, head=-4, arm_f=(28 + b * 3, 75), arm_b=(-18, 60),
                      leg_f=(20, -18 - b * 2), leg_b=(-16, -6 - b * 2)))
    anims.append(("idle", 6, True, idle))
    # run cycle
    run = []
    for i in range(8):
        t = i / 8 * math.tau
        hip_f = 34 * math.sin(t)
        hip_b = 34 * math.sin(t + math.pi)
        knee_f = -12 - 62 * max(0.0, math.cos(t - 0.35))
        knee_b = -12 - 62 * max(0.0, math.cos(t + math.pi - 0.35))
        run.append(P(torso=16, head=-12, arm_f=(-38 * math.sin(t), 85), arm_b=(38 * math.sin(t), 85),
                     leg_f=(hip_f, knee_f), leg_b=(hip_b, knee_b), dy=-1.5 * abs(math.sin(t))))
    anims.append(("run", 14, True, run))
    anims.append(("jump", 10, False, [
        P(torso=6, head=-6, arm_f=(165, 10), arm_b=(-35, 45), leg_f=(55, -75), leg_b=(5, -45), grounded=False),
        P(torso=4, head=-8, arm_f=(170, 5), arm_b=(-45, 35), leg_f=(45, -95), leg_b=(15, -60), grounded=False),
    ]))
    anims.append(("fall", 8, True, [
        P(torso=4, head=-4, arm_f=(115, 25), arm_b=(-110, 25), leg_f=(22, -30), leg_b=(-12, -14), grounded=False),
        P(torso=4, head=-4, arm_f=(125, 20), arm_b=(-118, 22), leg_f=(26, -34), leg_b=(-14, -18), grounded=False),
    ]))
    anims.append(("super_jump", 8, True, [
        P(torso=0, head=-10, arm_f=(178, 0), arm_b=(-25, 40), leg_f=(8, -4), leg_b=(-6, -30), grounded=False),
        P(torso=0, head=-10, arm_f=(178, 0), arm_b=(-30, 45), leg_f=(10, -8), leg_b=(-8, -36), grounded=False),
    ]))
    # wall climb (wall on the right / facing side)
    climb = []
    for i in range(4):
        s = 1 if i % 2 == 0 else -1
        climb.append(P(torso=6, head=-30, arm_f=(150 + s * 12, -10 - s * 10), arm_b=(115 - s * 12, 20 + s * 10),
                       leg_f=(85 - s * 15, -95 + s * 10), leg_b=(55 + s * 15, -80 - s * 10), grounded=False,
                       pelvis=(44, 56 + (i % 2) * 1.5)))
    anims.append(("wall_climb", 8, True, climb))
    anims.append(("wall_idle", 2, True, [climb[0]]))
    # ceiling crawl: crawl on all fours then flip vertically
    crawl = []
    for i in range(4):
        s = math.sin(i / 4 * math.tau)
        crawl.append(P(torso=88, head=-50, arm_f=(18 + s * 22, -20), arm_b=(-8 - s * 22, -15),
                       leg_f=(15 - s * 20, -75), leg_b=(-15 + s * 20, -70), flip_v=True, dy=-1))
    anims.append(("ceiling_crawl", 8, True, crawl))
    # web swing
    anims.append(("swing", 8, True, [
        P(torso=10, head=-14, arm_f=(172, 0), arm_b=(-35, 70), leg_f=(70, -85), leg_b=(40, -70), grounded=False),
        P(torso=14, head=-14, arm_f=(170, 0), arm_b=(-45, 65), leg_f=(60, -60), leg_b=(25, -45), grounded=False),
        P(torso=18, head=-10, arm_f=(168, 0), arm_b=(-50, 60), leg_f=(40, -30), leg_b=(5, -20), grounded=False),
    ]))
    # punches
    anims.append(("jab", 18, False, [
        P(torso=10, head=-6, arm_f=(45, 110), arm_b=(-20, 70), leg_f=(26, -16), leg_b=(-22, -6)),
        P(torso=18, head=-12, arm_f=(88, 0), arm_b=(-30, 85), leg_f=(32, -8), leg_b=(-30, 0), extras={}),
        P(torso=14, head=-10, arm_f=(70, 30), arm_b=(-25, 80), leg_f=(30, -12), leg_b=(-26, -4)),
    ]))
    anims.append(("cross", 18, False, [
        P(torso=6, head=-6, arm_f=(30, 110), arm_b=(-40, 95), leg_f=(24, -16), leg_b=(-22, -8)),
        P(torso=24, head=-16, arm_f=(15, 115), arm_b=(92, 0), leg_f=(36, -10), leg_b=(-34, 0)),
        P(torso=18, head=-12, arm_f=(25, 110), arm_b=(70, 25), leg_f=(30, -12), leg_b=(-28, -4)),
    ]))
    anims.append(("finisher", 14, False, [
        P(torso=30, head=-25, arm_f=(30, 120), arm_b=(-30, 80), leg_f=(55, -95), leg_b=(-25, -60)),
        P(torso=4, head=-14, arm_f=(170, 0), arm_b=(-40, 60), leg_f=(20, -40), leg_b=(-10, -20), grounded=False, pelvis=(48, 60)),
        P(torso=-30, head=0, arm_f=(150, 20), arm_b=(-90, 40), leg_f=(120, 0), leg_b=(20, -60), grounded=False, rot=-25, pelvis=(46, 56)),
        P(torso=12, head=-6, arm_f=(40, 80), arm_b=(-30, 70), leg_f=(28, -20), leg_b=(-24, -8)),
    ]))
    anims.append(("kick", 16, False, [
        P(torso=-6, head=-4, arm_f=(55, 70), arm_b=(-45, 50), leg_f=(80, -115), leg_b=(-6, -4)),
        P(torso=-26, head=6, arm_f=(70, 60), arm_b=(-70, 30), leg_f=(96, 0), leg_b=(-8, -2)),
        P(torso=-22, head=4, arm_f=(65, 60), arm_b=(-65, 35), leg_f=(92, -6), leg_b=(-8, -2)),
        P(torso=4, head=-4, arm_f=(30, 80), arm_b=(-25, 60), leg_f=(30, -40), leg_b=(-14, -6)),
    ]))
    anims.append(("web_shoot", 14, False, [
        P(torso=8, head=-8, arm_f=(70, 40), arm_b=(-25, 70), leg_f=(22, -14), leg_b=(-18, -6)),
        P(torso=12, head=-12, arm_f=(92, 0), arm_b=(-30, 75), leg_f=(24, -12), leg_b=(-20, -4), extras={"web_ball": True}),
        P(torso=10, head=-10, arm_f=(88, 4), arm_b=(-28, 72), leg_f=(24, -12), leg_b=(-20, -4)),
    ]))
    anims.append(("slam", 14, False, [
        P(torso=30, head=-20, arm_f=(20, 60), arm_b=(-20, 60), leg_f=(60, -100), leg_b=(-20, -70)),
        P(torso=0, head=-10, arm_f=(170, 0), arm_b=(165, 5), leg_f=(30, -60), leg_b=(5, -40), grounded=False),
        P(torso=40, head=-30, arm_f=(60, 0), arm_b=(45, 0), leg_f=(40, -40), leg_b=(-10, -20), grounded=False),
        P(torso=55, head=-40, arm_f=(25, 0), arm_b=(10, 10), leg_f=(70, -110), leg_b=(-35, -60)),
    ]))
    anims.append(("throw", 14, False, [
        P(torso=-10, head=-2, arm_f=(-130, 30), arm_b=(30, 60), leg_f=(30, -10), leg_b=(-25, -6)),
        P(torso=22, head=-14, arm_f=(70, 0), arm_b=(-40, 60), leg_f=(36, -14), leg_b=(-30, 0), extras={"web_line": (60, 10)}),
        P(torso=14, head=-10, arm_f=(50, 30), arm_b=(-30, 60), leg_f=(30, -14), leg_b=(-24, -4)),
    ]))
    anims.append(("dodge", 16, False, [
        P(torso=40, head=-30, arm_f=(70, 110), arm_b=(40, 110), leg_f=(100, -140), leg_b=(80, -135), rot=r, grounded=False,
          pelvis=(48, 62))
        for r in (0, 90, 180, 270)
    ]))
    anims.append(("hurt", 10, False, [
        P(torso=-22, head=-22, arm_f=(-50, 40), arm_b=(-80, 30), leg_f=(30, -30), leg_b=(-25, -10)),
        P(torso=-14, head=-14, arm_f=(-30, 50), arm_b=(-60, 40), leg_f=(25, -25), leg_b=(-20, -10)),
    ]))
    anims.append(("defeated", 8, False, [
        P(torso=-30, head=-20, arm_f=(-80, 20), arm_b=(-110, 20), leg_f=(30, -20), leg_b=(-10, -10), grounded=False),
        P(torso=0, head=-10, arm_f=(-100, 10), arm_b=(-130, 10), leg_f=(20, -10), leg_b=(-5, -5), rot=-60),
        P(torso=0, head=-14, arm_f=(-160, 5), arm_b=(-175, 5), leg_f=(10, -10), leg_b=(-4, -4), rot=-90),
    ]))
    anims.append(("victory", 4, True, [
        P(torso=2, head=-12, arm_f=(172, 6), arm_b=(-20, 70), leg_f=(22, -10), leg_b=(-18, -4)),
        P(torso=2, head=-14, arm_f=(176, 2), arm_b=(-22, 72), leg_f=(22, -10), leg_b=(-18, -4)),
    ]))
    anims.append(("land", 10, False, [
        P(torso=30, head=-22, arm_f=(30, 60), arm_b=(-20, 60), leg_f=(60, -110), leg_b=(-30, -80)),
    ]))
    anims.append(("carry", 6, True, [
        P(torso=8, head=-8, arm_f=(170, 0), arm_b=(40, 80), leg_f=(30, -40), leg_b=(-10, -20), grounded=False),
    ]))
    # ---- fighting-game moveset: guard, parry, heavy, specials
    anims.append(("block", 4, True, [
        P(torso=6, head=6, arm_f=(62, 108), arm_b=(48, 122), leg_f=(30, -32), leg_b=(-24, -18)),
        P(torso=7, head=7, arm_f=(64, 106), arm_b=(50, 120), leg_f=(31, -36), leg_b=(-25, -22)),
    ]))
    anims.append(("block_hit", 10, False, [
        P(torso=-6, head=10, arm_f=(55, 116), arm_b=(44, 126), leg_f=(32, -26), leg_b=(-30, -12)),
        P(torso=2, head=8, arm_f=(60, 110), arm_b=(48, 122), leg_f=(30, -30), leg_b=(-26, -16)),
    ]))
    anims.append(("parry", 18, False, [
        P(torso=6, head=6, arm_f=(62, 108), arm_b=(48, 122), leg_f=(30, -32), leg_b=(-24, -18)),
        P(torso=-10, head=-6, arm_f=(145, 18), arm_b=(25, 95), leg_f=(34, -28), leg_b=(-28, -12)),
        P(torso=-6, head=-4, arm_f=(130, 30), arm_b=(30, 90), leg_f=(32, -30), leg_b=(-26, -14)),
    ]))
    anims.append(("heavy", 9, False, [
        P(torso=-14, head=-4, arm_f=(-50, 100), arm_b=(30, 80), leg_f=(35, -60), leg_b=(-30, -30)),
        P(torso=-18, head=-2, arm_f=(-72, 112), arm_b=(36, 86), leg_f=(46, -82), leg_b=(-34, -40)),
        P(torso=30, head=-22, arm_f=(98, 0), arm_b=(-50, 60), leg_f=(56, -20), leg_b=(-46, 0)),
        P(torso=28, head=-20, arm_f=(95, 4), arm_b=(-48, 62), leg_f=(54, -22), leg_b=(-44, -2)),
        P(torso=14, head=-10, arm_f=(60, 40), arm_b=(-30, 70), leg_f=(32, -18), leg_b=(-26, -6)),
    ]))
    anims.append(("sp_whirl", 20, True, [
        P(torso=10, head=-10, arm_f=(95, 0), arm_b=(-95, 0), leg_f=(40, -60), leg_b=(-20, -40), rot=r, grounded=False,
          pelvis=(48, 56), extras={"web_line": (90 + r, 26)})
        for r in range(0, 360, 45)
    ]))
    jab_p = dict(torso=20, head=-12, arm_f=(90, 0), arm_b=(-30, 85), leg_f=(40, -14), leg_b=(-34, 0))
    cross_p = dict(torso=24, head=-14, arm_f=(15, 115), arm_b=(94, 0), leg_f=(38, -12), leg_b=(-36, 0))
    anims.append(("sp_flurry", 16, True, [P(**(jab_p if i % 2 == 0 else cross_p), dx=(i % 2) * 1.5) for i in range(6)]))
    anims.append(("sp_uppercut", 8, False, [
        P(torso=30, head=-20, arm_f=(10, 100), arm_b=(-30, 70), leg_f=(70, -110), leg_b=(-30, -80)),
        P(torso=-6, head=-14, arm_f=(174, 0), arm_b=(-40, 60), leg_f=(24, -44), leg_b=(-10, -24), grounded=False,
          pelvis=(48, 50)),
        P(torso=-4, head=-12, arm_f=(176, 2), arm_b=(-36, 62), leg_f=(30, -60), leg_b=(-8, -30), grounded=False,
          pelvis=(48, 50)),
    ]))
    # fighting-game set: 5-hit chain (jab, cross, hook, roundhouse, finisher), guard stance, entrance
    anims.append(("hook", 16, False, [
        P(torso=0, head=-6, arm_f=(40, 100), arm_b=(30, 115), leg_f=(28, -16), leg_b=(-26, -6)),
        P(torso=26, head=-14, arm_f=(25, 110), arm_b=(88, 78), leg_f=(38, -12), leg_b=(-36, 0)),
        P(torso=20, head=-12, arm_f=(30, 105), arm_b=(72, 62), leg_f=(34, -12), leg_b=(-30, -4)),
    ]))
    anims.append(("roundhouse", 14, False, [
        P(torso=-10, head=-4, arm_f=(50, 80), arm_b=(-40, 60), leg_f=(95, -120), leg_b=(-6, -4)),
        P(torso=-34, head=10, arm_f=(80, 50), arm_b=(-80, 30), leg_f=(118, -4), leg_b=(-8, -2)),
        P(torso=-30, head=8, arm_f=(75, 55), arm_b=(-75, 35), leg_f=(112, -10), leg_b=(-8, -2)),
        P(torso=4, head=-4, arm_f=(30, 80), arm_b=(-25, 60), leg_f=(30, -40), leg_b=(-14, -6)),
    ]))
    stance = dict(torso=10, head=-8, arm_f=(42, 112), arm_b=(22, 122), leg_f=(32, -22), leg_b=(-30, -12))
    anims.append(("stance", 3, True, [P(**stance), P(**stance, dy=0.7)]))
    anims.append(("intro", 5, False, [
        P(torso=42, head=-32, arm_f=(8, 25), arm_b=(-30, 20), leg_f=(70, -120), leg_b=(-40, -112)),
        P(torso=40, head=-28, arm_f=(10, 28), arm_b=(-28, 22), leg_f=(68, -118), leg_b=(-40, -110)),
        P(torso=18, head=-16, arm_f=(30, 90), arm_b=(-10, 80), leg_f=(40, -50), leg_b=(-26, -40)),
        P(torso=4, head=-10, arm_f=(100, -4), arm_b=(-25, 70), leg_f=(26, -12), leg_b=(-22, -6)),
        P(torso=4, head=-10, arm_f=(100, -4), arm_b=(-25, 70), leg_f=(26, -12), leg_b=(-22, -6)),
        P(**stance),
    ]))
    return anims


def render_sheet(style):
    frames, manifest, idx = [], {}, 0
    for name, fps, loop, poses in hero_animations():
        manifest[name] = [idx, len(poses), fps, loop]
        for p in poses:
            frames.append(draw_character(HERO_BODY, p, style, hero_decorate))
            idx += 1
    return frames, manifest
