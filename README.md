# Product Data Readiness Audit — Cinderhaven Provisions

A complete product data health audit for a fictional specialty food company, built as a portfolio piece for a data consulting practice targeting CEOs of growing food brands.

Cinderhaven Provisions is a $25 million specialty food brand with 90 SKUs, 3 product lines, and 4 contracted retailers. The company is fictional. The dataset is synthetic. The methodology, the analytical frameworks, and the deliverables are real. Everything regenerates from a single command.

## Why now

GS1 Sunrise 2027 requires every food brand to re-validate product data for 2D barcodes. FSMA 204 traceability rules are already being enforced by Walmart and Albertsons via contract, ahead of the July 2028 federal deadline. Most specialty food companies don't know which of their SKUs will fail. This audit finds out — and quantifies what dirty data is already costing.

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
- **Postgres** — Cinderhaven Data Platform (9 tables, 1.1M scan data rows)
- **ggplot2** — all charts, custom theme with project color palette
- **plotly** — interactive chart versions in HTML report
- **reactable** — interactive tables in report and dashboard
- **openxlsx2** — Excel workbook generation (8 tabs)
- **R/Shiny** — Data Debt Calculator standalone app
- **renv** — dependency management and reproducibility

## How to reproduce

**Prerequisites:** [R](https://cran.r-project.org/) with RPostgres installed.

```bash
git clone https://github.com/MsShawnP/product-data-health-audit.git
cd product-data-health-audit
cp .Renviron.example .Renviron   # edit DATABASE_URL if not using local Docker
Rscript -e "renv::restore()"
Rscript -e "renv::install('RPostgres')"
Rscript R/run_all.R
```

To run locally, start the shared Docker Postgres from
[refactor-older-cinderhaven-projects](https://github.com/MsShawnP/refactor-older-cinderhaven-projects):

```bash
# In the refactor-older-cinderhaven-projects repo:
docker compose up

# Then in this repo:
Rscript R/run_all.R
```

The R pipeline loads tables from the Cinderhaven Data Platform, builds
all canonical data frames, generates 21 charts, renders the Excel
workbook, and produces the Quarto artifacts. Total R run time:
approximately two minutes.

The Shiny calculator runs separately: `Rscript -e "shiny::runApp('shiny/')"`.

## Running this for a different company

The R pipeline reads company-specific parameters from `config.yml`: database path, output filename prefix, and company name. To reuse this audit methodology for a different company:

1. **Replace `config.yml` values** with the new company's name and output prefix.
2. **Populate a Postgres database** with the same 8-table schema (`product_master`, `sku_costs`, `chargebacks`, `stores`, `distribution_log`, `scan_data`, `promotions`, `retailer_requirements`) and set `DATABASE_URL` in `.Renviron`.
3. **Update Quarto front matter** — title, subtitle, author, and date in `quarto/report.qmd`, `dashboard.qmd`, and `tearsheet.qmd`. These are per-engagement metadata, not auto-generated.
4. **Rewrite report prose** — the body text in the `.qmd` files is written for Cinderhaven's specific findings. New data produces new numbers through the pipeline, but the narrative interpretation is always per-engagement.
5. **Run `Rscript R/run_all.R`** — the pipeline, charts, Excel workbook, and all rendered artifacts rebuild from the new data.

The R scripts, chart logic, Excel workbook structure, and analytical frameworks carry over unchanged. The Shiny Data Debt Calculator is already company-agnostic.

## Directory structure

```
product-data-health-audit/
├── config.yml                           # Company-specific parameters
├── .Renviron.example                    # DATABASE_URL template
├── data/
│   └── (legacy SQLite artifacts gitignored)
├── R/
│   ├── 00_theme.R                       # Custom ggplot2 theme + color palette
│   ├── 01_load_raw.R                    # Load tables from Postgres
│   ├── 02_build_frames.R               # Build all canonical data frames
│   ├── 03_verify.R                      # Distribution verification
│   ├── 04_hero_charts.R                 # 4 hero charts
│   ├── 05_supporting_charts.R           # 17 supporting charts
│   ├── 06_excel_workbook.R              # 8-tab Excel workbook
│   └── run_all.R                        # Pipeline orchestrator
├── quarto/
│   ├── _quarto.yml                      # Quarto project config
│   ├── report.qmd                       # Audit report (HTML + PDF)
│   ├── tearsheet.qmd                    # Executive tearsheet (PDF)
│   ├── dashboard.qmd                    # Monday Morning Dashboard (HTML)
│   ├── compliance_timeline.qmd          # Shareable compliance timeline (PDF)
│   └── scorecard.qmd                    # Shareable scorecard template (PDF)
├── shiny/
│   └── app.R                            # Data Debt Calculator
├── output/                              # All generated (gitignored, rebuilt by pipeline)
│   ├── frames/                          # Canonical .rds data frames
│   ├── charts/                          # All chart PNGs + interactive HTML
│   ├── cinderhaven_audit.xlsx           # Excel workbook
│   ├── compliance_timeline.pdf          # Shareable artifact
│   └── scorecard.pdf                    # Shareable artifact
├── docs/process/                        # Build-process documentation
├── data_generation_log.md               # How the synthetic data was built
├── .github/workflows/render.yml         # CI pipeline
├── renv.lock                            # Dependency snapshot
└── README.md                            # This file
```

## License

MIT — see [LICENSE](LICENSE).
