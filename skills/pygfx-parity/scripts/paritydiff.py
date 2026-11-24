"""Compare plot-area crops of two backends.

usage: paritydiff.py OUTDIR BASELINE TARGET SCENARIO...
Prints the share of pixels whose max channel difference exceeds a threshold
and writes, in OUTDIR:
- SCENARIO.diff.png: gray baseline, differing pixels in red
- SCENARIO.trio.png: baseline | target | diff side by side, for viewing
"""

import sys

import numpy
from PIL import Image

THRESHOLD = 48  # per-channel difference ignored below this (antialiasing)


def load(path):
    return numpy.asarray(Image.open(path).convert("RGB"), dtype=numpy.int16)


def main():
    outdir, base, target = sys.argv[1:4]
    for name in sys.argv[4:]:
        try:
            a = load(f"{outdir}/{name}.{base}.png")
            b = load(f"{outdir}/{name}.{target}.png")
        except FileNotFoundError as e:
            print(f"{name:24s} missing {e.filename}")
            continue
        if a.shape != b.shape:
            print(f"{name:24s} size mismatch {a.shape} vs {b.shape}")
            continue
        diff = numpy.abs(a - b).max(axis=2) > THRESHOLD
        share = 100.0 * diff.mean()
        gray = a.mean(axis=2).astype(numpy.uint8)
        out = numpy.dstack([gray, gray, gray]) // 2 + 64
        out[diff] = (255, 0, 0)
        Image.fromarray(out.astype(numpy.uint8)).save(f"{outdir}/{name}.diff.png")

        gap = numpy.full((a.shape[0], 10, 3), 255, dtype=numpy.int16)
        trio = numpy.hstack([a, gap, b, gap, out.astype(numpy.int16)])
        Image.fromarray(trio.astype(numpy.uint8)).save(f"{outdir}/{name}.trio.png")
        print(f"{name:24s} differing pixels {share:6.2f}%")


if __name__ == "__main__":
    main()
