"""Export Cinderhaven SSOT tables from Postgres into local SQLite for PDHA.

Replaces the independent data generators. The R pipeline's 01_load_raw.R
reads from the exported SQLite when DATABASE_URL is not set, producing
identical analytical frames as if it connected to dbt marts.

The export does the raw-to-mart transformation that dbt previously handled:
  - Merges raw.product_master + raw.sku_costs into a single product_master
  - Maps retailer_id codes (RET-WALMART) to readable names (Walmart)
  - Formats chargeback months as YYYY-MM text
  - Computes first_scan_week per (sku, store) from scan_data

Usage:
    flyctl proxy 5434 -a cinderhaven-db  # in another terminal
    POSTGRES_PASSWORD=... python scripts/export_from_postgres.py
"""
from __future__ import annotations

import os
import sqlite3
import sys
from decimal import Decimal
from pathlib import Path

import psycopg2

PGPORT = os.environ.get("PGPORT", "5434")
PGPASS = os.environ.get("POSTGRES_PASSWORD", "")
DB_URL = os.environ.get(
    "DATABASE_URL",
    f"postgresql://postgres:{PGPASS}@127.0.0.1:{PGPORT}/cinderhaven",
)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "cinderhaven_product_master.db"

EXPORTS = {
    "product_master": """
        SELECT
            pm.sku, pm.product_name, pm.product_line, pm.subcategory,
            pm.gtin14, pm.upc, pm.case_pack_qty,
            pm.unit_weight_lbs, pm.case_weight_lbs,
            pm.case_length_in, pm.case_width_in, pm.case_height_in,
            pm.msrp, pm.brand_owner, pm.country_of_origin, pm.last_updated,
            sc.cogs_per_unit, sc.landed_cost_per_unit, sc.wholesale_price,
            sc.wholesale_walmart, sc.wholesale_costco, sc.wholesale_whole_foods,
            sc.wholesale_sprouts, sc.wholesale_regional,
            sc.wholesale_unfi, sc.wholesale_kehe, sc.wholesale_dtc,
            sc.trade_spend_pct_walmart, sc.trade_spend_pct_costco,
            sc.trade_spend_pct_whole_foods, sc.trade_spend_pct_sprouts,
            sc.trade_spend_pct_regional, sc.trade_spend_pct_unfi,
            sc.trade_spend_pct_kehe, sc.trade_spend_pct_dtc,
            CASE WHEN sc.wholesale_dtc > 0
                 THEN sc.wholesale_dtc - sc.cogs_per_unit END AS dtc_margin_per_unit,
            CASE WHEN sc.wholesale_dtc > 0
                 THEN (sc.wholesale_dtc - sc.cogs_per_unit) / sc.wholesale_dtc END AS dtc_margin_pct,
            sc.wholesale_price - sc.cogs_per_unit AS margin_per_unit,
            CASE WHEN sc.wholesale_price > 0
                 THEN (sc.wholesale_price - sc.cogs_per_unit) / sc.wholesale_price END AS margin_pct,
            COALESCE(rc.retailer_count, 0) AS retailer_count,
            COALESCE(dc.distributor_count, 0) AS distributor_count,
            COALESCE(ac.authorized_store_count, 0) AS authorized_store_count
        FROM raw.product_master pm
        JOIN raw.sku_costs sc ON pm.sku = sc.sku
        LEFT JOIN (
            SELECT sku, COUNT(DISTINCT retailer_id) AS retailer_count
            FROM raw.distribution_log dl
            JOIN raw.stores s ON dl.store_id = s.store_id
            WHERE dl.deauthorized_date IS NULL
            GROUP BY sku
        ) rc ON pm.sku = rc.sku
        LEFT JOIN (
            SELECT sku, COUNT(DISTINCT distributor_id) AS distributor_count
            FROM raw.sku_distributors
            GROUP BY sku
        ) dc ON pm.sku = dc.sku
        LEFT JOIN (
            SELECT sku, COUNT(DISTINCT store_id) AS authorized_store_count
            FROM raw.distribution_log
            WHERE deauthorized_date IS NULL
            GROUP BY sku
        ) ac ON pm.sku = ac.sku
    """,
    "chargebacks": """
        SELECT
            rc.chargeback_id, rc.sku,
            r.name AS retailer,
            rc.amount, rc.reason,
            TO_CHAR(rc.month, 'YYYY-MM') AS month,
            rc.triggered_by_field
        FROM raw.retailer_chargebacks rc
        JOIN raw.retailers r ON rc.retailer_id = r.retailer_id
    """,
    "stores": """
        SELECT
            s.store_id,
            r.name AS retailer,
            s.region, s.state, s.volume_tier
        FROM raw.stores s
        JOIN raw.retailers r ON s.retailer_id = r.retailer_id
    """,
    "distribution": """
        SELECT
            dl.sku, dl.store_id,
            s.retailer_id, s.chain_name, s.region, s.state, s.volume_tier,
            dl.authorized_date, dl.deauthorized_date,
            CASE WHEN dl.deauthorized_date IS NULL THEN true ELSE false END AS is_active,
            COALESCE(sa.weeks_with_sales, 0)  AS weeks_with_sales,
            COALESCE(sa.total_units, 0)       AS total_units,
            COALESCE(sa.total_dollars, 0)     AS total_dollars,
            COALESCE(sa.avg_weekly_units, 0)  AS avg_weekly_units,
            sa.first_scan_week,
            sa.last_scan_week
        FROM raw.distribution_log dl
        JOIN raw.stores s ON dl.store_id = s.store_id
        LEFT JOIN (
            SELECT sku, store_id,
                   COUNT(DISTINCT week_ending) AS weeks_with_sales,
                   SUM(units_sold)             AS total_units,
                   SUM(dollars_sold)           AS total_dollars,
                   CASE WHEN COUNT(DISTINCT week_ending) > 0
                        THEN SUM(units_sold)::float / COUNT(DISTINCT week_ending)
                        ELSE 0 END             AS avg_weekly_units,
                   MIN(week_ending)            AS first_scan_week,
                   MAX(week_ending)            AS last_scan_week
            FROM raw.scan_data
            GROUP BY sku, store_id
        ) sa ON dl.sku = sa.sku AND dl.store_id = sa.store_id
    """,
    "scan_data": """
        SELECT sku, store_id, week_ending, units_sold, dollars_sold
        FROM raw.scan_data
    """,
    "promotions": """
        SELECT
            p.promo_id, p.sku,
            r.name AS retailer,
            p.start_week, p.end_week,
            p.discount_depth_pct, p.promo_type, p.promo_cost, p.funding_mechanism
        FROM raw.promotions p
        JOIN raw.retailers r ON p.retailer_id = r.retailer_id
    """,
    "retailer_requirements": """
        SELECT
            r.name AS retailer,
            rr.field,
            CASE WHEN rr.required THEN 1 ELSE 0 END AS required,
            rr.notes
        FROM raw.retailer_requirements rr
        JOIN raw.retailers r ON rr.retailer_id = r.retailer_id
    """,
}


def export():
    if not PGPASS and "DATABASE_URL" not in os.environ:
        print("Set POSTGRES_PASSWORD or DATABASE_URL.", file=sys.stderr)
        sys.exit(1)

    print(f"Connecting to Postgres...")
    pg = psycopg2.connect(DB_URL)
    pg.set_session(readonly=True)
    cur = pg.cursor()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        backup = OUT.with_suffix(".db.bak")
        if backup.exists():
            backup.unlink()
        print(f"  Backing up existing DB to {backup.name}")
        OUT.rename(backup)

    sl = sqlite3.connect(str(OUT))
    sl.execute("PRAGMA journal_mode=WAL")
    sl.execute("PRAGMA synchronous=NORMAL")

    for table_name, query in EXPORTS.items():
        cur.execute(query)
        cols = [desc[0] for desc in cur.description]

        col_defs = []
        for col in cols:
            col_defs.append(f'"{col}" TEXT')
        sl.execute(f"DROP TABLE IF EXISTS [{table_name}]")
        sl.execute(f"CREATE TABLE [{table_name}] ({', '.join(col_defs)})")

        batch_size = 10_000
        total = 0
        while True:
            rows = cur.fetchmany(batch_size)
            if not rows:
                break
            clean = [
                tuple(
                    float(v) if isinstance(v, Decimal)
                    else str(v) if isinstance(v, (bool,)) and v is not None
                    else v
                    for v in row
                )
                for row in rows
            ]
            placeholders = ", ".join(["?"] * len(cols))
            sl.executemany(
                f"INSERT INTO [{table_name}] VALUES ({placeholders})",
                clean,
            )
            total += len(rows)
            if total % 200_000 == 0:
                print(f"    {table_name}: {total:,} rows...", flush=True)

        sl.commit()
        print(f"  {table_name}: {total:,} rows")

    sl.execute("ANALYZE")
    sl.close()
    pg.close()

    size_mb = OUT.stat().st_size / (1024 * 1024)
    print(f"\nExported to {OUT} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    export()
