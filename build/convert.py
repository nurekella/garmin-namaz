import re
from pathlib import Path
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPM
src = Path("build/svg")
dst = Path("resources/drawables")
dst.mkdir(parents=True, exist_ok=True)
SIZE = 48
for svg in src.glob("*.svg"):
    raw = svg.read_text(encoding="utf-8")
    raw = raw.replace('currentColor', '#F5F0E8')
    tmp = src / f"{svg.stem}_color.svg"
    tmp.write_text(raw, encoding="utf-8")
    drawing = svg2rlg(str(tmp))
    if drawing is None:
        print(f"FAIL {svg.name}")
        continue
    scale = SIZE / max(drawing.width, drawing.height)
    drawing.scale(scale, scale)
    drawing.width *= scale
    drawing.height *= scale
    out = dst / f"icon_{svg.stem}.png"
    renderPM.drawToFile(drawing, str(out), fmt="PNG", bg=0)
    print(f"{out.name}: {out.stat().st_size} bytes")
