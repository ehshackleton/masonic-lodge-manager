#!/usr/bin/env python3
"""Regenera insignias y logos públicos desde logo-amenti.jpg y amenti.png."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / "public" / "images"
PUBLIC = Path(__file__).resolve().parents[1] / "public"
SRC_MASTER = ROOT / "logo-amenti.jpg"
SRC_SEAL = Path(__file__).resolve().parents[1] / "amenti.png"

GOLD = (212, 175, 55, 255)


def to_rgba(im: Image.Image) -> Image.Image:
    return im.convert("RGBA") if im.mode != "RGBA" else im.copy()


def remove_near_white(im: Image.Image, threshold: int = 248, soft: int = 14) -> Image.Image:
    im = to_rgba(im)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            minimum = min(r, g, b)
            if minimum >= threshold:
                px[x, y] = (r, g, b, 0)
            elif minimum >= threshold - soft:
                fade = (threshold - minimum) / soft
                px[x, y] = (r, g, b, int(a * fade))
    return im


def trim_transparent(im: Image.Image, pad: int = 8) -> Image.Image:
    im = to_rgba(im)
    bbox = im.getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


def fit_square(im: Image.Image, size: int) -> Image.Image:
    im = trim_transparent(im)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    im.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas.paste(im, ((size - im.width) // 2, (size - im.height) // 2), im)
    return canvas


def add_gold_stroke(im: Image.Image, width: int = 1) -> Image.Image:
    im = to_rgba(im)
    alpha = im.split()[-1]
    stroke = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for dx, dy in [(-width, 0), (width, 0), (0, -width), (0, width)]:
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        layer.paste(GOLD, (0, 0), alpha)
        shifted = Image.new("RGBA", im.size, (0, 0, 0, 0))
        shifted.paste(layer, (dx, dy), layer)
        stroke = Image.alpha_composite(stroke, shifted)
    return Image.alpha_composite(stroke, im)


def circular_mask(size: int, inset: int = 6) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((inset, inset, size - inset - 1, size - inset - 1), fill=255)
    return mask


def circular_badge(seal: Image.Image, size: int = 512) -> Image.Image:
    content = fit_square(seal, size - 56)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    plate = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(plate)
    draw.ellipse((8, 8, size - 9, size - 9), fill=(255, 255, 255, 255))
    draw.ellipse((4, 4, size - 5, size - 5), outline=GOLD, width=3)
    draw.ellipse((10, 10, size - 11, size - 11), outline=(30, 45, 74, 255), width=2)
    out = Image.alpha_composite(out, plate)
    out.paste(content, (28, 28), content)
    alpha = out.split()[-1]
    out.putalpha(Image.composite(alpha, Image.new("L", (size, size), 0), circular_mask(size)))
    return out


def hero_variant(im: Image.Image, size: int = 880) -> Image.Image:
    im = fit_square(im, size)
    glow = ImageEnhance.Brightness(im.filter(ImageFilter.GaussianBlur(16))).enhance(1.12)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(glow, (0, 0), glow)
    return Image.alpha_composite(canvas, im)


def save_png(im: Image.Image, path: Path) -> None:
    im.save(path, "PNG", optimize=True)
    print(f"wrote {path.name} {im.size}")


def main() -> None:
    master = remove_near_white(Image.open(SRC_MASTER), threshold=246, soft=16)
    master = trim_transparent(master, pad=12)
    dark_master = add_gold_stroke(master, width=1)

    save_png(fit_square(dark_master, 800), ROOT / "logo-amenti.png")
    save_png(fit_square(master, 800), ROOT / "logo-amenti-light.png")
    save_png(hero_variant(dark_master, 880), ROOT / "logo-amenti-hero.png")
    save_png(hero_variant(dark_master, 880), ROOT / "logo-amenti-card.png")

    seal = remove_near_white(Image.open(SRC_SEAL), threshold=250, soft=12) if SRC_SEAL.exists() else master
    seal = trim_transparent(seal, pad=10)

    save_png(fit_square(seal, 512), ROOT / "insignia-sello.png")
    save_png(circular_badge(seal, 512), ROOT / "logo-amenti-badge.png")
    save_png(fit_square(seal, 256), ROOT / "logo-amenti-mark.png")

    fit_square(seal, 256).save(PUBLIC / "icon.png", "PNG", optimize=True)
    fit_square(seal, 512).save(PUBLIC / "apple-touch-icon.png", "PNG", optimize=True)
    print("wrote icon.png + apple-touch-icon.png")


if __name__ == "__main__":
    main()
