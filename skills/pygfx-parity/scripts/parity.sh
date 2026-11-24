#!/bin/bash
# usage: parity.sh OUTDIR SCENARIO...
# Renders each scenario with the gl and pygfx backends, then diffs them.
# PYTHON: interpreter with silx (editable), pygfx and PyOpenGL (default: python)
# DISPLAY: a real X display (default :0); the plots are grabbed from the screen
set -u
here=$(cd "$(dirname "$0")" && pwd)
py=${PYTHON:-python}
export DISPLAY=${DISPLAY:-:0}
out=$1
shift
mkdir -p "$out"
for n in "$@"; do
  for b in gl pygfx; do
    timeout 120 "$py" "$here/parity2d.py" "$n" "$b" "$out" > "$out/$n.$b.log" 2>&1 \
      || echo "render failed: $n $b (rc=$?, see $out/$n.$b.log)"
  done
done
"$py" "$here/paritydiff.py" "$out" gl pygfx "$@"
