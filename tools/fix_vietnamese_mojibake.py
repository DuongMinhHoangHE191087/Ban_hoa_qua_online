#!/usr/bin/env python3
"""
Fix Vietnamese UTF-8 mojibake in source files.

Strategy:
1) Full-string latin-1/cp1252 -> utf-8 round-trip when possible
2) Longest-first replacement map for common Vietnamese / punctuation mojibake
3) Write UTF-8 (no BOM)
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

EXTS = {
    ".jsp",
    ".jspf",
    ".js",
    ".css",
    ".html",
    ".java",
    ".xml",
    ".properties",
    ".md",
    ".txt",
    ".sql",
    ".json",
}
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

# Longest-first known mojibake sequences for Vietnamese (UTF-8 misread as Latin-1/CP1252)
# Generated from common diacritic syllables + punctuation
REPLACEMENTS: list[tuple[str, str]] = [
    # multi-char punctuation / symbols
    ("â†”", "↔"),
    ("â†’", "→"),
    ("â†", "←"),
    ("â€”", "—"),
    ("â€“", "–"),
    ("â€¦", "…"),
    ("â€™", "'"),
    ("â€˜", "'"),
    ("â€œ", '"'),
    ("â€\x9d", '"'),
    ("â€¢", "•"),
    ("âœ…", "✅"),
    ("âŒ", "❌"),
    ("â³", "⏳"),
    ("â¸", "⏸"),
    ("Â·", "·"),
    ("Â ", " "),
    ("Â\xa0", "\u00a0"),
    # common Vietnamese syllables / words seen broken in this repo
    ("Láº¥y", "Lấy"),
    ("láº¥y", "lấy"),
    ("Ä\u0110áº¿m", "Đếm"),  # Ä + Đ + áº¿m mixed form
    ("Ä\x90áº¿m", "Đếm"),
    ("Äáº¿m", "Đếm"),
    ("tá»•ng", "tổng"),
    ("Tá»•ng", "Tổng"),
    ("dÃ¹ng", "dùng"),
    ("DÃ¹ng", "Dùng"),
    ("phÃ¢n", "phân"),
    ("PhÃ¢n", "Phân"),
    ("trang", "trang"),  # noop safety
]

# Comprehensive character-level / short sequence map for UTF-8->Latin1 Vietnamese
# Source pattern: utf-8 bytes of each letter decoded as latin-1
def _build_char_map() -> list[tuple[str, str]]:
    letters = (
        "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩị"
        "òóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ"
        "ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊ"
        "ÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ"
    )
    pairs: list[tuple[str, str]] = []
    for ch in letters:
        broken = ch.encode("utf-8").decode("latin-1")
        if broken != ch:
            pairs.append((broken, ch))
    # also cp1252 variant for bytes that differ (0x80-0x9F)
    for ch in letters:
        try:
            broken = ch.encode("utf-8").decode("cp1252")
        except UnicodeDecodeError:
            continue
        if broken != ch:
            pairs.append((broken, ch))
    # sort longest first
    pairs.sort(key=lambda x: len(x[0]), reverse=True)
    # dedupe keeping first
    seen = set()
    out: list[tuple[str, str]] = []
    for b, g in pairs:
        if b in seen:
            continue
        seen.add(b)
        out.append((b, g))
    return out


CHAR_MAP = _build_char_map()


def roundtrip_fix(text: str) -> str | None:
    for enc in ("latin-1", "cp1252"):
        try:
            return text.encode(enc).decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            continue
    return None


def map_fix(text: str) -> str:
    # Apply long manual replacements first
    for bad, good in sorted(REPLACEMENTS, key=lambda x: len(x[0]), reverse=True):
        if bad != good and bad in text:
            text = text.replace(bad, good)
    # Then char map (longest first already)
    for bad, good in CHAR_MAP:
        if bad in text:
            text = text.replace(bad, good)
    return text


def smart_fix(text: str) -> str:
    # Try whole-file roundtrip first if clearly mojibake-heavy
    rt = roundtrip_fix(text)
    if rt is not None:
        # Use only if it increases Vietnamese letter count
        from_set = set(
            "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ"
        )
        if sum(1 for c in rt if c in from_set) > sum(1 for c in text if c in from_set):
            text = rt
    # Always apply map fix (handles partial corruption)
    prev = None
    cur = text
    for _ in range(3):
        if cur == prev:
            break
        prev = cur
        cur = map_fix(cur)
    return cur


# Heuristic: file likely has mojibake if these markers exist
DETECT = re.compile(
    r"Ã.|Ä.|Æ.|áº.|á».|â€.|â†.|Â[\xa0\xb7 ]|dÃ¹ng|phÃ¢n|tá»•ng|Láº¥y|Äáº¿m|Ä\x90"
)


def walk():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS and not d.startswith(".")]
        for fn in filenames:
            p = Path(dirpath) / fn
            if p.suffix.lower() in EXTS:
                yield p


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix", action="store_true")
    args = ap.parse_args()

    changed = []
    for path in walk():
        try:
            raw = path.read_bytes()
        except OSError:
            continue
        if len(raw) > 5_000_000:
            continue
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            # Convert non-utf8 to utf8
            for enc in ("cp1252", "latin-1"):
                try:
                    text = raw.decode(enc)
                    break
                except UnicodeDecodeError:
                    text = None
            if text is None:
                continue
            fixed = smart_fix(text)
            if args.fix:
                path.write_bytes(fixed.encode("utf-8"))
            changed.append((path, True, text, fixed))
            continue

        if not DETECT.search(text):
            continue

        fixed = smart_fix(text)
        if fixed != text:
            changed.append((path, False, text, fixed))
            if args.fix:
                path.write_bytes(fixed.encode("utf-8"))

    print(f"Files needing fix: {len(changed)}")
    for path, was_invalid, before, after in changed:
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        print(f"\n=== {rel} invalid_src={was_invalid} ===")
        b_lines = before.splitlines()
        a_lines = after.splitlines()
        n = 0
        for i, (bl, al) in enumerate(zip(b_lines, a_lines), 1):
            if bl != al:
                print(f"  L{i}- {bl[:140]}")
                print(f"  L{i}+ {al[:140]}")
                n += 1
                if n >= 12:
                    break

    if args.fix:
        print(f"\nWrote {len(changed)} files as UTF-8.")
    else:
        print("\nDry-run. Use --fix to apply.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
