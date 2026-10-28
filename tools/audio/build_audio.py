"""Synthesizes all original music loops and sound effects (22.05 kHz mono 16-bit WAV).

Usage: python3 tools/audio/build_audio.py
"""
import os
import wave
import numpy as np

SR = 22050
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
rng = np.random.default_rng(7)


def save(name, sig, folder="audio"):
    sig = np.asarray(sig, dtype=np.float64)
    peak = np.max(np.abs(sig)) or 1.0
    sig = sig / peak * 0.89
    data = (sig * 32767).astype(np.int16)
    path = os.path.join(ROOT, "assets", folder, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, s=0.6, r=0.05):
    out = np.ones(n) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = min(ai, n)
    out[:ai] = np.linspace(0, 1, ai) if ai else out[:ai]
    di = min(di, n - ai)
    out[ai:ai + di] = np.linspace(1, s, di) if di else out[ai:ai + di]
    if ri and n > ri:
        out[-ri:] *= np.linspace(1, 0, ri)
    return out


def osc(kind, freq, dur, duty=0.5):
    t = t_axis(dur)
    ph = (freq * t) % 1.0
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "saw":
        return 2 * ph - 1
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    return np.sin(2 * np.pi * freq * t)


def note_freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def lowpass(sig, k=0.15):
    out = np.empty_like(sig)
    acc = 0.0
    for i, v in enumerate(sig):
        acc += k * (v - acc)
        out[i] = acc
    return out


def fast_lowpass(sig, width=6):
    kernel = np.ones(width) / width
    return np.convolve(sig, kernel, mode="same")


# ------------------------------------------------------------------ drums
def kick(dur=0.25):
    t = t_axis(dur)
    f = 120 * np.exp(-t * 28) + 42
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)


def snare(dur=0.2):
    t = t_axis(dur)
    return (rng.uniform(-1, 1, t.size) * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 22)


def hat(dur=0.06):
    t = t_axis(dur)
    n = rng.uniform(-1, 1, t.size)
    n = n - fast_lowpass(n, 3)
    return n * np.exp(-t * 70)


# ------------------------------------------------------------------ song builder
SCALES = {"minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10], "major": [0, 2, 4, 5, 7, 9, 11],
          "phrygian": [0, 1, 3, 5, 7, 8, 10], "harm": [0, 2, 3, 5, 7, 8, 11]}


def song(bpm, bars, root, scale, progression, lead_kind="square", bass_kind="tri", drum_style="rock", seed=1,
         lead_vol=0.32, bass_vol=0.42, pad=True, swing=0.0, intensity=1.0):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    step = beat / 4
    total = int(SR * beat * 4 * bars)
    mix = np.zeros(total + SR)
    sc = SCALES[scale]

    def put(sig, start):
        i = int(start * SR)
        j = min(i + sig.size, mix.size)
        mix[i:j] += sig[:j - i]

    # motif: 2-bar phrase repeated with variation
    motif = []
    for s in range(32):
        if r.random() < 0.55 or s % 8 == 0:
            deg = int(r.integers(0, 7)) + (7 if r.random() < 0.25 else 0)
            ln = int(r.choice([1, 2, 2, 3, 4]))
            motif.append((s, deg, ln))
    for bar in range(bars):
        chord = progression[bar % len(progression)]
        bar_t = bar * beat * 4
        # bass
        for k in range(8):
            deg = chord if k % 4 != 3 else chord + 4
            m = root - 12 + sc[deg % 7] + 12 * (deg // 7)
            dur = step * 2 * 0.92
            sig = osc(bass_kind, note_freq(m), dur) * env(int(dur * SR), 0.004, 0.08, 0.7, 0.03)
            put(sig * bass_vol, bar_t + k * step * 2)
        # pad chord
        if pad:
            dur = beat * 4
            sig = np.zeros(int(dur * SR))
            for iv in (0, 2, 4):
                deg = chord + iv
                m = root + sc[deg % 7] + 12 * (deg // 7)
                sig += osc("saw", note_freq(m), dur) * 0.33 + osc("saw", note_freq(m) * 1.004, dur) * 0.33
            sig = fast_lowpass(sig, 18) * env(sig.size, 0.25, 0.4, 0.8, 0.3)
            put(sig * 0.10 * intensity, bar_t)
        # lead (skip first bars as intro, rest every other phrase varied)
        if bar >= 2:
            phrase_off = (bar % 2) * 16
            for s, deg, ln in motif:
                if phrase_off <= s < phrase_off + 16:
                    d2 = deg + (2 if (bar // 4) % 2 == 1 and s % 4 == 0 else 0)
                    m = root + 12 + sc[d2 % 7] + 12 * (d2 // 7)
                    dur = step * ln * 0.9
                    sw = swing * step if s % 2 == 1 else 0.0
                    sig = osc(lead_kind, note_freq(m), dur, duty=0.25) * env(int(dur * SR), 0.004, 0.06, 0.55, 0.04)
                    sig += osc("sin", note_freq(m) * 2, dur) * 0.12 * env(int(dur * SR), 0.004, 0.05, 0.3, 0.04)
                    put(sig * lead_vol, bar_t + (s - phrase_off) * step + sw)
        # drums
        for k in range(16):
            tt = bar_t + k * step + (swing * step if k % 2 == 1 else 0)
            if drum_style == "rock":
                if k in (0, 8, 10):
                    put(kick() * 0.9, tt)
                if k in (4, 12):
                    put(snare() * 0.55, tt)
                if k % 2 == 0:
                    put(hat() * 0.22, tt)
            elif drum_style == "chase":
                if k % 4 == 0 or k == 14:
                    put(kick() * 0.9, tt)
                if k in (4, 12):
                    put(snare() * 0.6, tt)
                put(hat() * (0.25 if k % 2 == 0 else 0.14), tt)
            elif drum_style == "tense":
                if k in (0, 6, 10):
                    put(kick() * 0.85, tt)
                if k == 12:
                    put(snare() * 0.5, tt)
                if k % 4 == 2:
                    put(hat() * 0.2, tt)
            elif drum_style == "epic":
                if k in (0, 3, 8, 11):
                    put(kick() * 1.0, tt)
                if k in (4, 12):
                    put(snare() * 0.7, tt)
                if k in (14, 15) and bar % 4 == 3:
                    put(snare() * 0.5, tt)
                put(hat() * 0.2, tt)
            elif drum_style == "calm":
                if k == 0:
                    put(kick() * 0.6, tt)
                if k == 8:
                    put(snare() * 0.3, tt)
    out = mix[:total]
    fade = int(0.01 * SR)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def jingle(notes, step, kind="square"):
    sig = np.zeros(int(SR * (len(notes) * step + 1.2)))
    for i, m in enumerate(notes):
        if m is None:
            continue
        dur = step * (3 if i == len(notes) - 1 else 0.95)
        s = osc(kind, note_freq(m), dur, 0.3) * env(int(dur * SR), 0.005, 0.1, 0.6, 0.2)
        s += osc("tri", note_freq(m - 12), dur) * 0.5 * env(int(dur * SR), 0.005, 0.1, 0.6, 0.2)
        a = int(i * step * SR)
        sig[a:a + s.size] += s[: sig.size - a]
    return sig


def build_music():
    save("title_theme", song(112, 16, 57, "dorian", [0, 5, 3, 4], seed=3, drum_style="calm", lead_kind="tri"), "music")
    save("ch1_streets", song(122, 16, 55, "dorian", [0, 3, 4, 3], seed=11, drum_style="rock", swing=0.18), "music")
    save("ch2_chase", song(150, 16, 52, "minor", [0, 5, 6, 4], seed=21, drum_style="chase", lead_kind="saw", lead_vol=0.24), "music")
    save("ch3_ambush", song(104, 16, 50, "phrygian", [0, 1, 0, 5], seed=31, drum_style="tense", lead_kind="tri"), "music")
    save("ch4_rescue", song(128, 16, 53, "harm", [0, 3, 5, 4], seed=41, drum_style="tense", lead_kind="square"), "music")
    save("ch5_showdown", song(146, 16, 50, "harm", [0, 5, 3, 4], seed=51, drum_style="epic", lead_kind="saw", lead_vol=0.26, intensity=1.4), "music")
    save("boss_theme", song(158, 8, 48, "phrygian", [0, 1, 5, 4], seed=61, drum_style="epic", lead_kind="saw", lead_vol=0.25), "music")
    save("victory_jingle", jingle([60, 64, 67, 72, None, 67, 72, 76], 0.13), "music")
    save("defeat_jingle", jingle([64, 63, 62, 61, None, 55], 0.22, kind="tri"), "music")


def build_sfx():
    t = t_axis(0.9)
    boom = rng.uniform(-1, 1, t.size)
    boom = fast_lowpass(boom, 30) * 3.0 * np.exp(-t * 5) + np.sin(2 * np.pi * (60 * np.exp(-t * 3)) * t) * np.exp(-t * 4)
    save("explosion", boom)
    t = t_axis(0.5)
    sweep = np.sin(2 * np.pi * np.cumsum(300 + 900 * t) / SR) * 0.3 + rng.uniform(-1, 1, t.size) * 0.5
    save("whoosh", fast_lowpass(sweep, 8) * np.sin(np.pi * t / 0.5))
    t = t_axis(0.18)
    save("gunshot", (rng.uniform(-1, 1, t.size) * np.exp(-t * 30) + np.sin(2 * np.pi * 120 * t) * np.exp(-t * 40)))
    t = t_axis(0.3)
    save("energy_shot", np.sin(2 * np.pi * np.cumsum(1400 - 3000 * t) / SR) * np.exp(-t * 9) * (0.7 + 0.3 * osc("square", 40, 0.3)))
    save("pickup", jingle([72, 76, 79, 84], 0.05) [: int(SR * 0.5)])
    save("checkpoint", jingle([67, 72, 79], 0.08)[: int(SR * 0.6)])
    t = t_axis(0.08)
    save("menu_move", np.sin(2 * np.pi * 880 * t) * np.exp(-t * 40))
    t = t_axis(0.16)
    save("menu_select", (np.sin(2 * np.pi * 660 * t) + np.sin(2 * np.pi * 990 * t)) * np.exp(-t * 18))
    t = t_axis(0.25)
    save("dodge", fast_lowpass(rng.uniform(-1, 1, t.size), 5) * np.sin(np.pi * t / 0.25))
    t = t_axis(0.5)
    metal = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * (6 + i * 3)) for i, f in enumerate((520, 1310, 2100, 3400)))
    save("cage_break", metal + rng.uniform(-1, 1, t.size) * np.exp(-t * 20))
    # cackle: pitched vowel bursts
    sig = np.zeros(int(SR * 1.2))
    for k in range(6):
        tt = t_axis(0.13)
        f = 330 + k * 25 + 60 * np.sin(2 * np.pi * 6 * tt)
        burst = (osc("saw", 1, 0.13) * 0)  # placeholder shape
        burst = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.6 + np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.25
        burst *= np.sin(np.pi * tt / 0.13)
        a = int(k * 0.17 * SR)
        sig[a:a + burst.size] += burst
    save("goblin_laugh", fast_lowpass(sig, 4))
    t = t_axis(0.12)
    save("land", fast_lowpass(rng.uniform(-1, 1, t.size), 12) * np.exp(-t * 35))
    t = t_axis(0.22)
    save("web_zip", np.sin(2 * np.pi * np.cumsum(2400 - 6000 * t) / SR) * np.exp(-t * 12) * 0.6 + rng.uniform(-1, 1, t.size) * 0.2 * np.exp(-t * 20))
    t = t_axis(0.4)
    save("shock", osc("square", 60, 0.4) * rng.uniform(0.3, 1, t.size) * np.exp(-t * 6))
    t = t_axis(0.35)
    save("heavy_hit", fast_lowpass(rng.uniform(-1, 1, t.size), 10) * np.exp(-t * 14) * 2 + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 12))


if __name__ == "__main__":
    build_sfx()
    build_music()
    print("audio built")
