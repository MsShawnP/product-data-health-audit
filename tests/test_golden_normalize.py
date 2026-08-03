"""Tests for scripts/golden_normalize.py (golden-diff noise suppression)."""

from __future__ import annotations

import importlib.util
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")


def _load():
    if SCRIPTS not in sys.path:
        sys.path.insert(0, SCRIPTS)
    spec = importlib.util.spec_from_file_location(
        "golden_normalize", os.path.join(SCRIPTS, "golden_normalize.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


gn = _load()


def test_html_widget_ids_normalize_equal():
    a = '<div id="htmlwidget-1a2b3c4d5e" class="reactable"></div><g clip-path="url(#cl_aa11bb)">'
    b = '<div id="htmlwidget-9f8e7d6c5b" class="reactable"></div><g clip-path="url(#cl_ff22ee)">'
    assert gn.normalize_html(a) == gn.normalize_html(b)


def test_html_real_difference_survives():
    a = '<div id="htmlwidget-1a2b3c">Walmart #6</div>'
    b = '<div id="htmlwidget-9f8e7d">Walmart #4</div>'
    assert gn.normalize_html(a) != gn.normalize_html(b)


def test_svg_ids_normalize_equal():
    a = '<svg id="svg_aabbccdd"><rect id="svg_aabbccdd_1"/></svg>'
    b = '<svg id="svg_11223344"><rect id="svg_11223344_1"/></svg>'
    assert gn.normalize_html(a) == gn.normalize_html(b)


def _make_xlsx(path, core_xml, sheet_xml):
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("docProps/core.xml", core_xml)
        z.writestr("xl/worksheets/sheet1.xml", sheet_xml)


def test_xlsx_ignores_core_timestamp(tmp_path):
    a = str(tmp_path / "a.xlsx")
    b = str(tmp_path / "b.xlsx")
    _make_xlsx(a, "<created>2026-05-01T00:00:00Z</created>", "<rows>same</rows>")
    _make_xlsx(b, "<created>2026-08-03T12:34:56Z</created>", "<rows>same</rows>")
    assert gn.diff(a, b) == 0


def test_xlsx_real_content_difference_flagged(tmp_path):
    a = str(tmp_path / "a.xlsx")
    b = str(tmp_path / "b.xlsx")
    _make_xlsx(a, "<created>2026-05-01T00:00:00Z</created>", "<rows>894000</rows>")
    _make_xlsx(b, "<created>2026-05-01T00:00:00Z</created>", "<rows>643000</rows>")
    assert gn.diff(a, b) == 1
