"""Generates the built-in Volt Launcher wallpapers (1920x1080 JPEG).

Usage: python tool/generate_wallpapers.py assets/wallpapers   (needs numpy and pillow)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

W, H = 1920, 1080
OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7)

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = xx / W, yy / H


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def rgb(hex_color):
    return np.array([int(hex_color[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)


def vertical(top, bottom, curve=1.0):
    return lerp(rgb(top), rgb(bottom), v ** curve)


def smooth_noise(scale, octaves=4):
    total = np.zeros((H, W), np.float32)
    amp, freq = 1.0, scale
    for _ in range(octaves):
        small = rng.random((max(2, int(H / freq)), max(2, int(W / freq)))).astype(np.float32)
        layer = np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255
        total += layer * amp
        amp *= 0.5
        freq /= 2
    return total / total.max()


def glow(img, cx, cy, radius, color, strength):
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
    return img + rgb(color) * (np.exp(-d ** 2) * strength / 100)[..., None]


def save(name, img, blur=0, grain=3.0):
    img = img + rng.normal(0, grain, img.shape)  # light grain avoids banding on TVs
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    if blur:
        out = out.filter(ImageFilter.GaussianBlur(blur))
    out.save(OUT / f"{name}.jpg", quality=86, optimize=True, progressive=True)


def ridge(base_y, amplitude, roughness):
    profile = np.zeros(W, np.float32)
    for k, a in enumerate([1, .5, .25, .12, .06][:roughness]):
        freq = 2 ** k * 1.5
        profile += a * np.sin(np.linspace(0, freq * np.pi, W) + rng.random() * 6) + a * .4 * rng.standard_normal(W).cumsum() / np.sqrt(W)
    profile = (profile - profile.min()) / (np.ptp(profile) + 1e-6)
    return base_y - profile * amplitude


# 1. Aurora: green/teal curtains over a night sky
img = vertical("#020713", "#0a1a2e", 1.2)
for cx, color, width in [(0.3, "#2bd99f", 0.06), (0.55, "#19b5c9", 0.05), (0.75, "#7b5cff", 0.07)]:
    wave = cx + 0.08 * np.sin(v * 5 + cx * 9) + 0.03 * np.sin(v * 13)
    band = np.exp(-((u - wave) / width) ** 2) * np.clip(1.2 - v * 1.3, 0, 1) * (0.6 + 0.4 * smooth_noise(160))
    img += rgb(color) * band[..., None] * 0.9
stars = (rng.random((H, W)) > 0.9993) * rng.uniform(120, 255, (H, W)) * np.clip(1 - v * 1.4, 0, 1)
img += stars[..., None]
save("aurora", img, blur=1)

# 2. Mountains: layered ridges at dusk
img = vertical("#1b1f4a", "#f08a5d", 1.6)
img = glow(img, W * 0.7, H * 0.6, 170, "#ffd59a", 55)
img = glow(img, W * 0.7, H * 0.6, 420, "#ff9a6a", 25)
for i, (base, amp, color) in enumerate([(0.62, 220, "#3b3566"), (0.72, 200, "#2a2650"), (0.82, 170, "#1c1a3a"), (0.93, 140, "#0f0e22")]):
    top = ridge(H * base, amp, 4)
    mask = yy >= top[None, :]
    img[mask] = rgb(color)
save("mountains", img, blur=1.2)

# 3. Ocean: deep blue waves
img = vertical("#03122b", "#0a4f7a", 0.9)
waves = np.sin(u * 22 + np.sin(v * 9) * 1.6 + v * 30) * 0.5 + 0.5
img += rgb("#2ec5ff") * (waves ** 6 * v * 0.35)[..., None] * 255 / 255 * 0.6
img = glow(img, W * 0.5, -150, 800, "#7fd3ff", 22)
save("ocean", img, blur=2)

# 4. Nebula: cosmic clouds in purple and pink
n1, n2 = smooth_noise(220, 5), smooth_noise(130, 5)
img = np.full((H, W, 3), rgb("#05030f"))
img += rgb("#8a2be2") * (n1 ** 2.2)[..., None] * 1.1
img += rgb("#ff4f9a") * (np.clip(n2 - 0.45, 0, 1) ** 1.5)[..., None] * 1.6
img += rgb("#3a7bff") * (np.clip(n1 * n2 - 0.3, 0, 1))[..., None] * 1.4
stars = (rng.random((H, W)) > 0.998) * rng.uniform(100, 255, (H, W))
img += stars[..., None]
save("nebula", img, blur=0.8)

# 5. Sunset dunes: warm sand curves
img = vertical("#ff9a5a", "#7a2e3a", 1.0)
img = glow(img, W * 0.3, H * 0.28, 110, "#fff1c9", 60)
img = glow(img, W * 0.3, H * 0.28, 320, "#ffc070", 25)
for base, amp, color in [(0.58, 90, "#c0623f"), (0.7, 110, "#9a4434"), (0.84, 120, "#6e2f2e")]:
    top = H * base - amp * (np.sin(np.linspace(0, 2.4 * np.pi, W) + base * 10) * 0.5 + 0.5)
    mask = yy >= top[None, :]
    shade = np.clip((yy - top[None, :]) / 260, 0, 1)
    img[mask] = (lerp(rgb(color) * 1.15, rgb(color) * 0.75, shade))[mask]
save("dunes", img, blur=1.5)

# 6. Bokeh: soft out-of-focus lights
img = vertical("#0b0c1f", "#1d1236", 1.0)
light = np.zeros((H, W), np.float32)
colors = ["#ff8a65", "#ffd54f", "#4fc3f7", "#ba68c8", "#81c784"]
for _ in range(70):
    cx, cy, r = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(25, 120)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    disc = np.clip((r - d) / 6, 0, 1) * rng.uniform(0.15, 0.45)
    img += rgb(colors[rng.integers(len(colors))]) * disc[..., None]
save("bokeh", img, blur=6)

# 7. Forest mist: dark green layers fading into fog
img = vertical("#cfd9d6", "#1d3b34", 1.3)
for base, amp, color in [(0.45, 160, "#6f8f86"), (0.58, 180, "#4c6e64"), (0.72, 200, "#2d4d44"), (0.88, 220, "#14281f")]:
    top = ridge(H * base, amp * 0.6, 3)
    tips = np.abs(np.sin(np.linspace(0, W / 14 * np.pi, W) + rng.random() * 6)) ** 6 * 26
    trees = top - tips
    mask = yy >= trees[None, :]
    img[mask] = rgb(color)[None, :] * np.ones_like(img[mask])
save("forest", img, blur=1.5)

# 8. Volt: flowing light lines on deep indigo
img = vertical("#0b1026", "#2a1650", 1.0)
lines = np.zeros((H, W), np.float32)
for k in range(14):
    ux = np.linspace(0, 1, W)
    y0 = H * (0.25 + 0.04 * k) + 160 * np.sin(ux * 3.2 + k * 0.35) + 60 * np.sin(ux * 7 + k)
    lines += np.exp(-((yy - y0[None, :]) / 2.2) ** 2) * (0.35 + 0.65 * (k % 3 == 0))
img += lerp(rgb("#4f7bff"), rgb("#d14dff"), u)[...] * lines[..., None] * 0.9
img = glow(img, W * 0.75, H * 0.45, 420, "#6b3cff", 25)
save("volt", img, blur=0.6)

for f in sorted(OUT.glob("*.jpg")):
    print(f.name, f.stat().st_size // 1024, "KB")


# ---------------------------------------------------------------------------
# Fjord set, used by the "Time of day" mode (morning, day, evening, night)

def fjord(name, sky_top, sky_bottom, sun, sun_color, mountain_colors, water_tint, aurora=False, stars=False):
    horizon = int(H * 0.62)
    img = vertical(sky_top, sky_bottom, 1.1)
    if sun:
        img = glow(img, W * sun[0], H * sun[1], 90, sun_color, 70)
        img = glow(img, W * sun[0], H * sun[1], 380, sun_color, 22)
    if stars:
        s = (rng.random((H, W)) > 0.9985) * rng.uniform(120, 255, (H, W))
        img += s[..., None] * (v < 0.6)[..., None]
    if aurora:
        for cx, color, width in [(0.35, "#36e6a6", 0.07), (0.6, "#2ad1c0", 0.05)]:
            wave = cx + 0.1 * np.sin(v * 6 + cx * 8)
            band = np.exp(-((u - wave) / width) ** 2) * np.clip(0.75 - v * 1.2, 0, 1) * (0.6 + 0.4 * smooth_noise(150))
            img += rgb(color) * band[..., None]

    # Mountains slope down towards the middle, like a fjord seen from the water
    xs = np.linspace(-1, 1, W)
    for depth, color in enumerate(mountain_colors):
        valley = np.abs(xs) ** (1.4 - depth * 0.15)
        height = (0.12 + 0.30 * valley) * H * (1 - depth * 0.18)
        top = horizon - height - ridge(0, 40 - depth * 8, 4)
        mask = (yy >= top[None, :]) & (yy < horizon)
        img[mask] = rgb(color)

    # Water: mirror the scene, darken it and add soft ripples
    above = img[:horizon][::-1]
    reflection = above[: H - horizon].copy()
    ripple = (np.sin(np.arange(H - horizon)[:, None] * 0.9 + rng.random() * 6) * 0.5 + 0.5) * 0.15
    reflection = reflection * (0.55 - ripple[..., None] * 0) + rgb(water_tint) * 0.25
    shift = (np.sin(np.arange(H - horizon) * 0.35) * 6).astype(int)
    for row, dx in enumerate(shift):
        reflection[row] = np.roll(reflection[row], dx, axis=0)
    img[horizon:] = reflection
    save(name, img, blur=1.2)


fjord("fjord_morning", "#5b6fa8", "#f6c59a", (0.5, 0.58), "#ffe0b0",
      ["#7c7aa0", "#5a5880", "#3d3c5c"], "#3a4a7a")
fjord("fjord_day", "#2f7fd6", "#bfe3ff", (0.78, 0.18), "#ffffff",
      ["#5f8fa8", "#3f6f86", "#274e60"], "#1d5d8a")
fjord("fjord_evening", "#2a1d4f", "#ff8a4a", (0.42, 0.6), "#ffb36b",
      ["#5a2f55", "#3e2142", "#26142c"], "#40203a")
fjord("fjord_night", "#01040d", "#0b1d33", None, "#000000",
      ["#0f1c2b", "#0a1420", "#060c14"], "#06101c", aurora=True, stars=True)

# ---------------------------------------------------------------------------
# More wallpapers

# City at night: skyline with lit windows
img = vertical("#070a1a", "#2a1e4a", 1.3)
img = glow(img, W * 0.5, H * 0.95, 700, "#ff7a59", 18)
x = 0
while x < W:
    bw, bh = int(rng.uniform(60, 170)), int(rng.uniform(180, 620))
    top = H - bh
    img[top:, x:x + bw] = rgb("#0a0c18")
    for wy in range(top + 14, H - 10, 22):
        for wx in range(x + 8, x + bw - 10, 18):
            if rng.random() < 0.35:
                img[wy:wy + 9, wx:wx + 8] = rgb(["#ffd27a", "#ffe9b0", "#9fd3ff"][rng.integers(3)])
    x += bw + int(rng.uniform(0, 12))
save("city_night", img, blur=0.6)

# Milky way: dense star band across a dark sky
band = np.exp(-((v - (0.25 + 0.5 * u)) / 0.12) ** 2)
img = vertical("#02030a", "#0b0f24", 1.0)
img += rgb("#8a7cff") * (band * smooth_noise(90, 5) ** 2 * 0.55)[..., None]
img += rgb("#ffcf9a") * (band * np.clip(smooth_noise(60, 5) - 0.5, 0, 1) * 0.9)[..., None]
dense = (rng.random((H, W)) > (0.9992 - band * 0.006)) * rng.uniform(120, 255, (H, W))
img += dense[..., None]
save("milky_way", img, blur=0.5, grain=2)

# Low-poly: flat-shaded triangles in blue/purple
cell = 120
pts_y, pts_x = np.mgrid[-1:H // cell + 2, -1:W // cell + 2]
jitter = rng.uniform(-0.4, 0.4, (2,) + pts_x.shape) * cell
px, py = pts_x * cell + jitter[0], pts_y * cell + jitter[1]
img = np.zeros((H, W, 3), np.float32)
from PIL import ImageDraw
canvas = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(canvas)
for j in range(px.shape[0] - 1):
    for i in range(px.shape[1] - 1):
        a, b, c, d = (px[j, i], py[j, i]), (px[j, i + 1], py[j, i + 1]), (px[j + 1, i], py[j + 1, i]), (px[j + 1, i + 1], py[j + 1, i + 1])
        for tri in ((a, b, c), (b, d, c)):
            cx_ = sum(p[0] for p in tri) / 3 / W
            cy_ = sum(p[1] for p in tri) / 3 / H
            base = rgb("#1b2a6b") * (1 - cx_) + rgb("#7a2d8f") * cx_
            shade = 0.75 + 0.5 * rng.random() - 0.25 * cy_
            draw.polygon(tri, fill=tuple(np.clip(base * shade, 0, 255).astype(int)))
img = np.asarray(canvas, np.float32)
save("low_poly", img, grain=1.5)

# Pastel waves: soft layered curves
img = vertical("#fde2e4", "#cde7f0", 1.0)
for k, color in enumerate(["#f7c6d0", "#e3c6f2", "#c6d8f7", "#bfeee0", "#a9d6e5"]):
    y0 = H * (0.35 + 0.13 * k) + 70 * np.sin(np.linspace(0, 2 * np.pi, W) * (1 + k * 0.2) + k)
    mask = yy >= y0[None, :]
    img[mask] = rgb(color)
save("pastel_waves", img, blur=2, grain=1.5)

# Rainy window: blurred city lights with droplets
img = vertical("#0d1b2a", "#1b263b", 1.0)
for _ in range(45):
    cx, cy, r = rng.uniform(0, W), rng.uniform(H * 0.3, H), rng.uniform(40, 140)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    img += rgb(["#ffb703", "#fb8500", "#8ecae6", "#e63946"][rng.integers(4)]) * (np.clip((r - d) / r, 0, 1) ** 2 * 0.35)[..., None]
img = np.asarray(Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(18)), np.float32)
for _ in range(220):
    cx, cy, r = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(3, 11)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    drop = np.clip((r - d) / r, 0, 1)
    img += 60 * (drop ** 0.5)[..., None] * 0.6
save("rainy_window", img, grain=2)

# Planet: large planet rising over space
img = vertical("#020208", "#0a0a1f", 1.0)
img += ((rng.random((H, W)) > 0.9993) * rng.uniform(100, 255, (H, W)))[..., None]
cx, cy, r = W * 0.5, H * 1.55, H * 1.05
d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
body = d < r
bands = np.sin((yy - cy) / r * 22 + smooth_noise(200, 3) * 3) * 0.5 + 0.5
surface = lerp(rgb("#1e3a8a"), rgb("#38bdf8"), bands)
img[body] = surface[body] * np.clip(1.2 - (d[body] / r), 0.3, 1)[..., None]
atmo = np.exp(-((d - r) / 26) ** 2) * (d > r * 0.97)
img += rgb("#7dd3fc") * (atmo * 0.9)[..., None]
save("planet", img, blur=0.6)

# Glacier: cold blues and white ice
img = vertical("#e8f4fb", "#5aa6c9", 1.2)
for base, amp, color in [(0.5, 160, "#cfe8f3"), (0.62, 150, "#9ccbe0"), (0.75, 140, "#5f9fbe"), (0.9, 110, "#2f6f8f")]:
    top = ridge(H * base, amp, 2)
    jag = np.abs(np.sin(np.linspace(0, 40 * np.pi, W))) * 18
    mask = yy >= (top - jag)[None, :]
    img[mask] = rgb(color)
save("glacier", img, blur=1.2, grain=2)

# Circles: minimal overlapping rings
img = vertical("#111827", "#1f2937", 1.0)
for cx, cy, r, color in [(0.3, 0.5, 300, "#f59e0b"), (0.55, 0.42, 260, "#ef4444"), (0.72, 0.6, 340, "#8b5cf6")]:
    d = np.sqrt((xx - W * cx) ** 2 + (yy - H * cy) ** 2)
    img += rgb(color) * (np.clip((r - d) / 3, 0, 1) * 0.28)[..., None]
save("circles", img, blur=1, grain=2)

# Lavender: rows of purple fields under a soft sky
img = vertical("#f3d9c6", "#c9a9e6", 1.0)
horizon = int(H * 0.5)
img = glow(img, W * 0.75, H * 0.42, 160, "#fff1d6", 45)
for row in range(horizon, H):
    t = (row - horizon) / (H - horizon)
    spacing = 8 + t * 90
    stripes = (np.sin(np.linspace(-1, 1, W) * W / spacing * (1 - t * 0.6)) * 0.5 + 0.5) ** 2
    img[row] = lerp(rgb("#6b3fa0") * (0.7 + 0.3 * t), rgb("#9b6fd0"), stripes)
save("lavender", img, blur=1.2, grain=2)

for f in sorted(OUT.glob("*.jpg")):
    print(f.name, f.stat().st_size // 1024, "KB")
