"""Generate synthetic engagement fixtures for the preflight wiring.

Produces two intake sets under tests/fixtures/engagement/:

  demo/       — Cinderhaven extracts with canonical headers; the CLEAN path.
  northwind/  — "Northwind Naturals": a different brand and retailer roster, one
                renamed header (to exercise column mapping), and cogs_per_unit
                deliberately DROPPED — the missing-required-column readiness path.

All data is synthetic (Cinderhaven is a demo dataset); Northwind is a rebrand of it
with no real-client identifiers. Re-run any time: `python scripts/make_engagement_fixtures.py`.
"""

from __future__ import annotations

import csv
import os
import sqlite3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "data", "cinderhaven_product_master.db")
FIX = os.path.join(ROOT, "tests", "fixtures", "engagement")

ITEM_COLS = [
    "sku", "product_name", "product_line", "gtin14", "upc",
    "brand_owner", "country_of_origin", "case_pack_qty", "unit_weight_lbs",
    "case_weight_lbs", "case_length_in", "case_width_in", "case_height_in",
    "cogs_per_unit", "wholesale_price", "msrp", "last_updated",
]
CB_COLS = ["chargeback_id", "sku", "retailer", "amount", "reason", "month", "triggered_by_field"]

# Northwind uses a different retailer roster; remap Cinderhaven's retailers onto it.
RETAILER_MAP = {
    "Walmart": "Kroger", "Costco": "Publix", "Whole Foods": "Wegmans",
    "Sprouts": "HEB", "Kroger": "Ahold Delhaize", "Regional Group": "Northeast Co-op",
}


def _rows(con, table, cols):
    cur = con.execute(f"SELECT {', '.join(cols)} FROM {table}")
    names = [d[0] for d in cur.description]
    return names, [dict(zip(names, r)) for r in cur.fetchall()]


def _write(path, header, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=header, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"  wrote {path} ({len(rows)} rows, {len(header)} cols)")


def main() -> None:
    con = sqlite3.connect(DB)

    # ---- demo (clean path) --------------------------------------------------
    _, items = _rows(con, "product_master", ITEM_COLS)
    _, cbs = _rows(con, "chargebacks", CB_COLS)
    cbs_sample = cbs[:600]  # a representative sample validates structure

    _write(os.path.join(FIX, "demo", "item_master.csv"), ITEM_COLS, items)
    _write(os.path.join(FIX, "demo", "chargebacks.csv"), CB_COLS, cbs_sample)

    # ---- northwind (readiness-report path) ----------------------------------
    # Rebrand: new SKU prefix, brand owner, retailer roster; rename a header to
    # exercise column mapping; DROP cogs_per_unit to trigger a missing-column block.
    nw_item_header = [c for c in ITEM_COLS if c != "cogs_per_unit"]
    nw_item_header = ["Item Description" if c == "product_name" else c for c in nw_item_header]
    nw_items = []
    for r in items:
        r2 = {k: v for k, v in r.items() if k != "cogs_per_unit"}
        r2["sku"] = r["sku"].replace("CHP-", "NWN-")
        r2["brand_owner"] = "Northwind Naturals"
        r2["Item Description"] = r["product_name"]
        nw_items.append(r2)
    _write(os.path.join(FIX, "northwind", "item_master.csv"), nw_item_header, nw_items)

    nw_cbs = []
    for r in cbs_sample:
        r2 = dict(r)
        r2["sku"] = r["sku"].replace("CHP-", "NWN-")
        r2["retailer"] = RETAILER_MAP.get(r["retailer"], r["retailer"])
        nw_cbs.append(r2)
    _write(os.path.join(FIX, "northwind", "chargebacks.csv"), CB_COLS, nw_cbs)

    con.close()
    print("done.")


if __name__ == "__main__":
    main()
