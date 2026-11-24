"""Render one scenario with one backend and save the plot-area crop.

usage: parity2d.py SCENARIO BACKEND OUTDIR
Writes OUTDIR/SCENARIO.BACKEND.png (data area only, frame and text excluded).
"""

import sys

import numpy

from silx.gui import qt
from silx.gui.plot import Plot2D
from silx.gui.colors import Colormap

import visual2d


def curve_over_image(p):
    p.addImage(visual2d.gauss(64), colormap=Colormap("gray"))
    p.addCurve((0, 64), (32, 32), legend="h", color="red", linewidth=4)
    p.addCurve((32, 32), (0, 64), legend="v", color="blue", linewidth=4, z=0)


def image_stack(p):
    red = numpy.zeros((40, 40, 4), numpy.float32)
    red[..., 0] = red[..., 3] = 1
    blue = red.copy()
    blue[..., 0], blue[..., 2] = 0, 1
    green = red.copy()
    green[..., 0], green[..., 1], green[..., 3] = 0, 1, 0.5
    p.addImage(red, legend="red z5", z=5)
    p.addImage(blue, legend="blue z0", origin=(20, 20), z=0)
    p.addImage(green, legend="green alpha z10", origin=(10, 10), z=10)


def markers_over_image(p):
    p.setGraphGrid("both")
    p.setDataBackgroundColor("yellow")
    p.addImage(visual2d.gauss(64), colormap=Colormap("gray"), origin=(16, 16), scale=(0.5, 0.5))
    p.addXMarker(30, legend="vx", color="red", text="vline")
    p.addYMarker(40, legend="hy", color="blue", text="hline")
    p.addMarker(40, 30, legend="pt", color="green", symbol="o", text="point")
    p.addShape((20, 30), (20, 30), legend="ov", shape="rectangle", color="magenta", fill=True, overlay=True)
    p.setGraphCursor(True, color="cyan", linewidth=3)
    p.setLimits(0, 64, 0, 64)


SCENARIOS = dict(visual2d.SCENARIOS)
SCENARIOS["curve_over_image"] = (Plot2D, curve_over_image)
SCENARIOS["image_stack"] = (Plot2D, image_stack)
SCENARIOS["markers_over_image"] = (Plot2D, markers_over_image)


def hover(plot):
    w = plot.getWidgetHandle()
    left, top, width, height = plot.getPlotBoundsInPixels()
    pos = qt.QPoint(int(left + width * 0.7), int(top + height * 0.3))
    from silx.gui.utils.testutils import QTest

    QTest.mouseMove(w, pos)
    visual2d.pump(10)


def main():
    name, backend, outdir = sys.argv[1:4]
    app = qt.QApplication([])
    cls, fill = SCENARIOS[name]
    win = cls(backend=backend)
    win.resize(visual2d.W, visual2d.H)
    win.move(40, 40)
    fill(win)
    win.show()
    win.raise_()
    visual2d.pump(40)
    if name in visual2d.INTERACT:
        visual2d.interact(name, win)
    if name == "markers_over_image":
        hover(win)
    visual2d.pump(40)
    handle = win.getWidgetHandle()
    left, top, width, height = win.getPlotBoundsInPixels()
    origin = handle.mapTo(win, qt.QPoint(0, 0))
    screen = win.screen()
    pix = screen.grabWindow(int(win.winId()))
    dpr = pix.devicePixelRatio()
    crop = pix.toImage().copy(
        int((origin.x() + left) * dpr),
        int((origin.y() + top) * dpr),
        int(width * dpr),
        int(height * dpr),
    )
    path = f"{outdir}/{name}.{backend}.png"
    crop.save(path)
    print("saved", path, crop.width(), crop.height(), flush=True)
    win.close()
    del app


if __name__ == "__main__":
    main()
