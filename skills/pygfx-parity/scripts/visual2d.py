"""Render one 2D scenario with several backends side by side and save a PNG.

usage: visual2d.py SCENARIO OUTDIR [backend ...]
"""

import os
import sys

import numpy

from silx.gui import qt
from silx.gui.plot import Plot1D, Plot2D, ImageView, items
from silx.gui.colors import Colormap
from silx.gui.utils.testutils import QTest

W, H = 640, 480


def gauss(n=256, m=None):
    m = m or n
    y, x = numpy.mgrid[-1 : 1 : n * 1j, -1 : 1 : m * 1j]
    return numpy.exp(-(x**2 + y**2) * 4) + 0.3 * numpy.sin(6 * x) * numpy.cos(4 * y)


def curves(p):
    x = numpy.linspace(0, 10, 200)
    for i, (ls, sym, color) in enumerate(
        [("-", "", "blue"), ("--", "o", "red"), ("-.", "s", "green"), (":", "d", "magenta"), ("-", "x", "black"), (" ", "d", "orange"), ("-", "+", "cyan"), ("-", "s", "brown")]
    ):
        c = p.addCurve(x[:: 5 if sym else 1], numpy.sin(x[:: 5 if sym else 1] + i * 0.4) + i * 0.6, legend=f"c{i} ls={ls!r} sym={sym!r}", color=color, linestyle=ls, symbol=sym, linewidth=1 + i % 3)
    p.setGraphTitle("Curves: linestyles / symbols / widths")
    p.setGraphXLabel("X label")
    p.setGraphYLabel("Y label")
    p.getLegendsDockWidget().show()


def symbols(p):
    syms = items.SymbolMixIn.getSupportedSymbols()
    for i, sym in enumerate(syms):
        if sym == "":
            continue
        p.addCurve(numpy.arange(8), numpy.full(8, i), legend=f"{sym!r}", symbol=sym, linestyle=" ", color="black")
        p.addMarker(8.3, i, legend=f"t{i}", text=repr(sym), symbol="", color="blue")
    p.setLimits(-0.5, 10, -1, len(syms))
    p.setGraphTitle("Every supported symbol")


def curve_fill_errors(p):
    x = numpy.linspace(0, 10, 25)
    y = numpy.sin(x) + 2
    p.addCurve(x, y, legend="errors", symbol="o", xerror=0.15, yerror=numpy.abs(y) * 0.1, color="blue")
    c = p.addCurve(x, numpy.cos(x) + 5, legend="fill", color="red", fill=True)
    p.addHistogram(numpy.abs(numpy.sin(numpy.arange(20) / 3)) * 3 + 6, numpy.arange(21) * 0.5, legend="hist", color="green", fill=True)
    p.setGraphTitle("Error bars / fill / histogram")


def image_cmap(p):
    p.addImage(gauss(), colormap=Colormap("viridis"), origin=(10, 20), scale=(0.5, 0.25))
    p.setKeepDataAspectRatio(True)
    p.setGraphTitle("Image viridis, origin+scale, keep aspect")


def image_norms(p):
    d = numpy.abs(gauss(200)) * 1000 + 1
    p.addImage(d, legend="log", colormap=Colormap("magma", normalization="log"))
    p.addImage(d, legend="sqrt", origin=(220, 0), colormap=Colormap("gray", normalization="sqrt"))
    p.addImage(d, legend="gamma", origin=(0, 220), colormap=Colormap("jet", normalization="gamma"))
    p.addImage(d, legend="asinh", origin=(220, 220), colormap=Colormap("temperature", normalization="arcsinh"))
    p.setGraphTitle("Image normalizations: log sqrt / gamma arcsinh")


def image_rgba(p):
    g = gauss(128)
    g = (g - g.min()) / (g.max() - g.min())
    rgba = numpy.zeros((128, 128, 4), numpy.float32)
    rgba[..., 0] = g
    rgba[..., 1] = 1 - g
    rgba[..., 2] = numpy.linspace(0, 1, 128)[None, :]
    rgba[..., 3] = 1
    p.addImage(rgba, legend="rgba float")
    rgb8 = (rgba[..., :3] * 255).astype(numpy.uint8)[:, ::-1]
    p.addImage(rgb8, legend="rgb uint8", origin=(140, 0))
    half = rgba.copy()
    half[..., 3] = 0.5
    p.addImage(half, legend="rgba alpha .5", origin=(70, 70), z=5)
    p.setGraphTitle("RGBA float / RGB uint8 / alpha 0.5 overlay")


def image_special(p):
    d = gauss(64).astype(numpy.float32)
    d[20:30, 20:30] = numpy.nan
    p.addImage(d, legend="nan", colormap=Colormap("viridis"))
    tiny = numpy.array([[0, 1], [2, 3]], numpy.uint16)
    p.addImage(tiny, legend="2x2 uint16", origin=(70, 0), scale=(16, 16), colormap=Colormap("jet"))
    c = (gauss(64) + 1j * gauss(64).T)
    item = items.ImageComplexData()
    item.setData(c)
    item.setOrigin((0, 70))
    item.setName("complex")
    p.addItem(item)
    p.setGraphTitle("NaN hole / 2x2 uint16 / complex (amplitude-phase)")


def scatter_mode(mode):
    def f(p):
        rng = numpy.random.default_rng(0)
        if mode in ("regular_grid",):
            y, x = numpy.mgrid[0:20, 0:30]
            x, y = x.ravel().astype(float), y.ravel().astype(float)
        elif mode == "irregular_grid":
            y, x = numpy.mgrid[0:20, 0:30]
            x = (x + rng.normal(0, 0.15, x.shape)).ravel()
            y = (y + rng.normal(0, 0.15, y.shape)).ravel()
        else:
            x = rng.uniform(0, 30, 600)
            y = rng.uniform(0, 20, 600)
        v = numpy.sin(x / 4) * numpy.cos(y / 3)
        s = p.addScatter(x, y, v, colormap=Colormap("viridis"), symbol="o")
        p.getScatter().setVisualization(mode)
        p.setGraphTitle(f"Scatter visualization={mode}")
        p.resetZoom()

    return f


def scatter_tiny(mode):
    def f(p):
        p.addScatter((0, 1, 0, 1), (0, 0, 2, 2), (0, 1, 2, 3), colormap=Colormap("jet"))
        p.getScatter().setVisualization(mode)
        p.setGraphTitle(f"4-point scatter {mode} (GL segfault case)")
        p.resetZoom()

    return f


def markers_shapes(p):
    p.addCurve([0, 10], [0, 10], legend="bg", color="#d3d3d3")
    p.addXMarker(2, legend="xm", text="X marker", color="red")
    p.addYMarker(8, legend="ym", text="Y marker", color="blue")
    p.addMarker(5, 5, legend="pt", text="point o", symbol="o", color="green")
    p.addMarker(7, 3, legend="pt2", text="point +", symbol="+", color="black")
    p.addMarker(3, 3, legend="pt3", text="point d", symbol="d", color="magenta")
    p.addShape(numpy.array([1, 4]), numpy.array([6, 9]), legend="rect", shape="rectangle", color="#ffa500", fill=True)
    p.addShape(numpy.array([6, 9, 8, 6]), numpy.array([6, 7, 9, 8]), legend="poly", shape="polygon", color="#800080", fill=False, linewidth=2)
    p.addShape(numpy.array([1, 3, 5, 9]), numpy.array([1, 2, 0.5, 1.5]), legend="polyl", shape="polylines", color="#a52a2a", linestyle=":", linewidth=3)
    p.addShape(numpy.array([0, 10]), numpy.array([4, 4]), legend="hline", shape="hline", color="#00ffff")
    p.addShape(numpy.array([9.5, 9.5]), numpy.array([0, 10]), legend="vline", shape="vline", color="#ffc0cb")
    p.setLimits(-0.5, 10.5, -0.5, 10.5)
    p.setGraphTitle("Markers / shapes")


def log_axes(p):
    x = numpy.logspace(-2, 3, 100)
    p.addCurve(x, x**2, legend="x^2", symbol=".")
    p.addCurve(x, numpy.sqrt(x) * 10, legend="sqrt", color="red")
    p.getXAxis().setScale("log")
    p.getYAxis().setScale("log")
    p.setGraphGrid("both")
    p.setGraphTitle("log-log, grid both")


def asinh_axis(p):
    x = numpy.linspace(-1000, 1000, 400)
    p.addCurve(x, x**3 / 1e6, legend="x^3")
    p.getYAxis().setScale("asinh")
    p.setGraphGrid("major")
    p.setGraphTitle("Y asinh scale")


def dual_y(p):
    x = numpy.linspace(0, 10, 100)
    p.addCurve(x, numpy.sin(x), legend="left", color="blue")
    p.addCurve(x, 1000 * numpy.cos(x) + 500, legend="right", color="red", yaxis="right")
    p.getYAxis(axis="right").setLabel("Right axis")
    p.setGraphYLabel("Left axis")
    p.getYAxis().setInverted(True)
    p.setGraphTitle("Dual Y axis, left inverted")


def dual_y_plain(p):
    x = numpy.linspace(0, 10, 100)
    p.addCurve(x, numpy.sin(x), legend="left", color="blue")
    p.addCurve(x, 1000 * numpy.cos(x) + 500, legend="right", color="red", yaxis="right")
    p.getYAxis(axis="right").setLabel("Right axis")
    p.setGraphYLabel("Left axis")
    p.setGraphTitle("Dual Y axis, not inverted")


def colors_bg(p):
    x = numpy.linspace(0, 10, 100)
    p.addCurve(x, numpy.sin(x), legend="c", color="yellow", linewidth=2)
    p.setBackgroundColor("#202040")
    p.setDataBackgroundColor("#000000")
    p.setForegroundColor("#ffcc00")
    p.setGridColor("#606060")
    p.setGraphGrid("both")
    p.setGraphTitle("Custom background/foreground/grid colors")


def time_axis(p):
    import datetime as dt

    t0 = dt.datetime(2026, 11, 24).timestamp()
    x = t0 + numpy.arange(0, 86400 * 3, 600)
    p.addCurve(x, numpy.sin(numpy.arange(x.size) / 20), legend="t")
    p.getXAxis().setTickMode(items.axis.TickMode.TIME_SERIES)
    p.setGraphTitle("Time-series X axis (3 days)")


def axes_off(p):
    p.addImage(gauss(128), colormap=Colormap("inferno"))
    p.setAxesDisplayed(False)


def large_curve(p):
    x = numpy.linspace(0, 1000, 1_000_000)
    p.addCurve(x, numpy.sin(x) + numpy.random.default_rng(1).normal(0, 0.1, x.size), legend="1M", linewidth=1)
    p.setGraphTitle("1M point curve")


def crosshair_zoom(p):
    x = numpy.linspace(0, 10, 100)
    p.addCurve(x, numpy.sin(x), legend="c")
    p.setGraphCursor(True, color="red", linewidth=1, linestyle="--")
    p.setInteractiveMode("zoom")


def draw_polygon(p):
    p.addImage(gauss(128), colormap=Colormap("gray"))
    p.setInteractiveMode("draw", shape="polygon", color="green")


def mask_overlay(p):
    p.addImage(gauss(128), colormap=Colormap("viridis"))
    mask = numpy.zeros((128, 128), numpy.uint8)
    mask[20:60, 30:90] = 1
    mask[70:110, 70:120] = 2
    p.getMaskToolsDockWidget().show()
    p.getMaskToolsDockWidget().setSelectionMask(mask)
    p.setGraphTitle("Mask overlay (levels 1 and 2)")


SCENARIOS = {
    "curves": (Plot1D, curves),
    "symbols": (Plot1D, symbols),
    "curve_fill_errors": (Plot1D, curve_fill_errors),
    "image_cmap": (Plot2D, image_cmap),
    "image_norms": (Plot2D, image_norms),
    "image_rgba": (Plot2D, image_rgba),
    "image_special": (Plot2D, image_special),
    "scatter_points": (Plot2D, scatter_mode("points")),
    "scatter_solid": (Plot2D, scatter_mode("solid")),
    "scatter_regular_grid": (Plot2D, scatter_mode("regular_grid")),
    "scatter_irregular_grid": (Plot2D, scatter_mode("irregular_grid")),
    "scatter_binned": (Plot2D, scatter_mode("binned_statistic")),
    "scatter_tiny_regular": (Plot2D, scatter_tiny("regular_grid")),
    "scatter_tiny_binned": (Plot2D, scatter_tiny("binned_statistic")),
    "markers_shapes": (Plot1D, markers_shapes),
    "log_axes": (Plot1D, log_axes),
    "asinh_axis": (Plot1D, asinh_axis),
    "dual_y": (Plot1D, dual_y),
    "dual_y_plain": (Plot1D, dual_y_plain),
    "colors_bg": (Plot1D, colors_bg),
    "time_axis": (Plot1D, time_axis),
    "axes_off": (Plot2D, axes_off),
    "large_curve": (Plot1D, large_curve),
    "crosshair_zoom": (Plot1D, crosshair_zoom),
    "draw_polygon": (Plot2D, draw_polygon),
    "mask_overlay": (Plot2D, mask_overlay),
}

INTERACT = {"crosshair_zoom", "draw_polygon"}


def interact(name, plot):
    w = plot.getWidgetHandle()
    r = w.rect()
    if name == "crosshair_zoom":
        a = qt.QPoint(int(r.width() * 0.3), int(r.height() * 0.3))
        b = qt.QPoint(int(r.width() * 0.6), int(r.height() * 0.6))
        QTest.mouseMove(w, a)
        QTest.mousePress(w, qt.Qt.LeftButton, qt.Qt.NoModifier, a)
        for t in numpy.linspace(0, 1, 10):
            QTest.mouseMove(w, a + (b - a) * float(t))
            pump(5)
    elif name == "draw_polygon":
        pts = [(0.3, 0.3), (0.7, 0.35), (0.6, 0.7), (0.35, 0.6)]
        for fx, fy in pts:
            pos = qt.QPoint(int(r.width() * fx), int(r.height() * fy))
            QTest.mouseMove(w, pos)
            pump(3)
            QTest.mouseClick(w, qt.Qt.LeftButton, qt.Qt.NoModifier, pos)
            pump(3)
        QTest.mouseMove(w, qt.QPoint(int(r.width() * 0.45), int(r.height() * 0.8)))
        pump(5)


def pump(n=20):
    app = qt.QApplication.instance()
    for _ in range(n):
        app.processEvents()
        QTest.qWait(10)


def main():
    name, outdir = sys.argv[1], sys.argv[2]
    backends = sys.argv[3:] or ["mpl", "pygfx"]
    app = qt.QApplication([])
    cls, fill = SCENARIOS[name]
    shots = []
    for i, backend in enumerate(backends):
        win = cls(backend=backend)
        win.setWindowTitle(f"{name} [{backend}]")
        win.resize(W, H)
        win.move(40 + i * (W + 20), 40)
        fill(win)
        win.show()
        win.raise_()
        pump(40)
        if name in INTERACT:
            interact(name, win)
        pump(40)
        screen = win.screen() if hasattr(win, "screen") else qt.QApplication.primaryScreen()
        pix = screen.grabWindow(int(win.winId()))
        shots.append((backend, pix.toImage()))
        if backend == "pygfx" and os.environ.get("SNAP"):
            snap = win.getWidgetHandle()._renderer.snapshot()
            arr = numpy.ascontiguousarray(numpy.asarray(snap))
            h, w_ = arr.shape[:2]
            img = qt.QImage(arr.data, w_, h, w_ * 4, qt.QImage.Format_RGBA8888).copy()
            shots.append(("pygfx renderer.snapshot", img))
        win.close()
        pump(5)
    tw = sum(img.width() for _, img in shots) + 10 * (len(shots) - 1)
    th = max(img.height() for _, img in shots) + 24
    out = qt.QImage(tw, th, qt.QImage.Format_RGB32)
    out.fill(qt.QColor("white"))
    painter = qt.QPainter(out)
    x = 0
    for label, img in shots:
        painter.setPen(qt.QColor("black"))
        painter.drawText(x + 4, 16, label)
        painter.drawImage(x, 24, img)
        x += img.width() + 10
    painter.end()
    path = f"{outdir}/{name}.png"
    out.save(path)
    print("saved", path, [(l, i.width(), i.height()) for l, i in shots], flush=True)


if __name__ == "__main__":
    main()
