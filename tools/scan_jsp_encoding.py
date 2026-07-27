#!/usr/bin/env python3
"""Report JSP files missing pageEncoding / charset meta."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent / "web"
print("Scanning:", ROOT)

missing_pe = []
missing_meta = []
ok = 0
for p in sorted(ROOT.rglob("*.jsp")):
    t = p.read_text(encoding="utf-8", errors="replace")
    head = t[:4000]
    pe = "pageEncoding" in head
    charset_ct = bool(re.search(r"charset\s*=\s*UTF-8", head, re.I))
    meta = bool(re.search(r"<meta[^>]+charset\s*=\s*[\"']?utf-8", head, re.I))
    rel = str(p.relative_to(ROOT.parent)).replace("\\", "/")
    if pe and charset_ct:
        ok += 1
    if not pe:
        missing_pe.append((rel, charset_ct, meta))
    if not meta and not pe:
        missing_meta.append(rel)

print(f"OK (has pageEncoding+charset contentType): {ok}")
print(f"Missing pageEncoding: {len(missing_pe)}")
for rel, ct, meta in missing_pe:
    print(f"  {rel}  contentTypeUTF8={ct} meta={meta}")
