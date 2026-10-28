"""Builds a looping README GIF from a Godot --write-movie PNG frame sequence.

Usage: python3 tools/capture/make_gif.py <frames_dir> <out.gif> [--start N] [--count N] [--width 480] [--step 2]
"""
import argparse
import glob
import os
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("frames")
ap.add_argument("out")
ap.add_argument("--start", type=int, default=10)
ap.add_argument("--count", type=int, default=170)
ap.add_argument("--width", type=int, default=480)
ap.add_argument("--step", type=int, default=2)
a = ap.parse_args()

files = sorted(glob.glob(os.path.join(a.frames, "*.png")))[a.start:a.start + a.count:a.step]
if not files:
    raise SystemExit("no frames found")
frames = []
for f in files:
    im = Image.open(f).convert("RGB")
    h = int(im.height * a.width / im.width)
    frames.append(im.resize((a.width, h), Image.LANCZOS))
# shared adaptive palette keeps colours stable across frames
pal = frames[len(frames) // 2].quantize(colors=200, method=Image.Quantize.MEDIANCUT)
q = [fr.quantize(palette=pal, dither=Image.Dither.NONE) for fr in frames]
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
q[0].save(a.out, save_all=True, append_images=q[1:], duration=int(1000 / 30 * a.step), loop=0, optimize=True)
print(f"{a.out}: {len(q)} frames, {os.path.getsize(a.out) / 1024:.0f} KB, {len(q) * a.step / 30:.1f}s")
