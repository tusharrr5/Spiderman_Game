"""Builds every volumetric character sheet in parallel (in-betweens, motion blur, grid atlases).

Each sheet is a grid atlas no wider than 4096 px (mobile/WebGL texture limit). The generated SpriteDB entry
records frame size, grid, display scale and foot offset so SpriteAnimator places the art exactly where
the old strips were.
"""
from __future__ import annotations

import math
import os
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image

import cast_art
import hero_art
import vol_chars as vc
from char_renderer import Skeleton
from vol_renderer import VolumeRenderer, expand_anim, lerp_pose

DENSITY = 2.0                   # output pixels per skeleton unit (4 texels per game px at display scale)
MAX_W = 4096
BLUR_ANIMS = {"jab", "cross", "finisher", "kick", "slam", "throw", "attack", "dive", "dodge", "web_shoot",
              "heavy", "parry", "sp_whirl", "sp_flurry", "sp_uppercut"}
INBETWEENS = 1


def _hero(dark):
    return dict(body=hero_art.HERO_BODY_VOL, frame=96, anims=hero_art.hero_animations,
                build=lambda sk, b: vc.build_hero(sk, b, dark), mats=lambda: vc.hero_materials(dark))


SHEETS = {
    "hero_classic": _hero(False),
    "hero_dark": _hero(True),
    "thug": dict(body=vc.THUG_VOL, frame=96, anims=lambda: cast_art.human_anims("melee"),
                 build=lambda sk, b: vc.build_thug(sk, b), mats=vc.thug_materials),
    "gunner": dict(body=vc.THUG_VOL, frame=96, anims=lambda: cast_art.human_anims("ranged"),
                   build=lambda sk, b: vc.build_thug(sk, b, "gunner"), mats=vc.gunner_materials),
    "thief": dict(body=vc.THIEF_VOL, frame=96, anims=lambda: cast_art.human_anims("thief"),
                  build=vc.build_thief, mats=vc.thief_materials),
    "brick": dict(body=vc.BRICK_VOL, frame=128, anims=lambda: cast_art.human_anims("brute"),
                  build=vc.build_brick, mats=vc.brick_materials),
    "goblin": dict(body=vc.GOBLIN_VOL, frame=128, anims=cast_art.goblin_anims,
                   build=vc.build_goblin, mats=vc.goblin_materials),
    "mj": dict(body=vc.MJ_VOL, frame=96, anims=cast_art.mj_anims, build=vc.build_mj, mats=vc.mj_materials),
}

STILLS = {
    "hero": (hero_art.HERO_BODY_VOL, lambda sk, b: vc.build_hero(sk, b, False), lambda: vc.hero_materials(False)),
    "hero_dark": (hero_art.HERO_BODY_VOL, lambda sk, b: vc.build_hero(sk, b, True), lambda: vc.hero_materials(True)),
    "thug": (vc.THUG_VOL, lambda sk, b: vc.build_thug(sk, b), vc.thug_materials),
    "thief": (vc.THIEF_VOL, vc.build_thief, vc.thief_materials),
    "brick": (vc.BRICK_VOL, vc.build_brick, vc.brick_materials),
    "goblin": (vc.GOBLIN_VOL, vc.build_goblin, vc.goblin_materials),
    "mj": (vc.MJ_VOL, vc.build_mj, vc.mj_materials),
    "captain": (vc.THUG_VOL, lambda sk, b: vc.build_thug(sk, b, "captain"), vc.captain_materials),
}


def render_still(key, pose, frame=96, k=3):
    """One high-resolution pose (portraits, story panels, title art). Returns (image, skeleton)."""
    body, build, mats = STILLS[key]
    R = VolumeRenderer(frame, k, mats())
    sk = Skeleton(body, pose, frame)
    img = R.to_image(R.render(build(sk, body), vc.LAYERS, dim=vc.DIM))
    return img, Skeleton(body, pose, frame)


# ---- versus roster (tools/art/spiderverse.py): 18 variant sheets at 3 texels per game px to save VRAM
import spiderverse  # noqa: E402
VS_DENSITY = 1.5
for _k, _v in spiderverse.VARIANTS.items():
    SHEETS["sv_" + _k] = dict(body=_v["body"], frame=96, anims=hero_art.hero_animations, build=spiderverse.builder(_k),
                              mats=(lambda k=_k: spiderverse.VARIANTS[k]["mats"]), density=VS_DENSITY)
    STILLS["sv_" + _k] = (_v["body"], spiderverse.builder(_k), (lambda k=_k: spiderverse.VARIANTS[k]["mats"]))

DRONE_STATES = [(0, "green", 0), (1, "green", 0), (0, "red", 0), (1, "red", 0), (0, "white", 0), (0, "dead", 35)]


def plan(key):
    """[(anim, fps, loop, [(pose, blend_info)])] with in-betweens; fps scaled so durations are unchanged."""
    spec = SHEETS[key]
    out = []
    for name, fps, loop, poses in spec["anims"]():
        frames = expand_anim(spec["body"], poses, loop, INBETWEENS, spec["frame"])
        new_fps = fps * len(frames) / max(1, len(poses))
        out.append((name, round(new_fps, 2), loop, frames))
    return out


_cache = {}


def _renderer(key):
    if key not in _cache:
        spec = SHEETS[key]
        _cache[key] = VolumeRenderer(spec["frame"], spec.get("density", DENSITY), spec["mats"]())
    return _cache[key]


def render_frame(args):
    key, anim, pose, blend = args
    spec = SHEETS[key]
    R = _renderer(key)
    body = spec["body"]

    def one(p):
        sk = Skeleton(body, p, spec["frame"])
        return R.render(spec["build"](sk, body), vc.LAYERS, dim=vc.DIM)

    if blend is not None and anim in BLUR_ANIMS:
        a, b, t = blend
        acc = None
        samples = (t - 0.22, t - 0.08, t + 0.08, t + 0.22)
        for s in samples:
            buf = one(lerp_pose(a, b, min(1.0, max(0.0, s))))
            acc = buf if acc is None else acc + buf
        img = R.to_image(acc / len(samples))
    else:
        img = R.to_image(one(pose))
    if pose.flip_v:
        # ceiling crawl is posed on all fours and flipped so the hands and feet grip the ceiling
        img = img.transpose(Image.FLIP_TOP_BOTTOM)
    return img.tobytes(), img.size


def render_drone(state):
    mats = vc.drone_materials()
    R = VolumeRenderer(64, DENSITY, mats)
    prims, tilt = vc.build_drone(state)
    img = R.to_image(R.render(prims, vc.LAYERS))
    if tilt:
        img = img.rotate(-tilt, resample=Image.BICUBIC)
    return img.tobytes(), img.size


def atlas(frames, px):
    cols = max(1, min(len(frames), MAX_W // px))
    rows = math.ceil(len(frames) / cols)
    out = Image.new("RGBA", (cols * px, rows * px), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, ((i % cols) * px, (i // cols) * px))
    return out, cols, rows


def build(out_dir, workers=None):
    db = {}
    jobs, layout = [], {}
    for key in SHEETS:
        man, start = {}, 0
        for name, fps, loop, frames in plan(key):
            man[name] = [start, len(frames), fps, loop]
            for pose, blend in frames:
                jobs.append((key, name, pose, blend))
            start += len(frames)
        layout[key] = (man, start)
    with ProcessPoolExecutor(max_workers=workers or os.cpu_count()) as ex:
        results = list(ex.map(render_frame, jobs, chunksize=4))
        drone = list(ex.map(render_drone, DRONE_STATES))
    i = 0
    for key, (man, count) in layout.items():
        imgs = [Image.frombytes("RGBA", results[i + k][1], results[i + k][0]) for k in range(count)]
        i += count
        px = imgs[0].width
        sheet, cols, rows = atlas(imgs, px)
        sheet.save(os.path.join(out_dir, key + ".png"), optimize=True)
        units = SHEETS[key]["frame"]
        db[key] = dict(frame=px, cols=cols, rows=rows, count=count, scale=round(units * 0.5 / px, 5),
                       feet=round(6.0 * px / units, 3), anims=man)
    imgs = [Image.frombytes("RGBA", s, b) for b, s in drone]
    px = imgs[0].width
    sheet, cols, rows = atlas(imgs, px)
    sheet.save(os.path.join(out_dir, "drone.png"), optimize=True)
    db["drone"] = dict(frame=px, cols=cols, rows=rows, count=len(imgs), scale=round(32.0 / px, 5),
                       feet=round(6.0 * px / 64, 3),
                       anims={"fly": [0, 2, 12, True], "telegraph": [2, 2, 10, True], "hurt": [4, 1, 8, False],
                              "ko": [5, 1, 4, False]})
    return db


def write_db(db, path):
    lines = ["class_name SpriteDB", "extends RefCounted",
             "## Generated by tools/art/build_all.py - do not edit by hand.",
             "## Each sheet is a grid atlas (cols x rows) of square frames; anims map to",
             "## [first_frame, frame_count, fps, loop]. scale = display scale, feet = px from frame bottom to the feet.", "",
             "const SHEETS: Dictionary = {"]
    for key, e in db.items():
        anims = ", ".join('"%s": [%d, %d, %s, %s]' % (a, v[0], v[1], repr(float(v[2])), "true" if v[3] else "false")
                          for a, v in e["anims"].items())
        lines.append('\t"%s": {"path": "res://assets/sprites/characters/%s.png", "frame": %d, "cols": %d, "rows": %d, '
                     '"count": %d, "scale": %s, "feet": %s, "anims": {%s}},'
                     % (key, key, e["frame"], e["cols"], e["rows"], e["count"], repr(e["scale"]), repr(e["feet"]), anims))
    lines.append("}")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
