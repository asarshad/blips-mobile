"""Resize the rounded-corner app icon to use as the splash logo.

Generates 1×/2×/3× PNG variants for the iOS xcassets LaunchImage imageset
at a logical size of 200 pt, which looks balanced on all modern iPhones.
"""
from PIL import Image

src = "icons/blips Exports/blips-iOS-Default-1024x1024@1x.png"

# Logical size 200 pt → 200 / 400 / 600 px for 1×/2×/3×
LOGICAL_PT = 200
SCALES = {
    "1x": LOGICAL_PT * 1,   # 200 px
    "2x": LOGICAL_PT * 2,   # 400 px
    "3x": LOGICAL_PT * 3,   # 600 px
}

XCASSETS_DIR = "ios/Runner/Assets.xcassets/LaunchImage.imageset"
ASSET_MAP = {
    "1x": f"{XCASSETS_DIR}/LaunchImage.png",
    "2x": f"{XCASSETS_DIR}/LaunchImage@2x.png",
    "3x": f"{XCASSETS_DIR}/LaunchImage@3x.png",
}
# Also update the source asset used by Android / other consumers
LEGACY_DST = "assets/splash/splash_logo.png"

base = Image.open(src).convert("RGBA")

for scale, px in SCALES.items():
    resized = base.resize((px, px), Image.LANCZOS)
    out = ASSET_MAP[scale]
    resized.save(out)
    check = Image.open(out)
    print(f"[{scale}] Saved {out}  {check.size}  ({px}px → {LOGICAL_PT}pt logical)")
    print(f"       corner={check.getpixel((0, 0))}  (should be transparent)")
    print(f"       center={check.getpixel((px // 2, px // 2))}  (should be orange)")

# Keep a single legacy copy for backward compat (use the 3× version)
import shutil
shutil.copy(ASSET_MAP["3x"], LEGACY_DST)
print(f"\nLegacy copy saved to {LEGACY_DST}")
print(f"Logical size: {LOGICAL_PT} pt on all densities.")
