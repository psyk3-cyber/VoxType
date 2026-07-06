#!/usr/bin/env python3
"""Generates the VoxType app icon (waveform on a gradient rounded square)
as an .iconset of PNGs. Run icon_to_icns.sh on macOS to produce AppIcon.icns.
Requires: pip install pillow
"""
import math
import os
from PIL import Image, ImageDraw

SIZES = [16, 32, 64, 128, 256, 512, 1024]
OUT = "AppIcon.iconset"

# Waveform bar heights (relative), symmetric and lively.
BARS = [0.28, 0.5, 0.78, 0.42, 0.95, 0.62, 0.82, 0.38, 0.55, 0.25]

TOP = (99, 91, 255)      # indigo
BOTTOM = (46, 196, 182)  # teal


def rounded_gradient(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    px = grad.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        r = int(TOP[0] + (BOTTOM[0] - TOP[0]) * t)
        g = int(TOP[1] + (BOTTOM[1] - TOP[1]) * t)
        b = int(TOP[2] + (BOTTOM[2] - TOP[2]) * t)
        for x in range(size):
            px[x, y] = (r, g, b, 255)
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    # macOS-style squircle approximation: rounded rect, radius ~22.5%
    pad = int(size * 0.05)
    radius = int(size * 0.225)
    d.rounded_rectangle([pad, pad, size - pad, size - pad], radius=radius, fill=255)
    img.paste(grad, (0, 0), mask)
    return img


def draw_waveform(img):
    size = img.size[0]
    d = ImageDraw.Draw(img)
    n = len(BARS)
    usable = size * 0.58
    bar_w = usable / (n * 1.8)
    gap = bar_w * 0.8
    total = n * bar_w + (n - 1) * gap
    x = (size - total) / 2
    cy = size / 2
    max_h = size * 0.5
    for h in BARS:
        bh = max(bar_w, max_h * h)
        d.rounded_rectangle(
            [x, cy - bh / 2, x + bar_w, cy + bh / 2],
            radius=bar_w / 2,
            fill=(255, 255, 255, 255),
        )
        x += bar_w + gap
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    master = draw_waveform(rounded_gradient(1024))
    names = []
    for s in SIZES:
        im = master.resize((s, s), Image.LANCZOS)
        if s <= 512:
            im.save(f"{OUT}/icon_{s}x{s}.png")
            names.append(f"icon_{s}x{s}.png")
        if s >= 32:
            im.save(f"{OUT}/icon_{s // 2}x{s // 2}@2x.png")
            names.append(f"icon_{s // 2}x{s // 2}@2x.png")
    master.save("icon_preview.png")
    print(f"Wrote {OUT}/ ({len(names)} PNGs) and icon_preview.png")
    print("Now run on macOS:  iconutil -c icns AppIcon.iconset -o AppIcon.icns")


if __name__ == "__main__":
    main()
