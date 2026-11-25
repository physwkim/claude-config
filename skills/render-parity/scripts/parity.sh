#!/bin/bash
# usage: RENDER=<adapter command> parity.sh OUTDIR BASE TARGET SCENARIO...
# Runs `$RENDER SCENARIO LABEL OUTDIR` for LABEL in BASE and TARGET, which
# must write OUTDIR/SCENARIO.LABEL.png, then diffs each pair.
# RENDER: word-split, so it can carry its interpreter
# PYTHON: interpreter with numpy and pillow for the diff (default python3)
# PARITY_TIMEOUT: seconds per render (default 120)
set -u
here=$(cd "$(dirname "$0")" && pwd)
: "${RENDER:?set RENDER to the adapter command}"
py=${PYTHON:-python3}
out=$1 base=$2 target=$3
shift 3
mkdir -p "$out"
for n in "$@"; do
  for b in "$base" "$target"; do
    timeout "${PARITY_TIMEOUT:-120}" $RENDER "$n" "$b" "$out" > "$out/$n.$b.log" 2>&1 \
      || echo "render failed: $n $b (rc=$?, see $out/$n.$b.log)"
  done
done
"$py" "$here/paritydiff.py" "$out" "$base" "$target" "$@"
