"""Generate all iOS app-icon sizes and splash assets from the latest exports.

Pipeline
--------
1. Flatten the transparent source PNG onto a white background
   (iOS app icon grids require opaque images).
2. Copy pre-sized export files directly where pixel dimensions match exactly
   (best quality — exact rendering from the design tool).
3. Resize from the 1024-px source for the few sizes not in the export set.
4. Copy the named dark / tinted 1024-px variants from the legacy exports into
   the AppIcon.appiconset (used by iOS 16+ adaptive icon support).
5. Regenerate the three LaunchImage PNGs used by the splash screen.

Run from the project root:
    python3 tools/gen_icons.py
"""

import os
import shutil
from PIL import Image

# ── Paths ──────────────────────────────────────────────────────────────────────
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# New pre-sized exports — use these directly where available.
NEW_EXPORTS = os.path.join(ROOT, "assets", "Icon Exports")

# Legacy exports — still used for dark / tinted adaptive-icon variants.
LEGACY_EXPORTS = os.path.join(ROOT, "icons", "blips Exports")

FLATTENED = os.path.join(ROOT, "icons", "flattened")
APPICONSET = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)
LAUNCH_IMAGESET = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset"
)
LEGACY_SPLASH = os.path.join(ROOT, "assets", "splash", "splash_logo.png")

# ── Step 1: Flatten the 1024-px Default source ────────────────────────────────
print("── Step 1: Flattening 1024-px Default source ───────────────────────────")
os.makedirs(FLATTENED, exist_ok=True)

default_1024_src = os.path.join(NEW_EXPORTS, "Icon-iOS-Default-1024x1024@1x.png")
img1024 = Image.open(default_1024_src).convert("RGBA")
w, h = img1024.size

# Detect dominant opaque edge colour for background fill.
edge_colors = []
for y in range(h):
    for x in [0, w - 1]:
        p = img1024.getpixel((x, y))
        if p[3] > 200:
            edge_colors.append(p[:3])
for x in range(w):
    for y in [0, h - 1]:
        p = img1024.getpixel((x, y))
        if p[3] > 200:
            edge_colors.append(p[:3])

bg = tuple(sum(c[i] for c in edge_colors) // len(edge_colors) for i in range(3)) \
    if edge_colors else (255, 255, 255)

flat_1024 = Image.new("RGB", img1024.size, bg)
flat_1024.paste(img1024, mask=img1024.split()[3])
flat_1024_path = os.path.join(FLATTENED, "Icon-iOS-Default-1024x1024@1x.png")
flat_1024.save(flat_1024_path)
print(f"  Flattened 1024×1024  bg={bg}  center={flat_1024.getpixel((w//2, h//2))}")

# ── Step 2: Copy pre-sized exports directly ───────────────────────────────────
# These files already have the exact pixel dimensions needed; copying them
# preserves the renderer's sub-pixel anti-aliasing at each small size.
print("\n── Step 2: Copying pre-sized exports ───────────────────────────────────")

# (export_filename, target_Icon-App filename, expected_px)
DIRECT_COPIES = [
    ("Icon-iOS-Default-1024x1024@1x.png", "Icon-App-1024x1024@1x.png", 1024),
    ("Icon-iOS-Default-20x20@2x.png",     "Icon-App-20x20@2x.png",        40),
    ("Icon-iOS-Default-20x20@3x.png",     "Icon-App-20x20@3x.png",        60),
    # 40x40@1x == 20x20@2x (same 40 px)
    ("Icon-iOS-Default-20x20@2x.png",     "Icon-App-40x40@1x.png",        40),
    ("Icon-iOS-Default-29x29@2x.png",     "Icon-App-29x29@2x.png",        58),
    ("Icon-iOS-Default-29x29@3x.png",     "Icon-App-29x29@3x.png",        87),
    ("Icon-iOS-Default-40x40@2x.png",     "Icon-App-40x40@2x.png",        80),
    ("Icon-iOS-Default-40x40@3x.png",     "Icon-App-40x40@3x.png",       120),
    # 57x57@2x == 38x38@3x (both 114 px)
    ("Icon-iOS-Default-38x38@3x.png",     "Icon-App-57x57@2x.png",       114),
    ("Icon-iOS-Default-60x60@2x.png",     "Icon-App-60x60@2x.png",       120),
    ("Icon-iOS-Default-60x60@3x.png",     "Icon-App-60x60@3x.png",       180),
    # 76x76@1x == 38x38@2x (both 76 px)
    ("Icon-iOS-Default-38x38@2x.png",     "Icon-App-76x76@1x.png",        76),
    ("Icon-iOS-Default-76x76@2x.png",     "Icon-App-76x76@2x.png",       152),
    ("Icon-iOS-Default-83.5x83.5@2x.png", "Icon-App-83.5x83.5@2x.png",  167),
]

copied_targets = set()
for src_name, dst_name, expected_px in DIRECT_COPIES:
    src = os.path.join(NEW_EXPORTS, src_name)
    dst = os.path.join(APPICONSET, dst_name)
    if not os.path.exists(src):
        print(f"  SKIP (not found): {src_name}")
        continue
    img = Image.open(src)
    actual_px = img.size[0]
    if actual_px != expected_px:
        print(f"  WARN: {src_name} is {actual_px}px, expected {expected_px}px — skipping")
        continue
    shutil.copy2(src, dst)
    copied_targets.add(dst_name)
    print(f"  {dst_name}  ({actual_px}×{actual_px}px)  ← {src_name}")

# ── Step 3: Resize from 1024-px source for remaining sizes ────────────────────
print("\n── Step 3: Resizing remaining sizes from 1024-px source ─────────────────")

base = Image.open(flat_1024_path).convert("RGB")

# (filename, pixel_size) — only sizes not covered by direct copies above.
RESIZE_SIZES = [
    ("Icon-App-20x20@1x.png",  20),
    ("Icon-App-29x29@1x.png",  29),
    ("Icon-App-50x50@1x.png",  50),
    ("Icon-App-50x50@2x.png", 100),
    ("Icon-App-57x57@1x.png",  57),
    ("Icon-App-72x72@1x.png",  72),
    ("Icon-App-72x72@2x.png", 144),
]

for filename, px in RESIZE_SIZES:
    if filename in copied_targets:
        print(f"  SKIP (already copied): {filename}")
        continue
    out = os.path.join(APPICONSET, filename)
    resized = base.resize((px, px), Image.LANCZOS)
    resized.save(out)
    print(f"  {filename}  ({px}×{px}px)  ← resized from 1024-px source")

# ── Step 4: Copy named adaptive-icon variants (dark / tinted) ─────────────────
print("\n── Step 4: Copying named adaptive-icon variants ─────────────────────────")

NAMED_VARIANTS = [
    ("blips-iOS-Dark-1024x1024@1x.png",       "blips-iOS-Dark-1024x1024@1x.png"),
    ("blips-iOS-TintedLight-1024x1024@1x.png", "blips-iOS-TintedLight-1024x1024@1x.png"),
]

for src_name, dst_name in NAMED_VARIANTS:
    src = os.path.join(LEGACY_EXPORTS, src_name)
    dst = os.path.join(APPICONSET, dst_name)
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f"  Copied {src_name}")
    else:
        print(f"  SKIP (not found): {src_name}")

# ── Step 5: Regenerate splash LaunchImage assets ──────────────────────────────
print("\n── Step 5: Regenerating splash screen assets ────────────────────────────")

# Use the transparent new export for the splash (preserves rounded corners).
splash_src = os.path.join(NEW_EXPORTS, "Icon-iOS-Default-1024x1024@1x.png")
splash_base = Image.open(splash_src).convert("RGBA")

LOGICAL_PT = 120
SPLASH_SCALES = {
    "1x": LOGICAL_PT * 1,   # 120 px
    "2x": LOGICAL_PT * 2,   # 240 px
    "3x": LOGICAL_PT * 3,   # 360 px
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
