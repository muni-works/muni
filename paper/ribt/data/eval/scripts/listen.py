"""Shared listening-set tooling: validate, loudness-level and limit every take.

Every take that goes into a listening set passes through `prepare()`:
  1. validate the RAW take (before any gain) and reject it, never ship it, if
     - any NaN/inf,
     - DC offset |mean| > 0.01,
     - more than 0.1% of samples at/above full scale (|x| >= 0.999: railed),
     - RMS below 1e-3 (-60 dBFS: near-silence),
     - duration differs from the reference by more than 2%;
  2. level to TARGET_LUFS (ITU-R BS.1770 via pyloudnorm; RMS fallback);
  3. peak-limit to a -1 dBFS ceiling (min-filter + box-smoothed gain, so the
     gain never exceeds what any sample needs), then trim the whole take if its
     4x-oversampled true peak still exceeds the ceiling.
Peak normalization is gone: one spike used to make a whole take quiet.

`Report` collects one row per take (raw and final LUFS / RMS / peak, DC,
verdict) and writes report.txt next to the set.
"""
import os

import numpy as np
from scipy.ndimage import minimum_filter1d, uniform_filter1d
from scipy.signal import resample_poly

SR = 24000
TARGET_LUFS = -23.0
CEIL_DB = -1.0
BEEP_LUFS = TARGET_LUFS - 10.0  # markers clearly quieter than speech
RAIL, RAIL_FRAC, DC_MAX, RMS_MIN, DUR_TOL = 0.999, 1e-3, 0.01, 1e-3, 0.02

try:
    import pyloudnorm

    _METER = pyloudnorm.Meter(SR)
    LOUDNESS = "BS.1770 LUFS (pyloudnorm)"
except ImportError:  # RMS fallback: dBFS of the RMS, offset so -23 means roughly the same level
    _METER = None
    LOUDNESS = "RMS dBFS - 3 (pyloudnorm missing)"


def db(x):
    return 20 * np.log10(max(float(x), 1e-12))


def lufs(x):
    if _METER is not None and len(x) >= int(0.4 * SR):
        v = _METER.integrated_loudness(x)
        if np.isfinite(v):
            return float(v)
    return db(np.sqrt(np.mean(x**2))) - 3.0


def true_peak(x):
    return float(np.abs(resample_poly(x, 4, 1)).max()) if len(x) else 0.0


def stats(x):
    return dict(lufs=lufs(x), rms_db=db(np.sqrt(np.mean(x**2))), peak_db=db(np.abs(x).max()), tp_db=db(true_peak(x)), dc=float(np.mean(x)))


def validate(x, ref_len=None):
    """List of failure reasons for a raw take (empty = valid)."""
    bad = []
    if not np.all(np.isfinite(x)):
        return ["nan/inf"]
    if len(x) == 0:
        return ["empty"]
    if abs(x.mean()) > DC_MAX:
        bad.append(f"dc {x.mean():+.3f}")
    rail = float(np.mean(np.abs(x) >= RAIL))
    if rail > RAIL_FRAC:
        bad.append(f"railed {100 * rail:.2f}%")
    rms = float(np.sqrt(np.mean(x**2)))
    if rms < RMS_MIN:
        bad.append(f"silent rms {db(rms):.1f} dBFS")
    if ref_len and abs(len(x) - ref_len) > DUR_TOL * ref_len:
        bad.append(f"duration {len(x) / SR:.2f}s vs ref {ref_len / SR:.2f}s")
    return bad


def limit(x, ceil_db=CEIL_DB, win_ms=5.0):
    c = 10 ** (ceil_db / 20)
    need = np.minimum(1.0, c / np.maximum(np.abs(x), 1e-12))
    w = max(3, int(win_ms * 1e-3 * SR) | 1)
    g = uniform_filter1d(minimum_filter1d(need, w, mode="nearest"), w, mode="nearest")
    y = x * np.minimum(g, need)
    tp = true_peak(y)
    return y * (c / tp) if tp > c else y


def level(x, target=TARGET_LUFS):
    return limit(x * 10 ** ((target - lufs(x)) / 20))


class Rejected(Exception):
    pass


class Report:
    def __init__(s, title):
        s.title, s.rows, s.rejects = title, [], []

    def prepare(s, x, name, ref_len=None):
        """Validated, leveled take; raises Rejected (and records it) if invalid."""
        x = np.asarray(x, dtype=np.float64)
        x = x if x.ndim == 1 else x.mean(1)
        bad = validate(x, ref_len)
        raw = stats(x) if np.all(np.isfinite(x)) and len(x) else None
        if bad:
            s.rows.append((name, raw, None, "REJECT: " + ", ".join(bad)))
            s.rejects.append((name, bad))
            print(f"  REJECT {name}: {', '.join(bad)}", flush=True)
            raise Rejected(name)
        old = 0.9 * x / max(np.abs(x).max(), 1e-9)  # what the old peak-normalizing writer shipped
        y = level(x)
        s.rows.append((name, raw, dict(old_lufs=lufs(old), **stats(y)), "ok"))
        return y

    def text(s):
        h = f"{s.title}\nloudness: {LOUDNESS}; target {TARGET_LUFS} LUFS, ceiling {CEIL_DB} dBFS true peak; beeps {BEEP_LUFS} LUFS\n"
        h += f"reject if: nan/inf, |dc|>{DC_MAX}, >{100 * RAIL_FRAC:.1f}% samples |x|>={RAIL}, rms<{db(RMS_MIN):.0f} dBFS, duration off ref >{100 * DUR_TOL:.0f}%\n\n"
        h += f"{'take':<44} {'raw LUFS':>8} {'raw pk':>7} {'raw dc':>7} {'old LUFS':>8} {'new LUFS':>8} {'new TP':>7}  verdict\n"
        for name, r, n, v in s.rows:
            f = lambda d, k, fmt: format(d[k], fmt) if d else "-"
            h += f"{name:<44} {f(r, 'lufs', '8.1f'):>8} {f(r, 'peak_db', '7.1f'):>7} {f(r, 'dc', '+7.3f'):>7} {f(n, 'old_lufs', '8.1f'):>8} {f(n, 'lufs', '8.1f'):>8} {f(n, 'tp_db', '7.1f'):>7}  {v}\n"
        if s.rejects:
            h += f"\n{len(s.rejects)} take(s) rejected and not shipped:\n" + "".join(f"  {n}: {', '.join(b)}\n" for n, b in s.rejects)
        return h

    def write(s, out):
        t = s.text()
        print(t, flush=True)
        open(os.path.join(out, "report.txt"), "w").write(t)


_BEEP = None


def beeps(k):
    """k 1 kHz beeps then a pause, at BEEP_LUFS (same level in every set)."""
    global _BEEP
    if _BEEP is None:
        t = np.arange(int(0.12 * SR)) / SR
        b = np.sin(2 * np.pi * 1000 * t) * np.hanning(len(t))
        burst = np.concatenate([b, np.zeros(int(0.1 * SR))] * 4)
        _BEEP = b * 10 ** ((BEEP_LUFS - lufs(burst)) / 20)
    gap = np.zeros(int(0.1 * SR))
    return np.concatenate([np.concatenate([_BEEP, gap]) for _ in range(k)] + [np.zeros(int(0.25 * SR))])
