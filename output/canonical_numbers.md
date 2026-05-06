# Cinderhaven canonical numbers

_Generated 2026-05-05 15:19:57 by `R/_emit_canonical_numbers.R`._
_Source database: `data/cinderhaven_product_master.db` (164.3 MB, mtime 2026-05-05 15:17:59)._

This document is the **single source of truth** for every numeric claim
made anywhere in the project. The Quarto report, the dashboard, the Excel
workbook, the executive tearsheet, and the Shiny calculator defaults all
derive their numbers from the same `output/frames/*.rds` files this script
reads. If two artifacts disagree on a number, the artifact is wrong — not
this file.

All numbers re-derive automatically when `R/run_all.R` is rerun against a
new snapshot of the SQLite database. The R expressions in fenced blocks
below are exact; copy-paste any of them into the project to verify.

---

## Catalog shape

- **90 SKUs** across 3 product lines (Artisan Sauces (30), Pantry Staples (30), Specialty Condiments (30)).
- **902 stores** in `stores` table; 4 contracted retailers (Walmart, Costco, UNFI, Whole Foods).
- Scan data window: **2024-05-11 → 2026-05-02** (104 weekly periods).
- Database row counts: chargebacks 381, distribution_log 12507, scan_data 1,118,009, promotions 198.

## Headline numbers

| Metric | Value | Re-derive |
|---|---:|---|
| TTM revenue, all SKUs | **$25.55M** | `sum(sku_master_full$ttm_revenue)` |
| 18-month chargeback total | **$88k** | `sum(sku_master_full$chargeback_total)` |
| Annualized chargeback run-rate | **$59k** | `cb_18mo * 12 / 18` |
| Walmart revenue at risk | **$18.20M** | failing-readiness SKUs × ttm_revenue, Walmart |
| Catalog mean data-quality score | **70.0** | `mean(sku_master_full$data_quality_score)` |
| Top-15-by-revenue mean quality | **66.7** | top 15 by ttm_revenue, mean of quality_score |

## Chargeback Pareto

- **50 of 90 SKUs** carry any chargebacks; 40 carry none.
- **5 SKUs** account for 50% of chargeback dollars.
- **15 SKUs** account for 80% of chargeback dollars.
- Top SKU: **CHP-0002 — Spicy Arrabbiata** at $12k (14.1% of total).

### Chargeback dollars by reason

| Reason | $ (18mo) | % | Events |
|---|---:|---:|---:|
| Invalid GTIN/UPC | $53k | 59.8% | 205 |
| Dimension mismatch | $16k | 18.1% | 72 |
| Missing product data | $16k | 17.6% | 88 |
| Late delivery | $2k | 2.6% | 10 |
| Short shipment | $2k | 1.9% | 6 |

Three data-defect reasons (Invalid GTIN/UPC, Missing product data,
Dimension mismatch) account for **95.6%** of chargeback dollars.

### Chargeback dollars by retailer

| Retailer | $ (18mo) | % of cb total | % of retailer revenue |
|---|---:|---:|---:|
| Walmart | $43k | 48.8% | 0.33% |
| UNFI | $26k | 29.6% | 0.61% |
| Whole Foods | $10k | 11.3% | 0.36% |
| Costco | $9k | 10.3% | 0.40% |

## Chargebacks as % of gross margin (top 5)

| SKU | Product | Chargebacks | Gross margin | Cb % of GM |
|---|---|---:|---:|---:|
| CHP-0039 | Herb Garden Hot Sauce | $1k | $7k | **19.5%** |
| CHP-0007 | Lemon Caper Piccata | $2k | $12k | **14.3%** |
| CHP-0021 | Balsamic Onion Marinara | $1k | $10k | **12.7%** |
| CHP-0022 | San Marzano Marinara | $689 | $7k | **10.2%** |
| CHP-0068 | Olive Oil - Everyday Blend | $491 | $6k | **8.1%** |

**The headline:** CHP-0039 (Herb Garden Hot Sauce) carries $1k in chargebacks against
$7k in TTM gross margin — **19.5% of gross margin to chargebacks**.

## Retailer readiness — revenue at risk

| Retailer | SKUs failing | Pass rate | Revenue at risk | % of catalog rev | Avg fields short |
|---|---:|---:|---:|---:|---:|
| Walmart | 50 / 90 | 44.4% | $18.20M | 71.2% | 1.72 |
| Costco | 48 / 90 | 46.7% | $17.99M | 70.4% | 1.68 |
| UNFI | 41 / 90 | 54.4% | $14.04M | 54.9% | 1.51 |
| Whole Foods | 27 / 90 | 70.0% | $9.77M | 38.2% | 0.33 |

## Retailer P&L (TTM, contracted retailers only)

| Retailer | Gross revenue | Trade spend | Chargebacks | Net contribution | Net margin % |
|---|---:|---:|---:|---:|---:|
| Walmart | $13.10M | $2.79M (21.3%) | $43k (0.33%) | **$10.27M** | **78.4%** |
| UNFI | $4.27M | $646k (15.1%) | $26k (0.61%) | **$3.60M** | **84.3%** |
| Whole Foods | $2.78M | $347k (12.5%) | $10k (0.36%) | **$2.43M** | **87.2%** |
| Costco | $2.25M | $370k (16.4%) | $9k (0.40%) | **$1.88M** | **83.2%** |

## Defect counts and revenue concentration

- **GTIN-14 invalid:** 9 of 90 SKUs (10.0% of catalog) carrying $6.56M of TTM revenue (25.7%).
- **UPC-12 invalid:** 3 of 90 SKUs.
- **OneWorldSync incomplete:** 81 of 90 SKUs (90.0% — only 9 in 'Registered – Complete').
- **Missing case dimensions:** 32.2% of SKUs, 36.1% of revenue.

Validator note: this audit uses the dataset's own mod-10 algorithm for
GTIN/UPC check digits. Strict GS1 weights would flag a much larger share
of the catalog. See methodology appendix for the trade-off.

## Time-to-shelf by data-quality tier

| Tier (label used in report) | n SKUs | Mean days to first scan |
|---|---:|---:|
| Worst 25% (lowest data-quality scores) | 23 | 32.4 |
| Below average | 23 | 29.5 |
| Above average | 22 | 13.0 |
| Best 25% | 22 | 10.1 |

**The 3× headline:** worst tier averages **32.4 days** vs. best tier
**10.1 days** — a 3.2× spread in time-to-shelf.

## Deauthorization

- Overall deauth rate: 0.64% (80 deauths across 12,507 authorizations).
- Bottom-half quality SKUs (worst 25% + below average): mean rate 1.18%, **31** SKUs with any deauth.
- Top-half quality SKUs (above average + best 25%): mean rate 0.26%, **14** SKUs with any deauth.

## Data debt by product line

| Product line | TTM revenue | Total issues | Issues per $1M | Chargebacks | Cb per $1M |
|---|---:|---:|---:|---:|---:|
| Pantry Staples | $6.49M | 73 | **11.3** | $16k | $2,506 |
| Specialty Condiments | $8.71M | 74 | **8.5** | $41k | $4,662 |
| Artisan Sauces | $10.35M | 69 | **6.7** | $31k | $3,013 |

## Process debt by data-entry source

| Source | n SKUs | Mean quality | Total chargebacks | $/SKU |
|---|---:|---:|---:|---:|
| quality_mgr | 10 | 66.2 | $14k | $1,444 |
| broker_upload | 13 | 68.3 | $19k | $1,435 |
| import_script | 12 | 68.8 | $17k | $1,413 |
| inventory_admin | 17 | 66.9 | $23k | $1,343 |
| production_admin | 19 | 74.3 | $10k | $513 |
| (unknown / NA) | 9 | 72.2 | $3k | $304 |
| ops_coordinator | 10 | 72.5 | $3k | $269 |

**The 3.3× ratio:** broker_upload averages $1,435 in chargebacks per SKU vs. production_admin's $513 — **2.8×**.

## Promo lift

- 60 of 198 promotions have enough prior scan history to compute lift cleanly.
- Across computable promos: median lift -0.8%, mean lift 3.0%.

## Reconciliation against the Python HTML report

The original HTML audit report (Python-generated, in the separate
`product-data-audit-queries` repo) was built against an earlier database
snapshot. Phase 8 of the rebuild plan calls for regenerating that report
against the current snapshot so all Cinderhaven artifacts agree on the
same numbers. Until that regeneration ships, **the Phase 0 frames in this
file are canonical** — any discrepancy is a stale-snapshot artifact in
the Python report, not a defect in the R pipeline.

### How to verify a single number

```r
# From the project root, in R:
source("R/00_theme.R")  # not strictly required for verification
frames <- "output/frames"
sku_master_full <- readRDS(file.path(frames, "sku_master_full.rds"))

# Annual chargeback run-rate:
sum(sku_master_full$chargeback_total) * 12 / 18

# Walmart revenue at risk:
rs <- readRDS(file.path(frames, "retailer_readiness_summary.rds"))
rs |> dplyr::filter(retailer == "Walmart", !overall_pass) |>
  dplyr::left_join(sku_master_full |> dplyr::select(sku, ttm_revenue),
                    by = "sku") |>
  dplyr::summarise(rar = sum(ttm_revenue))
```

---

_Last regenerated: 2026-05-05 15:19:57._
