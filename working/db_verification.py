"""
Comprehensive diagnostic of cinderhaven_product_master.db.
Read-only: no fixes, no writes. Prints a results table to stdout.
"""

import sqlite3
from pathlib import Path

DB = Path("C:/Users/mssha/OneDrive/Desktop/product-data-health-audit/data/cinderhaven_product_master.db")

con = sqlite3.connect(DB)
con.row_factory = sqlite3.Row
cur = con.cursor()

results = []  # (num, desc, result, severity)

def add(num, desc, result, severity="OK"):
    results.append((num, desc, result, severity))

def q(sql, *params):
    return cur.execute(sql, params).fetchall()

def q1(sql, *params):
    row = cur.execute(sql, params).fetchone()
    return None if row is None else row[0]

def list_cols(table):
    return [r[1] for r in q(f"PRAGMA table_info({table})")]

# ------------------------------------------------------------------
# PRODUCT_MASTER
# ------------------------------------------------------------------
pm_cols = set(list_cols("product_master"))

# 1. Nulls/blanks in fields that should never be null
required = [c for c in ["sku", "product_name", "product_line", "upc_12", "gtin_14"] if c in pm_cols]
null_counts = {}
for col in required:
    n_null = q1(f"SELECT COUNT(*) FROM product_master WHERE {col} IS NULL OR TRIM({col}) = ''")
    if n_null:
        null_counts[col] = n_null
if null_counts:
    add(1, "Nulls/blanks in required fields (product_master)",
        ", ".join(f"{c}={n}" for c, n in null_counts.items()), "HIGH")
else:
    add(1, "Nulls/blanks in required fields (product_master)", "none — all populated", "OK")

# 2. Duplicate SKUs
dup = q("SELECT sku, COUNT(*) c FROM product_master GROUP BY sku HAVING c > 1")
if dup:
    add(2, "Duplicate SKUs in product_master", f"{len(dup)} duplicates", "HIGH")
else:
    add(2, "Duplicate SKUs in product_master", f"none — {q1('SELECT COUNT(DISTINCT sku) FROM product_master')} unique", "OK")

# 3. Case weights — zeros, negatives, implausible
cw_col = "case_weight" if "case_weight" in pm_cols else ("case_weight_lbs" if "case_weight_lbs" in pm_cols else None)
if cw_col:
    n_null = q1(f"SELECT COUNT(*) FROM product_master WHERE {cw_col} IS NULL")
    n_zero = q1(f"SELECT COUNT(*) FROM product_master WHERE {cw_col} = 0")
    n_neg  = q1(f"SELECT COUNT(*) FROM product_master WHERE {cw_col} < 0")
    n_huge = q1(f"SELECT COUNT(*) FROM product_master WHERE {cw_col} > 100")
    n_tiny = q1(f"SELECT COUNT(*) FROM product_master WHERE {cw_col} > 0 AND {cw_col} < 0.1")
    rng = q1(f"SELECT MIN({cw_col})||' / '||MAX({cw_col}) FROM product_master WHERE {cw_col} IS NOT NULL")
    sev = "HIGH" if (n_zero or n_neg or n_huge or n_tiny) else ("MED" if n_null else "OK")
    add(3, f"Case weights ({cw_col})",
        f"null={n_null}, zero={n_zero}, neg={n_neg}, >100lb={n_huge}, <0.1lb={n_tiny}, range={rng}", sev)
else:
    add(3, "Case weights", "no case_weight column found", "INFO")

# 4. Case dimensions — zeros, negatives, implausible
dim_cols = [c for c in ["case_length", "case_width", "case_height",
                        "case_length_in", "case_width_in", "case_height_in"] if c in pm_cols]
if dim_cols:
    parts = []
    sev = "OK"
    for c in dim_cols:
        n_null = q1(f"SELECT COUNT(*) FROM product_master WHERE {c} IS NULL")
        n_zero = q1(f"SELECT COUNT(*) FROM product_master WHERE {c} = 0")
        n_neg  = q1(f"SELECT COUNT(*) FROM product_master WHERE {c} < 0")
        n_huge = q1(f"SELECT COUNT(*) FROM product_master WHERE {c} > 60")  # >60 inches ~ implausible
        if n_zero or n_neg or n_huge: sev = "HIGH"
        elif n_null and sev == "OK":  sev = "MED"
        parts.append(f"{c}: null={n_null} zero={n_zero} neg={n_neg} >60in={n_huge}")
    add(4, "Case dimensions", " | ".join(parts), sev)
else:
    add(4, "Case dimensions", "no case dim columns found", "INFO")

# 5. Serving size formats
ss = q("SELECT serving_size, COUNT(*) c FROM product_master GROUP BY serving_size ORDER BY c DESC")
distinct_ss = len(ss)
n_blank = sum(r["c"] for r in ss if r["serving_size"] is None or str(r["serving_size"]).strip() == "")
add(5, "Serving size variants",
    f"{distinct_ss} distinct strings; {n_blank} blank/null. Top 5: " +
    "; ".join(f"'{r['serving_size']}'×{r['c']}" for r in ss[:5]),
    "MED" if distinct_ss > 6 else "OK")

# 6. Brand owner: NA/blank vs real
if "brand_owner" in pm_cols:
    n_na    = q1("SELECT COUNT(*) FROM product_master WHERE brand_owner IS NULL OR TRIM(brand_owner) = '' OR UPPER(brand_owner) = 'NA'")
    n_real  = q1("SELECT COUNT(*) FROM product_master WHERE brand_owner IS NOT NULL AND TRIM(brand_owner) != '' AND UPPER(brand_owner) != 'NA'")
    add(6, "Brand owner population",
        f"{n_real} populated, {n_na} null/blank/'NA'",
        "HIGH" if n_na > 0 else "OK")
else:
    add(6, "Brand owner", "no brand_owner column", "INFO")

# ------------------------------------------------------------------
# SKU_COSTS
# ------------------------------------------------------------------
sc_cols = set(list_cols("sku_costs"))
cogs_col = next((c for c in ["cogs", "cogs_per_unit"] if c in sc_cols), None)
ws_col   = next((c for c in ["wholesale_price", "wholesale", "wholesale_per_unit"] if c in sc_cols), None)

# 7. COGS > wholesale (negative margin)
if cogs_col and ws_col:
    n_neg_margin = q1(f"SELECT COUNT(*) FROM sku_costs WHERE {cogs_col} > {ws_col}")
    add(7, "Negative margin SKUs (COGS > wholesale)",
        f"{n_neg_margin} SKUs",
        "HIGH" if n_neg_margin else "OK")
else:
    add(7, "Negative margin SKUs", f"missing column(s): cogs={cogs_col}, wholesale={ws_col}", "INFO")

# 8. Zeros/negatives in COGS or wholesale
problems = []
sev = "OK"
for col in [c for c in [cogs_col, ws_col] if c]:
    n_zero = q1(f"SELECT COUNT(*) FROM sku_costs WHERE {col} = 0")
    n_neg  = q1(f"SELECT COUNT(*) FROM sku_costs WHERE {col} < 0")
    n_null = q1(f"SELECT COUNT(*) FROM sku_costs WHERE {col} IS NULL")
    if n_zero or n_neg: sev = "HIGH"
    elif n_null and sev == "OK": sev = "MED"
    problems.append(f"{col}: null={n_null} zero={n_zero} neg={n_neg}")
add(8, "Zeros/negatives in cost columns", " | ".join(problems) if problems else "n/a", sev)

# 9. Gross margin range
if cogs_col and ws_col:
    row = cur.execute(f"""
        SELECT MIN({ws_col}-{cogs_col}) mn,
               MAX({ws_col}-{cogs_col}) mx,
               AVG({ws_col}-{cogs_col}) av,
               MIN(({ws_col}-{cogs_col})*1.0/NULLIF({ws_col},0)) min_pct,
               MAX(({ws_col}-{cogs_col})*1.0/NULLIF({ws_col},0)) max_pct,
               AVG(({ws_col}-{cogs_col})*1.0/NULLIF({ws_col},0)) avg_pct
        FROM sku_costs
        WHERE {cogs_col} IS NOT NULL AND {ws_col} IS NOT NULL""").fetchone()
    add(9, "Gross margin range",
        f"$/unit min={row['mn']:.2f}, max={row['mx']:.2f}, mean={row['av']:.2f}; "
        f"%-margin min={row['min_pct']*100:.1f}%, max={row['max_pct']*100:.1f}%, mean={row['avg_pct']*100:.1f}%",
        "OK")
else:
    add(9, "Gross margin range", "cannot compute (missing columns)", "INFO")

# ------------------------------------------------------------------
# SCAN_DATA
# ------------------------------------------------------------------
sd_cols = set(list_cols("scan_data"))
units_col = next((c for c in ["units_sold", "units"] if c in sd_cols), None)
rev_col   = next((c for c in ["dollars_sold", "revenue", "dollars"] if c in sd_cols), None)
week_col  = next((c for c in ["week_ending", "week"] if c in sd_cols), None)

# 10. Negative units or revenue
if units_col and rev_col:
    n_neg_u = q1(f"SELECT COUNT(*) FROM scan_data WHERE {units_col} < 0")
    n_neg_r = q1(f"SELECT COUNT(*) FROM scan_data WHERE {rev_col} < 0")
    add(10, "Negative units / revenue in scan_data",
        f"neg units={n_neg_u}, neg revenue={n_neg_r}",
        "HIGH" if (n_neg_u or n_neg_r) else "OK")
else:
    add(10, "Negative units / revenue", "missing columns", "INFO")

# 11. Units per store-week distribution
if units_col:
    row = cur.execute(f"""
        SELECT MIN({units_col}) mn, MAX({units_col}) mx,
               AVG({units_col}) av,
               (SELECT {units_col} FROM scan_data ORDER BY {units_col} LIMIT 1 OFFSET (SELECT COUNT(*)/2 FROM scan_data)) med,
               COUNT(CASE WHEN {units_col} > 1000 THEN 1 END) huge
        FROM scan_data""").fetchone()
    add(11, f"Units per store-week ({units_col})",
        f"min={row['mn']}, max={row['mx']}, mean={row['av']:.2f}, median~={row['med']}, >1000={row['huge']}",
        "HIGH" if row["huge"] else "OK")

# 12. Revenue per unit — does it line up with wholesale?
if units_col and rev_col and ws_col and cogs_col:
    row = cur.execute(f"""
        SELECT MIN({rev_col}*1.0/NULLIF({units_col},0)) mn,
               MAX({rev_col}*1.0/NULLIF({units_col},0)) mx,
               AVG({rev_col}*1.0/NULLIF({units_col},0)) av
        FROM scan_data WHERE {units_col} > 0""").fetchone()
    ws_row = cur.execute(f"SELECT MIN({ws_col}) mn, MAX({ws_col}) mx, AVG({ws_col}) av FROM sku_costs").fetchone()
    add(12, "Revenue per unit vs wholesale",
        f"scan $/u min={row['mn']:.2f}, max={row['mx']:.2f}, mean={row['av']:.2f}; "
        f"wholesale min={ws_row['mn']:.2f}, max={ws_row['mx']:.2f}, mean={ws_row['av']:.2f}",
        "OK")

# 13. Week gaps (weeks with zero data anywhere)
if week_col:
    # All distinct weeks in the table
    weeks_present = [r[0] for r in cur.execute(f"SELECT DISTINCT {week_col} FROM scan_data ORDER BY {week_col}").fetchall()]
    n_weeks = len(weeks_present)
    # Expected weeks: 7-day intervals between min and max
    if n_weeks >= 2:
        from datetime import datetime, timedelta
        try:
            d_min = datetime.strptime(weeks_present[0], "%Y-%m-%d")
            d_max = datetime.strptime(weeks_present[-1], "%Y-%m-%d")
            expected = (d_max - d_min).days // 7 + 1
            gap = expected - n_weeks
            add(13, "Week gaps in scan_data",
                f"{n_weeks} weeks present, span {weeks_present[0]} .. {weeks_present[-1]}, expected {expected}, gaps={gap}",
                "MED" if gap > 0 else "OK")
        except Exception as e:
            add(13, "Week gaps", f"{n_weeks} weeks present (date parse failed: {e})", "INFO")
    else:
        add(13, "Week gaps", f"{n_weeks} weeks", "INFO")

# ------------------------------------------------------------------
# DISTRIBUTION_LOG
# ------------------------------------------------------------------
dl_cols = set(list_cols("distribution_log"))
auth_col   = next((c for c in ["auth_date", "authorization_date"] if c in dl_cols), None)
deauth_col = next((c for c in ["deauth_date", "deauthorization_date"] if c in dl_cols), None)

# 14. Deauth before auth
if auth_col and deauth_col:
    n = q1(f"""SELECT COUNT(*) FROM distribution_log
               WHERE {deauth_col} IS NOT NULL AND {auth_col} IS NOT NULL
               AND date({deauth_col}) < date({auth_col})""")
    add(14, "Deauth before auth dates", f"{n} rows",
        "HIGH" if n else "OK")
else:
    add(14, "Deauth before auth", f"missing cols (auth={auth_col}, deauth={deauth_col})", "INFO")

# 15. SKU authorized at same store more than once
store_col = next((c for c in ["store_id", "store"] if c in dl_cols), None)
sku_col_dl = next((c for c in ["sku", "sku_id"] if c in dl_cols), None)
if store_col and sku_col_dl:
    n = q1(f"""SELECT COUNT(*) FROM (
                  SELECT {sku_col_dl}, {store_col} FROM distribution_log
                  GROUP BY {sku_col_dl}, {store_col} HAVING COUNT(*) > 1)""")
    total_pairs = q1(f"SELECT COUNT(DISTINCT {sku_col_dl}||'|'||{store_col}) FROM distribution_log")
    add(15, "SKU re-authorized at same store",
        f"{n} (sku, store) pairs appear >1 time of {total_pairs} unique pairs",
        "MED" if n else "OK")

# ------------------------------------------------------------------
# STORES
# ------------------------------------------------------------------
st_cols = set(list_cols("stores"))
sid_col = next((c for c in ["store_id", "store"] if c in st_cols), None)

# 16. Duplicate store IDs
if sid_col:
    n = q1(f"SELECT COUNT(*) FROM (SELECT {sid_col} FROM stores GROUP BY {sid_col} HAVING COUNT(*) > 1)")
    add(16, "Duplicate store IDs", f"{n} duplicates", "HIGH" if n else "OK")
else:
    add(16, "Duplicate store IDs", "no store_id column", "INFO")

# 17. Store count by retailer
if "retailer" in st_cols:
    rows = q("SELECT retailer, COUNT(*) c FROM stores GROUP BY retailer ORDER BY c DESC")
    add(17, "Store count by retailer",
        ", ".join(f"{r['retailer']}={r['c']}" for r in rows), "OK")

# ------------------------------------------------------------------
# PROMOTIONS
# ------------------------------------------------------------------
try:
    pr_cols = set(list_cols("promotions"))
except sqlite3.OperationalError:
    pr_cols = set()

start_col = next((c for c in ["start_date", "promo_start"] if c in pr_cols), None)
end_col   = next((c for c in ["end_date", "promo_end"] if c in pr_cols), None)
disc_col  = next((c for c in ["discount_rate", "discount_pct", "discount"] if c in pr_cols), None)

# 18. Start > end
if start_col and end_col:
    n = q1(f"SELECT COUNT(*) FROM promotions WHERE date({start_col}) > date({end_col})")
    add(18, "Promo start > end", f"{n} rows", "HIGH" if n else "OK")
else:
    add(18, "Promo start > end",
        "no promotions table" if not pr_cols else f"missing cols (start={start_col}, end={end_col})",
        "INFO")

# 19. Discount rate outside 0-100%
if disc_col:
    # Could be stored as 0–1 or 0–100 — check both interpretations
    row = cur.execute(f"SELECT MIN({disc_col}) mn, MAX({disc_col}) mx FROM promotions").fetchone()
    n_below = q1(f"SELECT COUNT(*) FROM promotions WHERE {disc_col} < 0")
    n_over  = q1(f"SELECT COUNT(*) FROM promotions WHERE {disc_col} > 100")
    n_over1 = q1(f"SELECT COUNT(*) FROM promotions WHERE {disc_col} > 1 AND {disc_col} <= 100")
    add(19, f"Promo discount rate ({disc_col})",
        f"min={row['mn']}, max={row['mx']}, <0={n_below}, >100={n_over}, in (1,100]={n_over1}",
        "HIGH" if (n_below or n_over) else "OK")
elif pr_cols:
    add(19, "Promo discount rate", "no discount column found", "INFO")

# 20. Promo distribution by retailer & product line
if pr_cols and "retailer" in pr_cols:
    rows = q("SELECT retailer, COUNT(*) c FROM promotions GROUP BY retailer ORDER BY c DESC")
    all_retailers = [r[0] for r in q("SELECT DISTINCT retailer FROM stores WHERE retailer IS NOT NULL")]
    have = {r["retailer"] for r in rows}
    missing = [x for x in all_retailers if x not in have]
    line_rows = []
    if "product_line" in pr_cols:
        line_rows = q("SELECT product_line, COUNT(*) c FROM promotions GROUP BY product_line ORDER BY c DESC")
    elif "sku" in pr_cols:
        line_rows = q("""
            SELECT pm.product_line, COUNT(*) c
            FROM promotions pr LEFT JOIN product_master pm ON pm.sku = pr.sku
            GROUP BY pm.product_line ORDER BY c DESC""")
    parts = ["By retailer: " + ", ".join(f"{r['retailer']}={r['c']}" for r in rows)]
    if missing: parts.append(f"missing retailers: {missing}")
    if line_rows: parts.append("By line: " + ", ".join(f"{r['product_line']}={r['c']}" for r in line_rows))
    add(20, "Promo distribution",
        " | ".join(parts),
        "MED" if missing else "OK")

# ------------------------------------------------------------------
# PRICE_HISTORY
# ------------------------------------------------------------------
try:
    ph_cols = set(list_cols("price_history"))
except sqlite3.OperationalError:
    ph_cols = set()

price_col = next((c for c in ["price", "wholesale_price", "list_price"] if c in ph_cols), None)
sku_col_ph = next((c for c in ["sku", "sku_id"] if c in ph_cols), None)

# 21. Zero/negative prices
if price_col:
    n_zero = q1(f"SELECT COUNT(*) FROM price_history WHERE {price_col} = 0")
    n_neg  = q1(f"SELECT COUNT(*) FROM price_history WHERE {price_col} < 0")
    n_null = q1(f"SELECT COUNT(*) FROM price_history WHERE {price_col} IS NULL")
    add(21, f"Price zeros/negatives ({price_col})",
        f"null={n_null}, zero={n_zero}, neg={n_neg}",
        "HIGH" if (n_zero or n_neg) else ("MED" if n_null else "OK"))
elif ph_cols:
    add(21, "Price zeros/negatives", "no price column", "INFO")
else:
    add(21, "Price zeros/negatives", "no price_history table", "INFO")

# 22. Price range by product line
if price_col and sku_col_ph:
    rows = cur.execute(f"""
        SELECT pm.product_line,
               MIN(ph.{price_col}) mn,
               MAX(ph.{price_col}) mx,
               AVG(ph.{price_col}) av,
               COUNT(*) n
        FROM price_history ph LEFT JOIN product_master pm ON pm.sku = ph.{sku_col_ph}
        GROUP BY pm.product_line""").fetchall()
    add(22, "Price range by product line",
        " | ".join(f"{r['product_line']}: min={r['mn']:.2f} max={r['mx']:.2f} mean={r['av']:.2f} n={r['n']}"
                   for r in rows), "OK")

# 23. SKUs with no price history
if sku_col_ph:
    rows = q(f"""
        SELECT pm.sku FROM product_master pm
        LEFT JOIN price_history ph ON ph.{sku_col_ph} = pm.sku
        WHERE ph.{sku_col_ph} IS NULL""")
    add(23, "SKUs with no price history",
        f"{len(rows)} SKUs" + (": " + ", ".join(r[0] for r in rows[:10]) + ("…" if len(rows) > 10 else "") if rows else ""),
        "HIGH" if rows else "OK")
elif ph_cols:
    add(23, "SKUs with no price history", "no sku column on price_history", "INFO")
else:
    add(23, "SKUs with no price history", "no price_history table", "INFO")

# ------------------------------------------------------------------
# Print
# ------------------------------------------------------------------
print("\n" + "=" * 130)
print(f"{'#':<3} {'Description':<55} {'Severity':<8} {'Result'}")
print("=" * 130)
for num, desc, result, sev in results:
    desc_short = desc if len(desc) <= 55 else desc[:52] + "..."
    print(f"{num:<3} {desc_short:<55} {sev:<8} {result}")
print("=" * 130)

# Quick summary by severity
from collections import Counter
sev_counts = Counter(r[3] for r in results)
print(f"\nSummary: {dict(sev_counts)}")

# Show schema overview
print("\nTable row counts:")
for t in ["product_master", "sku_costs", "scan_data", "distribution_log",
          "stores", "promotions", "price_history"]:
    try:
        n = q1(f"SELECT COUNT(*) FROM {t}")
        print(f"  {t:<22} {n:>10,}")
    except sqlite3.OperationalError:
        print(f"  {t:<22} (table missing)")

con.close()
