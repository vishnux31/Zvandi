import os
from PIL import Image

SRC = r"C:\Users\ASUS\.cursor\projects\c-Projects-MyBike\assets\app_icon.png"
OUT_DIR = r"C:\Projects\MyBike\assets\icon"
os.makedirs(OUT_DIR, exist_ok=True)

BG = (192, 73, 43)  # brand deep orange-red (#C0492B)
SIZE = 1024

img = Image.open(SRC).convert("RGBA")

# 1) Square, full-bleed icon: fit source onto a solid BG square.
square = Image.new("RGBA", (SIZE, SIZE), BG + (255,))
w, h = img.size
scale = SIZE / max(w, h)
nw, nh = int(w * scale), int(h * scale)
resized = img.resize((nw, nh), Image.LANCZOS)
square.paste(resized, ((SIZE - nw) // 2, (SIZE - nh) // 2), resized)
square.convert("RGB").save(os.path.join(OUT_DIR, "app_icon.png"))

# 2) Adaptive foreground: white bike on transparent bg, with safe padding.
# Color-key the orange background to transparent, then scale down to ~58%.
keyed = square.copy()
px = keyed.load()
tol = 70
for y in range(SIZE):
    for x in range(SIZE):
        r, g, b, a = px[x, y]
        if abs(r - BG[0]) < tol and abs(g - BG[1]) < tol and abs(b - BG[2]) < tol:
            px[x, y] = (0, 0, 0, 0)

# Crop to the non-transparent bounding box, then center on padded canvas.
bbox = keyed.getbbox()
content = keyed.crop(bbox) if bbox else keyed
target = int(SIZE * 0.58)
cw, ch = content.size
cscale = target / max(cw, ch)
content = content.resize((max(1, int(cw * cscale)), max(1, int(ch * cscale))), Image.LANCZOS)
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fg.paste(content, ((SIZE - content.size[0]) // 2, (SIZE - content.size[1]) // 2), content)
fg.save(os.path.join(OUT_DIR, "app_icon_foreground.png"))

print("WROTE", os.listdir(OUT_DIR))
