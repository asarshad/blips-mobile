"""Resize the rounded-corner app icon to use as the splash logo."""
from PIL import Image

src = "icons/blips Exports/blips-iOS-Default-1024x1024@1x.png"
dst = "assets/splash/splash_logo.png"
size = 768  # bigger than the old 400px; appears ~256px logical on 3× displays

img = Image.open(src).convert("RGBA")
img = img.resize((size, size), Image.LANCZOS)
img.save(dst)

check = Image.open(dst)
print(f"Saved {dst}  {check.size}  mode={check.mode}")
print(f"  corner={check.getpixel((0,0))}  (should be transparent)")
print(f"  center={check.getpixel((size//2, size//2))}  (should be orange)")
