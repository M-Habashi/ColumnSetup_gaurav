from pathlib import Path


OUT_DIR = Path(__file__).resolve().parent
W, H = 1600, 900

BLACK = "#111827"
GRID = "#d1d5db"
LIGHT_GRID = "#eef2f7"
TEXT = "#111827"
MUTED = "#4b5563"
BLUE = "#007CA8"
COPPER = "#AC6420"
PURPLE = "#74058A"
GREEN = "#39BF5E"
RED = "#901500"
PANEL = "#ffffff"

TABLE_ROWS = [
    ("J4", "1st-floor RMS/std displacement error", "82.90", "0.00", "0.47"),
    ("J5", "1st-floor peak displacement error", "50.45", "0.00", "0.62"),
    ("J6", "2nd-floor RMS/std displacement error", "81.36", "0.00", "0.12"),
    ("J7", "3rd-floor RMS/std displacement error", "81.01", "0.00", "0.18"),
]


def esc(text):
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def line(x1, y1, x2, y2, color=BLACK, width=3, dash=None):
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    return (
        f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" '
        f'stroke="{color}" stroke-width="{width}" stroke-linecap="round"{dash_attr}/>'
    )


def rect(x, y, w, h, fill="none", stroke=GRID, width=1, rx=0):
    return (
        f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" '
        f'fill="{fill}" stroke="{stroke}" stroke-width="{width}" rx="{rx}"/>'
    )


def text(x, y, body, size=26, color=TEXT, weight=400, anchor="start", italic=False):
    style = "font-style:italic;" if italic else ""
    return (
        f'<text x="{x:.2f}" y="{y:.2f}" fill="{color}" font-size="{size}" '
        f'font-weight="{weight}" text-anchor="{anchor}" style="{style}">{esc(body)}</text>'
    )


def multiline(x, y, lines, size=22, color=MUTED, leading=1.22, width=None):
    out = []
    for i, item in enumerate(lines):
        out.append(text(x, y + i * size * leading, item, size=size, color=color))
    return "\n".join(out)


def arrow_marker():
    return (
        '<defs>'
        '<marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="3" '
        'orient="auto" markerUnits="strokeWidth">'
        f'<path d="M0,0 L0,6 L9,3 z" fill="{BLUE}"/>'
        "</marker>"
        '<marker id="arrow-purple" markerWidth="10" markerHeight="10" refX="8" refY="3" '
        'orient="auto" markerUnits="strokeWidth">'
        f'<path d="M0,0 L0,6 L9,3 z" fill="{PURPLE}"/>'
        "</marker>"
        "</defs>"
    )


def spring(x, y, scale=1.0, color=BLACK):
    pts = []
    for i in range(8):
        px = x + (i - 3.5) * 5 * scale
        py = y + (8 if i % 2 else -8) * scale
        pts.append(f"{px:.2f},{py:.2f}")
    return (
        f'<polyline points="{" ".join(pts)}" fill="none" stroke="{color}" '
        f'stroke-width="{2.0 * scale:.2f}" stroke-linecap="round" stroke-linejoin="round"/>'
    )


def fixed_support(x, y, scale=1.0, color=BLACK):
    parts = [line(x - 18 * scale, y, x + 18 * scale, y, color, 2.5 * scale)]
    for i in range(5):
        xx = x - 16 * scale + i * 8 * scale
        parts.append(line(xx, y, xx - 7 * scale, y + 8 * scale, color, 1.6 * scale))
    return "\n".join(parts)


def rotation_symbol(x, y, r=18, color=BLUE):
    path = (
        f'<path d="M{x+r:.2f},{y:.2f} A{r:.2f},{r:.2f} 0 1 1 {x-r*0.45:.2f},{y-r*0.90:.2f}" '
        f'fill="none" stroke="{color}" stroke-width="3" marker-end="url(#arrow)"/>'
    )
    return path


def frame_diagram(x, y, w, h, case):
    parts = []
    bay_count = 3
    story_count = 3
    left = x + 0.10 * w
    right = x + 0.92 * w
    base = y + 0.86 * h
    top = y + 0.18 * h
    bay = (right - left) / bay_count
    story = (base - top) / story_count
    exp_h = 0.50 * story if case == 1 else 0.39 * story
    interface_y = base - exp_h

    for level in range(1, story_count + 1):
        yy = base - level * story
        parts.append(line(left, yy, right, yy, BLACK, 2.8))
    for col in range(bay_count + 1):
        xx = left + col * bay
        lower = base
        if col == 0:
            lower = interface_y
        parts.append(line(xx, lower, xx, top, BLACK, 2.8))
    parts.append(line(left, base, left, interface_y, COPPER, 6))

    for col in range(bay_count + 1):
        xx = left + col * bay
        if case == 2 and col > 0:
            parts.append(spring(xx, base + 18, 0.9, BLACK))
            parts.append(line(xx, base, xx, base + 9, BLACK, 2))
        else:
            parts.append(fixed_support(xx, base + 4, 0.7, BLACK))

    if case == 2:
        parts.append(rotation_symbol(left, interface_y, 15, PURPLE))
        parts.append(text(left + 20, interface_y - 7, "M=0", 18, PURPLE, 700))
    if case == 3:
        for level in range(1, story_count + 1):
            yy = base - level * story
            for col in range(bay_count + 1):
                xx = left + col * bay
                parts.append(rotation_symbol(xx, yy, 13, BLUE))
        parts.append(rotation_symbol(left, interface_y, 15, PURPLE))
        parts.append(text(left + 20, interface_y - 7, "M=0", 18, PURPLE, 700))

    for level in range(1, story_count + 1):
        yy = base - level * story
        ax = left + 1.42 * bay
        parts.append(
            f'<line x1="{ax:.2f}" y1="{yy-10:.2f}" x2="{ax+50:.2f}" y2="{yy-10:.2f}" '
            f'stroke="{BLUE}" stroke-width="3" marker-end="url(#arrow)"/>'
        )
        parts.append(text(ax - 18, yy - 16, f"u{level}", 22, BLUE, 700, italic=True))

    parts.append(line(left - 25, base, left - 25, interface_y, COPPER, 2))
    parts.append(text(left - 34, (base + interface_y) / 2 + 6, '40"', 20, COPPER, 700, "end"))
    parts.append(line(left, base + 34, left + bay, base + 34, MUTED, 1.5))
    parts.append(text(left + bay / 2, base + 58, "10 ft bays", 18, MUTED, 500, "middle"))

    if case == 1:
        parts.append(text(right + 10, base - story / 2, "6.67 ft", 19, MUTED, 500))
        parts.append(text(left + 5, interface_y - 12, "fixed θ", 18, RED, 700))
    elif case == 2:
        parts.append(text(right + 10, base - story / 2, "8.47 ft", 19, MUTED, 500))
    else:
        parts.append(text(right + 10, base - story / 2, "6.20 ft", 19, MUTED, 500))

    return "\n".join(parts)


def mini_table(x, y, w, h, style=1):
    cols = [0, 0.34, 0.52, 0.68, 0.84, 1.0]
    headers = ["J", "Meaning", "Case 1", "Case 2", "Case 3"]
    out = [rect(x, y, w, h, "#ffffff", GRID, 1, 0)]
    row_h = h / 5
    out.append(rect(x, y, w, row_h, "#f3f6f8", "none", 0, 0))
    for i in range(1, 5):
        out.append(line(x, y + i * row_h, x + w, y + i * row_h, GRID, 1))
    for c in cols[1:-1]:
        out.append(line(x + c * w, y, x + c * w, y + h, GRID, 1))
    for i, header in enumerate(headers):
        cx = x + (cols[i] + 0.02) * w
        out.append(text(cx, y + 0.63 * row_h, header, 19, TEXT, 800))
    for r, row in enumerate(TABLE_ROWS):
        yy = y + (r + 1) * row_h
        if r % 2 == 1:
            out.append(rect(x, yy, w, row_h, "#fbfcfd", "none", 0, 0))
        values = [row[0], row[1], row[2], row[3], row[4]]
        for i, value in enumerate(values):
            color = TEXT
            weight = 600 if i == 0 else 400
            if i >= 2:
                weight = 800
                color = [COPPER, GREEN, BLUE][i - 2]
            out.append(text(x + (cols[i] + 0.02) * w, yy + 0.63 * row_h, value, 18, color, weight))
    return "\n".join(out)


def case_card(x, y, w, h, case, title, bullets, accent):
    out = [rect(x, y, w, h, PANEL, "#cbd5e1", 1.4, 8)]
    out.append(rect(x, y, w, 9, accent, "none", 0, 8))
    out.append(text(x + 24, y + 44, title, 30, TEXT, 800))
    out.append(frame_diagram(x + 8, y + 52, w - 16, 0.58 * h, case))
    out.append(multiline(x + 24, y + h - 112, bullets, 20, MUTED, 1.25))
    return "\n".join(out)


def base_svg(content, subtitle="", bg="#f8fafc"):
    grid = []
    for xx in range(0, W + 1, 80):
        grid.append(line(xx, 0, xx, H, LIGHT_GRID, 1))
    for yy in range(0, H + 1, 80):
        grid.append(line(0, yy, W, yy, LIGHT_GRID, 1))
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
        f"{arrow_marker()}"
        f'<rect width="{W}" height="{H}" fill="{bg}"/>'
        + "\n".join(grid)
        + text(70, 68, "Numerical-Experimental Substructure Choices", 42, TEXT, 850)
        + text(70, 105, subtitle, 22, MUTED, 400)
        + content
        + "</svg>"
    )


def alt1():
    cards = [
        case_card(55, 145, 470, 485, 1, "Case 1 · Fixed Rotation", [
            "Only 3 floor translations",
            "Top/base rotations prevented",
            "Inflection fixed at mid-column",
        ], COPPER),
        case_card(565, 145, 470, 485, 2, "Case 2 · Exact M=0 Cut", [
            "3 dynamic translation DOFs",
            "Base rotational springs",
            "Released zero-moment interface",
        ], GREEN),
        case_card(1075, 145, 470, 485, 3, "Case 3 · First-Mode Tuned", [
            "Translations + internal rotations",
            "Interface moment released",
            "40 in inflection optimized for mode 1",
        ], BLUE),
    ]
    content = "\n".join(cards) + mini_table(130, 685, 1340, 165)
    return base_svg(content, "Light-mode conference layout · numerical frame in black, experiment in copper")


def alt2():
    out = []
    out.append(rect(55, 135, 1490, 585, "#ffffff", "#cbd5e1", 1.2, 8))
    for i, (case, title, bullets, accent) in enumerate([
        (1, "Case 1", ["fixed θ", "80 in first story", "large modeling error"], COPPER),
        (2, "Case 2", ["M=0 release", "height exact for idealization", "J-values vanish"], GREEN),
        (3, "Case 3", ["joint rotations kept", "mode-1 height tuning", "small higher-mode error"], BLUE),
    ]):
        x = 70 + i * 495
        out.append(rect(x, 155, 465, 545, "#fbfdff", "#d7dde6", 1, 6))
        out.append(text(x + 24, 195, title, 34, accent, 850))
        out.append(frame_diagram(x + 5, 215, 455, 330, case))
        out.append(multiline(x + 28, 602, bullets, 23, MUTED, 1.35))
    out.append(mini_table(160, 748, 1280, 115))
    return base_svg("\n".join(out), "Matrix layout · visual comparison above, indicators below")


def alt3():
    out = []
    y = 150
    for i, (case, title, bullets, accent) in enumerate([
        (1, "1  Translation Only", ["fixed rotations", "known mid-height inflection"], COPPER),
        (2, "2  Base Springs + M=0", ["released interface rotation", "exact for this idealization"], GREEN),
        (3, "3  Full Joint Rotations", ["massless rotations condensed", "first-mode optimized"], BLUE),
    ]):
        x = 70 + i * 505
        out.append(text(x, y, title, 32, accent, 850))
        out.append(frame_diagram(x - 10, y + 25, 455, 365, case))
        out.append(multiline(x, y + 420, bullets, 22, MUTED, 1.25))
        if i < 2:
            out.append(
                f'<line x1="{x+420}" y1="{y+235}" x2="{x+488}" y2="{y+235}" '
                f'stroke="{MUTED}" stroke-width="3" marker-end="url(#arrow)"/>'
            )
    out.append(rect(80, 730, 1440, 125, "#ffffff", "#cbd5e1", 1.2, 8))
    out.append(text(110, 770, "Error indicators from El Centro response", 28, TEXT, 800))
    out.append(mini_table(505, 744, 975, 96))
    return base_svg("\n".join(out), "Progression layout · from fixed rotation to first-mode-optimized frame")


def alt4():
    out = []
    out.append(rect(45, 130, 1510, 700, "#ffffff", "#94a3b8", 1.5, 4))
    out.append(text(80, 172, "Geometry and Boundary Conditions", 31, TEXT, 850))
    out.append(text(1040, 172, "Validation Indicators", 31, TEXT, 850))
    for i, (case, title, bullets, accent) in enumerate([
        (1, "Case 1", ["θ restrained", "h = 6.67 ft"], COPPER),
        (2, "Case 2", ["base kθ", "M=0 at 40 in"], GREEN),
        (3, "Case 3", ["joint θ DOFs", "mode-1 tuned"], BLUE),
    ]):
        y = 210 + i * 190
        out.append(text(90, y + 20, title, 28, accent, 850))
        out.append(frame_diagram(190, y - 18, 420, 180, case))
        out.append(multiline(650, y + 34, bullets, 22, MUTED, 1.3))
    out.append(mini_table(1000, 220, 500, 420))
    out.append(multiline(1000, 690, [
        "J4-J7 are displacement-response errors [%].",
        "Case 2 is exact for the simplified linear idealization.",
        "Case 3 has small residual error from higher modes.",
    ], 22, MUTED, 1.35))
    return base_svg("\n".join(out), "Engineering-sheet layout · compact notes and tabular emphasis")


def alt5():
    out = []
    out.append(text(70, 150, "Three ways to choose the numerical substructure", 32, TEXT, 850))
    out.append(rect(68, 174, 1460, 2, BLUE, "none", 0, 0))
    for i, (case, title, accent) in enumerate([
        (1, "Fixed rotations", COPPER),
        (2, "Zero-moment interface", GREEN),
        (3, "Joint rotations, mode 1", BLUE),
    ]):
        x = 85 + i * 500
        out.append(text(x, 225, title, 29, accent, 850))
        out.append(frame_diagram(x - 15, 250, 440, 355, case))
    out.append(rect(70, 642, 1460, 195, "#ffffff", "#cbd5e1", 1.2, 8))
    out.append(text(100, 690, "Comparison table", 29, TEXT, 850))
    out.append(multiline(100, 732, [
        "J4/J6/J7: floor RMS/std displacement error",
        "J5: first-floor peak displacement error",
    ], 21, MUTED, 1.3))
    out.append(mini_table(575, 672, 905, 135))
    return base_svg("\n".join(out), "Minimal landscape layout · larger diagrams, compact metric legend")


ALTERNATIVES = [alt1, alt2, alt3, alt4, alt5]


def main():
    for idx, builder in enumerate(ALTERNATIVES, start=1):
        path = OUT_DIR / f"nume_exp_poster_alt{idx}.svg"
        path.write_text(builder(), encoding="utf-8")
        print(path)


if __name__ == "__main__":
    main()
