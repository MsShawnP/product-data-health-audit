"""Preflight column specs for the Product Data Health Audit.

Two client extracts feed this audit — an item master and a chargeback/deduction
extract. These specs mirror INPUT-SPEC.md §1 and §2 exactly; keep them in sync.
Consumed by scripts/run_preflight.py.
"""

from __future__ import annotations

from lailara_engagement import ColumnSpec, PreflightSpec

TOOL = "product-data-health-audit"
VERSION = "1.0"


def item_master_spec() -> PreflightSpec:
    """INPUT-SPEC §1 — one row per SKU."""
    S = "INPUT-SPEC §1"
    cols = [
        ColumnSpec("sku", dtype="identifier", required=True, unique=True,
                   spec_ref=S, description="Primary key; unique per SKU"),
        ColumnSpec("product_name", dtype="string", required=True, spec_ref=S,
                   description="Product name, labels every finding"),
        ColumnSpec("product_line", dtype="string", required=True, spec_ref=S,
                   description="Product line, drives data-debt-by-line"),
        ColumnSpec("gtin14", dtype="identifier", required=True, spec_ref=S,
                   description="GTIN-14; check-digit validated"),
        ColumnSpec("upc", dtype="identifier", required=True, spec_ref=S,
                   description="UPC; check-digit validated"),
        # Completeness fields: column must exist, blanks are audit findings.
        ColumnSpec("brand_owner", dtype="string", required=True, allow_blank=True,
                   spec_ref=S, description="Required-field completeness check"),
        ColumnSpec("country_of_origin", dtype="string", required=True, allow_blank=True,
                   spec_ref=S, description="Required-field completeness check"),
        ColumnSpec("case_pack_qty", dtype="number", required=True, allow_blank=True,
                   not_negative=True, spec_ref=S, description="Case-pack completeness"),
        ColumnSpec("unit_weight_lbs", dtype="number", required=True, allow_blank=True,
                   not_negative=True, spec_ref=S, description="Weight plausibility"),
        ColumnSpec("case_weight_lbs", dtype="number", required=True, allow_blank=True,
                   not_negative=True, spec_ref=S, description="Case-weight completeness"),
        ColumnSpec("case_length_in", dtype="number", required=True, allow_blank=True,
                   not_negative=True, spec_ref=S, description="Case-dimension completeness"),
        ColumnSpec("case_width_in", dtype="number", required=True, allow_blank=True,
                   not_negative=True, spec_ref=S, description="Case-dimension completeness"),
        ColumnSpec("case_height_in", dtype="number", required=True, allow_blank=True,
                   not_negative=True, spec_ref=S, description="Case-dimension completeness"),
        # Money: required and non-negative.
        ColumnSpec("cogs_per_unit", dtype="number", required=True, not_negative=True,
                   spec_ref=S, description="Gross-margin math"),
        ColumnSpec("wholesale_price", dtype="number", required=True, not_negative=True,
                   spec_ref=S, description="Revenue / margin math"),
        ColumnSpec("msrp", dtype="number", required=True, allow_blank=True, not_negative=True,
                   spec_ref=S, description="Reference pricing"),
        # Optional.
        ColumnSpec("last_updated", dtype="date", required=False,
                   spec_ref=S, description="Audit-trail / SKU-age analysis"),
    ]
    return PreflightSpec(tool=f"{TOOL}:item-master", columns=cols, version=VERSION)


def chargebacks_spec() -> PreflightSpec:
    """INPUT-SPEC §2 — one row per chargeback line item."""
    S = "INPUT-SPEC §2"
    cols = [
        ColumnSpec("chargeback_id", dtype="identifier", required=True, unique=True,
                   spec_ref=S, description="Primary key; unique per line item"),
        ColumnSpec("sku", dtype="identifier", required=True, spec_ref=S,
                   description="Joins to item-master sku"),
        ColumnSpec("retailer", dtype="string", required=True, spec_ref=S,
                   description="Per-retailer P&L and roster"),
        ColumnSpec("amount", dtype="number", required=True, not_negative=True,
                   spec_ref=S, description="Chargeback dollars"),
        ColumnSpec("reason", dtype="string", required=True, spec_ref=S,
                   description="Reason-category breakdown"),
        # 'month' is YYYY-MM (not a full date), so validate as string not date.
        ColumnSpec("month", dtype="string", required=True, spec_ref=S,
                   description="Reporting month YYYY-MM; annualization window"),
        ColumnSpec("triggered_by_field", dtype="string", required=False, allow_blank=True,
                   spec_ref=S, description="Data-defect attribution; blank = fulfillment-driven"),
    ]
    return PreflightSpec(tool=f"{TOOL}:chargebacks", columns=cols, version=VERSION)


# Map the runner's --flag name to (spec builder, handoff basename).
SPECS = {
    "item_master": (item_master_spec, "item_master"),
    "chargebacks": (chargebacks_spec, "chargebacks"),
}
