#!/usr/bin/env python3
"""
Detect and fix UTF-8 mojibake (Vietnamese) in source files.

Detection: if re-interpreting the text as latin-1/cp1252 bytes then decoding
as UTF-8 yields more Vietnamese diacritics and fewer mojibake markers, flag it.
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
    "tools",  # skip our own reports
}

# Characters typical of correct Vietnamese
VN_CHARS = set("àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ")

# Strong mojibake markers (UTF-8 misread as Latin-1/Windows-1252)
MOJI_MARKERS = re.compile(
    r"(?:Ã.|Ä.|Æ.|áº.|á».|â€.|Â.|Ã¡|Ã |Ã¢|Ã£|Ã©|Ã¨|Ãª|Ã­|Ã¬|Ã³|Ã²|Ã´|Ã¹|Ãº|Ã½|Ä‘|Ä\u0110|Æ¡|Æ°)"
)

# Manual known multi-byte glyph fixes that may survive partial repair
MANUAL_MAP = {
    "â†”": "↔",
    "â€”": "—",
    "â€“": "–",
    "â€™": "'",
    "â€œ": '"',
    "â€\x9d": '"',
    "â€¢": "•",
    "â€¦": "…",
    "âœ…": "✅",
    "âŒ": "❌",
    "â³": "⏳",
    "â¸": "⏸",
    "Â ": " ",
    "Â·": "·",
}


def count_vn(s: str) -> int:
    return sum(1 for ch in s if ch in VN_CHARS)


def count_moji(s: str) -> int:
    return len(MOJI_MARKERS.findall(s))


def try_fix_mojibake(text: str) -> str | None:
    """
    Attempt classic fix: text was UTF-8 bytes mis-decoded as latin-1/cp1252.
    Returns fixed string if improvement detected, else None.
    """
    candidates: list[str] = []

    for enc in ("latin-1", "cp1252"):
        try:
            fixed = text.encode(enc, errors="strict").decode("utf-8", errors="strict")
            candidates.append(fixed)
        except (UnicodeEncodeError, UnicodeDecodeError):
            # Partial: encode with replace then only keep if clearly better
            try:
                raw = text.encode(enc, errors="replace")
                fixed = raw.decode("utf-8", errors="replace")
                if "\ufffd" not in fixed:
                    candidates.append(fixed)
            except Exception:
                pass

    # Also apply MANUAL_MAP alone
    manual = text
    for bad, good in MANUAL_MAP.items():
        manual = manual.replace(bad, good)
    if manual != text:
        candidates.append(manual)

    best = None
    best_score = -10**9
    base_vn = count_vn(text)
    base_moji = count_moji(text)

    for cand in candidates:
        if cand == text:
            continue
        # Prefer more VN diacritics, fewer mojibake markers, similar length
        score = (count_vn(cand) - base_vn) * 3 + (base_moji - count_moji(cand)) * 5
        # Penalize huge length changes
        score -= abs(len(cand) - len(text)) // 50
        if score > best_score:
            best_score = score
            best = cand

    # Require real improvement
    if best is not None and best_score >= 3:
        return best
    return None


def iterative_fix(text: str) -> tuple[str, int]:
    """Apply fix repeatedly until stable (handles double-encoding)."""
    cur = text
    rounds = 0
    for _ in range(3):
        fixed = try_fix_mojibake(cur)
        if fixed is None:
            break
        cur = fixed
        rounds += 1
    # Final manual map pass
    for bad, good in MANUAL_MAP.items():
        if bad in cur:
            cur = cur.replace(bad, good)
    return cur, rounds


def walk_files():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS and not d.startswith(".")]
        for fn in filenames:
            path = Path(dirpath) / fn
            if path.suffix.lower() not in EXTS:
                continue
            yield path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix", action="store_true", help="Write fixes to disk")
    ap.add_argument("--dry-run", action="store_true", help="Only report (default)")
    args = ap.parse_args()
    do_fix = args.fix

    issues: list[tuple[Path, int, int, str, str]] = []
    invalid_utf8: list[Path] = []

    for path in walk_files():
        try:
            data = path.read_bytes()
        except OSError:
            continue
        if len(data) > 5_000_000:
            continue

        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            invalid_utf8.append(path)
            # try recover as cp1252 then re-encode utf-8
            try:
                text = data.decode("cp1252")
            except UnicodeDecodeError:
                text = data.decode("latin-1")
            if do_fix:
                path.write_bytes(text.encode("utf-8"))
            continue

        moji = count_moji(text)
        if moji == 0 and count_vn(text) > 0:
            # still try fix in case markers missed
            pass

        fixed, rounds = iterative_fix(text)
        if fixed != text:
            issues.append((path, moji, rounds, text, fixed))
            if do_fix:
                # write UTF-8 without BOM
                path.write_bytes(fixed.encode("utf-8"))

    print(f"Invalid UTF-8 files: {len(invalid_utf8)}")
    for p in invalid_utf8:
        print(f"  INVALID  {p.relative_to(ROOT)}")

    print(f"\nMojibake files: {len(issues)}")
    for path, moji, rounds, before, after in sorted(issues, key=lambda x: -x[1]):
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        print(f"\n=== {rel}  (markers≈{moji}, fix_rounds={rounds}) ===")
        # show first differing lines
        b_lines = before.splitlines()
        a_lines = after.splitlines()
        shown = 0
        for i, (bl, al) in enumerate(zip(b_lines, a_lines), 1):
            if bl != al:
                print(f"  L{i}-: {bl[:120]}")
                print(f"  L{i}+: {al[:120]}")
                shown += 1
                if shown >= 8:
                    break
        if len(b_lines) != len(a_lines):
            print(f"  (line count {len(b_lines)} -> {len(a_lines)})")

    if do_fix:
        print(f"\nFIXED {len(issues)} mojibake + {len(invalid_utf8)} invalid encoding files.")
    else:
        print("\nDry-run only. Re-run with --fix to write changes.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
