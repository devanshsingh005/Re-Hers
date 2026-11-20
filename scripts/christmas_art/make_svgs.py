"""Generates the Christmas decoration SVGs (flat vector art, transparent backgrounds).
Usage: python3 -I scripts/christmas_art/make_svgs.py <out_dir>
The output goes into Re-Hearse_v1/Assets.xcassets/Christmas/<name>.imageset/<name>.svg."""
import math, os, sys, random

OUT = sys.argv[1]
random.seed(7)

DARK_GREEN = "#2E5A3B"
MID_GREEN = "#3F7A4E"
LIGHT_GREEN = "#5E9C68"
TWIG = "#6B4A2E"
RED = "#C9353D"
RED_DARK = "#9E2630"
RED_HI = "#F07A7A"
GOLD = "#E2A83A"
GOLD_DARK = "#B9822A"
SNOW = "#FFFFFF"
SNOW_SHADE = "#DCE4EC"
SNOW_SHADE2 = "#C9D4DF"


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            + body + "\n</svg>\n")


def bez(p0, p1, p2, t):
    a = (1 - t) ** 2
    b = 2 * (1 - t) * t
    c = t ** 2
    return (a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1])


def bez_tan(p0, p1, p2, t):
    dx = 2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0])
    dy = 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1])
    n = math.hypot(dx, dy) or 1
    return dx / n, dy / n


def needle(x, y, ang, length, width, color):
    """A tapered needle: a thin leaf shape from (x, y) in direction ang."""
    ex, ey = x + math.cos(ang) * length, y + math.sin(ang) * length
    nx, ny = -math.sin(ang) * width / 2, math.cos(ang) * width / 2
    mx, my = x + math.cos(ang) * length * 0.45, y + math.sin(ang) * length * 0.45
    return (f'<path d="M{f(x)} {f(y)} Q{f(mx + nx)} {f(my + ny)} {f(ex)} {f(ey)} '
            f'Q{f(mx - nx)} {f(my - ny)} {f(x)} {f(y)}Z" fill="{color}"/>')


def pine_twig(p0, p1, p2, needle_len, count, width=1.6, twig_w=1.6, spread=0.75, colors=None, back=True):
    """Needles on both sides of a quadratic twig, swept towards its tip."""
    colors = colors or [DARK_GREEN, MID_GREEN, LIGHT_GREEN]
    out = [f'<path d="M{f(p0[0])} {f(p0[1])} Q{f(p1[0])} {f(p1[1])} {f(p2[0])} {f(p2[1])}" '
           f'fill="none" stroke="{TWIG}" stroke-width="{f(twig_w)}" stroke-linecap="round"/>']
    layers = []
    for i in range(count):
        t = 0.06 + 0.94 * i / max(1, count - 1)
        x, y = bez(p0, p1, p2, t)
        tx, ty = bez_tan(p0, p1, p2, t)
        base = math.atan2(ty, tx)
        L = needle_len * (0.55 + 0.45 * math.sin(math.pi * min(1, t * 1.1)))  # shorter at both ends
        for side in (-1, 1):
            ang = base + side * spread + random.uniform(-0.12, 0.12)
            col = colors[(i + (side > 0)) % len(colors)]
            layers.append((random.random(), needle(x, y, ang, L * random.uniform(0.85, 1.05), width, col)))
    # tip needle
    tx, ty = bez_tan(p0, p1, p2, 1)
    layers.append((0.5, needle(p2[0], p2[1], math.atan2(ty, tx), needle_len * 0.5, width, MID_GREEN)))
    layers.sort(key=lambda a: a[0])
    return "\n".join(out + [l for _, l in layers])


def berry(x, y, r):
    return (f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{RED}"/>'
            f'<path d="M{f(x - r * 0.95)} {f(y + r * 0.1)} A{f(r)} {f(r)} 0 0 0 {f(x + r * 0.95)} {f(y + r * 0.1)} '
            f'A{f(r * 1.05)} {f(r * 0.8)} 0 0 1 {f(x - r * 0.95)} {f(y + r * 0.1)}Z" fill="{RED_DARK}" opacity="0.55"/>'
            f'<circle cx="{f(x - r * 0.35)}" cy="{f(y - r * 0.38)}" r="{f(r * 0.28)}" fill="{RED_HI}" opacity="0.9"/>')


def berry_cluster(points, r, stem_from=None):
    out = []
    if stem_from:
        for (x, y) in points:
            out.append(f'<path d="M{f(stem_from[0])} {f(stem_from[1])} L{f(x)} {f(y - r * 0.7)}" stroke="{TWIG}" '
                       f'stroke-width="1" stroke-linecap="round"/>')
    for (x, y) in points:
        out.append(berry(x, y, r))
    return "\n".join(out)


# ---------------------------------------------------------------------------
# 1. Pine branch with berries, hanging in from the top-right corner (160 x 64)
# ---------------------------------------------------------------------------
def pine_branch():
    b = []
    # main twig: enters at the right edge, droops slightly to the left
    b.append(pine_twig((162, 4), (110, 2), (40, 22), 16, 26, width=2.3, twig_w=2.0))
    b.append(pine_twig((128, 5), (112, 24), (96, 46), 13, 13, width=2.1, twig_w=1.5))
    b.append(pine_twig((150, 4), (154, 26), (146, 52), 14, 14, width=2.2, twig_w=1.6))
    b.append(pine_twig((76, 13), (64, 30), (58, 40), 10, 7, width=1.5, twig_w=1.2))
    b.append(berry_cluster([(104, 30), (113, 36), (102, 42)], 4.6, stem_from=(110, 18)))
    b.append(berry_cluster([(136, 18), (144, 14)], 4.0, stem_from=(140, 8)))
    b.append(berry_cluster([(66, 32)], 3.6, stem_from=(70, 22)))
    return svg(160, 64, "\n".join(b))


# ---------------------------------------------------------------------------
# 2. Santa hat, sitting on the scan card's top-right corner (84 x 66)
# ---------------------------------------------------------------------------
def santa_hat():
    body = f'''
<path d="M10 46 C14 26 30 10 52 8 C66 7 74 14 76 26 C78 36 76 44 72 50 C70 40 66 32 58 28 C50 34 36 42 10 46Z" fill="{RED}"/>
<path d="M52 8 C66 7 74 14 76 26 C78 36 76 44 72 50 C70 40 66 32 58 28 C62 22 60 14 52 8Z" fill="{RED_DARK}" opacity="0.55"/>
<path d="M20 30 C30 18 40 13 50 12" fill="none" stroke="{RED_HI}" stroke-width="2.4" stroke-linecap="round" opacity="0.55"/>
<path d="M4 50 C4 42 10 38 18 38 C34 37 50 33 60 27 C66 24 72 28 70 35 C68 42 58 46 46 49 C32 53 18 58 10 58 C6 58 4 55 4 50Z" fill="{SNOW}" stroke="{SNOW_SHADE2}" stroke-width="0.8"/>
<path d="M6 54 C12 56 24 53 38 49 C52 45 64 41 69 36 C68 42 58 46 46 49 C32 53 18 58 10 58 C7 58 5 56 6 54Z" fill="{SNOW_SHADE}"/>
<circle cx="73" cy="54" r="8" fill="{SNOW}" stroke="{SNOW_SHADE2}" stroke-width="0.8"/>
<path d="M66 57 A8 8 0 0 0 81 54 A8 6 0 0 1 66 57Z" fill="{SNOW_SHADE}"/>
'''
    return svg(84, 66, body)


# ---------------------------------------------------------------------------
# Trees, cottage, gift, hills
# ---------------------------------------------------------------------------
def fir_tree(cx, base_y, h, w, color=MID_GREEN, shade=DARK_GREEN, snow=True):
    """A layered fir: three jagged tiers, darker on the right, snow on the tier tops."""
    out = [f'<rect x="{f(cx - w * 0.06)}" y="{f(base_y - h * 0.12)}" width="{f(w * 0.12)}" height="{f(h * 0.14)}" fill="{TWIG}"/>']
    tiers = [(0.0, 0.42, 1.0), (0.26, 0.70, 0.78), (0.52, 1.0, 0.54)]
    for (t0, t1, ww) in tiers:
        top = base_y - h * t1
        bot = base_y - h * (t0 + 0.08)
        hw = w * ww / 2
        # jagged bottom edge
        pts = [(cx, top)]
        pts.append((cx + hw, bot))
        steps = 4
        for i in range(1, steps):
            x = cx + hw - 2 * hw * i / steps
            pts.append((x + hw / steps * 0.5, bot - h * 0.035))
            pts.append((x, bot))
        pts.append((cx - hw, bot))
        d = "M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts) + "Z"
        out.append(f'<path d="{d}" fill="{color}"/>')
        # shaded right half
        out.append(f'<path d="M{f(cx)} {f(top)} L{f(cx + hw)} {f(bot)} L{f(cx + hw * 0.1)} {f(bot - h * 0.02)}Z" fill="{shade}" opacity="0.6"/>')
        if snow:
            sy = top + (bot - top) * 0.38
            out.append(f'<path d="M{f(cx)} {f(top - 0.5)} L{f(cx + hw * 0.42)} {f(sy)} Q{f(cx + hw * 0.2)} {f(sy - h * 0.03)} '
                       f'{f(cx + hw * 0.05)} {f(sy + h * 0.02)} Q{f(cx - hw * 0.2)} {f(sy - h * 0.03)} {f(cx - hw * 0.42)} {f(sy)}Z" fill="{SNOW}" stroke="{SNOW_SHADE2}" stroke-width="0.6" stroke-linejoin="round"/>')
    return "\n".join(out)


def cottage(x, base_y, w):
    h = w * 0.62
    wall_top = base_y - h * 0.62
    roof_top = base_y - h
    return f'''
<rect x="{f(x + w * 0.62)}" y="{f(roof_top + h * 0.02)}" width="{f(w * 0.11)}" height="{f(h * 0.28)}" fill="#7A3B2A"/>
<rect x="{f(x + w * 0.60)}" y="{f(roof_top - h * 0.02)}" width="{f(w * 0.15)}" height="{f(h * 0.07)}" rx="{f(h * 0.03)}" fill="{SNOW}"/>
<rect x="{f(x + w * 0.08)}" y="{f(wall_top)}" width="{f(w * 0.84)}" height="{f(base_y - wall_top)}" fill="#7B4B2E"/>
<rect x="{f(x + w * 0.08)}" y="{f(wall_top)}" width="{f(w * 0.84)}" height="{f((base_y - wall_top) * 0.18)}" fill="#5E3820" opacity="0.6"/>
<rect x="{f(x + w * 0.20)}" y="{f(wall_top + h * 0.16)}" width="{f(w * 0.16)}" height="{f(h * 0.16)}" rx="1" fill="#F6C453"/>
<rect x="{f(x + w * 0.64)}" y="{f(wall_top + h * 0.16)}" width="{f(w * 0.16)}" height="{f(h * 0.16)}" rx="1" fill="#F6C453"/>
<rect x="{f(x + w * 0.42)}" y="{f(wall_top + h * 0.22)}" width="{f(w * 0.16)}" height="{f(base_y - wall_top - h * 0.22)}" rx="1" fill="#4A2A18"/>
<path d="M{f(x - w * 0.04)} {f(wall_top + h * 0.04)} L{f(x + w * 0.5)} {f(roof_top)} L{f(x + w * 1.04)} {f(wall_top + h * 0.04)} Q{f(x + w * 0.5)} {f(wall_top - h * 0.06)} {f(x - w * 0.04)} {f(wall_top + h * 0.04)}Z" fill="{SNOW}" stroke="{SNOW_SHADE2}" stroke-width="0.6" stroke-linejoin="round"/>
<path d="M{f(x + w * 0.5)} {f(roof_top)} L{f(x + w * 1.04)} {f(wall_top + h * 0.04)} Q{f(x + w * 0.8)} {f(wall_top - h * 0.02)} {f(x + w * 0.56)} {f(wall_top - h * 0.03)}Z" fill="{SNOW_SHADE}"/>
'''


def gift(x, base_y, s):
    top = base_y - s
    return f'''
<rect x="{f(x)}" y="{f(top + s * 0.22)}" width="{f(s)}" height="{f(s * 0.78)}" rx="2" fill="{RED}"/>
<rect x="{f(x + s * 0.55)}" y="{f(top + s * 0.22)}" width="{f(s * 0.45)}" height="{f(s * 0.78)}" rx="2" fill="{RED_DARK}" opacity="0.45"/>
<rect x="{f(x - s * 0.06)}" y="{f(top + s * 0.12)}" width="{f(s * 1.12)}" height="{f(s * 0.2)}" rx="2" fill="#D9424A"/>
<rect x="{f(x + s * 0.42)}" y="{f(top + s * 0.12)}" width="{f(s * 0.16)}" height="{f(s * 0.88)}" fill="{GOLD}"/>
<path d="M{f(x + s * 0.5)} {f(top + s * 0.14)} C{f(x + s * 0.2)} {f(top - s * 0.12)} {f(x + s * 0.06)} {f(top + s * 0.12)} {f(x + s * 0.5)} {f(top + s * 0.14)}Z" fill="{GOLD}"/>
<path d="M{f(x + s * 0.5)} {f(top + s * 0.14)} C{f(x + s * 0.8)} {f(top - s * 0.12)} {f(x + s * 0.94)} {f(top + s * 0.12)} {f(x + s * 0.5)} {f(top + s * 0.14)}Z" fill="{GOLD_DARK}"/>
<path d="M{f(x - s * 0.04)} {f(base_y)} Q{f(x + s * 0.5)} {f(base_y - s * 0.08)} {f(x + s * 1.04)} {f(base_y)}Z" fill="{SNOW}"/>
'''


def sparkle(x, y, r, color=SNOW, opacity=0.9):
    return (f'<path d="M{f(x)} {f(y - r)} L{f(x + r * 0.22)} {f(y - r * 0.22)} L{f(x + r)} {f(y)} L{f(x + r * 0.22)} {f(y + r * 0.22)} '
            f'L{f(x)} {f(y + r)} L{f(x - r * 0.22)} {f(y + r * 0.22)} L{f(x - r)} {f(y)} L{f(x - r * 0.22)} {f(y - r * 0.22)}Z" '
            f'fill="{color}" opacity="{opacity}"/>')


def hills(w, h, back_y, front_y):
    """Two snow hills across the full width: a shaded one behind, a white one in front."""
    return f'''
<path d="M0 {f(back_y + 6)} C{f(w * 0.18)} {f(back_y - 8)} {f(w * 0.36)} {f(back_y - 2)} {f(w * 0.52)} {f(back_y + 4)} C{f(w * 0.68)} {f(back_y + 10)} {f(w * 0.84)} {f(back_y - 10)} {f(w)} {f(back_y - 2)} L{f(w)} {f(h)} L0 {f(h)}Z" fill="{SNOW_SHADE}"/>
<path d="M0 {f(front_y)} C{f(w * 0.22)} {f(front_y - 14)} {f(w * 0.42)} {f(front_y + 6)} {f(w * 0.62)} {f(front_y - 2)} C{f(w * 0.78)} {f(front_y - 8)} {f(w * 0.9)} {f(front_y + 2)} {f(w)} {f(front_y - 4)} L{f(w)} {f(h)} L0 {f(h)}Z" fill="{SNOW}"/>
<path d="M0 {f(front_y)} C{f(w * 0.22)} {f(front_y - 14)} {f(w * 0.42)} {f(front_y + 6)} {f(w * 0.62)} {f(front_y - 2)} C{f(w * 0.78)} {f(front_y - 8)} {f(w * 0.9)} {f(front_y + 2)} {f(w)} {f(front_y - 4)}" fill="none" stroke="{SNOW_SHADE2}" stroke-width="1" opacity="0.9"/>
<path d="M0 {f(front_y + 10)} C{f(w * 0.25)} {f(front_y + 2)} {f(w * 0.45)} {f(front_y + 16)} {f(w * 0.7)} {f(front_y + 10)} C{f(w * 0.85)} {f(front_y + 6)} {f(w * 0.95)} {f(front_y + 12)} {f(w)} {f(front_y + 10)}" fill="none" stroke="{SNOW_SHADE}" stroke-width="1.5" opacity="0.8"/>
'''


# ---------------------------------------------------------------------------
# 3. Snowy scene along the bottom of the scan card (360 x 92)
# ---------------------------------------------------------------------------
def snow_scene():
    w, h = 360, 92
    b = [hills(w, h, 58, 70)]
    b.append(fir_tree(22, 68, 58, 34))
    b.append(fir_tree(48, 64, 40, 24, color=LIGHT_GREEN, shade=MID_GREEN))
    b.append(cottage(70, 66, 46))
    b.append(fir_tree(132, 62, 30, 18, color=LIGHT_GREEN, shade=MID_GREEN))
    b.append(fir_tree(302, 62, 36, 22, color=LIGHT_GREEN, shade=MID_GREEN))
    b.append(fir_tree(334, 70, 60, 36))
    # front snow drift over the tree trunks
    b.append(f'<path d="M0 74 C40 66 80 72 120 70 C170 68 220 76 270 72 C310 69 340 72 360 70 L360 92 L0 92Z" fill="{SNOW}"/>')
    b.append(f'<path d="M0 74 C40 66 80 72 120 70 C170 68 220 76 270 72 C310 69 340 72 360 70" fill="none" stroke="{SNOW_SHADE}" stroke-width="1"/>')
    b.append(sparkle(196, 30, 5))
    b.append(sparkle(250, 44, 3.5))
    return svg(w, h, "\n".join(b))


# ---------------------------------------------------------------------------
# 4. Snow landscape with a gift, above the Search bar (400 x 104)
# ---------------------------------------------------------------------------
def snow_gift():
    w, h = 400, 104
    b = [hills(w, h, 70, 82)]
    b.append(fir_tree(84, 80, 44, 26, color=LIGHT_GREEN, shade=MID_GREEN))
    b.append(fir_tree(352, 80, 70, 40))
    b.append(fir_tree(382, 84, 46, 26, color=LIGHT_GREEN, shade=MID_GREEN))
    b.append(gift(298, 86, 30))
    b.append(f'<path d="M0 88 C60 80 120 86 180 84 C240 82 300 90 340 86 C370 83 390 86 400 85 L400 104 L0 104Z" fill="{SNOW}"/>')
    b.append(f'<path d="M0 88 C60 80 120 86 180 84 C240 82 300 90 340 86 C370 83 390 86 400 85" fill="none" stroke="{SNOW_SHADE}" stroke-width="1"/>')
    b.append(sparkle(40, 40, 4, SNOW_SHADE2, 0.8))
    b.append(sparkle(230, 36, 5, SNOW_SHADE2, 0.8))
    return svg(w, h, "\n".join(b))


# ---------------------------------------------------------------------------
# 5. Holly for the piano player's top corners (52 x 64), drawn for the top-left
# ---------------------------------------------------------------------------
def holly_leaf(cx, cy, length, width, ang, color, vein):
    """A holly leaf centred at (cx, cy) along angle ang: spike points joined by inward (scalloped) curves."""
    n = 4
    def edge(sign):
        pts = []
        for i in range(n + 1):
            t = i / n
            x = -length / 2 + length * t
            y = sign * width / 2 * (math.sin(math.pi * t) ** 0.7) * (1.15 if 0 < i < n else 0)
            pts.append((x, y))
        return pts
    up, lo = edge(-1), edge(1)
    ca, sa = math.cos(ang), math.sin(ang)
    T = lambda x, y: (cx + x * ca - y * sa, cy + x * sa + y * ca)
    d = "M%s %s" % tuple(map(f, T(*up[0])))
    for a, b in zip(up, up[1:]):
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2 * 0.35   # pulled towards the midrib
        d += " Q%s %s %s %s" % (*map(f, T(mx, my)), *map(f, T(*b)))
    rev = list(reversed(lo))
    for a, b in zip(rev, rev[1:]):
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2 * 0.35
        d += " Q%s %s %s %s" % (*map(f, T(mx, my)), *map(f, T(*b)))
    x0, y0 = T(-length / 2, 0)
    x1, y1 = T(length / 2, 0)
    return (f'<path d="{d}Z" fill="{color}"/>'
            f'<path d="M{f(x0)} {f(y0)} L{f(x1)} {f(y1)}" stroke="{vein}" stroke-width="0.9" opacity="0.8"/>')


def holly_corner():
    b = []
    b.append(pine_twig((-2, -2), (6, 22), (4, 58), 10, 12, width=1.6, twig_w=1.4))
    b.append(pine_twig((-2, -2), (20, 4), (40, 10), 9, 9, width=1.5, twig_w=1.2))
    b.append(holly_leaf(20, 20, 26, 12, math.radians(35), DARK_GREEN, LIGHT_GREEN))
    b.append(holly_leaf(12, 28, 24, 11, math.radians(80), MID_GREEN, LIGHT_GREEN))
    b.append(berry_cluster([(14, 16), (21, 13), (18, 22)], 3.6))
    return svg(52, 64, "\n".join(b))


# ---------------------------------------------------------------------------
# 6. Pine and berries for the piano player's bottom-left corner (90 x 104)
# ---------------------------------------------------------------------------
def pine_corner():
    b = []
    b.append(pine_twig((-2, 106), (10, 70), (16, 30), 14, 16, width=1.9, twig_w=1.8))
    b.append(pine_twig((-2, 106), (30, 92), (72, 96), 13, 14, width=1.8, twig_w=1.6))
    b.append(pine_twig((4, 98), (26, 74), (44, 62), 11, 10, width=1.6, twig_w=1.3))
    b.append(holly_leaf(34, 84, 26, 12, math.radians(-30), DARK_GREEN, LIGHT_GREEN))
    b.append(berry_cluster([(24, 82), (31, 78), (28, 88)], 4.0))
    return svg(90, 104, "\n".join(b))


# ---------------------------------------------------------------------------
# 7. Hanging ornament for the Search header (30 x 72)
# ---------------------------------------------------------------------------
def ornament():
    body = f'''
<path d="M15 0 L15 34" stroke="{GOLD_DARK}" stroke-width="1"/>
<rect x="10.5" y="32" width="9" height="7" rx="1.5" fill="{GOLD}"/>
<rect x="15" y="32" width="4.5" height="7" rx="1.5" fill="{GOLD_DARK}" opacity="0.5"/>
<circle cx="15" cy="53" r="15" fill="{RED}"/>
<path d="M2 58 A15 15 0 0 0 28 58 A15 9 0 0 1 2 58Z" fill="{RED_DARK}" opacity="0.5"/>
<path d="M1.5 51 Q15 46 28.5 51" fill="none" stroke="{GOLD}" stroke-width="1.6"/>
<path d="M1.8 56 Q15 61 28.2 56" fill="none" stroke="{GOLD}" stroke-width="1.6"/>
<ellipse cx="9" cy="45" rx="3.6" ry="2.4" transform="rotate(-35 9 45)" fill="{RED_HI}" opacity="0.8"/>
'''
    return svg(30, 70, body)


assets = {
    "xmas-pine-branch": pine_branch(),
    "xmas-santa-hat": santa_hat(),
    "xmas-snow-scene": snow_scene(),
    "xmas-snow-gift": snow_gift(),
    "xmas-holly-corner": holly_corner(),
    "xmas-pine-corner": pine_corner(),
    "xmas-ornament": ornament(),
}
os.makedirs(OUT, exist_ok=True)
for name, text in assets.items():
    with open(os.path.join(OUT, name + ".svg"), "w") as fh:
        fh.write(text)
    print(name, len(text.encode()), "bytes")
