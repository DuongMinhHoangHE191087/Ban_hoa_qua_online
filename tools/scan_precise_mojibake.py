#!/usr/bin/env python3
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
letters = (
    "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩị"
    "òóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ"
    "ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊ"
    "ÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ"
)
broken = set()
for ch in letters:
    b = ch.encode("utf-8").decode("latin-1")
    if b != ch:
        broken.add(b)
for s in ["â†”", "â†’", "â†", "â€”", "â€“", "â€™", "â€œ", "â€¦", "âœ…", "âŒ", "Â·", "Â "]:
    broken.add(s)

pat = re.compile("|".join(re.escape(x) for x in sorted(broken, key=len, reverse=True)))
exclude = {"build", "node_modules", "out", "playwright-report", "test-results", ".git", "lib"}
exts = {".jsp", ".jspf", ".js", ".css", ".html", ".java", ".xml", ".properties", ".md", ".sql", ".txt"}

hits = []
for p in root.rglob("*"):
    if not p.is_file() or p.suffix.lower() not in exts:
        continue
    if any(part in exclude for part in p.parts):
        continue
    try:
        t = p.read_text(encoding="utf-8")
    except Exception:
        continue
    ms = list(pat.finditer(t))
    if ms:
        samples = sorted({m.group() for m in ms})[:15]
        hits.append((len(ms), str(p.relative_to(root)).replace("\\", "/"), samples))

hits.sort(reverse=True)
print(f"Remaining mojibake files: {len(hits)}")
for c, r, s in hits:
    print(f"{c:4d}  {r}")
    print(f"      samples: {s}")
