"""Volumetric 'pre-rendered 3D' character renderer for Web-Slinger: Night Patrol.

Characters are still posed with the forward-kinematics Skeleton from char_renderer, but instead of
flat cel shapes every body part is built from tapered capsules and ellipsoids that are rendered as
3D height fields (orthographic side camera):

  * primitives inside one group (torso + muscles, a limb, the head) are blended with a smooth-max,
    so muscles and joints flow into each other organically;
  * groups are depth-composited, so the front arm passes in front of the chest and the back leg
    sits behind the hips;
  * each pixel gets an analytic surface normal, then key light + hemisphere ambient + rim light +
    Blinn-Phong specular + screen-space ambient occlusion are applied per material;
  * materials can carry procedural patterns (suit web seams, fabric weave, scales) that wrap
    around the 3D surface, and emissive parts glow;
  * frames are supersampled and box-filtered with premultiplied alpha for clean edges, and fast
    strike frames can be rendered with true motion blur (several sub-poses accumulated).

Everything is original procedural art. Units are the skeleton's frame units (the old 96 px frame);
`scale` maps them to output pixels.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

from char_renderer import Skeleton, up, down, add

SS = 2                         # supersampling per output pixel
LIGHT = np.array([-0.42, -0.62, 0.66])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
VIEW = np.array([0.0, 0.0, 1.0])
HALF = (LIGHT + VIEW) / np.linalg.norm(LIGHT + VIEW)
RIM_DIR = np.array([0.78, -0.62])
RIM_DIR = RIM_DIR / np.linalg.norm(RIM_DIR)


def rgb(h: str):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], dtype=np.float64) / 255.0


@dataclass
class Material:
    color: np.ndarray
    spec: float = 0.25          # specular strength
    shine: float = 18.0         # specular exponent
    rim: float = 0.55           # rim light strength
    wrap: float = 0.0           # diffuse wrap (skin / cloth softness)
    sss: np.ndarray | None = None   # shadow tint for skin (subsurface feel)
    emissive: bool = False
    pattern: object = None      # callable(ctx) -> (albedo, normal_bump or None)
    sheen: float = 0.0          # grazing-angle fabric sheen


@dataclass
class Prim:
    kind: str                   # "cap" | "ell"
    a: tuple
    b: tuple = (0.0, 0.0)
    ra: float = 1.0
    rb: float = 1.0
    za: float = 0.0
    zb: float = 0.0
    group: str = "body"
    mat: str = "base"
    flat: float = 1.0           # depth squash of the cross-section
    angle: float = 0.0          # ellipsoid rotation (radians)
    rx: float = 1.0
    ry: float = 1.0
    data: dict = field(default_factory=dict)


class Ctx:
    """Per-pixel data handed to material patterns (all arrays are 1-D over the covered pixels)."""

    def __init__(self, **kw):
        self.__dict__.update(kw)


# ------------------------------------------------------------------ primitive evaluation
def _eval_cap(p: Prim, X, Y):
    ax, ay = p.a
    bx, by = p.b
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    if l2 < 1e-9:
        t = np.zeros_like(X)
    else:
        t = np.clip(((X - ax) * dx + (Y - ay) * dy) / l2, 0.0, 1.0)
    qx, qy = ax + dx * t, ay + dy * t
    r = p.ra + (p.rb - p.ra) * t
    ox, oy = X - qx, Y - qy
    d2 = ox * ox + oy * oy
    inside = d2 < r * r
    s = np.sqrt(np.maximum(r * r - d2, 0.0))
    zc = p.za + (p.zb - p.za) * t
    h = zc + s * p.flat
    n = np.stack([ox * p.flat, oy * p.flat, s + 1e-6], -1)
    ln = math.sqrt(l2) or 1.0
    # local coordinates: u along the bone (frame units), v lateral (-1 back .. +1 front of bone)
    tx, ty = dx / ln, dy / ln
    lat = (ox * -ty + oy * tx) / np.maximum(r, 1e-6)
    return inside, h, n, t * ln, lat, r


def _eval_ell(p: Prim, X, Y):
    cx, cy = p.a
    ca, sa = math.cos(p.angle), math.sin(p.angle)
    lx = (X - cx) * ca + (Y - cy) * sa
    ly = -(X - cx) * sa + (Y - cy) * ca
    q = (lx / p.rx) ** 2 + (ly / p.ry) ** 2
    inside = q < 1.0
    s = np.sqrt(np.maximum(1.0 - q, 0.0))
    rz = p.ra * p.flat
    h = p.za + rz * s
    # gradient of the implicit ellipsoid
    gx, gy = lx / (p.rx * p.rx), ly / (p.ry * p.ry)
    gz = s / max(rz, 1e-6)
    nx = gx * ca - gy * sa
    ny = gx * sa + gy * ca
    n = np.stack([nx, ny, gz + 1e-6], -1)
    return inside, h, n, lx, ly / p.ry, p.ry


# ------------------------------------------------------------------ renderer
class VolumeRenderer:
    def __init__(self, frame: int, scale: float, materials: dict):
        self.frame = frame
        self.scale = scale
        self.out = int(round(frame * scale))
        self.res = self.out * SS
        self.materials = materials
        k = 1.0 / (scale * SS)
        coords = (np.arange(self.res) + 0.5) * k
        self.X, self.Y = np.meshgrid(coords, coords)

    def render(self, prims: list[Prim], layers: list[str], blend_k: float = 1.1, outline: float = 0.55,
               dim: dict | None = None) -> np.ndarray:
        """Returns premultiplied float RGBA (res x res x 4) at supersampled resolution.
        Groups are painted in `layers` order (back to front); primitives inside a group are depth-blended."""
        R = self.res
        groups: dict[str, dict] = {}
        inv = 1.0 / (self.scale * SS)
        for idx, p in enumerate(prims):
            if p.kind == "cap":
                ext = max(p.ra, p.rb)
                x0, x1 = min(p.a[0], p.b[0]) - ext, max(p.a[0], p.b[0]) + ext
                y0, y1 = min(p.a[1], p.b[1]) - ext, max(p.a[1], p.b[1]) + ext
            else:
                ext = max(p.rx, p.ry)
                x0, x1, y0, y1 = p.a[0] - ext, p.a[0] + ext, p.a[1] - ext, p.a[1] + ext
            i0, i1 = max(0, int(y0 / inv) - 1), min(R, int(y1 / inv) + 2)
            j0, j1 = max(0, int(x0 / inv) - 1), min(R, int(x1 / inv) + 2)
            if i0 >= i1 or j0 >= j1:
                continue
            X, Y = self.X[i0:i1, j0:j1], self.Y[i0:i1, j0:j1]
            inside, h, n, u, v, r = (_eval_cap if p.kind == "cap" else _eval_ell)(p, X, Y)
            if not inside.any():
                continue
            g = groups.get(p.group)
            if g is None:
                g = {"w": np.zeros((R, R)), "n": np.zeros((R, R, 3)), "best": np.full((R, R), -1e9),
                     "pid": np.full((R, R), -1, dtype=np.int32), "u": np.zeros((R, R)), "v": np.zeros((R, R))}
                groups[p.group] = g
            sl = (slice(i0, i1), slice(j0, j1))
            w = np.where(inside, np.exp(np.clip(h / blend_k, -60, 60)), 0.0)
            nn = n / np.linalg.norm(n, axis=-1, keepdims=True)
            g["w"][sl] += w
            g["n"][sl] += nn * w[..., None]
            better = inside & (h > g["best"][sl])
            g["best"][sl] = np.where(better, h, g["best"][sl])
            g["pid"][sl] = np.where(better, idx, g["pid"][sl])
            g["u"][sl] = np.where(better, u, g["u"][sl])
            g["v"][sl] = np.where(better, v, g["v"][sl])

        H = np.full((R, R), -1e9)
        N = np.zeros((R, R, 3))
        PID = np.full((R, R), -1, dtype=np.int32)
        U = np.zeros((R, R))
        V = np.zeros((R, R))
        GID = np.full((R, R), -1, dtype=np.int32)
        order = [g for g in layers if g in groups] + [g for g in groups if g not in layers]
        for gi, name in enumerate(order):
            g = groups[name]
            cov = g["w"] > 0
            hs = np.where(cov, blend_k * np.log(np.maximum(g["w"], 1e-300)), -1e9)
            take = cov
            H = np.where(take, hs, H)
            N = np.where(take[..., None], g["n"], N)
            PID = np.where(take, g["pid"], PID)
            U = np.where(take, g["u"], U)
            V = np.where(take, g["v"], V)
            GID = np.where(take, gi, GID)

        mask = PID >= 0
        img = np.zeros((R, R, 4))
        if not mask.any():
            return img
        N = N / np.maximum(np.linalg.norm(N, axis=-1, keepdims=True), 1e-9)

        # screen-space ambient occlusion from the height field
        Hm = np.where(mask, H, np.nan)
        base = np.nanmin(Hm) - 4.0
        Hf = np.where(mask, H, base)
        blur = _gauss(Hf, 2.2 * self.scale * SS)
        occ = np.clip(blur - Hf, 0.0, None)
        ao = np.clip(1.0 - occ * 0.075, 0.35, 1.0)
        # contact darkening along depth discontinuities between groups
        edge = _group_edges(GID)
        ao = ao * np.where(edge, 0.62, 1.0)

        idx = np.nonzero(mask)
        n = N[idx]
        pid = PID[idx]
        albedo = np.zeros((len(pid), 3))
        spec_k = np.zeros(len(pid))
        shine = np.ones(len(pid))
        rim_k = np.zeros(len(pid))
        wrap = np.zeros(len(pid))
        sss = np.zeros((len(pid), 3))
        sheen = np.zeros(len(pid))
        emis = np.zeros(len(pid), dtype=bool)
        for k in np.unique(pid):
            sel = pid == k
            p = prims[k]
            m = self.materials[p.mat]
            col = np.broadcast_to(m.color, (sel.sum(), 3)).copy()
            nsel = n[sel]
            if m.pattern is not None:
                ctx = Ctx(u=U[idx][sel], v=V[idx][sel], x=self.X[idx][sel], y=self.Y[idx][sel], n=nsel, prim=p,
                          color=col)
                res = m.pattern(ctx)
                col = res[0]
                if len(res) > 1 and res[1] is not None:
                    nb = nsel + res[1]
                    nsel = nb / np.linalg.norm(nb, axis=-1, keepdims=True)
                    n[sel] = nsel
                if len(res) > 2 and res[2] is not None:
                    e = res[2]
                    emis_sel = emis[sel]
                    emis_sel |= e
                    emis[sel] = emis_sel
            albedo[sel] = col
            spec_k[sel] = m.spec
            shine[sel] = m.shine
            rim_k[sel] = m.rim
            wrap[sel] = m.wrap
            sheen[sel] = m.sheen
            sss[sel] = m.sss if m.sss is not None else 0.0
            if m.emissive:
                emis[sel] = True

        ndl = n @ LIGHT
        diff = np.clip((ndl + wrap) / (1.0 + wrap), 0.0, 1.0)
        # hemisphere ambient: cool sky from above, warm bounce from below
        sky = np.array([0.42, 0.47, 0.62])
        ground = np.array([0.30, 0.24, 0.22])
        hemi = 0.5 - 0.5 * n[:, 1]
        amb = ground[None, :] + (sky - ground)[None, :] * hemi[:, None]
        key = np.array([1.05, 0.98, 0.90])
        a_o = ao[idx]
        lit = albedo * (amb * a_o[:, None] * 0.62 + diff[:, None] * key[None, :] * 1.12 * (0.55 + 0.45 * a_o[:, None]))
        # subsurface tint in the terminator/shadow for skin
        lit += sss * (1.0 - diff)[:, None] * 0.35 * a_o[:, None]
        spec = np.clip(n @ HALF, 0.0, 1.0) ** shine * spec_k
        lit += spec[:, None] * key[None, :] * a_o[:, None]
        fres = (1.0 - np.clip(n[:, 2], 0.0, 1.0)) ** 2.4
        rim = fres * np.clip(n[:, 0] * RIM_DIR[0] + n[:, 1] * RIM_DIR[1], 0.0, 1.0) * rim_k
        lit += rim[:, None] * np.array([0.55, 0.70, 1.0])[None, :]
        lit += (sheen * fres)[:, None] * albedo * 0.8
        # silhouette darkening keeps characters readable on busy backgrounds
        lit *= (1.0 - outline * np.clip(1.0 - n[:, 2] * 3.2, 0.0, 1.0) * 0.55)[:, None]
        if dim:
            gid = GID[idx]
            for gi, name in enumerate(order):
                if name in dim:
                    lit[gid == gi] *= dim[name]
        lit = np.where(emis[:, None], albedo * 1.15, lit)
        lit = _tonemap(lit)

        img[idx[0], idx[1], :3] = lit
        img[idx[0], idx[1], 3] = 1.0
        # emissive glow halo
        if emis.any():
            glow = np.zeros((R, R, 3))
            glow[idx[0][emis], idx[1][emis]] = albedo[emis]
            gl = np.stack([_gauss(glow[..., c], 2.4 * self.scale * SS) for c in range(3)], -1) * 1.8
            ga = np.clip(gl.max(-1), 0.0, 0.85)
            add_rgb = np.clip(gl, 0.0, 1.0)
            # composite glow under/over existing pixels (premultiplied add)
            img[..., :3] = img[..., :3] * img[..., 3:4] + add_rgb * (1.0 - img[..., 3:4]) * ga[..., None] * 0.9 \
                + add_rgb * img[..., 3:4] * 0.18
            img[..., 3] = np.clip(img[..., 3] + ga * (1.0 - img[..., 3]), 0.0, 1.0)
            return img
        img[..., :3] *= img[..., 3:4]
        return img

    def to_image(self, premul: np.ndarray) -> Image.Image:
        R, o = self.res, self.out
        a = premul.reshape(o, SS, o, SS, 4).mean(axis=(1, 3))
        alpha = a[..., 3:4]
        col = np.where(alpha > 1e-4, a[..., :3] / np.maximum(alpha, 1e-4), 0.0)
        out = np.concatenate([col, alpha], -1)
        return Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def _tonemap(c):
    # gentle filmic shoulder + slight contrast
    c = np.clip(c, 0.0, None)
    t = c * (1.0 + c / 4.0) / (1.0 + c)
    return np.clip(t * 1.06, 0.0, 1.0)


def _gauss(a, sigma):
    if sigma < 0.5:
        return a
    rad = int(sigma * 2.5)
    xs = np.arange(-rad, rad + 1)
    k = np.exp(-(xs * xs) / (2 * sigma * sigma))
    k /= k.sum()
    return _conv1d(_conv1d(a, k, 0), k, 1)


def _conv1d(a, k, axis):
    rad = len(k) // 2
    pad = [(0, 0)] * a.ndim
    pad[axis] = (rad, rad)
    ap = np.pad(a, pad, mode="edge")
    out = np.zeros_like(a)
    n = a.shape[axis]
    for i, w in enumerate(k):
        sl = [slice(None)] * a.ndim
        sl[axis] = slice(i, i + n)
        out += ap[tuple(sl)] * w
    return out


def _group_edges(gid):
    """Pixels of a group that touch a group painted in front of it (contact shadow line)."""
    e = np.zeros(gid.shape, dtype=bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (0, 2), (-2, 0), (0, -2)):
        g2 = np.roll(gid, (dy, dx), (0, 1))
        e |= (gid >= 0) & (g2 > gid)
    return e


# ------------------------------------------------------------------ pose interpolation
def lerp_pose(p0, p1, t):
    from char_renderer import Pose

    def L(a, b):
        return a + (b - a) * t

    def LT(a, b):
        return (L(a[0], b[0]), L(a[1], b[1]))

    pel = None
    if p0.pelvis is not None and p1.pelvis is not None:
        pel = LT(p0.pelvis, p1.pelvis)
    elif t < 0.5:
        pel = p0.pelvis
    else:
        pel = p1.pelvis
    ex = dict(p0.extras if t < 0.5 else p1.extras)
    for k in set(p0.extras) & set(p1.extras):
        a, b = p0.extras[k], p1.extras[k]
        if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
            ex[k] = L(a, b)
    return Pose(torso=L(p0.torso, p1.torso), head=L(p0.head, p1.head), arm_f=LT(p0.arm_f, p1.arm_f),
                arm_b=LT(p0.arm_b, p1.arm_b), leg_f=LT(p0.leg_f, p1.leg_f), leg_b=LT(p0.leg_b, p1.leg_b),
                rot=L(p0.rot, p1.rot), grounded=p0.grounded if t < 0.5 else p1.grounded, pelvis=pel,
                dx=L(p0.dx, p1.dx), dy=L(p0.dy, p1.dy), flip_v=p0.flip_v, extras=ex)


def expand_anim(body, poses, loop, k, frame):
    """Insert k in-between poses between keys (wrapping for loops). Returns [(pose, (a, b, t) | None)]
    so callers can motion-blur in-betweens by sampling around t."""
    if len(poses) < 2 or k <= 0:
        return [(p, None) for p in poses]
    out = []
    n = len(poses)
    last = n if loop else n - 1
    for i in range(last):
        a, b = poses[i], poses[(i + 1) % n]
        out.append((a, None))
        for j in range(1, k + 1):
            t = j / (k + 1)
            out.append((lerp_pose(a, b, t), (a, b, t)))
    if not loop:
        out.append((poses[-1], None))
    return out
