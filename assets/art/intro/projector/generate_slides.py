"""Generates the intro projector slides (slide_1..3.png, 256x144 pixel art).
Run from this folder: python3 generate_slides.py (needs Pillow)."""
import random
from PIL import Image, ImageDraw
W, H = 256, 144
OUT = (13, 15, 26)

def sky(d, top, bottom, bands=9):
    for i in range(bands):
        t = i / (bands - 1)
        c = tuple(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3))
        y0 = int(H * i / bands); y1 = int(H * (i + 1) / bands)
        d.rectangle([0, y0, W, y1], fill=c)

def skyline(d, rng, base, color, win, minh, maxh, density=0.25):
    x = 0
    while x < W:
        w = rng.randint(10, 22); h = rng.randint(minh, maxh)
        d.rectangle([x, base - h, x + w, base], fill=color)
        if rng.random() < 0.3:
            d.rectangle([x + w // 2, base - h - 6, x + w // 2 + 1, base - h], fill=color)
        for wy in range(base - h + 4, base - 3, 5):
            for wx in range(x + 2, x + w - 2, 4):
                if rng.random() < density:
                    d.rectangle([wx, wy, wx + 1, wy + 1], fill=win)
        x += w + rng.randint(0, 3)

def robot(d, x, y, s=1, body=(63, 95, 143), eye=(232, 64, 42)):
    # small boxy robot, feet at (x, y); s = scale
    def r(a, b, c, e, col): d.rectangle([x + a * s, y - e * s, x + c * s, y - b * s], fill=col)
    r(-4, 0, -2, 4, OUT); r(2, 0, 4, 4, OUT)          # legs
    r(-5, 4, 5, 13, OUT); r(-4, 5, 4, 12, body)       # torso
    r(-3, 7, 3, 10, (42, 58, 92))                     # chest panel
    r(-4, 13, 4, 19, OUT); r(-3, 14, 3, 18, body)     # head
    r(-2, 16, 2, 17, eye)                             # visor
    r(0, 19, 0, 22, OUT); r(-1, 22, 1, 23, eye)       # antenna

def scan(img):
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(0, H, 2):
        d.line([0, y, W, y], fill=(0, 0, 0, 28))
    return img

# 1. The factory: JARVIS's eye over endless production lines.
rng = random.Random(1)
img = Image.new("RGB", (W, H)); d = ImageDraw.Draw(img)
sky(d, (24, 18, 44), (60, 30, 70))
for i in range(6):  # factory pillars
    x = 10 + i * 44
    d.rectangle([x, 0, x + 6, H], fill=(34, 32, 58)); d.rectangle([x + 1, 0, x + 1, H], fill=(52, 50, 84))
cx, cy = 128, 34  # giant eye
d.ellipse([cx - 30, cy - 18, cx + 30, cy + 18], fill=OUT)
d.ellipse([cx - 27, cy - 15, cx + 27, cy + 15], fill=(42, 58, 92))
d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(232, 64, 42))
d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(255, 210, 63))
d.rectangle([cx - 8, cy - 8, cx - 6, cy - 6], fill=(255, 255, 255))
d.polygon([(cx - 14, cy + 10), (cx - 120, H), (cx + 120, H), (cx + 14, cy + 10)], fill=(232, 64, 42))
img2 = img.copy(); img = Image.blend(img, img2, 1)  # (keep)
d = ImageDraw.Draw(img, "RGBA")
d.polygon([(cx - 14, cy + 10), (cx - 120, H), (cx + 120, H), (cx + 14, cy + 10)], fill=(24, 18, 44, 200))
for row, (yy, s) in enumerate([(98, 1), (122, 1), (143, 2)]):  # conveyor belts with robots
    d.rectangle([0, yy, W, yy + 3], fill=OUT); d.rectangle([0, yy + 1, W, yy + 1], fill=(255, 138, 31))
    for x in range(8 + row * 7, W, 18 * s):
        robot(d, x, yy, s)
scan(img).save("slide_1.png")

# 2. The march: robot army in the neon streets, humans fleeing.
rng = random.Random(2)
img = Image.new("RGB", (W, H)); d = ImageDraw.Draw(img)
sky(d, (40, 22, 70), (232, 112, 60))
skyline(d, rng, 110, (58, 38, 92), (255, 138, 31), 40, 80, 0.2)
skyline(d, rng, 120, (30, 26, 52), (255, 43, 214), 25, 60, 0.3)
d.rectangle([0, 120, W, H], fill=(20, 20, 34))
for x in range(0, W, 16):
    d.rectangle([x, 131, x + 7, 132], fill=(255, 210, 63))
for i, x in enumerate(range(150, W, 13)):  # army from the right
    robot(d, x + (i % 2) * 4, 128 + (i % 2) * 8, 1 + (i % 3 == 0))
for x in (40, 58, 80):  # tiny fleeing humans
    d.rectangle([x, 122, x + 1, 128], fill=(240, 200, 170)); d.rectangle([x - 1, 128, x + 2, 132], fill=(80, 140, 220))
d = ImageDraw.Draw(img, "RGBA")
d.polygon([(232, 0), (250, 0), (70, 122), (40, 122)], fill=(255, 240, 180, 45))  # drone searchlight
scan(img).save("slide_2.png")

# 3. The giant: one huge robot over a burning city, eyes on you.
rng = random.Random(3)
img = Image.new("RGB", (W, H)); d = ImageDraw.Draw(img)
sky(d, (60, 10, 20), (232, 64, 42))
gx = 128
d.rectangle([gx - 40, 40, gx + 40, H], fill=OUT)                 # body
d.rectangle([gx - 37, 43, gx + 37, H], fill=(42, 58, 92))
d.rectangle([gx - 26, 8, gx + 26, 44], fill=OUT)                 # head
d.rectangle([gx - 23, 11, gx + 23, 41], fill=(63, 95, 143))
d.rectangle([gx - 18, 20, gx - 6, 26], fill=(255, 43, 43)); d.rectangle([gx + 6, 20, gx + 18, 26], fill=(255, 43, 43))
d.rectangle([gx - 14, 33, gx + 14, 36], fill=OUT)
for k in range(5):
    d.rectangle([gx - 12 + k * 6, 33, gx - 10 + k * 6, 36], fill=(255, 138, 31))
for sx in (-1, 1):  # shoulders + arms reaching down
    d.rectangle([gx + sx * 40 - (30 if sx < 0 else 0), 44, gx + sx * 40 + (0 if sx < 0 else 30), 58], fill=OUT)
    ax = gx + sx * 62
    d.rectangle([ax - 8, 44, ax + 8, 120], fill=OUT); d.rectangle([ax - 5, 47, ax + 5, 117], fill=(63, 95, 143))
    d.rectangle([ax - 10, 112, ax + 10, 124], fill=OUT); d.rectangle([ax - 7, 115, ax + 7, 121], fill=(232, 64, 42))
d.rectangle([gx - 30, 60, gx + 30, 90], fill=(31, 42, 70))
d.ellipse([gx - 10, 64, gx + 10, 84], fill=(255, 210, 63))     # core
skyline(d, rng, H, (24, 12, 20), (255, 138, 31), 15, 45, 0.25)
for _ in range(14):  # fires
    x = rng.randint(0, W); y = rng.randint(110, 135)
    d.polygon([(x, y), (x - 3, y + 8), (x + 3, y + 8)], fill=(255, 210, 63))
scan(img).save("slide_3.png")
print("ok")
