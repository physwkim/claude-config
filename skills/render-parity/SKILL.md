---
name: render-parity
description: Compare what two renderers draw for the same scenes as images, either a reference renderer against a new one (silx's OpenGL plot backend against its pygfx backend; adapter included) or one renderer before and after a change. Prints the share of differing pixels and writes side-by-side and diff PNGs. Use before and after changing rendering code, to record a baseline, measure what the change did, and look at the scenes yourself.
---

# Render parity

A test that reads back state shows that the renderer was asked to draw the right thing. Only the pixels show what it drew. Render the same scenes twice, crop the area both renderings must agree on, and count the pixels whose largest channel difference exceeds a threshold.

There are two kinds of answer key:

- **A reference renderer.** An existing renderer is the answer key for a new one, such as OpenGL for pygfx, a CPU path for a GPU path, or a C original for a port. Known differences, such as glyph rasterization and line joins, leave a floor, so judge a change before against after, not against zero.
- **The same renderer at the base commit.** The renderer before the change is the answer key for itself after it. This has no floor. With `--threshold 0`, every red pixel is something the change did. Raise the threshold only if a rerun of unchanged code already differs.

## Adapter

An adapter is a command run as `RENDER SCENARIO LABEL OUTDIR`. It draws one scenario with the renderer that LABEL names and writes `OUTDIR/SCENARIO.LABEL.png`.

- **Write only the region both renderings must agree on.** Crop away window frames, text, and anything one renderer may legitimately draw differently.
- **Make both images the same size, at the same device pixel ratio.** A size mismatch is reported and never resampled, because resampling hides the difference you are looking for.
- **Use fixed input.** Fix the data, seeds, view limits and window size, and fix pointer positions for interactive states.

The scenarios live in the adapter. Pick the ones that exercise the code the change touches, plus a few that the change should not touch.

Adapters:

- `adapters/silx/`: silx `PlotWidget`, comparing the `gl` and `pygfx` backends. Read `adapters/silx/README.md` before changing silx's pygfx backend.

For a new project, give a reusable adapter its own folder, `adapters/<project>/`, with a README shaped like the silx one. A one-off adapter goes in the scratchpad.

## Run

```bash
RENDER="<adapter command>" PYTHON=<python with numpy and pillow> \
  ~/.claude/skills/render-parity/scripts/parity.sh OUTDIR BASE TARGET SCENARIO...
```

This renders each scenario with both labels and logs each render to `OUTDIR/SCENARIO.LABEL.log`. It then prints one line per scenario and writes two images:

- `SCENARIO.diff.png`: the base image in gray, with differing pixels in red.
- `SCENARIO.trio.png`: base, target and diff side by side.

To diff images that already exist, run `scripts/paritydiff.py [--threshold N] OUTDIR BASE TARGET SCENARIO...`. A side is either `LABEL`, read from OUTDIR, or `DIR/LABEL`, read from another run's folder. For example, the target before and after a change:

`paritydiff.py --threshold 0 <scratchpad>/cmp <scratchpad>/parity_before/pygfx <scratchpad>/parity_after/pygfx SCENARIO...`

## Workflow for a rendering change

1. **Record a baseline before editing.** Run the scenarios on the unmodified code into `<scratchpad>/parity_before`.
2. **Write the failing test first.** Write it in the project's own test suite (the adapter README says where), and see it fail on the unmodified code.
3. **Make the change.** Then render the same scenarios into `<scratchpad>/parity_after`.
4. **Compare, then read the trio images.**
   - Reference against target: compare the shares before and after. The share should drop on the scenarios the change targets and not rise on the others.
   - The target before against after, with `--threshold 0`, on the scenarios the change should not touch: any red there is a side effect.
   - A share alone does not tell a shifted line from a wrong color. The trio images do.

## Rules

- The adapters and scripts are personal dev tools. Never copy them into the project repository or a pull request.
- Write outputs to the session scratchpad.
