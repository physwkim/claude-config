"""Compare two renderings of the same scenarios.

usage: paritydiff.py [--threshold N] OUTDIR BASE TARGET SCENARIO...
A side is LABEL, read as OUTDIR/SCENARIO.LABEL.png, or DIR/LABEL, read as
DIR/SCENARIO.LABEL.png (the same renderer from an earlier run).
Prints the share of pixels whose max channel difference exceeds N
(default 48) and writes, in OUTDIR:
- SCENARIO.diff.png: gray baseline, differing pixels in red
- SCENARIO.trio.png: baseline | target | diff side by side, for viewing
"""

import os
import sys

import numpy
from PIL import Image


def load(outdir, side, name):
    folder, label = os.path.split(side)
    path = os.path.join(folder or outdir, f"{name}.{label}.png")
    return numpy.asarray(Image.open(path).convert("RGB"), dtype=numpy.int16)


def main():
    args = sys.argv[1:]
    threshold = 48  # ignores antialiasing differences between two renderers
    if args[:1] == ["--threshold"]:
        threshold = int(args[1])
        args = args[2:]
    outdir, base, target = args[:3]
    os.makedirs(outdir, exist_ok=True)
    for name in args[3:]:
        try:
            a = load(outdir, base, name)
            b = load(outdir, target, name)
        except FileNotFoundError as e:
            print(f"{name:24s} missing {e.filename}")
            continue
        if a.shape != b.shape:
            print(f"{name:24s} size mismatch {a.shape} vs {b.shape}")
            continue
        diff = numpy.abs(a - b).max(axis=2) > threshold
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
