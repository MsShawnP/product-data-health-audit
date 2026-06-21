# Decisions Log

Durable choices with rationale. These should hold across future sessions.

---

### 2026-05-20 — Shiny defaults use field-presence pass rate (60%), not strict validation (0%)

- **Why:** The strict check in `R/02_build_frames.R` (GTIN check-digit verification + OneWorldSync registration) produces a 0% pass rate for the 50-SKU dataset — every SKU fails at least one validation. A 0% default makes the calculator's sensitivity slider useless since there's no room to explore scenarios. The 60% field-presence rate better represents what a real company would self-report when using the tool.
- **Scope:** `shiny/app.R` default values for pass_rate slider on both Calculator and Cost of Delay tabs.
- **Do not:** Change the default to 0% even though strict validation produces that number. The Shiny app is a general-purpose tool, not a mirror of Cinderhaven's strict audit results.

### 2026-05-20 — GitHub Pages must deploy `_files/` directories alongside Quarto HTML

- **Why:** Quarto renders with `embed-resources: false` for both `report.qmd` and `dashboard.qmd`. The HTML files depend on their corresponding `_files/` directories for CSS, JS, fonts, and interactive widgets (ggiraph, reactable). Without these directories, the pages load with no styling, no interactivity, and no images.
- **Scope:** `.github/workflows/render.yml`, "Assemble Pages site" step. Applies to any future Quarto HTML artifact added to the site.
- **Do not:** Switch to `embed-resources: true` as a workaround — it bloats file sizes and breaks widget interactivity. Always copy the `_files/` directory when adding a new HTML artifact to the Pages deployment.

### 2026-05-22 — UNFI removal: filter at earliest pipeline stage

- **Why:** UNFI is a distributor, not a retailer. Rather than filtering at each downstream consumer (charts, tables, narrative), filter all source tables immediately after raw load in `02_build_frames.R`. Every frame, chart, and report inherits the exclusion automatically.
- **Scope:** `R/02_build_frames.R` (lines 43-47), plus removal from `R/00_theme.R` retailer_colors, `R/04_hero_charts.R` contracted vector, `R/05_supporting_charts.R` chart 6 + chart 12, `R/06_excel_workbook.R` data dictionary, and all `.qmd` narrative references.
- **Do not:** Re-add UNFI or add other distributors to the retailer analysis. The analysis covers all six retailers in the dataset: Walmart, Costco, Whole Foods, Kroger, Sprouts, Regional Group.

### 2026-05-22 — Chargeback reason remap in 02_build_frames.R

- **Why:** Raw DB reason codes (`label_fine`, `pricing_error`, `damaged`, `late_delivery`, `short_ship`) need human-readable names for charts, narratives, and the fix-ROI calculation. The mapping was originally set to analytical categories ("Invalid GTIN/UPC", "Missing product data", "Dimension mismatch") but was changed to honest, transparent names that match what each reason actually represents in the data.
- **Mapping:** `label_fine`→"Label / barcode fine", `pricing_error`→"Pricing error", `damaged`→"Damaged goods", `late_delivery`→"Late delivery", `short_ship`→"Short shipment".
- **Scope:** `R/02_build_frames.R` (lines 50-56). All downstream code expects the human-readable names.
- **Do not:** Change the mapping without also updating `R/04_hero_charts.R` `amt_18()`, `R/05_supporting_charts.R` chart 14, and `quarto/report.qmd` `data_defect_pct`.

### 2026-05-22 — SVG for HTML, PNG for PDF via format-conditional chart() helper

- **Why:** SVG gives crisp vector charts in the HTML report. But PDF rendering requires `rsvg-convert` to convert SVG→PDF for LaTeX, and it's not installed. Hardcoding either format breaks the other.
- **Scope:** `quarto/report.qmd` setup chunk defines `chart(name)` which returns `.svg` for HTML and `.png` for PDF. Both `save_chart()` and `save_pair()` now generate SVG alongside PNG. Tearsheet keeps hardcoded `.png` paths (PDF-only document).
- **Do not:** Set `dev: "svglite"` globally in `_quarto.yml` — it breaks PDF. Don't replace the `chart()` helper with static paths unless `rsvg-convert` is installed system-wide.

### 2026-05-20 — Charts use Lailara Design System tokens, not hardcoded colors

- **Why:** Charts should look like part of the Lailara portfolio. All non-focal elements use greyscale tokens (`LL_RECEDE`, `LL_RECEDE_DARK`), backgrounds use `LL_CANVAS`, and red accent (`LL_RED_42`) is reserved for the single focal data point per chart.
- **Scope:** `R/00_theme.R`, `R/04_hero_charts.R`, `R/05_supporting_charts.R`. Applies to any future chart added.
- **Do not:** Use hardcoded hex greys (`#B0B0B0`, `#888888`, etc.) or white backgrounds in chart code. Always reference the semantic token from `R/00_theme.R`.

### 2026-05-22 — Narrative rewrite: every claim must match the data

- **Why:** The original report.qmd narrative made claims the synthetic dataset does not support: varied defect types, quality tiers with spread, entry-path analysis, stalled-launch and shelf-loss cost estimates, 3-retailer scope, and hardcoded SKU names. The rewrite ensures every sentence is backed by what the data actually contains.
- **Scope:** `quarto/report.qmd` (all 4 parts, ~960 lines), `quarto/tearsheet.qmd`. Affects setup chunk variables, inline R expressions, section headings, and prose throughout.
- **Key changes:** Expanded from 3 to 6 retailers. Removed quality-tier analysis (DQ score = 75 for all 50 SKUs, zero variance). Removed entry-path analysis (updated_by is NA for all records). Removed stalled-launch and shelf-loss cost estimates (no supporting data). Changed hardcoded CHP-0002/CHP-0044 references to dynamically computed top_rev/top_cb SKUs.
- **Do not:** Add narrative claims about data patterns without first verifying the pattern exists in the analytical frames. The dataset is synthetic and intentionally limited.

### 2026-05-22 — Removed unsupported cost estimates

- **Why:** `stalled_launch_cost` and `shelf_loss_cost` were fabricated estimates with no backing data in the dataset. The report should only make dollar claims it can trace to actual records.
- **Scope:** `quarto/report.qmd` setup chunk (variables removed), Part 1 narrative (sections removed), Part 4 methodology (estimates removed from total).
- **Do not:** Re-introduce aggregate cost estimates that combine measured chargebacks with modeled/assumed costs unless the model is documented in the methodology section.

### 2026-05-22 — Barcode validator uses GS1-standard weights, not dataset-generator weights

- **Why:** The previous EAN-13-style weights `(1,3,1,3,...)` matched the synthetic data generator but violated the GS1 spec for GTIN-14. The difference in failure rates (90% vs ~81%) is acceptable — the report uses dynamic inline R and adapts automatically.
- **Scope:** `R/barcode_validators.R`, `mod10_check_digit()`. Applies to GTIN-14 and UPC-A validation.
- **Do not:** Revert to EAN-13 weights to match the dataset generator. If the synthetic data needs regenerating, generate it with correct GS1 weights instead.

### 2026-05-22 — Retailer readiness excludes SSOT-absent fields

- **Why:** The `retailer_requirements` table references fields (`allergen_statement`, `nutrition_facts`, `product_image`, `sds_sheet`, `serving_size`) that do not exist in the raw `product_master`. Left-joining these against `field_evals` produced NAs, which `coalesce(passes, FALSE)` silently converted to failures — making every SKU fail every retailer. Fields with name mismatches (`case_dimensions`, `unit_weight`) compounded the problem.
- **Scope:** `R/02_build_frames.R` lines 201-236. The `required_fields` frame now remaps `case_dimensions` → `case_dims`, `unit_weight` → `unit_weight_lbs`, and filters out the 5 absent fields.
- **Do not:** Re-add absent fields to the readiness check. If the SSOT is updated to include these columns, add them back to `field_evals` and remove the filter exclusion at the same time.

### 2026-05-22 — UPC validation accepts 12-digit UPC-A and 13-digit EAN-13

- **Why:** The SSOT has 13-digit UPC codes (EAN-13 format). The original `is_valid_upc12()` required exactly 12 digits, failing every SKU. Added `is_valid_upc()` that checks both formats. Narrative references changed from "UPC-12" to "UPC" throughout.
- **Scope:** `R/barcode_validators.R` (new `is_valid_upc` function), `R/02_build_frames.R` (uses `is_valid_upc` for both `upc_valid` and `field_evals`), `quarto/report.qmd` and `quarto/tearsheet.qmd` (all "UPC-12" → "UPC").
- **Do not:** Remove `is_valid_upc12()` — it's still used by `tests/test_mod10.R`.

### 2026-05-22 — One-week fix timeline (down from two weeks)

- **Why:** With only barcode defects to fix (no case dimensions, no missing product data fields), the action plan shrinks from 4 phases / 14 days to 3 phases / 5 days. The fix scope is: correct UPC-12 and GTIN-14 check digits, add a validation gate, deploy monitoring.
- **Scope:** `quarto/report.qmd` Part 3 action plan, `quarto/tearsheet.qmd` "A one-week turnaround" section.
- **Do not:** Expand the timeline without adding corresponding fix actions backed by actual defects in the data.

### 2026-06-21 — Option B for CHP-AS-009: rewrite narrative, do NOT change Postgres SSOT

- **Why:** After the Cinderhaven data reseed, CHP-AS-009 (Truffle Mushroom Sauce) now has DQ score 100.0, $0 chargebacks, and 6/6 retailer pass rate. The narrative sections that use it as the "your best-seller is your biggest hidden risk" showcase contradict the data. The decision is to rewrite the narrative around a different showcase SKU that actually has defects, rather than corrupting the database to match old prose.
- **Scope:** `quarto/report.qmd` sections "The $X-a-month problem nobody sees" and "The SKU you can't afford to ignore"; `quarto/tearsheet.qmd` "The crown jewel" section. All use `top_rev` (dynamically computed #1 revenue SKU).
- **Division of labor:** Claude Chat rewrites all narrative prose (Economist style). Claude Code provides the updated figures and candidate showcase SKU after pipeline re-run, then integrates the new prose into the Quarto source and re-renders.
- **Do not:** Modify `raw_tables.rds`, the Postgres SSOT, or any dbt models to re-introduce defects into CHP-AS-009.

### 2026-06-21 — Triage sort: chargeback-bearing SKUs first

- **Why:** `fix_priority_score` weights revenue 40%, putting high-revenue/$0-chargeback SKUs (CHP-PS-006, CHP-DG-004) at positions #1-#2 in triage tables. The tearsheet, report, dashboard, and Excel workbook all show $0 savings and $0/hr for the top-ranked items, undermining the ROI argument.
- **Scope:** All four triage table sorts: `report.qmd`, `tearsheet.qmd`, `dashboard.qmd`, `R/06_excel_workbook.R`. Sort is now `desc(chargeback_total > 0), desc(fix_priority_score)` — chargeback-bearing SKUs first, then by composite priority within each tier.
- **Do not:** Change `fix_priority_score` formula itself — it's still valid as a general-purpose composite. The sort change is display-level only.

### 2026-06-21 — Revenue-at-risk table: fix vectorization bug

- **Why:** `rev_at_risk(retailer)` in the report's rr-summary-table chunk was called vectorized inside `transmute`, receiving all 6 retailer names at once instead of one at a time. The recycled `==` comparison produced a near-total join, returning ~$18.9M for every retailer regardless of their actual failure count.
- **Scope:** `quarto/report.qmd` line 211. Fix: wrap in `sapply()`.
- **Do not:** Remove the `rev_at_risk()` function — it's correct when called with a single retailer name.
