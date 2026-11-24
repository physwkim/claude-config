---
name: pygfx-parity
description: Compare silx PlotWidget rendering of the pygfx backend against the OpenGL backend as images (share of differing pixels plus side-by-side and diff PNGs). Use before and after changing silx's pygfx plot backend (src/silx/gui/plot/backends/BackendPygfx.py) to record a baseline and measure what a fix changed, and to look at 2D scenes with your own eyes.
---

# pygfx vs OpenGL image parity for silx 2D plots

The OpenGL backend is the reference. Render the same scene with both backends,
crop the plot area, and count pixels whose largest channel difference exceeds 48.

## Setup (once per machine/session)

A Python env with silx installed editable, pygfx and PyOpenGL. Put it in the
session scratchpad, not in the repository:

```bash
V=<scratchpad>/venv
~/miniconda3/bin/python -m venv $V
$V/bin/pip install -U pip meson meson-python ninja 'cython>=3.1' numpy
cd ~/work/silx
PATH=$V/bin:$PATH $V/bin/pip install --no-build-isolation -e '.[full,pygfx]' \
    pytest pytest-mock pytest-httpserver pytest-xvfb 'imageio[tifffile]' scipy pillow ruff
```

It needs a real X display (`DISPLAY=:0`): windows are grabbed from the screen.

## Workflow for a pygfx backend fix

1. **Baseline before editing.** Pick the scenarios the change touches and render
   them on the unmodified code:
   `PYTHON=$V/bin/python ~/.claude/skills/pygfx-parity/scripts/parity.sh <scratchpad>/parity_before SCENARIO...`
2. **Failing test first.** Add a pixel test in
   `src/silx/gui/plot/test/test_plotwidget.py` with the `_renderPygfx(plot)` helper
   (draws now, returns the RGB image and the device pixel ratio), and run it on the
   unmodified backend to see it fail:
   `PATH=$V/bin:$PATH python -m pytest --no-xvfb -p no:cacheprovider -q src/silx/gui/plot/test/test_plotwidget.py -k testPygfx`
3. Fix, then render again into `<scratchpad>/parity_after` with the same scenarios.
4. Compare the two printouts and **read the `SCENARIO.trio.png` images**
   (GL | pygfx | diff in red). A fix should lower the share on the scenarios it
   targets and not raise the others. Other known differences (text size, line
   width) keep a floor, so compare before vs after, not against zero.

## Scenarios

- `scripts/visual2d.py` `SCENARIOS`: curves, symbols, curve_fill_errors,
  image_cmap, image_norms, image_rgba, image_special, scatter_* , markers_shapes,
  log_axes, asinh_axis, dual_y, dual_y_plain, colors_bg, time_axis, axes_off,
  large_curve, crosshair_zoom, draw_polygon, mask_overlay
- `scripts/parity2d.py` adds: curve_over_image, image_stack, markers_over_image
  (with grid, data background, markers, overlay shape and crosshair)

Add a scenario as a function `f(plot)` in `parity2d.py` and register it in its
`SCENARIOS`.

To see a whole window (frame, labels, legend) with mpl as well:
`$V/bin/python ~/.claude/skills/pygfx-parity/scripts/visual2d.py SCENARIO OUTDIR mpl gl pygfx`
writes `OUTDIR/SCENARIO.png` with the windows side by side.

## Rules

- These scripts are personal dev tools: never copy them into the silx repository
  or a pull request.
- Write outputs to the session scratchpad.
