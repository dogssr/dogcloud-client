#!/usr/bin/env python3
"""Regenerates every platform icon from one square brand image.

    python3 tool/brand_icons.py assets_source/brand/icon.png

The source is full-bleed artwork, at least 1024 px. Android draws it as the
adaptive foreground over its own edge color, so a launcher mask only ever
trims the artwork's corners; the tray status icons are not touched.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / 'android/app/src/main/res'
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def rounded(image, size, radius_ratio, inset_ratio=0.0):
    """[image] scaled into a [size] canvas, inset and corner-rounded."""
    inner = round(size * (1 - 2 * inset_ratio))
    art = image.resize((inner, inner), Image.LANCZOS)
    mask = Image.new('L', (inner * 4, inner * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, inner * 4 - 1, inner * 4 - 1),
        radius=round(inner * 4 * radius_ratio),
        fill=255,
    )
    art.putalpha(mask.resize((inner, inner), Image.LANCZOS))
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    offset = (size - inner) // 2
    canvas.paste(art, (offset, offset), art)
    return canvas


def circle(image, size):
    art = image.resize((size, size), Image.LANCZOS)
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    art.putalpha(mask.resize((size, size), Image.LANCZOS))
    return art


def edge_color(image):
    rgb = image.convert('RGB').resize((64, 64), Image.LANCZOS)
    ring = [
        rgb.getpixel((x, y))
        for x in range(64)
        for y in range(64)
        if min(x, y, 63 - x, 63 - y) < 3
    ]
    return tuple(sum(channel) // len(ring) for channel in zip(*ring))


def android(image):
    color = '#%02X%02X%02X' % edge_color(image)
    (RES / 'values/ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">{color}</color>\n'
        '</resources>\n'
    )
    for name, scale in DENSITIES.items():
        size = round(48 * scale)
        mipmap = RES / f'mipmap-{name}'
        rounded(image, size, 0.18).save(mipmap / 'ic_launcher.webp', 'WEBP', quality=95)
        circle(image, size).save(mipmap / 'ic_launcher_round.webp', 'WEBP', quality=95)
        # The adaptive mask shows the middle 72 of the 108 dp layer.
        layer = round(108 * scale)
        drawable = RES / f'drawable-{name}'
        drawable.mkdir(exist_ok=True)
        rounded(image, layer, 0, inset_ratio=1 / 6).save(drawable / 'ic_launcher_foreground.png')
        # Android 12's splash draws a 288 dp layer and shows its middle 192.
        rounded(image, round(288 * scale), 0, inset_ratio=1 / 6).save(drawable / 'ic_splash.png')
        tv = RES / f'mipmap-television-{name}'
        if tv.exists():
            rounded(image, round(80 * scale), 0.18).save(tv / 'ic_launcher.webp', 'WEBP', quality=95)
    banner = Image.new('RGBA', (320, 180), edge_color(image) + (255,))
    logo = rounded(image, 140, 0.22)
    banner.paste(logo, ((320 - 140) // 2, (180 - 140) // 2), logo)
    banner.convert('RGB').save(RES / 'mipmap-xhdpi/ic_banner.png')


def macos(image):
    target = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for size in (16, 32, 64, 128, 256, 512, 1024):
        # Apple's grid: an 824 px rounded square on a 1024 px canvas.
        rounded(image, size, 0.225, inset_ratio=100 / 1024).save(target / f'app_icon_{size}.png')


def windows(image):
    icon = rounded(image, 256, 0.18)
    sizes = [(s, s) for s in (16, 24, 32, 48, 64, 128, 256)]
    icon.save(ROOT / 'windows/runner/resources/app_icon.ico', sizes=sizes)
    icon.save(ROOT / 'assets/images/icon.ico', sizes=sizes)


def app_assets(image):
    rounded(image, 550, 0.225).save(ROOT / 'assets/images/icon.png')


def main():
    source = Image.open(sys.argv[1] if len(sys.argv) > 1 else ROOT / 'assets_source/brand/icon.png')
    image = source.convert('RGBA')
    if image.width != image.height or image.width < 1024:
        sys.exit('brand icon must be square and at least 1024 px')
    android(image)
    macos(image)
    windows(image)
    app_assets(image)


if __name__ == '__main__':
    main()
