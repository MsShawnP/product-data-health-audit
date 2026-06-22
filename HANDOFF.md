# Handoff — Product Data Health Audit

## Status: Stable / Published

The full pipeline builds, all reports render, CI is green, and the site is live on GitHub Pages.

## What was done (recent sessions)

1. **50-SKU dataset rebuild** — replaced all hardcoded 90-SKU references with dynamic R computations across report.qmd, tearsheet.qmd, dashboard.qmd, and scorecard.qmd.

2. **Correctness fixes (10 findings)** — vectorized `ds()`/`ds_short()` for use in `mutate()`, fixed `cut()` → `ntile()` for tied quantiles, added `ignore.case = TRUE` to chargeback reason matching, fixed NA handling in `updated_by`, guarded division-by-zero in `deauth_ratio`, computed `proddata_cb_18mo` as remainder instead of matching nonexistent reason string, scoped margin comparison to contracted retailers only.

3. **CI pipeline** — added all 55+ R package dependencies to `renv.lock` via `renv::snapshot()`. Modified `R/run_all.R` to skip the Postgres load step when `DATABASE_URL` is empty and `raw_tables.rds` exists. Committed `raw_tables.rds` (1.5 MB) so CI can run without a database.

4. **GitHub Pages deployment** — CI deploys to https://audit.lailarallc.com on every push to main. Landing page links to report, dashboard, tearsheet, compliance timeline, scorecard, and Excel workbook.

## Key files

| File | Role |
|---|---|
| `R/run_all.R` | Pipeline orchestrator (steps 1-6 R, 7-10 Quarto) |
| `R/01_load_raw.R` | Postgres loader (skipped in CI) |
| `R/02_build_frames.R` | Builds analytical frames from raw tables |
| `quarto/report.qmd` | Main narrative report (~1160 lines, 67 R chunks) |
| `quarto/dashboard.qmd` | Interactive dashboard |
| `quarto/tearsheet.qmd` | Executive 2-page PDF |
| `renv.lock` | Complete R dependency lockfile |
| `output/frames/raw_tables.rds` | Cached database snapshot for offline/CI use |
| `.github/workflows/render.yml` | CI: test → build → deploy to Pages |
| `index.html` | GitHub Pages landing page |

## 2026-05-20 15:30

**Started from:** Project stable/published. 4 optional next-steps in HANDOFF.

**Did:**
- Completed all 4 optional items (portfolio review, worktree cleanup already done, Shiny already deployed, GitHub Actions updated to v5/v6/v7)
- Fixed broken images on GitHub Pages (report_files/ and dashboard_files/ not copied to _site/)
- Audited and recalibrated Shiny calculator for 50-SKU dataset (was still using 90-SKU defaults)
- Updated README.md and index.html from 90 SKUs/$361k to 50 SKUs/$430k

**State:**
- Git pushed with 3 commits (Actions update, Pages _files fix, Shiny recalibration)
- Shiny redeployment to shinyapps.io in progress (separate session, hitting error)
- Internal docs/process/ files still reference old 90-SKU numbers (historical)

**Next:**
- Verify Shiny redeployment completed (live app should show N=50, C=$112k defaults)
- Verify GitHub Pages renders charts/images after _files fix
- Run `/improve` pass (never done) and dependency audit (never done)
- Consider updating data_generation_log.md for 50-SKU dataset

## 2026-05-20 16:30

**Started from:** Shiny needed redeployment to shinyapps.io. GitHub Pages charts missing. Previous session's _files fix untested.

**Did:**
- Redeployed Shiny app to shinyapps.io (token refresh + renv shiny dep fix required)
- Fixed GitHub Pages missing charts — added `cp -r output/charts` and `cp -r assets` to workflow Assemble step
- Applied Lailara brand kit to all 21 charts: showtext for brand fonts on CI, canvas background, design system greyscale tokens replacing hardcoded greys
- Added table overflow-x CSS to report.css
- Updated renv.lock twice (shiny deps, showtext/sysfonts)

**State:**
- Shiny app: live and correct at shinyapps.io with 50-SKU defaults
- GitHub Pages: all 15 chart images load, but chart quality is poor — showtext renders fuzzy text at small sizes
- Triage reactable table has unwanted horizontal scrollbar
- One chart reportedly doesn't render — not yet identified which one
- Report content area too narrow (max-width: 820px) — charts and tables feel squeezed
- CI green, 5 commits pushed this session

**Next (priority order):**
1. **DATA BUG:** Total TTM revenue is $27.9M but Postgres source should produce $32.1M. Likely the cached `raw_tables.rds` is stale or `R/02_build_frames.R` is filtering/losing rows. Re-export from Postgres, compare row counts, trace the discrepancy. This affects every dollar figure in the report.
2. Fix chart rendering: switch from showtext rasterizer to `ragg::agg_png` device, bump DPI to 300, increase base_size to 14-15, increase all geom_text size params. Test locally before pushing.
3. Fix triage table scrollbar (reactable in report.qmd ~line 859)
4. Identify and fix the one chart that doesn't render at all
5. Widen report content area (report.css max-width: 820px → wider)
6. Run `/improve` pass (never done) and dependency audit (never done)

## 2026-05-22

**Started from:** Narrative in report.qmd and tearsheet.qmd made claims the data didn't support.

**Did:**
- Comprehensive rewrite of report.qmd (~960 lines, 45 chunks) so every narrative claim matches the actual data
- Updated tearsheet.qmd crown jewel section, entry-path narrative, and fix timeline
- Expanded retailer scope from 3 to all 6 in data
- Removed quality-tier analysis (zero DQ variance), entry-path analysis (all NA), stalled-launch/shelf-loss cost estimates (no supporting data)
- Changed chargeback reason remap to honest names in 02_build_frames.R
- Changed hardcoded SKU references to dynamic top_rev / top_cb computations
- Verified both HTML (report.qmd) and PDF (tearsheet.qmd) render successfully

**State:**
- report.qmd and tearsheet.qmd are honest and render cleanly
- No remaining references to removed variables or hardcoded SKUs
- Git: changes unstaged (not committed)

**Next (priority order):**
1. ~~**DATA BUG:**~~ Resolved — stale raw_tables.rds was missing scan_data. Current file (7.1MB, 1.4M scan rows) produces $33.0M TTM revenue. No code fix needed.
2. ~~Commit and push~~ Done (dd5f8a1, 866b34a).
3. ~~Verify chart rendering quality, triage table scrollbar, report width~~ Verified — charts render as SVG vectors (crisp), scrollbar gone, width reasonable.
4. ~~Run `/improve` pass~~ Done 2026-05-22. See audit results below.

## 2026-05-22 (session 2) — Chart title clipping + /improve audit

**Started from:** Chart titles clipped in SVG output. `/improve` never run.

**Did:**
- Fixed chart title clipping: added `wrap_title()` helper to `R/00_theme.R`, applied to all 19 long titles across `R/04_hero_charts.R` and `R/05_supporting_charts.R`
- Fixed encoding corruption in `R/00_theme.R` (smart quotes, mojibake from prior PowerShell write)
- Fixed chart 06 NA bug: `c6$retailer == "Walmart"` returned NAs due to factor coercion; fixed with `which()`
- Restructured chart 06 title so `$` glyph isn't the leading character (showtext SVG viewport clipping)
- Added `plot.margin` to `theme_lailara()` for viewport breathing room
- Committed and pushed (9818f0c)
- Ran full `/improve` audit (first ever for this project)

**State:**
- Git: clean, pushed to main
- All charts regenerated with corrected titles
- CI should be green

**`/improve` audit findings (2026-05-22):**

### CRITICAL — must fix before the analysis is credible

1. **Data quality score denominator bug** — `R/02_build_frames.R:129` divides `checks_passed_6` by 8 instead of 6. Every SKU that passes all 6 checks gets 75%, not 100%. This is why `mean_dq_all = 75.0` with zero variance. Fix: change `/8` to `/6` or add the 2 missing check-digit validations to the numerator.

2. **Retailer readiness checks reference nonexistent fields** — `R/02_build_frames.R:206-236`. The `retailer_requirements` table requires `allergen_statement`, `nutrition_facts`, `product_image`, `sds_sheet` — none exist in `sku_dim`. Left join returns NA → `coalesce(passes, FALSE)` silently fails every SKU. Also field name mismatches: `case_dimensions` vs individual columns, `unit_weight` vs `unit_weight_lbs`. This is why 100% of SKUs fail retailer readiness.

3. **UPC-12 validation has 0% pass rate** — `barcode_validators.R:29`. UPC data appears to be 13 characters, failing the 12-character length check. Likely a SSOT data generation issue — plan separately.

4. **Entire narrative needs rewriting** after scoring fixes. Once quality scores distribute realistically and some SKUs pass retailer readiness, every chart and claim changes.

### IMPORTANT — worth improving

5. Hardcoded `$55M` in `report.qmd:336` — should be dynamic or removed.
6. No PLAN.md exists.
7. Error handling gaps at I/O boundaries (no `tryCatch()` on `readRDS()` calls).
8. Barcode validator uses EAN-13 weights, not GS1-standard GTIN-14 weights (`barcode_validators.R:13`).
9. O(n²) `still_broken_vec` computation (`02_build_frames.R:374-380`) — should use a join.

### NICE TO HAVE

10. Frame-loading boilerplate duplicated across 5 scripts.
11. Minor naming inconsistencies (`chargebacks_e`, `read_p()`).
12. `data_generation_log.md` still references 90 SKUs.

**DO NOT CHANGE THE SSOT** (`raw_tables.rds` / Postgres). If the synthetic data itself needs adjusting (e.g., adding `allergen_statement` columns, fixing UPC lengths), that is a separate plan.

## 2026-05-22 (session 3) — Critical scoring bug fixes

**Started from:** /improve audit found 4 critical bugs (DQ denominator, retailer readiness field mapping, UPC validation, narrative rewrite needed).

**Did:**
- Fixed DQ score denominator: `checks_passed_6 / 8` → `/ 6` in `R/02_build_frames.R:129`. Scores now 100% (all completeness checks pass; the real issue is check-digit validation, which is separate).
- Fixed retailer readiness field mapping: remapped `case_dimensions` → `case_dims`, `unit_weight` → `unit_weight_lbs`. Excluded 5 SSOT-absent fields (`allergen_statement`, `nutrition_facts`, `product_image`, `sds_sheet`, `serving_size`).
- Added `is_valid_upc()` to `R/barcode_validators.R` accepting both 12-digit UPC-A and 13-digit EAN-13 (SSOT has 13-digit codes).
- Updated ~15 narrative passages in report.qmd and tearsheet.qmd: "universal failure" → "near-universal", dynamic inline R vars for pass counts, removed hardcoded `$55M`, "UPC-12" → "UPC" throughout.
- Full pipeline renders cleanly (report HTML, tearsheet PDF, dashboard, scorecard, compliance timeline, Excel workbook).

**Post-fix data:**
- DQ score: 100% all SKUs (completeness is fine; check-digit correctness is the real blocker)
- GTIN failures: 45/50 (90%) — intentional synthetic corruption
- UPC failures: 45/50 (90%) — different 5 SKUs than GTIN
- No SKU has both valid GTIN and valid UPC
- Readiness: Costco/Sprouts/Walmart at 10% pass; Kroger/Regional Group/Whole Foods at 0%

**State:**
- Git: clean, pushed to main (141c7d8)
- CI should be green
- All /improve CRITICAL items (1-4) resolved

**Next:** Project is in maintenance mode. Next /improve review due 2026-06-22, next dep audit due 2026-07-22.

## 2026-05-22 (session 4) — /improve cleanup + dependency audit

**Started from:** 5 important + 3 nice-to-have /improve items remaining, plus dependency audit never done.

**Did:**
- Fixed #7: tryCatch on readRDS() in 02_build_frames.R
- Fixed #8: Switched barcode validator to GS1-standard GTIN-14 weights, updated tests
- Fixed #9: Replaced O(n²) still_broken_vec with join-based approach
- Fixed #10: Extracted shared read_frame helper into R/00_setup.R
- Fixed #11: Renamed chargebacks_e → chargebacks_enriched across 3 scripts
- Fixed #12: Updated data_generation_log.md from 90→50 SKUs
- Created PLAN.md (local only, gitignored)
- Dependency audit: updated bit64/renv, added svglite/textshaping/processx to lockfile, no CVEs
- Pushed 4 commits, CI green

**State:**
- All 12 /improve items resolved
- Health tracker fully green
- Git: clean, pushed to main (e18a0bc)
- CI: green

**Next:** Maintenance mode. Next /improve: 2026-06-22. Next dep audit: 2026-07-22.

---

## Improvement History

## 2026-06-21 — Chart fixes round 2 + table nowrap (session 9)

**Started from:** Chart bar fills fixed (session 8). Round 2 focused on color semantics: ordinal gradients, removing decorative color, cutting unreadable charts, and table text wrapping.

**Did:**
- Chart 11 (deauth by quality tier): replaced multi-hue `risk_band_colors` with single-hue HK gradient (darkest=worst, lightest=best)
- Chart 3 (retailer P&L): replaced unreadable single grouped-bar ($8M vs $112K) with 4 small-multiple horizontal bars faceted by metric, each with own scale, all Chicago-20
- Chart 7 (data debt by product line): all 5 bars Chicago-20, highlighted highest (Specialty Condiments) in Tokyo-40, dynamic title referencing actual highest/lowest
- Collapsible panels: all callout-note/callout-tip left borders → Chicago-20
- Report tables: `white-space: nowrap` on all td, table `width: auto`, overflow-x scroll on wrapper
- Dashboard tables: already had nowrap + overflow (verified, no changes)
- Tearsheet tables: LaTeX l/r alignment = no wrap by default (verified, no changes)

**State:** All pushed to main (2 commits: `fd93d14`, `58bcd15`). Pipeline renders cleanly. All outputs current.

**Next:**
1. Fix 3 remaining methodology contradictions (report.qmd lines 218, 918, 920) — carried from session 4
2. Project in maintenance mode. Next /improve: 2026-06-22. Next dep audit: 2026-07-22.

---

### 2026-05-22 — First /improve audit
- **Findings:** 4 critical, 5 important, 3 nice-to-have
- **Top concerns:** 100% SKU failure rate caused by three compounding code bugs (wrong score denominator, missing field mappings in retailer readiness, UPC validation failure). Narrative will need full rewrite after fixes.
- **What was fixed session 2:** Chart title clipping (wrap_title + encoding fixes + chart 06 NA bug). Committed as 9818f0c.
- **What was fixed session 3:** All 4 critical items (DQ denominator, readiness field mapping, UPC validation, narrative update). Committed as 141c7d8.
- **What was fixed session 4:** All remaining items (#7-#12) plus dependency audit. Committed as d770702, ce80690, c017a73, e18a0bc.
- **All items resolved.** Next review: 2026-06-22

## 2026-06-03 18:25

**Started from:** Project in maintenance mode. Audit read raw.* tables and duplicated transforms dbt already owned.

**Did:**
- Refactored R pipeline to consume dbt mart layer exclusively (dim_products, fct_chargebacks, dim_stores, fct_scan_data, fct_promotions, dim_retailer_requirements). Removed R-side retailer joins, sku_costs join, first_scan aggregation.
- Created 5 new dbt mart models in the platform, expanded dim_products with 19 columns.
- Full baseline-diff verification via stash: all 15 frames match on shared columns at 1e-10, all 16 protected metrics identical, retailer-name standardization affected zero rows.
- Read-only audit of 4 other consumers: CPA clean, C2C clean, RDR needs work (reads int/stg), RVDT needs work (reads staging, re-derives margins, has SQLite source).

**State:** Pipeline reads marts exclusively. dim_products is the sole product-master definition. Commits: 238aaa0 (refactor), a04ab67 (cache), e79e6e5 (log). Not pushed.

**Next:** Retailer Deduction Recovery refactor — repoint from int_all_*/stg_retailer_* to fct_*/dim_* marts. Some staging-only tables need new mart models first. Same baseline-diff verification pattern.

## 2026-06-13

**Started from:** Phase 5 sweep deferred fixes — stale SQLite + Chart 12 caption.

**Did:** Refreshed SQLite from relocked platform Postgres (verified row counts). Fixed Chart 12 caption "3 retailers" → "6 retailers" (caption text only). Re-ran full R pipeline — new figures: $693,209 (36mo) / $231,070 (annual). Investigated Path A chargebacks: 281 records, $93,110/yr is the true data-attributable figure. PDHA classifier uses reason-string matching, not triggered_by_field.

**State:** Pipeline output current with relocked platform data. Committed and pushed (523cd4e). Report's $231K headline is all chargebacks, not the data-attributable subset.

**Next:** To lead with data-attributable cost ($93K/yr), pipeline needs `triggered_by_field` from `raw.retailer_chargebacks`. Either add to `fct_chargebacks` mart or have PDHA export pull from raw. Update 8 website surfaces that reference $458K.

## 2026-06-21 — 16-issue audit remediation (session 1)

**Started from:** Full audit of 9 artifacts found 16 issues. Decision locked: Option B for CHP-AS-009 (rewrite narrative, do NOT change Postgres SSOT).

**Did (code fixes):**
1. **Revenue-at-risk table (Issue 2):** `rev_at_risk(retailer)` was called vectorized inside `transmute` — received all 6 retailer names, recycled `==` produced same $18.9M for every row. Fix: wrapped in `sapply()` in `report.qmd:211`.
2. **Chart 06 NA bar (Issue 3):** Factor levels restricted to `c("Walmart","Costco","Whole Foods")` — Kroger, Sprouts, Regional Group became NA. Fix: removed `intersect()` restriction, added all 6 retailers to `scale_fill_manual` in `R/05_supporting_charts.R:170`.
3. **Triage sort (Issue 12):** `fix_priority_score` put $0-chargeback SKUs (CHP-PS-006, CHP-DG-004) at #1-#2. Fix: sort by `desc(chargeback_total > 0), desc(fix_priority_score)` in 4 files (report, tearsheet, dashboard, Excel workbook).
4. **Tearsheet cross-refs (Issue 12):** `::: {layout-ncol=3}` caused "(a)" sub-figure labels. Fix: replaced with LaTeX `\begin{minipage}` layout in `tearsheet.qmd`.
5. **Dead calculator link (Issue 10):** Updated `shinyapps.io` → `calculator.lailarallc.com` in `index.html` and `report.qmd:771`.
6. **Landing page figures (Issue 11):** "$25M" → "$34M", "52hrs" → "40hrs". Added Excel workbook download card (Issue 15).
7. **README:** "$25M" → "$34M".
8. **Hardcoded barcode claim (Issue 8):** "Not a single SKU has both a valid GTIN and a valid UPC" was hardcoded and false (38/50 have both valid). Replaced with dynamic inline R using `n_both_barcode_valid`.
9. **SVGs confirmed true vector (Issue 5):** False alarm — svglite output, no embedded PNGs.

**Key findings during diagnosis:**
- **Current data post-reseed:** 12/50 GTIN failures, 12/50 UPC failures (same 12 SKUs, always both invalid). 38/50 pass both. Retailer pass rates: Costco 76%, Kroger/WF 50%, others 46%. No retailer at 0%.
- **40-hour fix discrepancy:** `ows_complete` is NA for all 50 SKUs → formula adds 30 min/SKU = 25 phantom hours. Plus 19 SKUs with `missing_case_dims = TRUE` (30 min each). Barcode-only fix is ~4 hours. Report narrative claims "Case dimensions, brand owner, country of origin, and OneWorldSync registrations are all already complete" — contradicted by both the formula and the data.
- **Top revenue SKU:** CHP-AS-009 has perfect data (DQ 100, both barcodes valid, $0 chargebacks) but `est_fix_hours = 0.5` due to OWS NA padding.
- **Top chargeback candidates for showcase rewrite:** CHP-SC-006 ($80K cb, $607K rev), CHP-SC-004 ($74K cb, $641K rev), CHP-DG-007 ($56K cb, $896K rev) — all have invalid GTIN+UPC.

**Decisions needed:**
1. **OWS formula:** Should `is.na(ows_complete)` count as 30 min of fix work? If no → total_fix_hours drops from ~40 to ~15. If yes → the narrative and fix table need to show OWS as a defect type.
2. **Case dimensions:** 19/50 SKUs have `missing_case_dims = TRUE`. Is this real or a reseed artifact? If real → narrative needs to stop claiming "case dimensions are complete."
3. **Showcase SKU for Claude Chat:** Which SKU replaces CHP-AS-009? Best candidates are CHP-SC-006 (top cb), CHP-DG-007 (high rev + high cb), or CHP-SC-004.

**State:** Changes in working tree, not committed. Pipeline has NOT been re-run — all code fixes need `Rscript R/run_all.R` to take effect.

**Next:**
1. Decide on OWS/case-dims questions above
2. Re-run R pipeline to regenerate all outputs
3. Provide Claude Chat with updated figures + chosen showcase SKU
4. Claude Chat rewrites narrative sections
5. Integrate new prose, re-render, deploy
6. Apply Lailara design system to HTML report/dashboard (Issue 9)
7. Verify companion PDFs (Issue 16)
8. Confirm `calculator.lailarallc.com` is live

## 2026-06-21 — Phases 2A–4 (session 2)

**Started from:** Session 1 diagnosed 16 issues, locked 3 decisions (OWS NA ≠ defect, 19 missing case dims = real, CHP-DG-007 is showcase SKU). No code committed yet, pipeline not re-run.

**Did:**

**Phase 2A — OWS formula fix + pipeline re-run:**
- Removed `ows_complete` from `issue_count`, `reason_defect_map`, `sku_defect_flags`, and `fix_minutes_est` in `R/02_build_frames.R`. Kept `ows_complete` column definition (data property, not defect).
- Removed OWS from hero chart calculations in `R/04_hero_charts.R` and chart 05 in `R/05_supporting_charts.R`.
- Removed `n_ows_incomplete`/`pct_ows_incomplete` from `report.qmd` setup chunk.
- Updated `index.html`: "40 hours" → "15 hours".
- Re-ran full pipeline (177.8s). New figures: total_fix_hours = 15, 36mo CB = $686,534, TTM rev = $33,712,481.

**Phase 3 — Technical fixes:**
- Standardized all 19 chart widths to 10 inches (was 8/9/10/11 mix). Changed `save_chart`/`save_pair`/`to_girafe` defaults to `w=10`/`w_in=10`.
- Created `quarto/assets/lailara.scss` — Quarto SCSS theme layer (body-bg, typography, borders, TOC).
- Applied SCSS theme to `report.qmd` and `dashboard.qmd` via `theme: [cosmo, assets/lailara.scss]`.
- Updated `quarto/assets/report.css` max-width from 1080px to 1200px.
- Verified all checklist items: chart 06 clean, no text overlap, dashboard waterfall inline SVG, tearsheet 2pp, companion PDFs clean.

**Phase 4 — Data extraction for Claude Chat:**
- Extracted all 10 tables + additional data points from pipeline frames.
- Key corrected findings vs session 1 assumptions:
  - Retailer pass rates (SKU-level, not field-level): Costco 76%, Kroger/WF 50%, Regional/Sprouts/Walmart 46%.
  - 12 SKUs fail ALL 6 retailers (not 0 as field-level sum suggested).
  - CHP-DG-007: revenue rank 9, 0/6 retailers passing, $18,834/yr annualized CB, 50 min fix time.
  - CHP-AS-009 confirmed clean: DQ 100, $0 CB, 6/6 retailers, both barcodes valid.
  - "$0-a-month" candidates: CHP-AS-005 ($111/retailer/month), CHP-PS-003 ($110), CHP-DG-001 ($94).
- Identified 4 lines in `report.qmd` (547, 787, 814, 950) that falsely claim case dimensions/OWS are "all complete" — Claude Chat must rewrite.

**State:**
- All changes in working tree, **not committed**.
- Pipeline output is current with all Phase 2A/3 changes.
- Phase 4 data delivered in conversation — ready for Claude Chat.

**Next (Phase 5+):**
1. Give Phase 4 data to Claude Chat for narrative rewrite of `report.qmd`
2. Claude Chat rewrites: CHP-DG-007 showcase, 4 "all complete" claims (lines 547/787/814/950), narrative logic around retailer pass rates
3. **Phase 5:** Integrate rewritten prose into `report.qmd`, re-run pipeline, re-render
4. **Phase 6:** Full verification pass, commit all changes, deploy to https://audit.lailarallc.com/
5. Confirm `calculator.lailarallc.com` is live

## 2026-06-21 — Phase 5: Narrative integration (session 3)

**Started from:** Phase 4 data extraction complete. Claude Chat had rewritten 6 sections, 4 surgical edits, tearsheet crown jewel, and landing page text. Ready to integrate prose into Quarto source.

**Did:**
- Replaced 6 full narrative sections in report.qmd with Chat-authored prose (CHP-DG-007 showcase, $111-a-month, pattern beneath the numbers, concentrated defect, 15 hours against $228,845, top-10 table)
- Applied 3 surgical edits in Part 4 collapsible panels (lines 787, 814, 950) correcting false "case dimensions complete" claims
- Rewrote tearsheet.qmd crown jewel: CHP-AS-009 → CHP-DG-007
- Updated index.html landing page with Option A ($51K data + $177K fulfillment)
- Fixed "The sequence" section: added case dimensions to phase one, updated $93K/$138K → $51K/$178K
- Searched for stale references ($93,826, 41%, $93,000) — found and fixed the only remaining instance
- Verified growth projections are dynamic (auto-update on render)

**State:**
- All Chat prose integrated into source files. Not committed.
- Pipeline NOT re-run — outputs are stale.
- 4 stale prose passages remain in report.qmd (lines 230, 324, 343) and 1 in tearsheet.qmd (line 208) — still imply universal barcode failure. Need follow-up Chat edit.

**Next:**
1. Fix 4 flagged stale passages (report.qmd lines 230, 324, 343; tearsheet.qmd line 208)
2. Re-run R pipeline (`Rscript R/run_all.R`)
3. Verify rendered report matches new prose
4. Apply Lailara design system to HTML report/dashboard (Issue 9)
5. Verify companion PDFs (Issue 16)
6. Confirm calculator.lailarallc.com is live
7. Commit and deploy

## 2026-06-21 — Phase 5 continuation: contradiction sweep (session 4)

**Started from:** Session 3 integrated Chat prose but left 4 stale "universal failure" passages. Pipeline not re-run.

**Did:** Applied 9 surgical edits across report.qmd and tearsheet.qmd in two rounds, fixing claims of universal barcode failure, uniform DQ scores, and near-universal readiness failure. Re-rendered pipeline twice (both clean). Final grep sweep caught 3 more contradictions in methodology notes.

**State:** Pipeline renders cleanly. 9 edits applied, not committed. 3 remaining contradictions in report.qmd methodology section (lines 218, 918, 920) — "near-universal" and "uniform/shared DQ score" claims that contradict data and our own edit to line 922.

## 2026-06-21 — Design system full sweep + dashboard fix (sessions 5–7)

**Started from:** Lailara Design System v2 never consistently applied. Calculator had blue header, stacked bars in portfolio, dashboard had dark navy header and teal table headers.

**Did:**
- **Color inventory** across all R chart files, CSS/SCSS, HTML, QMD — mapped every hex to design system tokens
- **Token mapping applied** to PDFs (tearsheet, compliance_timeline, scorecard), Excel workbook, reactable tables, tooltips, report link color
- **Calculator fixes**: navbar `background-color: #f5f3ee !important` (Bootstrap primary was bleeding through), verified composition chart was already separate bars, deployed to Fly.io
- **Dashboard full fix (all 3 tabs)**:
  - Header bar: dark navy `#1a1a1a` → Canvas `#f5f3ee` with London-85 border
  - Table headers: Chicago-20 `#1f2e7a` bg, white text (all 3 tabs)
  - Removed heat-map cell fills from data columns; color only on status/judgment badges
  - P&L chart: stacked waterfall → separate horizontal bars per retailer (facet_wrap)
  - Chart 3 (hero): stacked composition → faceted grouped bars
  - Chart 20: stacked → grouped (position_dodge) bars
  - Tab 3 triage: sort by savings_per_hour desc, $0 pushed to bottom
  - CSS: white-space nowrap on all table cells, overflow-x auto on wrapper
- **Standing rule enforced: NO STACKED BARS anywhere in portfolio** — grep confirms zero `position_stack` calls remain

**State:**
- Git: clean, pushed to main. Commits: `ee97804` (design system sweep), `bec15e1` (calculator), `d6f08d4` (dashboard + charts), `97bc49f` (CI fix)
- Pipeline renders cleanly (226s)
- All outputs current: report HTML, dashboard HTML, 3 PDFs, Excel workbook, all charts
- Calculator live at calculator.lailarallc.com

**Verified live:**
- audit.lailarallc.com — CI run 27909582736 passed (4m8s), all changes deployed including chart rewrites, dashboard design pass, CSS sizing fix
- calculator.lailarallc.com — Fly.io deploy succeeded, full design system redo live

**Next:**
1. Fix 3 remaining methodology contradictions (report.qmd lines 218, 918, 920) — carried from session 4
2. Project in maintenance mode. Next /improve: 2026-06-22. Next dep audit: 2026-07-22.

## 2026-06-22 — Report polish: layout, Part 4 restructure, text fixes, growth formula (session 10)

**Started from:** Chart color encoding confirmed correct (session 9). Remaining: triage table, layout, Part 4 structure, text fixes, growth formula.

**Did:**
- Fixed triage reactable (strip fills, sort savings/hr, nowrap headers)
- Fixed report layout (body text fills 1200px, reactable font/size, panel text width)
- Restructured Part 4: 8 collapsible callouts → 1 single collapsible with ## subsections
- Applied 10+ text fixes across report.qmd (chargeback range, DQ checks 8→6, artifact counts, retailer readiness rewrite, etc.)
- Fixed growth formula: denominator hardcoded 3 → dynamic n_retailers (6), retailers 5/8 → 8/12
- Updated R/05_supporting_charts.R chart 12 to match
- Corrected stale memory ($228K → $147K annual cb)

**State:**
- 2 commits pushed: `07c26db`, `6440cd6`
- Working tree: 3 pre-existing uncommitted changes (.Rprofile, raw_tables.rds, waterfall SVG)
- Flagged NOT fixed: 3× hardcoded "$228,845" in report.qmd, chart 11 teal hexes → LL_SEQ, 3 methodology contradictions (lines ~218/918/920)

**Next:**
1. Fix 3 hardcoded "$228,845" → `ds(annual_cb)` inline R expressions
2. Fix chart 11: hardcoded teal → LL_SEQ Hong Kong sequential gradient
3. Fix 3 methodology contradictions (lines ~218, 918, 920) — carried from session 4
4. /improve review due (last: 2026-05-22)

## 2026-06-22 — Post-reseed narrative update + date audit (session 11)

**Started from:** Report built on pre-reseed data ($228,845 annual). Post-reseed Postgres/SQLite has $146,961. ~15 hardcoded dollar amounts from old data throughout report, tearsheet, dashboard, landing page.

**Did:**
- Investigated $245K chargeback discrepancy — traced to raw_tables.rds regenerated from re-seeded database (not a pipeline bug)
- Deleted stale raw_tables.rds, regenerated from SQLite, re-ran full R pipeline (steps 01-06)
- Converted 3 hardcoded "$228,845" in report.qmd to dynamic `ds(annual_cb)` inline R
- Applied all 12 items from audit-reseed-rewrites.md: $111→$56 section, CHP-DG-007 at $2.2M/#6, data-defect share 22%→35%, fulfillment $177K→dynamic, monthly CB $19K→dynamic, revenue references→dynamic, tearsheet paragraph, landing page $177K→$96K, dashboard $20K→$15K, top-10 revenue table→dynamic R chunk
- Audited all date anchors: TTM anchored to max(week_ending) not Sys.Date(), chargebacks use full dataset with no date filter, no CURRENT_DATE in any computation
- Confirmed CHP-SC-006 TTM revenue is $51,332 (88% CB-to-revenue ratio — confirmed from raw scan data)
- Verified zero remaining hits for old figures ($228,845, $686,534, $896,803, etc.) in any .qmd source

**State:**
- All .qmd source files updated. Rendered HTML is stale (needs Quarto re-render).
- Two open issues NOT resolved:
  1. Chargebacks span 37 months (Jan 2023 – Jan 2026) but annualization divisor is hardcoded to 36. ~2.7% undercount.
  2. No explicit observation period stated in the report.
- NOT committed, NOT pushed.

**Next:**
1. Resolve 36/37 chargeback month mismatch (filter to 36 months OR dynamic divisor)
2. Add explicit observation period statement to report
3. Re-render all Quarto outputs (report HTML/PDF, dashboard, tearsheet, scorecard, compliance timeline)
4. CHP-SC-006 88% CB-to-revenue ratio — Chat may want to adjust framing
5. Fix 3 methodology contradictions (report.qmd lines ~218/918/920) — carried from session 4
6. Commit and deploy

## 2026-06-22 — Chart bar fill sweep (session 8)

**Started from:** Session 7 applied design system to chrome/layout but left bar fills wrong. 19 of 21 charts used `LL_RECEDE` (gridline gray `#d9d9d9`) for bar fills and `LL_RED` (`#CC100A`, Red-42) for accents — both wrong per design system.

**Did:**
- **00_theme.R:** Replaced `LL_RECEDE`/`LL_RECEDE_MID`/`LL_RECEDE_DARK` aliases with proper chart-role aliases: `LL_BAR_DEFAULT` (Chicago-20 `#1f2e7a`), `LL_BAR_HIGHLIGHT` (Tokyo-40 `#b82d4a`), `LL_BAR_POSITIVE` (HK teal), `LL_BAR_SECONDARY` (Chicago Light), `LL_BAR_RED` (Red Dark `#8e0b07`). Updated `risk_band_colors` and `passfail_colors` to use `LL_RED_DARK` instead of `LL_RED`. Updated `cinderhaven_palette` list to match.
- **04_hero_charts.R:** Fixed all 4 hero charts — Pareto annotation fill, time-to-shelf (→ `risk_band_colors`), retailer margin trade spend bar, fix ROI bars.
- **05_supporting_charts.R:** Fixed all 15 active supporting charts (5–9, 11–17, 19–23). Every `cinderhaven_palette$recede` → `LL_BAR_DEFAULT`, every `cinderhaven_palette$red` as fill → `LL_BAR_HIGHLIGHT`, risk-tier charts → `risk_band_colors`, line chart colors → `LL_TOKYO`/`LL_CHICAGO_LIGHT`.
- Deleted stale `20_retailer_setup_readiness_stacked.*` files (leftover from grouped-bar conversion).
- Full pipeline re-rendered twice (206s each). Quarto reports + PDFs clean.

**Verification (grep of all SVGs):**
- `#CC100A`: **zero** occurrences across all SVGs
- `#1F2E7A` (Chicago-20): present in 14/19 active charts; 5 charts correctly use specialized palettes (risk bands: `#8E0B07`/`#B82D4A`/`#8E9AD0`/`#158F75`; line chart: `#B82D4A`/`#8E9AD0`; pass/fail: `#B82D4A`/`#0C6552`)

**State:**
- Git: clean, pushed to main (`720f035`)
- CI: passed (27922364799, 3m56s)
- All charts, reports, dashboard, PDFs current and deployed

**Next:**
1. Fix 3 remaining methodology contradictions (report.qmd lines 218, 918, 920) — carried from session 4
2. Project in maintenance mode. Next /improve: 2026-06-22. Next dep audit: 2026-07-22.

## 2026-06-22 — Dashboard table CSS fixes (session 12)

**Started from:** Dashboard tabs 1 and 3 had narrow tables confined to content container. Tab 2's P&L table extended wider. Headers truncated on tabs 1/3.

**Did:**
- Diagnosed root cause: `fullWidth = FALSE` added `rt-inline` class (inline-flex) constraining table width. Changed to `fullWidth = TRUE` on tabs 1 and 3.
- Changed all column `width` → `minWidth` in dashboard.qmd so columns grow instead of being fixed.
- Fixed CSS specificity battle: dashboard.css `.rt-table` lost to report.css `.cell-output-display .reactable .rt-table` (higher specificity wins when both have `!important`). Added matching selector in dashboard.css.
- Fixed `.Reactable { overflow: hidden }` → `overflow: visible` to allow table expansion past container.
- Tried and reverted viewport-width breakout CSS (95vw + calc(-50vw+50%)) — too aggressive, pushed content off screen.
- Final: all 3 tabs have zero truncated headers verified via scrollWidth DOM inspection. Tables extend beyond 1320px container with horizontal scroll.

**State:** Committed and pushed (91b238a). CI passed. Working tree has pre-existing uncommitted changes (.Rprofile deleted, raw_tables.rds modified, waterfall SVG modified).

**Next:**
1. Resolve 36/37 chargeback month mismatch (filter to 36 months OR dynamic divisor)
2. Add explicit observation period statement to report
3. Fix 3 methodology contradictions (report.qmd lines ~218/918/920) — carried from session 4
4. Re-render all Quarto outputs, commit, deploy
5. /improve review due (last: 2026-05-22). Next dep audit: 2026-07-22.
