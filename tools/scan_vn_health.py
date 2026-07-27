#!/usr/bin/env python3
"""Health check for Vietnamese UI text in web + src."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
vn = set("àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ")
exclude = {"build", "node_modules", "out", "playwright-report", "test-results", ".git", "lib", "docs", "tools"}
exts = {".jsp", ".jspf", ".js", ".java", ".html", ".css"}

stats = {"files": 0, "with_vn": 0, "fffd": [], "question_runs": [], "page_enc_missing": []}
for p in root.rglob("*"):
    if not p.is_file() or p.suffix.lower() not in exts:
        continue
    if any(part in exclude for part in p.parts):
        continue
    try:
        data = p.read_bytes()
        text = data.decode("utf-8")
    except Exception as e:
        stats.setdefault("decode_fail", []).append(str(p.relative_to(root)))
        continue
    stats["files"] += 1
    if any(c in vn for c in text):
        stats["with_vn"] += 1
    if "\ufffd" in text:
        stats["fffd"].append(str(p.relative_to(root)).replace("\\", "/"))
    # long ??? runs often mean lost encoding
    if re.search(r"\?\?\?\?", text):
        # ignore urls/regex
        if not re.search(r"https?://|\.\*|\\\\", text):
            stats["question_runs"].append(str(p.relative_to(root)).replace("\\", "/"))
    if p.suffix.lower() == ".jsp":
        head = text[:2000]
        if "pageEncoding" not in head and "page-encoding" not in head:
            stats["page_enc_missing"].append(str(p.relative_to(root)).replace("\\", "/"))

print("Scanned files:", stats["files"])
print("Files with Vietnamese diacritics:", stats["with_vn"])
print("U+FFFD replacement char files:", len(stats["fffd"]))
for x in stats["fffd"][:20]:
    print(" ", x)
print("???? runs:", len(stats["question_runs"]))
for x in stats["question_runs"][:20]:
    print(" ", x)
print("JSP still missing pageEncoding:", len(stats["page_enc_missing"]))
for x in stats["page_enc_missing"]:
    print(" ", x)
print("decode_fail:", stats.get("decode_fail", []))
