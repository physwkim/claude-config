# silx adapter: OpenGL vs pygfx plot backends

This adapter compares the two backends of silx's `PlotWidget`. The OpenGL backend (`gl`) is the reference, and the pygfx backend (`pygfx`, in `src/silx/gui/plot/backends/BackendPygfx.py`) is the target. `parity2d.py` writes the plot area only, without the frame or text.

## Setup (once per machine/session)

Use a Python env with silx installed in editable mode, plus pygfx and PyOpenGL. Put it in the session scratchpad, not in the repository:

```bash
V=<scratchpad>/venv
~/miniconda3/bin/python -m venv $V
$V/bin/pip install -U pip meson meson-python ninja 'cython>=3.1' numpy
cd ~/work/silx
PATH=$V/bin:$PATH $V/bin/pip install --no-build-isolation -e '.[full,pygfx]' \
    pytest pytest-mock pytest-httpserver pytest-xvfb 'imageio[tifffile]' scipy pillow ruff
```

The renders are grabbed from the screen, so they need a real X display.

## Run

```bash
A=~/.claude/skills/render-parity
DISPLAY=:0 RENDER="$V/bin/python $A/adapters/silx/parity2d.py" PYTHON=$V/bin/python \
  $A/scripts/parity.sh <scratchpad>/parity_before gl pygfx SCENARIO...
```

## Test for a fix

Add a pixel test in `src/silx/gui/plot/test/test_plotwidget.py`. The `_renderPygfx(plot)` helper draws the plot immediately and returns the RGB image and the device pixel ratio. Run the test on the unmodified backend to see it fail:

`PATH=$V/bin:$PATH python -m pytest --no-xvfb -p no:cacheprovider -q src/silx/gui/plot/test/test_plotwidget.py -k testPygfx`

## Scenarios

- `visual2d.py` `SCENARIOS`: curves, symbols, curve_fill_errors, image_cmap, image_norms, image_rgba, image_special, scatter_*, markers_shapes, log_axes, asinh_axis, dual_y, dual_y_plain, colors_bg, time_axis, axes_off, large_curve, crosshair_zoom, draw_polygon, mask_overlay
- `parity2d.py` adds curve_over_image, image_stack and markers_over_image. These include a grid, a data background, markers, an overlay shape and a crosshair.

To add a scenario, write a function `f(plot)` in `parity2d.py` and register it in that file's `SCENARIOS`.

To see whole windows (frame, labels, legend) with the mpl backend as well, run `$V/bin/python $A/adapters/silx/visual2d.py SCENARIO OUTDIR mpl gl pygfx`. It writes `OUTDIR/SCENARIO.png` with the windows side by side.
