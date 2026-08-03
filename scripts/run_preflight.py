"""Preflight gate for the Product Data Health Audit.

Runs the lailara_engagement preflight over the client extracts BEFORE the R stage
touches anything. Emits:

  * a branded Data Readiness Report (HTML + terminal) per input, and
  * on a clean/warnings pass: a validated CSV handoff the R stage reads, plus a
    PREFLIGHT_STATUS.json token the R gate (R/00_preflight_gate.R) checks.

If any required extract fails validation, no handoff is written, the token records
`passed: false`, and the process exits non-zero. The R stage refuses to run without a
clean token — so unvalidated client data can never reach the analysis.

Usage:
    python scripts/run_preflight.py \
        --config engagement.demo.yml \
        --item-master data/item_master.csv \
        --chargebacks data/chargebacks.csv \
        [--out output/preflight] [--final]

Exit codes: 0 = ready (clean or proceeded-with-warnings); 2 = blocked; 1 = usage error.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

from lailara_engagement import (
    build_provenance,
    load_config,
    read_table,
    render_terminal,
    run_preflight,
    validation_status_label,
    write_report,
)

# Import the specs whether run as a script or a module.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from preflight_spec import SPECS, TOOL, VERSION  # noqa: E402

STATUS_FILE = "PREFLIGHT_STATUS.json"


def _find_config(explicit: str | None) -> str:
    if explicit:
        return explicit
    for cand in ("engagement.yml", "engagement.demo.yml"):
        if os.path.exists(cand):
            return cand
    raise SystemExit(
        "No config found. Pass --config, or add engagement.yml / engagement.demo.yml."
    )


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Preflight the audit's client extracts.")
    ap.add_argument("--config", default=None,
                    help="engagement.yml (defaults to engagement.yml then engagement.demo.yml)")
    ap.add_argument("--item-master", default=None, help="Item-master CSV/XLSX (INPUT-SPEC §1)")
    ap.add_argument("--chargebacks", default=None, help="Chargeback extract CSV/XLSX (INPUT-SPEC §2)")
    ap.add_argument("--out", default=os.path.join("output", "preflight"),
                    help="Output dir for the readiness report + validated handoff")
    ap.add_argument("--final", action="store_true",
                    help="Drop the DRAFT watermark (deliverable is final)")
    args = ap.parse_args(argv)

    inputs = {"item_master": args.item_master, "chargebacks": args.chargebacks}
    if not any(inputs.values()):
        ap.error("provide at least one of --item-master / --chargebacks")

    config = load_config(_find_config(args.config))
    os.makedirs(args.out, exist_ok=True)
    handoff_dir = os.path.join(args.out, "validated")

    reads = []
    reports = []
    overall_passed = True
    input_meta = []

    for key, path in inputs.items():
        if not path:
            continue
        if not os.path.exists(path):
            raise SystemExit(f"input not found: {path}")
        spec_builder, basename = SPECS[key]
        spec = spec_builder()
        read = read_table(path)
        report = run_preflight(read, spec, config)
        reads.append(read)
        reports.append((key, basename, read, report))
        overall_passed = overall_passed and report.passed
        input_meta.append({
            "role": key,
            "filename": read.filename,
            "sha256": read.sha256,
            "n_rows": read.n_rows,
            "n_cols": read.n_cols,
            "status": report.status,
        })

    status_overall = "clean"
    if any(r.status == "failed" for _, _, _, r in reports):
        status_overall = "failed"
    elif any(r.status == "warnings" for _, _, _, r in reports):
        status_overall = "warnings"
    n_warn_total = sum(r.n_warnings for _, _, _, r in reports)

    prov = build_provenance(
        tool=TOOL, tool_version=VERSION, inputs=reads, config=config,
        validation_status=validation_status_label(status_overall, n_warn_total),
    )

    # Per-input branded readiness report + terminal echo.
    for key, basename, read, report in reports:
        write_report(
            report, config, args.out,
            provenance=prov, draft=not args.final,
            basename=f"data-readiness-report-{basename}",
            title=f"Data Readiness Report — {key.replace('_', ' ').title()}",
        )
        print(render_terminal(report, config, prov))
        print()

    # Token the R gate reads. Written on every run (passed or not).
    status_payload = {
        "tool": TOOL,
        "version": VERSION,
        "passed": overall_passed,
        "status": status_overall,
        "as_of_date": config.as_of_date.isoformat(),
        "client_name": config.client_name,
        "engagement_id": config.engagement_id,
        "config_hash_short": config.config_hash_short,
        "is_demo": config.is_demo,
        "final": bool(args.final),
        "inputs": input_meta,
    }
    with open(os.path.join(args.out, STATUS_FILE), "w", encoding="utf-8") as fh:
        json.dump(status_payload, fh, indent=2)

    if not overall_passed:
        print(f"BLOCKED — data not ready. See {args.out}/data-readiness-report-*.html")
        return 2

    # Clean/warnings: write the validated handoff the R stage consumes.
    os.makedirs(handoff_dir, exist_ok=True)
    for key, basename, read, _ in reports:
        read.frame.to_csv(
            os.path.join(handoff_dir, f"{basename}.csv"), index=False,
        )
    print(f"READY ({status_overall}). Validated handoff -> {handoff_dir}/")
    print(f"Token -> {os.path.join(args.out, STATUS_FILE)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
