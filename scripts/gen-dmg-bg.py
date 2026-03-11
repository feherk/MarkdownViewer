#!/usr/bin/env python3
"""Generate DMG background images (1x and 2x)."""
from PIL import Image, ImageDraw, ImageFont
import sys, os

def generate(w, h, out_path):
    img = Image.new("RGB", (w, h), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    scale = w / 600  # 1x=600, 2x=1200

    # Arrow between icon positions (150 and 450 in 1x)
    ax = int(220 * scale)
    bx = int(380 * scale)
    cy = int(185 * scale)

    color = (170, 170, 170)
    line_w = max(2, int(3 * scale))
    arrow_size = int(12 * scale)

    # Arrow line
    draw.line([(ax, cy), (bx - arrow_size, cy)], fill=color, width=line_w)

    # Arrowhead
    draw.polygon([
        (bx, cy),
        (bx - arrow_size * 2, cy - arrow_size),
        (bx - arrow_size * 2, cy + arrow_size),
    ], fill=color)

    # Text
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", int(13 * scale))
    except Exception:
        font = ImageFont.load_default()

    text = "Drag to Applications to install"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    tx = (w - tw) // 2
    ty = cy + int(55 * scale)

    draw.text((tx, ty), text, fill=(150, 150, 150), font=font)

    img.save(out_path, "PNG")
    print(f"  {out_path} ({w}x{h})")

out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
print("Generating DMG backgrounds:")
generate(600, 400, os.path.join(out_dir, "dmg-background.png"))
generate(1200, 800, os.path.join(out_dir, "dmg-background@2x.png"))
