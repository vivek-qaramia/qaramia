"""Generate peekuu icon + splash PNGs at 1024x1024.

Draws the "P" mark directly with Pillow's ImageDraw — no Cairo / SVG
rasteriser required. Mirrors the geometry in branding/qaramia-mark.svg
(320 viewBox scaled ×3.2 → 1024):
  * P stem  — vertical rounded stroke, gold→coral→love
  * P bowl  — right semicircle off the top of the stem, rose→crimson
  * Halo    — soft radial bleed of the peach behind the mark (icon only)

Two outputs:
  - qaramia-icon-1024.png   — icon-ready, dark wine background
  - qaramia-splash-1024.png — splash-ready, transparent mark on the same colour
                              (flutter_native_splash composites the background)
"""
import os
from PIL import Image, ImageDraw

SIZE = 1024
CENTER = SIZE // 2

# Background (dark wine, matches QBrand.wine)
BG = (31, 11, 20, 255)

# Brand colour stops
GOLD  = (255, 209, 102)
CORAL = (255, 138, 92)
LOVE  = (233, 69, 96)
ROSE  = (255, 107, 129)
DEEP  = (201, 24, 74)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_color_3stop(c0, c1, c2, t):
    """Three-stop gradient: c0 at 0.0, c1 at 0.45, c2 at 1.0."""
    if t <= 0.45:
        return lerp(c0, c1, t / 0.45)
    return lerp(c1, c2, (t - 0.45) / 0.55)


def stroke_circle_with_gradient(img: Image.Image, cx, cy, r, stroke,
                                colors3, sweep_start_deg=None, sweep_end_deg=None):
    """Render a stroked circle (or arc) with a 3-stop gradient by drawing many
    short colour-interpolated arcs."""
    draw = ImageDraw.Draw(img)
    # 4-pixel slices for smooth blending
    if sweep_start_deg is None:
        sweep_start_deg = 0
        sweep_end_deg = 360
    total = sweep_end_deg - sweep_start_deg
    steps = max(1, int(total))
    for i in range(steps):
        t = i / steps
        col = gradient_color_3stop(colors3[0], colors3[1], colors3[2], t)
        a0 = sweep_start_deg + i * (total / steps)
        a1 = sweep_start_deg + (i + 1) * (total / steps) + 0.6  # +0.6 overlap = no seams
        draw.arc(
            (cx - r, cy - r, cx + r, cy + r),
            start=a0, end=a1,
            fill=col + (255,), width=stroke,
        )


def _cap(img: Image.Image, x, y, stroke, color):
    """Round line cap — a filled circle of the stroke's diameter."""
    r = stroke // 2
    ImageDraw.Draw(img).ellipse((x - r, y - r, x + r, y + r), fill=color + (255,))


def stroke_vline_with_gradient(img: Image.Image, x, y0, y1, stroke, colors3):
    """Vertical stroke with a 3-stop gradient (top→bottom) and round caps."""
    draw = ImageDraw.Draw(img)
    steps = max(1, int(abs(y1 - y0)))
    for i in range(steps):
        t = i / steps
        col = gradient_color_3stop(colors3[0], colors3[1], colors3[2], t)
        yy0 = y0 + (y1 - y0) * (i / steps)
        yy1 = y0 + (y1 - y0) * ((i + 1) / steps) + 0.8  # overlap = no seams
        draw.line([(x, yy0), (x, yy1)], fill=col + (255,), width=stroke)
    _cap(img, x, y0, stroke, colors3[0])
    _cap(img, x, y1, stroke, colors3[2])


def stroke_line_with_gradient(img: Image.Image, p0, p1, stroke, colors3):
    draw = ImageDraw.Draw(img)
    steps = 64
    for i in range(steps):
        t = i / steps
        t1 = (i + 1) / steps
        col = gradient_color_3stop(colors3[0], colors3[1], colors3[2], 0.7)
        # one solid colour line is enough at this scale
        x0 = p0[0] + (p1[0] - p0[0]) * t
        y0 = p0[1] + (p1[1] - p0[1]) * t
        x1 = p0[0] + (p1[0] - p0[0]) * t1
        y1 = p0[1] + (p1[1] - p0[1]) * t1
        draw.line([(x0, y0), (x1, y1)], fill=col + (255,), width=stroke)


def make_halo(size, center, radius, colour, alpha_peak=110):
    """Soft radial halo behind the mark — multi-pass blurred ellipse."""
    halo = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(halo)
    # Draw 80 concentric circles fading out
    for i in range(80, 0, -1):
        r = radius + i * 4
        a = int(alpha_peak * (i / 80) ** 2)
        draw.ellipse(
            (center - r, center - r, center + r, center + r),
            fill=colour + (a // 8,),  # very faint per ring; they stack
        )
    return halo


def build_icon(out_path, with_background=True, with_halo=True):
    if with_background:
        img = Image.new('RGBA', (SIZE, SIZE), BG)
    else:
        img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))

    # Halo
    if with_halo:
        halo = make_halo(SIZE, CENTER, 200, CORAL, alpha_peak=130)
        img.alpha_composite(halo)

    # Geometry mirrors branding/qaramia-mark.svg (320 viewBox) scaled ×3.2.
    s = SIZE / 320
    stroke = int(30 * s)  # 96 — matches the SVG's 30px stroke

    # P bowl FIRST — right semicircle off the top of the stem (rose → crimson).
    # SVG: M 124 72 A 58 58 0 0 1 124 188 → centre (124,130), r 58.
    # Both ends land on the stem line, so the stem (drawn next, on top) covers
    # the junctions cleanly — no separate bowl end-caps needed.
    bowl_cx = int(124 * s)
    bowl_cy = int(130 * s)
    bowl_r = int(58 * s)
    # PIL arcs sweep clockwise from 3-o'clock; the right half is -90° (top)
    # through 0° (east) to 90° (bottom).
    stroke_circle_with_gradient(img, bowl_cx, bowl_cy, bowl_r, stroke,
                                [ROSE, ROSE, DEEP],
                                sweep_start_deg=-90, sweep_end_deg=90)

    # P stem ON TOP — vertical rounded stroke (gold → coral → love, top→bottom)
    stem_x = int(124 * s)
    stem_y0 = int(72 * s)
    stem_y1 = int(248 * s)
    stroke_vline_with_gradient(img, stem_x, stem_y0, stem_y1, stroke,
                               [GOLD, CORAL, LOVE])

    img.save(out_path, 'PNG', optimize=True)
    print(f'  wrote {out_path} ({SIZE}x{SIZE})')


os.makedirs('E:/claude/qaramia-v2/branding', exist_ok=True)
build_icon('E:/claude/qaramia-v2/branding/qaramia-icon-1024.png',
           with_background=True, with_halo=True)
build_icon('E:/claude/qaramia-v2/branding/qaramia-splash-1024.png',
           with_background=False, with_halo=False)
print('Done.')
