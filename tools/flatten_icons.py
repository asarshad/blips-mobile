"""Flatten iOS icon PNGs by compositing RGBA sources onto opaque backgrounds."""
from PIL import Image
import os

src_dir = "icons/blips Exports"
out_dir = "icons/flattened"
os.makedirs(out_dir, exist_ok=True)

files = {
    "blips-iOS-Default-1024x1024@1x.png": (255, 255, 255),
    "blips-iOS-Dark-1024x1024@1x.png": (0, 0, 0),
    "blips-iOS-TintedLight-1024x1024@1x.png": (255, 255, 255),
}

for name, fallback_bg in files.items():
    path = os.path.join(src_dir, name)
    if not os.path.exists(path):
        print(f"SKIP: {name} not found")
        continue

    img = Image.open(path).convert("RGBA")
    w, h = img.size

    # Detect dominant opaque edge color
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
        print(f"{name}: detected edge bg {bg}")
    else:
        bg = fallback_bg
        print(f"{name}: no opaque edges, fallback bg {bg}")

    background = Image.new("RGB", img.size, bg)
    background.paste(img, mask=img.split()[3])
    out_path = os.path.join(out_dir, name)
    background.save(out_path)

    check = Image.open(out_path)
    print(f"  -> {out_path}  mode={check.mode}  center={check.getpixel((w//2, h//2))}  corner={check.getpixel((0,0))}")

print("\nDone. Update pubspec.yaml image_path entries to point at icons/flattened/ then re-run flutter_launcher_icons.")
