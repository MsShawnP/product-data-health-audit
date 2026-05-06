"""One-shot schema inspector. Used only to plan the R joins; not part of the pipeline."""
import sqlite3, json, textwrap, os

DB = r"C:\Users\mssha\OneDrive\Desktop\product-data-health-audit\cinderhaven_product_master.db"
con = sqlite3.connect(DB)
cur = con.cursor()

tables = [r[0] for r in cur.execute(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
).fetchall()]
print("=" * 70)
print(f"TABLES ({len(tables)}):", tables)
print("=" * 70)

for t in tables:
    n = cur.execute(f"SELECT COUNT(*) FROM '{t}'").fetchone()[0]
    cols = cur.execute(f"PRAGMA table_info('{t}')").fetchall()
    print(f"\n--- {t}  ({n:,} rows, {len(cols)} cols) ---")
    for cid, name, ctype, notnull, dflt, pk in cols:
        print(f"  {name:35s} {ctype:15s} pk={pk} nn={notnull}")
    sample = cur.execute(f"SELECT * FROM '{t}' LIMIT 2").fetchall()
    colnames = [c[1] for c in cols]
    for row in sample:
        d = dict(zip(colnames, row))
        # truncate long values
        for k, v in d.items():
            if isinstance(v, str) and len(v) > 60:
                d[k] = v[:57] + "..."
        print("  sample:", json.dumps(d, default=str))

con.close()
