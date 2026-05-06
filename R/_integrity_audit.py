"""Comprehensive data-integrity audit of cinderhaven_product_master.db.

Checks for the same class of authorization-mismatch bug we found in
chargebacks, and for orphan / temporal / referential-integrity issues.
Read-only — does not modify the DB.
"""
from __future__ import annotations
import sqlite3
from pathlib import Path
from collections import Counter

DB = Path(r"C:/Users/mssha/OneDrive/Desktop/product-data-health-audit/data/cinderhaven_product_master.db")
con = sqlite3.connect(DB)
cur = con.cursor()

def q(sql, *params):
    return cur.execute(sql, params).fetchall()

def banner(n, title):
    print(f"\n{'='*70}\n{n}. {title}\n{'='*70}")

# Authorized (sku, retailer) set
auth_pairs = set(q("""
    SELECT DISTINCT d.sku, s.retailer
    FROM distribution_log d JOIN stores s ON s.store_id = d.store_id
"""))
auth_skus = {sku for sku, _ in auth_pairs}
auth_sku_store = set(q("SELECT DISTINCT sku, store_id FROM distribution_log"))

# ---------- 1. SCAN DATA ----------
banner(1, "SCAN DATA - rows on (sku, store) pairs with no authorization")
# scan_data has store_id; check (sku, store_id) against distribution_log
n_scan = q("SELECT COUNT(*) FROM scan_data")[0][0]
unauth_scan = q("""
    SELECT COUNT(*), SUM(units_sold), SUM(dollars_sold)
    FROM scan_data sd
    WHERE NOT EXISTS (
      SELECT 1 FROM distribution_log d
      WHERE d.sku = sd.sku AND d.store_id = sd.store_id
    )
""")[0]
unauth_skus_in_scan = q("""
    SELECT COUNT(DISTINCT sd.sku || '|' || sd.store_id)
    FROM scan_data sd
    WHERE NOT EXISTS (
      SELECT 1 FROM distribution_log d
      WHERE d.sku = sd.sku AND d.store_id = sd.store_id
    )
""")[0][0]
print(f"  Total scan_data rows: {n_scan:,}")
print(f"  Unauthorized scan rows: {unauth_scan[0]:,} ({100*unauth_scan[0]/n_scan:.1f}%)")
print(f"    units: {unauth_scan[1] or 0:,}   dollars: ${unauth_scan[2] or 0:,.2f}")
print(f"  Distinct unauthorized (sku, store) pairs: {unauth_skus_in_scan:,}")

# ---------- 2. PROMOTIONS ----------
banner(2, "PROMOTIONS - rows on (sku, retailer) pairs with no authorization")
promos = q("SELECT sku, retailer FROM promotions")
n_promo = len(promos)
unauth_promo = [(s, r) for s, r in promos if (s, r) not in auth_pairs]
print(f"  Total promotions: {n_promo}")
print(f"  Unauthorized (sku, retailer) promo rows: {len(unauth_promo)} ({100*len(unauth_promo)/n_promo:.1f}%)")
if unauth_promo:
    by_retailer = Counter(r for _, r in unauth_promo)
    print("  Top unauth retailers in promos:", dict(by_retailer.most_common(5)))
    print(f"  Sample: {unauth_promo[:5]}")

# ---------- 3. PRICE HISTORY ----------
banner(3, "PRICE HISTORY - rows on (sku, retailer) pairs with no authorization")
cols = q("PRAGMA table_info(price_history)")
print(f"  price_history columns: {[c[1] for c in cols]}")
ph = q("SELECT sku, retailer FROM price_history")
n_ph = len(ph)
unauth_ph = [(s, r) for s, r in ph if (s, r) not in auth_pairs]
print(f"  Total price_history: {n_ph}")
print(f"  Unauthorized (sku, retailer) price rows: {len(unauth_ph)} ({100*len(unauth_ph)/n_ph:.1f}%)")
if unauth_ph:
    print(f"  By retailer: {dict(Counter(r for _, r in unauth_ph).most_common())}")
    print(f"  Sample: {unauth_ph[:5]}")

# ---------- 4. DISTRIBUTION LOG ORPHANS ----------
banner(4, "DISTRIBUTION LOG - orphan stores or SKUs")
n_dist = q("SELECT COUNT(*) FROM distribution_log")[0][0]
orphan_stores = q("""
    SELECT COUNT(*) FROM distribution_log d
    WHERE NOT EXISTS (SELECT 1 FROM stores s WHERE s.store_id = d.store_id)
""")[0][0]
orphan_skus = q("""
    SELECT COUNT(*) FROM distribution_log d
    WHERE NOT EXISTS (SELECT 1 FROM product_master p WHERE p.sku = d.sku)
""")[0][0]
print(f"  Total distribution_log rows: {n_dist:,}")
print(f"  Rows with store_id not in stores: {orphan_stores}")
print(f"  Rows with sku not in product_master: {orphan_skus}")

# Also check scan_data for orphans
banner("4b", "SCAN DATA - orphan stores or SKUs")
orph_scan_store = q("""
    SELECT COUNT(*) FROM scan_data sd
    WHERE NOT EXISTS (SELECT 1 FROM stores s WHERE s.store_id = sd.store_id)
""")[0][0]
orph_scan_sku = q("""
    SELECT COUNT(*) FROM scan_data sd
    WHERE NOT EXISTS (SELECT 1 FROM product_master p WHERE p.sku = sd.sku)
""")[0][0]
print(f"  scan_data rows with store_id not in stores: {orph_scan_store}")
print(f"  scan_data rows with sku not in product_master: {orph_scan_sku}")

# ---------- 5. CHARGEBACKS post-fix ----------
banner(5, "CHARGEBACKS - confirm all rows on authorized (sku, retailer) pairs")
cb = q("SELECT sku, retailer, amount FROM chargebacks")
n_cb = len(cb)
unauth_cb = [(s, r, a) for s, r, a in cb if (s, r) not in auth_pairs]
print(f"  Total chargebacks: {n_cb}")
print(f"  Unauthorized chargeback rows: {len(unauth_cb)}")
print(f"  Unauthorized chargeback dollars: ${sum(x[2] for x in unauth_cb):,.2f}")
print(f"  Total chargeback dollars: ${sum(x[2] for x in cb):,.2f}")

# ---------- 6. STORES counts vs README claims ----------
banner(6, "STORES - count by retailer vs README claim")
expected = {"Walmart": 500, "Costco": 80, "Whole Foods": 120, "Regional": 200, "UNFI": None, "DTC": None}
actual = dict(q("SELECT retailer, COUNT(*) FROM stores GROUP BY retailer"))
print(f"  {'Retailer':<15}{'Actual':>10}{'README':>10}  Diff")
for r in sorted(actual):
    exp = expected.get(r)
    diff = "" if exp is None else f"{actual[r] - exp:+d}"
    print(f"  {r:<15}{actual[r]:>10}{(exp if exp is not None else '-'):>10}  {diff}")
print(f"  Total: {sum(actual.values()):,}")

# ---------- 7. TEMPORAL ----------
banner(7, "TEMPORAL - chargebacks/scans before SKU's first authorization")
# First authorization date per SKU
first_auth = dict(q("""
    SELECT sku, MIN(authorized_date) FROM distribution_log GROUP BY sku
"""))
# Chargebacks before SKU's first auth
cb_before = q("""
    SELECT c.sku, c.month, c.amount
    FROM chargebacks c
    JOIN (SELECT sku, MIN(authorized_date) AS first_auth FROM distribution_log GROUP BY sku) fa
      ON fa.sku = c.sku
    WHERE c.month || '-01' < fa.first_auth
""")
print(f"  Chargebacks dated before SKU's first authorization: {len(cb_before)}")
if cb_before[:5]:
    for r in cb_before[:5]: print(f"    {r}")

# Scan data before first auth at that store
scan_before = q("""
    SELECT COUNT(*) FROM scan_data sd
    JOIN distribution_log d
      ON d.sku = sd.sku AND d.store_id = sd.store_id
    WHERE sd.week_ending < d.authorized_date
""")[0][0]
print(f"  scan_data rows dated before that store's authorization: {scan_before:,}")

# Scan data after deauthorization
scan_after_deauth = q("""
    SELECT COUNT(*) FROM scan_data sd
    JOIN distribution_log d
      ON d.sku = sd.sku AND d.store_id = sd.store_id
    WHERE d.deauthorized_date IS NOT NULL
      AND sd.week_ending > d.deauthorized_date
""")[0][0]
print(f"  scan_data rows dated after that store's deauthorization: {scan_after_deauth:,}")

# Date ranges
print("\n  Date ranges:")
for tbl, col in [("distribution_log", "authorized_date"), ("chargebacks", "month"),
                 ("scan_data", "week_ending"), ("promotions", "start_week"),
                 ("price_history", "effective_date" if any(c[1]=="effective_date" for c in q("PRAGMA table_info(price_history)")) else "start_date")]:
    cols_in = [c[1] for c in q(f"PRAGMA table_info({tbl})")]
    if col not in cols_in:
        print(f"    {tbl}.{col}: column not present, columns are {cols_in}")
        continue
    mn, mx = q(f"SELECT MIN({col}), MAX({col}) FROM {tbl}")[0]
    print(f"    {tbl}.{col}: {mn}  ..  {mx}")

# ---------- 8. PRODUCT MASTER orphans ----------
banner(8, "PRODUCT MASTER - SKUs with no authorizations anywhere")
all_skus = {s for s, in q("SELECT sku FROM product_master")}
no_auth = sorted(all_skus - auth_skus)
print(f"  Total SKUs: {len(all_skus)}")
print(f"  SKUs with no row in distribution_log: {len(no_auth)}")
if no_auth:
    rows = q(f"SELECT sku, product_name, active_retailers FROM product_master WHERE sku IN ({','.join('?'*len(no_auth))})", *no_auth)
    for s, n, ar in rows:
        print(f"    {s}  {n[:40]:40s}  active_retailers={ar!r}")

con.close()
print("\nDone.")
