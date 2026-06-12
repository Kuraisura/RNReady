#!/usr/bin/env python3
"""Generate the RN Ready brand artwork (logo + splash) with Pillow.

Concept: a mint→emerald gradient heart with a navy EKG/QRS pulse line cut
through it, on the clinical-navy field. No SVG tooling needed — the heart is a
parametric curve, supersampled 4× and downsampled with LANCZOS for clean edges.

Outputs (into assets/images/):
  app_icon.png                    1024² opaque  — iOS / Android legacy icon
  app_icon_android_foreground.png 1024² alpha   — adaptive foreground (safe zone)
  splash_logo.png                 1152² alpha   — native splash image

Run:  python tool/make_brand.py
Then: dart run flutter_launcher_icons   &&   dart run flutter_native_splash:create
"""

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images")

NAVY = (0x0B, 0x12, 0x20)
MINT = (0x5E, 0xEA, 0xD4)
EMERALD = (0x34, 0xD3, 0x99)
SS = 4  # supersampling factor


def _heart_points(n=2000):
    pts = []
    for i in range(n + 1):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = (13 * math.cos(t) - 5 * math.cos(2 * t)
             - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((x, y))
    return pts


def make_glyph(px):
    """A square RGBA image (size px) holding the centred heart + pulse glyph."""
    w = px * SS
    heart = _heart_points()
    xs = [p[0] for p in heart]
    ys = [p[1] for p in heart]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    gw, gh = maxx - minx, maxy - miny
    margin = 0.06
    scale = (w * (1 - 2 * margin)) / max(gw, gh)
    offx = (w - gw * scale) / 2
    offy = (w - gh * scale) / 2

    def to_img(x, y):
        return (offx + (x - minx) * scale, offy + (maxy - y) * scale)  # flip y

    poly = [to_img(x, y) for (x, y) in heart]

    # Heart mask + mint→emerald vertical gradient fill.
    mask = Image.new("L", (w, w), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    grad = Image.new("RGB", (1, w))
    for yy in range(w):
        f = yy / (w - 1)
        grad.putpixel((0, yy), tuple(
            int(MINT[c] + (EMERALD[c] - MINT[c]) * f) for c in range(3)))
    grad = grad.resize((w, w))
    glyph = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    glyph.paste(grad, (0, 0), mask)

    # Navy QRS pulse, clipped to the heart so it never pokes out.
    base = -3.0
    pulse = [(-13, base), (-9, base), (-7.5, base + 2), (-6, base),
             (-4.5, base - 4), (-1.5, base + 7), (1, base - 5), (3, base),
             (5.5, base), (7.5, base + 2), (9, base), (13, base)]
    ip = [to_img(x, y) for (x, y) in pulse]
    pimg = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pimg)
    lw = int(w * 0.028)
    pd.line(ip, fill=NAVY + (255,), width=lw, joint="curve")
    r = lw // 2
    for (x, y) in ip:  # round end-caps
        pd.ellipse([x - r, y - r, x + r, y + r], fill=NAVY + (255,))
    clipped = ImageChops.multiply(pimg.split()[3], mask)
    pimg.putalpha(clipped)
    glyph = Image.alpha_composite(glyph, pimg)

    return glyph.resize((px, px), Image.LANCZOS)


def _centered(canvas, glyph, frac):
    size = canvas.size[0]
    g = glyph.resize((int(size * frac),) * 2, Image.LANCZOS)
    off = (size - g.size[0]) // 2
    canvas.alpha_composite(g, (off, off))


def main():
    os.makedirs(OUT, exist_ok=True)
    glyph = make_glyph(1024)

    # Adaptive foreground — transparent, glyph inside the 66% safe zone.
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    _centered(fg, glyph, 0.60)
    fg.save(os.path.join(OUT, "app_icon_android_foreground.png"))

    # Full app icon — opaque navy field with a soft mint glow behind the heart.
    icon = Image.new("RGBA", (1024, 1024), NAVY + (255,))
    glow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [1024 * 0.22, 1024 * 0.20, 1024 * 0.78, 1024 * 0.80],
        fill=MINT + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(85))
    icon = Image.alpha_composite(icon, glow)
    _centered(icon, glyph, 0.64)
    icon.convert("RGB").save(os.path.join(OUT, "app_icon.png"))  # opaque, no alpha

    # Splash logo — transparent, generous padding for the Android-12 circle.
    sp = Image.new("RGBA", (1152, 1152), (0, 0, 0, 0))
    _centered(sp, glyph, 0.58)
    sp.save(os.path.join(OUT, "splash_logo.png"))

    print("Wrote app_icon.png, app_icon_android_foreground.png, splash_logo.png")


if __name__ == "__main__":
    main()
