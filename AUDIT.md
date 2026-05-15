# Project Audit — Product Data Health Audit

**Audited:** 2026-05-15
**Tier:** Medium
**Status:** In progress

---

## Phase 1: Baseline Assessment

### What This Project Is

A complete product data health audit for Cinderhaven Provisions (fictional $25M specialty food brand), built as a portfolio piece for a data consulting practice targeting CEOs at $10M–$100M companies. One R pipeline generates five artifacts from a synthetic SQLite database.

### Current State Summary

| Component | Count | Status |
|-----------|-------|--------|
| R scripts (main pipeline) | 6 | Clean, 4,400 lines |
| R diagnostic scripts | 11 | Hardcoded dev paths |
| Quarto documents | 5 | All rendered |
| Analytical frames | 13 | Complete (RDS + CSV) |
| Charts | 23 | 4 hero + 17 supporting |
| Excel workbook | 1 | 8 tabs, formatted |
| Shiny app | 1 | Standalone, deployable |
| GitHub Actions CI | 1 | Properly configured |
| Planning/prose docs | 9 | Complete |

**Pipeline status:** Fully functional. `Rscript R/run_all.R` regenerates everything end-to-end.

### What Was Intended vs. What Exists

Per the README and rebuild plan, the project delivers:

1. **Audit report (HTML + PDF)** — Exists, rendered, 8-page case study
2. **Executive tearsheet (2-page PDF)** — Exists, rendered
3. **Monday Morning Dashboard (HTML)** — Exists, rendered, interactive tables
4. **Excel workbook (8 tabs)** — Exists, 221 KB, properly formatted
5. **Data Debt Calculator (Shiny)** — Exists, standalone, not yet deployed
6. **Compliance timeline (PDF)** — Exists, shareable artifact
7. **Scorecard template (PDF)** — Exists, shareable artifact

**Verdict:** All intended deliverables exist and render correctly.

### Issues Found

**1. Hardcoded development paths in 11 diagnostic scripts** (Medium)
All underscore-prefixed R scripts use `ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"` — a stale path from an earlier dev location. These scripts are NOT part of the main pipeline but would fail on any other machine or the current location.

**2. Incomplete companion artifact links in README** (Low)
Four placeholder links in the "Companion artifacts" section: GTIN Validator, SQL query library, HTML audit report, Data Debt Calculator.

**3. Color palette divergence in supporting charts** (Low)
`05_supporting_charts.R` defines local color palettes that differ from the canonical `00_theme.R` values (e.g., Pantry Staples: #1E8C7E vs #2e8b57). Hero charts use the theme correctly; supporting charts may show minor visual inconsistency.

### Strengths

- Clean separation: numbered scripts run in sequence, underscore scripts are dev-only
- Single source of truth for numbers (`canonical_numbers.md`)
- Proper dependency management (renv.lock)
- Graceful fallbacks (Quarto not found? Skip render, continue pipeline)
- Comprehensive synthetic data with documented intentional defects
- GitHub Actions CI properly configured with artifact uploads

---

## Phase 2: Internal Review

Four parallel reviews completed: architecture, performance, documentation/DevEx, and security. Findings deduplicated and ranked by leverage.

### Tier 1 — Must Fix (high leverage, credibility issues)

**1. 1,700+ generated files tracked in git, including 1,224 binary fonts**
The `output/charts/*_files/` directories contain bundled JS/CSS/font dependencies from htmlwidget renders. All chart PNGs, HTML interactives, RDS files, the Excel workbook, and rendered Quarto outputs are also tracked. The project claims "everything regenerates from a single command" but commits all regenerated outputs. A reviewer browsing the repo sees 1,200+ font files — strong negative signal.
*Fix:* Add gitignore rules for `output/charts/`, `output/*.xlsx`, `output/*.pdf`, `quarto/*.html`, `quarto/*.pdf`. Run `git rm -r --cached` on tracked generated files.

**2. CI workflow cannot actually reproduce the pipeline**
`render.yml` runs `Rscript R/run_all.R` but never runs `setup.sh`, never initializes the git submodule, never installs Python, and never builds the database. The pipeline's first step `stopifnot(file.exists(DB_PATH))` would fail. The "reproducible pipeline" claim is undermined.
*Fix:* Add `submodules: recursive` to checkout, add Python setup step, add `setup.sh` before the R pipeline.

**3. Velocity computation duplicated in 3 places with drift risk**
The same 4-week/12-week velocity rollup from raw scan data is computed independently in `R/06_excel_workbook.R` (lines 60–108), `quarto/dashboard.qmd` (lines 71–119), and partially in `R/02_build_frames.R`. The dashboard even acknowledges this: "Mirrors the canonical computation so dashboard and workbook always agree." If they drift, the portfolio piece shows inconsistent numbers.
*Fix:* Compute velocity once in `02_build_frames.R` as a canonical frame. Both consumers read the pre-built RDS.

**4. `dollar_short` formatting function duplicated 4x with subtle inconsistencies**
Defined in `R/00_theme.R` (as `fmt_dollar_short`), `R/05_supporting_charts.R`, `quarto/dashboard.qmd`, and `shiny/app.R` — each with slightly different implementations. The theme version has `abs()` guards; others don't. The Shiny version uses `vapply` (different behavior entirely).
*Fix:* Canonical version in `00_theme.R`. All scripts that source it use `fmt_dollar_short` directly. Shiny copies the canonical implementation verbatim.

**5. Color palette divergence in supporting charts**
`R/05_supporting_charts.R` lines 51–61 shadow the canonical palettes from `00_theme.R` with different hex values. The file also defines a `theme_audit()` alias used 12 times instead of the canonical `theme_cinderhaven()`.
*Fix:* Delete shadow palettes. Replace `theme_audit()` calls with `theme_cinderhaven()`.

**6. 18 dev/diagnostic scripts with hardcoded personal paths tracked in git**
All `R/_*.R` files, `inspect_db.py`, and `working/` contain `C:/Users/mssha/OneDrive/Desktop/...`. Exposes username and directory structure in a public repo. Signals incomplete cleanup for publication.
*Fix:* Add `R/_*`, `working/`, `inspect_db.py` to `.gitignore` and `git rm --cached`.

### Tier 2 — Should Fix (real improvements, moderate leverage)

**7. Stale duplicate `dashboard.qmd` at project root**
Two copies exist: root `dashboard.qmd` and `quarto/dashboard.qmd`. They differ only in column-width styling. The pipeline renders the quarto/ copy. The root copy is stale.
*Fix:* Delete root `dashboard.qmd`.

**8. No error handling or assertions in pipeline**
`run_all.R` runs all scripts via `source()` with no `tryCatch`. If `02_build_frames.R` produces a zero-row frame due to a key mismatch, all downstream scripts proceed on corrupted data silently. `03_verify.R` prints diagnostics but never halts the pipeline.
*Fix:* Add `stopifnot(nrow(...) > 0)` after each frame in `02_build_frames.R`. Wrap `source()` calls in `tryCatch` in `run_all.R`.

**9. Quarto renders report.qmd twice (HTML + PDF separately)**
`run_all.R` calls `quarto render report.qmd --to html` then `quarto render report.qmd --to pdf`, re-evaluating all R chunks both times. The three independent PDFs (tearsheet, compliance_timeline, scorecard) also render sequentially.
*Fix:* Single `quarto render report.qmd` for both formats. Parallelize the three independent PDF renders. Enable `freeze: auto` in `_quarto.yml`.

**10. Planning/prose docs clutter the root directory**
Six markdown files (`cinderhaven_full_report_prose_v2.md`, `executive_tearsheet_prose.md`, `excel_workbook_content.md`, `phase7_shareable_artifacts_content.md`, `phase8_writing_deliverables.md`, `quarto_report_scope_final.md`) are build scaffolding, not documentation. They create noise at root level.
*Fix:* Move to `docs/process/` to preserve the collaboration methodology story, or gitignore them.

**11. `.gitignore` missing sensitive file patterns**
No rules for `.env`, `.Renviron`, `*.pem`, `*.key`, `credentials*`. A contributor creating a `.Renviron` with API keys would have it staged by default.
*Fix:* Add `.env`, `.env.*`, `.Renviron`, `*.pem`, `*.key`, `credentials*` to `.gitignore`.

**12. README companion artifact links are placeholders**
Four "[link]" / "[GitHub link]" / "[link when deployed]" entries. Worse than omitting the section — looks unfinished.
*Fix:* Populate real URLs or remove the section until ready.

**13. `read_p` helper duplicated 9 times**
Same frame-reading one-liner defined independently in every consuming script with slightly different directory variables.
*Fix:* Move into `00_theme.R` (already the shared utility module).

**14. `setup.sh` is bash-only; no Windows note**
Project was developed on Windows but `setup.sh` uses bash constructs. README presents it without platform caveats.
*Fix:* Add "requires bash — on Windows use WSL or Git Bash" note.

### Tier 3 — Nice to Have (scalability prep, polish)

**15. `rowwise()` anti-patterns in `02_build_frames.R`** — Three places use `rowwise()` where vectorized operations would work. Negligible at 90 SKUs, would degrade at scale.

**16. `03_verify.R` is a gate that doesn't gate** — Prints diagnostics but never halts execution on failure.

**17. GitHub Actions missing explicit `permissions:` block** — No vulnerability, but least-privilege hardening would add `permissions: contents: read`.

**18. `price_history` table loaded but never used** — Carried through every load of `raw_tables.rds` for no purpose.

**19. README directory tree doesn't match actual file listing** — Missing `index.html`, root `dashboard.qmd`, `working/`, underscore scripts, `.nojekyll`.

### Strengths Confirmed

- **Excellent code documentation** — GTIN validation rationale, per-defect effort estimates, frame section headers. Code reads like it was written to be reviewed.
- **Strong README** — Serves both technical reviewers and potential clients. "Why Quarto over Jupyter" demonstrates decision-making.
- **`data_generation_log.md` is outstanding** — Every intentional defect tied to real-world patterns. Demonstrates deep domain expertise.
- **Clean architecture** — Acyclic dependency graph, RDS interface between scripts, no circular dependencies.
- **No security vulnerabilities** — No secrets, no injection vectors in main pipeline, Shiny input validation is correct.
- **Sound data flow** — Load once, build canonical frames, consume from disk. Idempotent pipeline.

---

## Phase 3: Landscape Scan

### Comparable Projects Reviewed

| # | Project | Type | Stack | Stars | Artifacts | Audience |
|---|---------|------|-------|-------|-----------|----------|
| 1 | [OHDSI/DataQualityDashboard](https://github.com/OHDSI/DataQualityDashboard) | R package — systematic data quality checks against medical databases | R, Shiny, JS | 176 | Shiny dashboard, JSON results | Data engineers, researchers |
| 2 | [Divine-Ezennia/Online-Retail-Behavioral-Analysis](https://github.com/Divine-Ezennia/Online-Retail-Behavioral-Analysis) | End-to-end R retail analytics with RFM segmentation and CLV modeling | R, Tableau | 0 | Executive report, visualizations, RDS artifacts | Business strategists |
| 3 | [rstudio/demo-co-quarto-report](https://github.com/rstudio/demo-co-quarto-report) | Official Posit demo — parameterized customer churn report | R, Quarto, Posit Connect | — | HTML + PDF report (parameterized) | Report builders (template) |
| 4 | [AaronGullickson/research-template](https://github.com/AaronGullickson/research-template) | Quarto research project template with reproducibility conventions | R, Quarto | — | Paper, presentation, research log | Academics |
| 5 | [Thomas Cottrell Portfolio](https://tcottrell321.github.io/Data-Analytics-Portfolio/) | Breadth portfolio — 6 projects across SQL, Python, Excel, Tableau, ML | Mixed | — | Excel, SQL reports, ML models, Tableau dashboards | Hiring managers |
| 6 | [datakaveri/data-quality-assessment](https://github.com/datakaveri/data-quality-assessment) | Python IoT data quality tool with 6 quantitative metrics | Python | 4 | PDF reports, JSON data, plots | Smart city engineers |
| 7 | [RAVI-CHANDRIKA-05/F&B-Industry-Analysis](https://github.com/RAVI-CHANDRIKA-05/Whats-Trending-in-the-Food-Beverage-Industry) | CPG food & beverage trend analysis | Python, Power BI | — | Power BI dashboard, analysis | Brand managers |

### Feature Matrix

| Dimension | Cinderhaven | OHDSI DQD | Retail-Behavioral | Posit Demo | Research Template | Cottrell Portfolio | datakaveri |
|-----------|:-----------:|:---------:|:------------------:|:----------:|:-----------------:|:------------------:|:----------:|
| Multi-artifact pipeline | **5+ types** | 1 (dashboard) | 3 | 2 (HTML+PDF) | 2 (paper+slides) | 6 separate projects | 2 (PDF+JSON) |
| CEO/board-level framing | **Yes** | No | Partial | No | No | Partial | No |
| Business cost quantification | **$361K/yr** | No | Segment values | No | No | Yes ($15.7B claim) | No |
| Interactive + print outputs | **Both** | Interactive only | Static + Tableau | Both | Static | Mixed | Static |
| Reproducible from one command | **Yes** | Yes (R package) | No setup docs | Yes | Yes | No (separate projects) | Yes |
| Synthetic data with methodology | **Documented** | No demo data | Real data | Bundled (no docs) | Varies | Real data | Sample data |
| Domain-specific depth | **Retail/CPG** | Healthcare | E-commerce | Generic | Generic | Mixed | IoT |
| CI/CD pipeline | Exists (broken) | Yes (R-CMD-check) | Posit Connect | No | No | No | No |
| Shiny/interactive tool | **Calculator app** | Dashboard | No | No | No | No | No |
| Excel workbook generation | **8 tabs** | No | No | No | No | Excel analysis | No |
| Custom visual theme | **Yes** | Yes | Yes | Yes (branded) | No | No | No |
| Dependency management | renv | R package | Not documented | renv | check_packages.R | N/A | requirements.txt |

### Competitive Position

**Where Cinderhaven is clearly better:**

1. **Multi-artifact depth is unmatched.** No comparable project produces 5+ distinct deliverable types (HTML report, PDF report, interactive dashboard, Excel workbook, Shiny app, compliance timeline, scorecard) from a single pipeline. Most projects produce 1-2 output types.

2. **CEO audience framing is rare.** Almost all data portfolio projects target hiring managers or technical reviewers. Cinderhaven explicitly targets C-suite at $10M-$100M companies. The cost quantification ($361K/yr), the "Monday Morning Dashboard" concept, and the broker intake checklist are consulting deliverables, not academic exercises.

3. **Synthetic data methodology is a differentiator.** `data_generation_log.md` documents every intentional defect tied to real-world patterns. No other comparable project documents why their data looks the way it does. This demonstrates domain expertise in a way that using a Kaggle dataset never can.

4. **"Why Quarto over Jupyter" section** demonstrates decision-making ability. No comparable project explains its tech stack choices to a non-technical audience.

5. **Code reads like it was written to be reviewed.** The GTIN validation rationale, per-defect effort estimates, and frame documentation are well above the portfolio norm. Most comparable projects have minimal or no inline documentation.

**Where Cinderhaven is behind or equal:**

1. **OHDSI DQD has real community traction** (176 stars, 106 forks, 29 releases). Cinderhaven is a solo portfolio piece — it demonstrates capability but not adoption.

2. **Posit's demo-co report has parameterized rendering** — one source generates reports for different product types. Cinderhaven's pipeline is not parameterized; it generates one company's audit. This is a missed opportunity to show the methodology is reusable.

3. **No live demo.** The Shiny app exists but isn't deployed. The dashboard is static HTML, not hosted. OHDSI has a live demo. Several portfolio projects have deployed Tableau Public dashboards or Shiny apps on shinyapps.io.

4. **CI is broken** (as found in Phase 2). OHDSI has R-CMD-check with codecov. The "reproducible pipeline" claim rings hollow if CI fails.

5. **Git hygiene issues** (1,700+ tracked generated files, dev scripts with personal paths) would be visible to any technical reviewer who clones the repo. The Posit demo and research template repos are clean.

**Gaps — features no comparable project has either:**

1. **No comparable project combines data quality assessment with business cost modeling.** OHDSI checks data quality but doesn't quantify the business impact. datakaveri scores quality but doesn't tie it to revenue. Cinderhaven's fix-ROI triage (chargebacks + time-to-shelf + deauth risk) is genuinely novel as a portfolio piece.

2. **No comparable project produces an Excel workbook as a deliverable.** This is a practical consulting touch — CEOs work in Excel, not Shiny dashboards. The 8-tab workbook with data dictionary and broker checklist shows understanding of how deliverables actually get used.

### Positioning Summary

Cinderhaven occupies a unique niche: **consulting-grade analytical deliverable, not a data science exercise.** The closest competitors are either tools (OHDSI DQD) or academic templates (research-template), not consulting case studies. The breadth portfolios (Cottrell, etc.) show range but not depth.

**The project's moat is the combination of:**
- Domain-specific depth (retail product data, not generic)
- Business cost quantification (not just "insights")
- Multiple deliverable types from one pipeline
- CEO-audience framing throughout

**The project's vulnerabilities are:**
- No live demo or deployment
- Broken CI undermines reproducibility claim
- Git hygiene issues visible to technical reviewers
- Not parameterized for reuse across companies

---

## Phase 4: Synthesis & Next Moves

### Prioritization Logic

Each move is scored by: **(internal severity) x (landscape leverage)**. A fix that addresses a Phase 2 Tier 1 issue AND closes a competitive gap ranks highest. A Phase 2 Tier 3 issue with no landscape relevance ranks lowest.

The project's moat is "consulting-grade precision from a reproducible pipeline." Every move should either **protect** that moat (fix inconsistencies, prove reproducibility) or **extend** it (deploy, parameterize, differentiate further).

### Ranked Moves

#### Move 1: Git Cleanup Sprint
**Effort:** 1-2 hours | **Impact:** Highest | **Fixes:** Phase 2 #1, #6, #11

The single biggest credibility upgrade. A technical reviewer who clones the repo currently sees 1,700+ generated files (including 1,224 binary fonts) and 18 dev scripts with hardcoded personal paths. This is the first thing a hiring manager or potential client's CTO notices.

- Add `.gitignore` rules for `output/charts/`, `output/*.xlsx`, `output/*.pdf`, `quarto/*.html`, `quarto/*.pdf`
- Add `.gitignore` rules for `R/_*`, `working/`, `inspect_db.py`
- Add `.gitignore` rules for `.env`, `.Renviron`, `*.pem`, `*.key`, `credentials*`
- `git rm -r --cached` all newly-ignored tracked files
- Remove stale root-level `dashboard.qmd` (Phase 2 #7)

**Why first:** Zero risk to functionality. Massive improvement to first impression. Unblocks Move 6 (clean root).

#### Move 2: Fix CI Pipeline
**Effort:** 30 minutes | **Impact:** High | **Fixes:** Phase 2 #2; Phase 3 "broken CI" vulnerability

The README claims "everything regenerates from a single command." The CI pipeline should prove it. Currently it fails because it never builds the database.

- Add `submodules: recursive` to the checkout step
- Add Python setup step
- Add `./setup.sh` before `Rscript R/run_all.R`
- Add explicit `permissions: contents: read` (Phase 2 #17)

**Why second:** Cheap fix, high credibility return. A green CI badge is proof of reproducibility.

#### Move 3: Consolidate Duplicated Code
**Effort:** 2-3 hours | **Impact:** High | **Fixes:** Phase 2 #3, #4, #5, #13; protects "consulting-grade precision" moat

The project's credibility rests on consistent numbers across all 5+ artifacts. Three duplication clusters create drift risk:

**3a. Velocity frame** — Compute once in `02_build_frames.R`, persist as RDS. Delete the 50-line velocity computation from `06_excel_workbook.R` and `dashboard.qmd`. Both read the pre-built frame instead.

**3b. `dollar_short` function** — Canonical version is `fmt_dollar_short` in `00_theme.R`. Delete the copies in `05_supporting_charts.R`, `dashboard.qmd`. Update Shiny app to copy canonical implementation with origin comment.

**3c. Color palettes** — Delete shadow palettes in `05_supporting_charts.R` lines 51-61. Replace 12 `theme_audit()` calls with `theme_cinderhaven()`.

**3d. `read_p` helper** — Move into `00_theme.R`. Delete 9 copies across consuming scripts.

**Why third:** Protects the moat. If dashboard and Excel workbook ever show different numbers, the "consulting-grade" claim collapses.

#### Move 4: Add Pipeline Assertions
**Effort:** 1 hour | **Impact:** Medium | **Fixes:** Phase 2 #8, #16

Demonstrates engineering discipline. A reviewer who sees `stopifnot(nrow(sku_master_full) > 0)` knows the author thinks about failure modes.

- Add `stopifnot(nrow(...) > 0)` after each frame computation in `02_build_frames.R`
- Wrap `source()` calls in `tryCatch` in `run_all.R` with clear error messages
- Add critical assertions to `03_verify.R` (quality-chargeback correlation, Pareto check)

#### Move 5: Clean Root Directory & README
**Effort:** 1 hour | **Impact:** Medium | **Fixes:** Phase 2 #10, #12, #14, #19

Polish the front door.

- Move 6 process docs to `docs/process/` (preserves the collaboration methodology story without cluttering root)
- Update README directory tree to match actual structure
- Either populate companion artifact links with real URLs or remove the section entirely
- Add Windows note to setup instructions ("requires bash — use WSL or Git Bash on Windows")

#### Move 6: Deploy Live Demo
**Effort:** 1-2 hours | **Impact:** Medium-High | **Fixes:** Phase 3 "no live demo" vulnerability

The Shiny Data Debt Calculator already works and has an `rsconnect/` config suggesting prior deployment. Deploying it to shinyapps.io and linking from the README turns a code-only portfolio piece into a live product.

- Deploy Shiny calculator to shinyapps.io
- Host dashboard HTML on GitHub Pages (already have `index.html` and `.nojekyll`)
- Update README companion artifacts with live links

#### Move 7: Optimize Quarto Rendering
**Effort:** 30 minutes | **Impact:** Low-Medium | **Fixes:** Phase 2 #9

Developer experience improvement, not portfolio-facing.

- Combine two `report.qmd` renders into one (let Quarto handle both formats)
- Enable `freeze: auto` in `_quarto.yml`
- Parallelize three independent PDF renders (tearsheet, compliance_timeline, scorecard)
- Estimated savings: 45-90 seconds off a 3-5 minute pipeline

#### Move 8 (Stretch): Parameterize the Pipeline
**Effort:** 4-8 hours | **Impact:** High (differentiator) | **Fixes:** Phase 3 "not parameterized" gap

The biggest lift but also the biggest competitive differentiator. Posit's demo-co report generates for multiple product types from one source. Cinderhaven could demonstrate the same: swap in a different company's data, get a different audit.

- Extract company name, SKU count, revenue figures into a config file
- Make report prose template-aware (parameterized Quarto)
- Add a second demo company or a "blank" template mode
- This transforms the project from "a case study I did" to "a reusable consulting tool"

**Defer unless:** you plan to actually use this methodology with real clients.

### Execution Order

```
Session 1 (3-4 hours): Move 1 + Move 2 + Move 5
  → Git cleanup, fix CI, clean root. Ship as one PR: "Publication hygiene."

Session 2 (3-4 hours): Move 3 + Move 4
  → Consolidate code, add assertions. Ship as one PR: "Single source of truth."

Session 3 (1-2 hours): Move 6 + Move 7
  → Deploy demo, optimize renders. Ship as one PR: "Live demo + pipeline optimization."

Session 4 (optional, 4-8 hours): Move 8
  → Parameterize. Ship as separate PR: "Reusable audit methodology."
```

### What NOT to Do

- **Don't rewrite the Shiny app.** It works, it's clean, it's standalone. Deploy it as-is.
- **Don't add more charts.** 23 is already comprehensive. More is not better.
- **Don't switch from R to Python.** R is the right choice for this project (ggplot2, reactable, openxlsx2). The README already explains why.
- **Don't add authentication or user accounts.** This is a portfolio piece, not a SaaS product.
- **Don't optimize the `rowwise()` patterns** unless you're planning to scale past 200 SKUs. At 90 SKUs the performance impact is unmeasurable.
