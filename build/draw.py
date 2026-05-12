from PIL import Image, ImageDraw
from pathlib import Path
import math

dst = Path("resources/drawables")
dst.mkdir(parents=True, exist_ok=True)
SIZE = 28
STROKE = 2
COLOR = (245, 240, 232, 255)  # Theme.COLOR_TEXT

# All geometry is fractions of SIZE so the icons scale cleanly.
def fx(f): return int(SIZE * f)

def new_canvas():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def sun_disk(d, cx, cy, r):
    d.ellipse((cx-r, cy-r, cx+r, cy+r), outline=COLOR, width=STROKE)

def ray(d, cx, cy, r_in, r_out, deg):
    a = math.radians(deg)
    x1 = cx + r_in * math.cos(a); y1 = cy + r_in * math.sin(a)
    x2 = cx + r_out * math.cos(a); y2 = cy + r_out * math.sin(a)
    d.line((x1, y1, x2, y2), fill=COLOR, width=STROKE)

def horizon(d, y, pad=2):
    d.line((pad, y, SIZE - pad, y), fill=COLOR, width=STROKE)

def crescent(cx, cy, r):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    full = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(full).ellipse((cx-r, cy-r, cx+r, cy+r), fill=COLOR)
    cut = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ox = int(r * 0.45)
    ImageDraw.Draw(cut).ellipse((cx-r+ox, cy-r-1, cx+r+ox, cy+r-1), fill=COLOR)
    # Subtract cut from full
    rgba_full = full.load(); rgba_cut = cut.load()
    out = full.copy()
    rgba_out = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if rgba_cut[x, y][3] > 0:
                rgba_out[x, y] = (0, 0, 0, 0)
    return out

# --- Fajr — sun on horizon, rays radiating upward ---
def make_fajr():
    img, d = new_canvas()
    cx = SIZE // 2
    horizon_y = fx(0.68)
    r = fx(0.18)
    sun_disk(d, cx, horizon_y, r)
    # mask out below horizon
    d.rectangle((0, horizon_y + 1, SIZE, SIZE), fill=(0, 0, 0, 0))
    horizon(d, horizon_y)
    for deg in (-90, -45, -135):
        ray(d, cx, horizon_y, r + 2, r + fx(0.18), deg)
    img.save(dst / "icon_fajr.png")

# --- Sunrise — sun fully up, with horizon line below ---
def make_sunrise():
    img, d = new_canvas()
    cx = SIZE // 2
    cy = fx(0.45)
    r = fx(0.18)
    sun_disk(d, cx, cy, r)
    horizon(d, fx(0.85))
    for deg in (-90, -45, -135, 0, 180):
        ray(d, cx, cy, r + 2, r + fx(0.18), deg)
    img.save(dst / "icon_sunrise.png")

# --- Dhuhr — high sun, 8 rays ---
def make_dhuhr():
    img, d = new_canvas()
    cx = cy = SIZE // 2
    r = fx(0.20)
    sun_disk(d, cx, cy, r)
    for i in range(8):
        ray(d, cx, cy, r + 2, r + fx(0.20), i * 45)
    img.save(dst / "icon_dhuhr.png")

# --- Asr — sun + slanted shadow line ---
def make_asr():
    img, d = new_canvas()
    cx = SIZE // 2
    cy = fx(0.40)
    r = fx(0.18)
    sun_disk(d, cx, cy, r)
    for deg in (-90, -45, -135, 0, 180, 45, 135):
        ray(d, cx, cy, r + 2, r + fx(0.16), deg)
    # shadow line slanting right
    d.line((fx(0.18), fx(0.78), fx(0.82), fx(0.78)), fill=COLOR, width=STROKE)
    img.save(dst / "icon_asr.png")

# --- Maghrib — sun setting below horizon, arrow down ---
def make_maghrib():
    img, d = new_canvas()
    cx = SIZE // 2
    horizon_y = fx(0.50)
    r = fx(0.18)
    sun_disk(d, cx, horizon_y - 2, r)
    # mask below horizon
    d.rectangle((0, horizon_y + 1, SIZE, SIZE), fill=(0, 0, 0, 0))
    horizon(d, horizon_y)
    # rays around upper half
    for deg in (-90, -45, -135, 0, 180):
        ray(d, cx, horizon_y - 2, r + 2, r + fx(0.16), deg)
    img.save(dst / "icon_maghrib.png")

# --- Isha — crescent + small star ---
def make_isha():
    img = crescent(SIZE // 2 - 1, SIZE // 2, fx(0.30))
    dd = ImageDraw.Draw(img)
    # star top-right (4-point plus)
    sx, sy = fx(0.85), fx(0.18)
    dd.line((sx - 3, sy, sx + 3, sy), fill=COLOR, width=STROKE)
    dd.line((sx, sy - 3, sx, sy + 3), fill=COLOR, width=STROKE)
    img.save(dst / "icon_isha.png")

# --- Tahajjud — crescent + multiple stars ---
def make_tahajjud():
    img = crescent(SIZE // 2, SIZE // 2 + 1, fx(0.26))
    dd = ImageDraw.Draw(img)
    for (sx, sy) in [(fx(0.18), fx(0.18)), (fx(0.85), fx(0.30)), (fx(0.20), fx(0.78))]:
        dd.line((sx - 2, sy, sx + 2, sy), fill=COLOR, width=STROKE)
        dd.line((sx, sy - 2, sx, sy + 2), fill=COLOR, width=STROKE)
    img.save(dst / "icon_tahajjud.png")

make_fajr(); make_sunrise(); make_dhuhr(); make_asr()
make_maghrib(); make_isha(); make_tahajjud()
print("done")
