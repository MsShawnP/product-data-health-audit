"""Golden-diff normalization for the render outputs.

Two classes of noise make raw byte-diffs of the pipeline outputs cry wolf even
when nothing meaningful changed (PDHA-RENDER-VERIFICATION.md, harness notes):

  * HTML: htmlwidgets / ggiraph assign random element IDs per render
    (`htmlwidget-<hex>`, `svg_<hex>`, ggiraph clip-path ids), so identical charts
    diff on the IDs alone.
  * XLSX: `docProps/core.xml` carries a creation timestamp that changes every run.

This module normalizes both so a golden comparison sees only real differences.

CLI:
    python scripts/golden_normalize.py normalize report.html        # -> stdout
    python scripts/golden_normalize.py diff a/report.html b/report.html
    python scripts/golden_normalize.py diff a/audit.xlsx b/audit.xlsx

`diff` exits 0 when the two files are equal after normalization, 1 when they
differ (printing a short summary), 2 on a usage error.
"""

from __future__ import annotations

import hashlib
import io
import re
import sys
import zipfile

# Random-id patterns emitted by htmlwidgets / ggiraph. Each maps a per-render
# random id to a stable placeholder so identical content compares equal.
_HTML_ID_PATTERNS = [
    (re.compile(r"htmlwidget[-_][0-9a-f]{6,}", re.I), "htmlwidget-ID"),
    (re.compile(r"svg_[0-9a-f]{6,}", re.I), "svg_ID"),
    (re.compile(r"\bggiraph[-_][0-9a-f]{6,}", re.I), "ggiraph-ID"),
    # ggiraph clip/def ids look like "cl_1a2b..." / "svg_..._clip" and appear in
    # url(#..) references; collapse the hex tail while keeping the prefix.
    (re.compile(r"(url\(#[A-Za-z_]+?)[0-9a-f]{6,}(\))", re.I), r"\1ID\2"),
]

# xlsx members whose content is inherently per-run (timestamps) and must be
# excluded from the comparison.
_XLSX_IGNORE = {"docProps/core.xml"}


def normalize_html(text: str) -> str:
    """Replace per-render random element IDs with stable placeholders."""
    for pat, repl in _HTML_ID_PATTERNS:
        text = pat.sub(repl, text)
    return text


def _read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def xlsx_fingerprint(path: str) -> dict[str, str]:
    """Map each xlsx member (except ignored ones) to a sha256 of its bytes."""
    out: dict[str, str] = {}
    with zipfile.ZipFile(path) as z:
        for name in sorted(z.namelist()):
            if name in _XLSX_IGNORE:
                continue
            out[name] = hashlib.sha256(z.read(name)).hexdigest()
    return out


def _is_xlsx(path: str) -> bool:
    return path.lower().endswith((".xlsx", ".xlsm"))


def diff(a: str, b: str) -> int:
    """Return 0 if a and b are equal after normalization, else 1 (with a summary)."""
    if _is_xlsx(a) or _is_xlsx(b):
        fa, fb = xlsx_fingerprint(a), xlsx_fingerprint(b)
        if fa == fb:
            return 0
        only_a = sorted(set(fa) - set(fb))
        only_b = sorted(set(fb) - set(fa))
        changed = sorted(k for k in set(fa) & set(fb) if fa[k] != fb[k])
        print(f"XLSX differs (ignoring {sorted(_XLSX_IGNORE)}):")
        if only_a:
            print("  only in A:", only_a)
        if only_b:
            print("  only in B:", only_b)
        if changed:
            print("  changed members:", changed)
        return 1
    na, nb = normalize_html(_read_text(a)), normalize_html(_read_text(b))
    if na == nb:
        return 0
    # Report the first differing line for a quick signal.
    la, lb = na.splitlines(), nb.splitlines()
    for i, (x, y) in enumerate(zip(la, lb), 1):
        if x != y:
            print(f"HTML differs at line {i} (after id-normalization):")
            print(f"  A: {x[:160]}")
            print(f"  B: {y[:160]}")
            return 1
    print(f"HTML differs in length after normalization: {len(la)} vs {len(lb)} lines")
    return 1


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "normalize":
        sys.stdout.write(normalize_html(_read_text(argv[1])))
        return 0
    if len(argv) >= 3 and argv[0] == "diff":
        return diff(argv[1], argv[2])
    sys.stderr.write(__doc__ or "")
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
