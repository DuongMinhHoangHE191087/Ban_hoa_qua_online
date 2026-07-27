#!/usr/bin/env python3
"""Scan project for UTF-8 mojibake / broken Vietnamese text."""
from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXTS = {".jsp", ".jspf", ".js", ".css", ".html", ".java", ".xml", ".properties", ".md", ".txt", ".sql"}
EXCLUDE_DIRS = {
    "build",
    "node_modules",
    "out",
    "playwright-report",
    "test-results",
    ".git",
    "lib",
    ".idea",
    "target",
}

# Common UTF-8-as-Latin1/Windows-1252 mojibake markers for Vietnamese + smart quotes
MOJI_RE = re.compile(
    r"(?:"
    r"Ã[\x80-\xBF]"
    r"|Ä[\x80-\xBF]"
    r"|áº[\x80-\xBF]"
    r"|á»[\x80-\xBF]"
    r"|Æ[\xA0-\xBF]"
    r"|â€."
    r"|Â[\xA0-\xFF]"
    r"|\uFFFD"
    r"|Ä‘|Ä\u0110|Æ¡|Æ°"
    r"|áº|á»"
    r")"
)

# Explicit known broken Vietnamese sequences (double-encoded UTF-8)
KNOWN = [
    "Äáº¿m",
    "tá»•ng",
    "dÃ¹ng",
    "phÃ¢n",
    "Äá»‹a",
    "chá»‰",
    "Äá»ƒ",
    "Äáº·c",
    "sá»‘",
    "Äiá»‡n",
    "thoáº¡i",
    "Äá»“ng",
    "Äáº·t",
    "Äáº·ng",
    "Äá»“",
    "Äá»™ng",
    "Äá»“i",
    "Äá»“ng",
    "HOáº T",
    "Äá»˜NG",
    "ÄÃƒ",
    "KHÃ“A",
    "Há»",
    "tÃªn",
    "Äá»‹a",
    "chá»‰",
    "xÃ¡c",
    "thá»±c",
    "ChÆ°a",
    "cáº­p",
    "nháº­t",
    "Vai trÃ²",
    "ÄÄƒng",
    "má»Ÿ",
    "gian hÃ ng",
    "Tráº¡ng thÃ¡i",
    "ÄÃ£",
    "phÃª",
    "duyá»‡t",
    "chá»",
    "Äang",
    "âœ…",
    "âŒ",
    "â³",
    "â¸",
    "â€”",
    "â€“",
    "â€™",
    "â€œ",
    "â€",
]


def main() -> None:
    results: list[tuple[int, bool, str, list[str]]] = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS and not d.startswith(".")]
        for fn in filenames:
            path = Path(dirpath) / fn
            if path.suffix.lower() not in EXTS:
                continue
            try:
                data = path.read_bytes()
            except OSError:
                continue
            if len(data) > 5_000_000:
                continue

            valid = True
            try:
                text = data.decode("utf-8")
            except UnicodeDecodeError:
                valid = False
                text = data.decode("utf-8", errors="replace")

            matches = list(MOJI_RE.finditer(text))
            count = len(matches)
            known_hits = sum(1 for k in KNOWN if k in text)
            score = count + known_hits * 5

            if score == 0 and valid:
                continue

            rel = str(path.relative_to(ROOT)).replace("\\", "/")
            samples: list[str] = []
            for m in matches[:4]:
                s = max(0, m.start() - 30)
                e = min(len(text), m.end() + 30)
                snippet = text[s:e].replace("\n", " ").replace("\r", "")
                samples.append(snippet)
            results.append((score, valid, rel, samples))

    results.sort(key=lambda x: (-x[0], x[2]))
    print(f"FOUND {len(results)} files with potential encoding issues\n")
    for score, valid, rel, samples in results:
        print(f"{score:5d} valid_utf8={valid}  {rel}")
        for s in samples[:2]:
            print(f"       ...{s}...")
    print("\n---DONE---")

    # Write simple report
    report = ROOT / "tools" / "mojibake-scan-report.txt"
    with report.open("w", encoding="utf-8") as f:
        f.write(f"FOUND {len(results)} files\n\n")
        for score, valid, rel, samples in results:
            f.write(f"{score}\tvalid={valid}\t{rel}\n")
            for s in samples:
                f.write(f"  {s}\n")
    print(f"Report: {report}")


if __name__ == "__main__":
    main()
