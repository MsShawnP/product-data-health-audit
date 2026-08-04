"""Regression test for the engagement preflight wiring (checklist §1, §2, §6).

Verifies the two deliverable-proof paths end to end:
  * demo extracts (canonical headers) -> CLEAN, exit 0, validated handoff written;
  * a synthetic client with a renamed header and a missing required column ->
    BLOCKED, exit 2, the readiness report names the missing column, no handoff.

Runnable now (Python-only); does not require the R/Quarto toolchain.
"""

from __future__ import annotations

import importlib.util
import json
import os
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
FIX = os.path.join(ROOT, "tests", "fixtures", "engagement")

pytest.importorskip("lailara_engagement")


def _load_runner():
    if SCRIPTS not in sys.path:
        sys.path.insert(0, SCRIPTS)
    spec = importlib.util.spec_from_file_location(
        "run_preflight", os.path.join(SCRIPTS, "run_preflight.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _read_token(out):
    with open(os.path.join(out, "PREFLIGHT_STATUS.json"), encoding="utf-8") as fh:
        return json.load(fh)


def test_demo_clean_path(tmp_path):
    runner = _load_runner()
    out = str(tmp_path / "demo")
    rc = runner.main([
        "--config", os.path.join(ROOT, "engagement.demo.yml"),
        "--item-master", os.path.join(FIX, "demo", "item_master.csv"),
        "--chargebacks", os.path.join(FIX, "demo", "chargebacks.csv"),
        "--out", out,
    ])
    assert rc == 0
    tok = _read_token(out)
    assert tok["passed"] is True
    assert tok["status"] == "clean"
    assert tok["client_name"] == "Cinderhaven Provisions"
    # Clean pass writes the validated handoff the R stage reads.
    assert os.path.exists(os.path.join(out, "validated", "item_master.csv"))
    assert os.path.exists(os.path.join(out, "validated", "chargebacks.csv"))


def test_northwind_missing_column_blocks(tmp_path):
    runner = _load_runner()
    out = str(tmp_path / "nwn")
    rc = runner.main([
        "--config", os.path.join(FIX, "engagement.northwind.yml"),
        "--item-master", os.path.join(FIX, "northwind", "item_master.csv"),
        "--chargebacks", os.path.join(FIX, "northwind", "chargebacks.csv"),
        "--out", out,
    ])
    assert rc == 2
    tok = _read_token(out)
    assert tok["passed"] is False
    assert tok["status"] == "failed"
    assert tok["client_name"] == "Northwind Naturals"
    # No handoff on a blocked run — unvalidated data never reaches the R stage.
    assert not os.path.exists(os.path.join(out, "validated"))
    # The readiness report names the missing required column with its spec ref.
    html = os.path.join(out, "data-readiness-report-item_master.html")
    with open(html, encoding="utf-8") as fh:
        body = fh.read()
    assert "cogs_per_unit" in body
    assert "INPUT-SPEC" in body


def test_northwind_header_mapping_resolved(tmp_path):
    """The renamed 'Item Description' header maps to product_name (no false missing)."""
    runner = _load_runner()
    out = str(tmp_path / "nwn2")
    runner.main([
        "--config", os.path.join(FIX, "engagement.northwind.yml"),
        "--item-master", os.path.join(FIX, "northwind", "item_master.csv"),
        "--out", out,
    ])
    html = os.path.join(out, "data-readiness-report-item_master.html")
    with open(html, encoding="utf-8") as fh:
        body = fh.read()
    # product_name is present (via mapping), so it must NOT be reported missing.
    assert "column 'product_name' not found" not in body
