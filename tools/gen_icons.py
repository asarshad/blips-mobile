"""Generate all iOS app-icon sizes and splash assets from the latest exports.

Pipeline
--------
1. Flatten the transparent source PNGs onto correct background colours
   (iOS app icon grids require opaque images).
2. Resize the flattened Default icon into every required Icon-App-* size.
3. Copy the named dark / tinted 1024-px variants straight into the
   AppIcon.appiconset (used by iOS 16+ adaptive icon support).
4. Regenerate the three LaunchImage PNGs used by the splash screen.

Run from the project root:
    python3 tools/gen_icons.py
"""

import os
import shutil
from PIL import Image

# ── Paths ──────────────────────────────────────────────────────────────────────
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORTS = os.path.join(ROOT, "icons", "blips Exports")
FLATTENED = os.path.join(ROOT, "icons", "flattened")
APPICONSET = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)
LAUNCH_IMAGESET = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset"
)
LEGACY_SPLASH = os.path.join(ROOT, "assets", "splash", "splash_logo.png")

# ── Step 1: Flatten source PNGs ────────────────────────────────────────────────
print("── Step 1: Flattening source PNGs ──────────────────────────────────────")
os.makedirs(FLATTENED, exist_ok=True)

FLATTEN_SOURCES = {
    "blips-iOS-Default-1024x1024@1x.png": (255, 255, 255),
    "blips-iOS-Dark-1024x1024@1x.png": (0, 0, 0),
    "blips-iOS-TintedLight-1024x1024@1x.png": (255, 255, 255),
}

for name, fallback_bg in FLATTEN_SOURCES.items():
    src_path = os.path.join(EXPORTS, name)
    if not os.path.exists(src_path):
        print(f"  SKIP (not found): {name}")
        continue

    img = Image.open(src_path).convert("RGBA")
    w, h = img.size

    # Detect dominant opaque edge colour for background fill.
    edge_colors = []
    for y in range(h):
        for x in [0, w - 1]:
            p = img.getpixel((x, y))
            if p[3] > 200:
                edge_colors.append(p[:3])
    for x in range(w):
        for y in [0, h - 1]:
            p = img.getpixel((x, y))
            if p[3] > 200:
                edge_colors.append(p[:3])

    if edge_colors:
        r = sum(c[0] for c in edge_colors) // len(edge_colors)
        g = sum(c[1] for c in edge_colors) // len(edge_colors)
        b = sum(c[2] for c in edge_colors) // len(edge_colors)
        bg = (r, g, b)
    else:
        bg = fallback_bg

    background = Image.new("RGB", img.size, bg)
    background.paste(img, mask=img.split()[3])
    out_path = os.path.join(FLATTENED, name)
    background.save(out_path)
    print(f"  {name}  bg={bg}  center={background.getpixel((w//2, h//2))}")

# ── Step 2: Resize Default icon into all Icon-App-* sizes ─────────────────────
print("\n── Step 2: Resizing app icon sizes ─────────────────────────────────────")

default_src = os.path.join(FLATTENED, "blips-iOS-Default-1024x1024@1x.png")
base = Image.open(default_src).convert("RGB")

# (filename, pixel_size)
ICON_SIZES = [
    ("Icon-App-20x20@1x.png",      20),
    ("Icon-App-20x20@2x.png",      40),
    ("Icon-App-20x20@3x.png",      60),
    ("Icon-App-29x29@1x.png",      29),
    ("Icon-App-29x29@2x.png",      58),
    ("Icon-App-29x29@3x.png",      87),
    ("Icon-App-40x40@1x.png",      40),
    ("Icon-App-40x40@2x.png",      80),
    ("Icon-App-40x40@3x.png",     120),
    ("Icon-App-50x50@1x.png",      50),
    ("Icon-App-50x50@2x.png",     100),
    ("Icon-App-57x57@1x.png",      57),
    ("Icon-App-57x57@2x.png",     114),
    ("Icon-App-60x60@2x.png",     120),
    ("Icon-App-60x60@3x.png",     180),
    ("Icon-App-72x72@1x.png",      72),
    ("Icon-App-72x72@2x.png",     144),
    ("Icon-App-76x76@1x.png",      76),
    ("Icon-App-76x76@2x.png",     152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

for filename, px in ICON_SIZES:
    out = os.path.join(APPICONSET, filename)
    resized = base.resize((px, px), Image.LANCZOS)
    resized.save(out)
    print(f"  {filename}  ({px}×{px}px)")

# ── Step 3: Copy named 1024-px variants (dark / tinted) ───────────────────────
print("\n── Step 3: Copying named adaptive-icon variants ─────────────────────────")

NAMED_VARIANTS = [
    ("blips-iOS-Dark-1024x1024@1x.png",        "blips-iOS-Dark-1024x1024@1x.png"),
    ("blips-iOS-TintedLight-1024x1024@1x.png",  "blips-iOS-TintedLight-1024x1024@1x.png"),
]

for src_name, dst_name in NAMED_VARIANTS:
    src = os.path.join(EXPORTS, src_name)
    dst = os.path.join(APPICONSET, dst_name)
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f"  Copied {src_name}")
    else:
        print(f"  SKIP (not found): {src_name}")

# ── Step 4: Regenerate splash LaunchImage assets ───────────────────────────────
print("\n── Step 4: Regenerating splash screen assets ────────────────────────────")

# Use the transparent source for the splash (we want the rounded corners).
splash_src = os.path.join(EXPORTS, "blips-iOS-Default-1024x1024@1x.png")
splash_base = Image.open(splash_src).convert("RGBA")

LOGICAL_PT = 200
SPLASH_SCALES = {
    "1x": LOGICAL_PT * 1,   # 200 px
    "2x": LOGICAL_PT * 2,   # 400 px
    "3x": LOGICAL_PT * 3,   # 600 px
}
SPLASH_FILES = {
    "1x": os.path.join(LAUNCH_IMAGESET, "LaunchImage.png"),
    "2x": os.path.join(LAUNCH_IMAGESET, "LaunchImage@2x.png"),
    "3x": os.path.join(LAUNCH_IMAGESET, "LaunchImage@3x.png"),
}

for scale, px in SPLASH_SCALES.items():
    resized = splash_base.resize((px, px), Image.LANCZOS)
    out = SPLASH_FILES[scale]
    resized.save(out)
    print(f"  [{scale}] LaunchImage  {px}×{px}px  →  {LOGICAL_PT}pt logical")

# Legacy copy (used by Android splash / other consumers).
shutil.copy2(SPLASH_FILES["3x"], LEGACY_SPLASH)
print(f"  Legacy copy → {os.path.relpath(LEGACY_SPLASH, ROOT)}")

print("\n✓ All done.")
