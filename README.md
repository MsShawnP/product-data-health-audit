# Product Data Readiness Audit — Cinderhaven Provisions

A complete product data health audit for a fictional specialty food company, built as a portfolio piece for a data consulting practice targeting CEOs at $10M to $100M.

Cinderhaven Provisions is a $25 million specialty food brand with 90 SKUs, 3 product lines, and 4 contracted retailers. The company is fictional. The dataset is synthetic. The methodology, the analytical frameworks, and the deliverables are real. Everything regenerates from a single command.

## What this produces

One pipeline generates five artifacts:

1. **Audit report** (Quarto HTML + PDF) — 8-page case study finding $361,000/year in quantifiable cost from product data defects, with a triage list that ranks every SKU by fix priority
2. **Executive tearsheet** (2-page PDF) — board-level summary with three headline numbers and a 14-day turnaround plan
3. **Monday Morning Dashboard** (standalone HTML) — the velocity report, retailer P&L, and triage tracker a CEO currently builds by hand in Excel, rebuilt as an interactive tool
4. **Excel workbook** (8 tabs, .xlsx) — the CEO's working copy with data dictionary and broker intake checklist
5. **Data Debt Calculator** (R/Shiny) — standalone tool for any specialty food brand to estimate their own data debt

Plus two one-page shareable artifacts: a GS1 Sunrise 2027 / FSMA 204 compliance timeline and a product data health scorecard template.

## Why Quarto over Jupyter

Three reasons. First, the primary audience is a CEO who opens an HTML file in a browser, not a data scientist who opens a notebook. Quarto renders to HTML and PDF from the same source without compromises in either format. Jupyter's PDF output requires LaTeX gymnastics that fight the toolchain instead of using it.

Second, the project has five distinct output artifacts with different formats, layouts, and rendering requirements. Quarto's project system handles this natively: one `_quarto.yml`, multiple `.qmd` files, each with its own format config. Jupyter would require a separate export pipeline for each artifact.

Third, R is the right language for this project (ggplot2 for charts, reactable for interactive tables, openxlsx2 for Excel generation, Shiny for the calculator), and Quarto's R integration is native. Jupyter's R kernel works but is a second-class citizen in the Jupyter ecosystem.

## How the synthetic data was engineered

The dataset was designed to mimic real retail product data, including the ways real data breaks. The data generation log (`data_generation_log.md`) documents every intentional defect and the real-world pattern it simulates.

Key design decisions:

- GTIN check digits misaligned on 10% of SKUs to mirror observed human data-entry error rates
- Chargeback concentrations follow a Pareto distribution seeded from real engagement patterns
- OneWorldSync registrations set to 10% complete, reflecting typical mid-market specialty food state
- Serving size strings varied across 14 formats to simulate inconsistent multi-source data entry
- Time-to-shelf modeled with quality-dependent lag producing a 3x spread between worst and best tiers
- Seven distinct data entry sources with different error profiles

With real data, four things would change: chargeback-to-defect linkage would be mechanical (retailers name the failing field), time-to-shelf analysis would include item setup submission dates, promotional lift analysis would be meaningful with proper control-store methodology, and competitive context would exist from category-level scan data. The analytical frameworks in this project are designed to work identically with real data. The numbers change. The structure does not.

## How Claude was used

This project was built using Claude Code for all technical implementation (R scripts, Quarto scaffolding, chart rendering, Excel workbook generation, Shiny app, pipeline orchestration) and Claude Chat for all narrative prose (report text, chart annotations, dashboard headers, data dictionary, compliance timeline content, scorecard content). The division was strict: Claude Code never wrote reader-facing prose, Claude Chat never wrote R code. The user made all structural and editorial decisions.

The collaboration pattern: Claude Chat drafted prose in conversation, the user reviewed and revised, approved text was handed to Claude Code as a file for assembly into the rendering pipeline. Claude Code built the technical infrastructure, reported back on what worked and what needed fixing, and the user directed the next step. Total build time across all phases was approximately two weeks of part-time work.

## Technical stack

- **R** — data prep, analytical frames, charts, workbook generation
- **Quarto** — HTML and PDF rendering for report, tearsheet, dashboard, shareable artifacts
- **SQLite** — source database (164 MB, 9 tables, 1.1M scan data rows)
- **ggplot2** — all charts, custom theme with project color palette
- **plotly** — interactive chart versions in HTML report
- **reactable** — interactive tables in report and dashboard
- **openxlsx2** — Excel workbook generation (8 tabs)
- **R/Shiny** — Data Debt Calculator standalone app
- **renv** — dependency management and reproducibility

## How to reproduce

```bash
git clone https://github.com/MsShawnP/product-data-health-audit
cd product-data-health-audit
Rscript R/run_all.R
```

The pipeline loads the SQLite database, builds all canonical data frames, generates 21 charts, renders the Excel workbook, and produces the Quarto HTML report, PDF report, dashboard, tearsheet, compliance timeline, and scorecard. Total run time: approximately two minutes.

The 165 MB SQLite database (`data/cinderhaven_product_master.db`) is not committed here — it exceeds GitHub's per-file size limit. Regenerate it by cloning [MsShawnP/cinderhaven-data](https://github.com/MsShawnP/cinderhaven-data) and running `python scripts/build_db.py`, then drop the resulting `.db` into `data/` here.

The Shiny calculator runs separately: `Rscript -e "shiny::runApp('shiny/')"`.

## Directory structure

```
product-data-health-audit/
├── data/
│   └── cinderhaven_product_master.db    # Source database
├── R/
│   ├── 00_theme.R                       # Custom ggplot2 theme + color palette
│   ├── 01_load_raw.R                    # Load raw tables from SQLite
│   ├── 02_build_frames.R               # Build all canonical data frames
│   ├── 03_verify.R                      # Distribution verification
│   ├── 04_hero_charts.R                 # 4 hero charts
│   ├── 05_supporting_charts.R           # 17 supporting charts
│   ├── 06_excel_workbook.R              # 8-tab Excel workbook
│   ├── _emit_canonical_numbers.R        # Generate canonical_numbers.md
│   └── run_all.R                        # Pipeline orchestrator
├── quarto/
│   ├── report.qmd                       # Audit report (HTML + PDF)
│   ├── tearsheet.qmd                    # Executive tearsheet (PDF)
│   ├── dashboard.qmd                    # Monday Morning Dashboard (HTML)
│   ├── compliance_timeline.qmd          # Shareable compliance timeline (PDF)
│   ├── scorecard.qmd                    # Shareable scorecard template (PDF)
│   └── _quarto.yml                      # Quarto project config
├── shiny/
│   └── app.R                            # Data Debt Calculator
├── output/
│   ├── frames/                          # Canonical .rds data frames
│   ├── charts/                          # All chart PNGs
│   ├── cinderhaven_audit.xlsx           # Excel workbook
│   ├── canonical_numbers.md             # Single source of truth for all numbers
│   ├── compliance_timeline.pdf          # Shareable artifact
│   └── scorecard.pdf                    # Shareable artifact
├── data_generation_log.md               # How the synthetic data was built
├── cinderhaven_rebuild_plan.md          # Master project spec
├── cinderhaven_full_report_prose_v2.md  # Approved report prose
├── executive_tearsheet_prose.md         # Approved tearsheet prose
├── renv.lock                            # Dependency snapshot
└── README.md                            # This file
```

## Companion artifacts

- **GTIN Validator** — live web tool for validating GS1 barcodes: [link]
- **SQL diagnostic query library** — 53 queries covering every analytical frame: [GitHub link]
- **HTML audit report** — Python-generated fast diagnostic: [GitHub link]
- **Data Debt Calculator** — estimate your own data debt: [link when deployed]

## License

This project is a portfolio piece. The methodology is freely reusable. The Cinderhaven name and dataset are fictional.
