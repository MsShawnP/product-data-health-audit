# Product Data Readiness Audit — Cinderhaven Provisions

A complete product data health audit for a specialty food brand — one pipeline, one command, five executive-ready deliverables that quantify what dirty product data is already costing.

**Live:** https://audit.lailarallc.com · Data Debt Calculator → https://calculator.lailarallc.com

Cinderhaven Provisions is a fictional $34M specialty food brand with 50 SKUs, 5 product lines, and 6 contracted retailers. The company is fictional. The dataset is synthetic. The methodology, the analytical frameworks, and the deliverables are real. Everything regenerates from a single command.

## What it does

One R pipeline generates five artifacts:

1. **Audit report** (Quarto HTML + PDF) — 8-page case study finding $93,000 a year in retailer chargebacks traced directly to product data defects, with a triage list that ranks every SKU by fix priority
2. **Executive tearsheet** (2-page PDF) — board-level summary with three headline numbers and a 14-day turnaround plan
3. **Monday Morning Dashboard** (standalone HTML) — the velocity report, retailer P&L, and triage tracker a CEO currently builds by hand in Excel, rebuilt as an interactive tool
4. **Excel workbook** (8 tabs, .xlsx) — the CEO's working copy with data dictionary and broker intake checklist
5. **Data Debt Calculator** (R/Shiny) — standalone tool for any specialty food brand to estimate their own data debt

Plus two one-page shareable artifacts: a GS1 Sunrise 2027 / FSMA 204 compliance timeline and a product data health scorecard template.

## Why it matters

GS1 Sunrise 2027 requires every food brand to re-validate product data for 2D barcodes — the deadline is confirmed with no extension. But the federal timeline is already beside the point: Walmart began enforcing FSMA 204-style traceability requirements on August 1, 2025. Kroger's deadline passed June 30, 2025. Over 70 retailers have announced their own traceability programs, and nearly half require compliance for all foods — not just the FDA's Food Traceability List.

Most specialty food companies don't know which of their SKUs will fail these requirements — or that dirty product data is already a recurring line item on their remittances. This audit finds out, quantifies the cost, and ranks the fixes.

## Quick start

**Prerequisites:** [R](https://cran.r-project.org/) and [Quarto](https://quarto.org/docs/get-started/).

```bash
git clone https://github.com/MsShawnP/product-data-health-audit.git
cd product-data-health-audit
Rscript -e "renv::restore()"
Rscript R/run_all.R
```

No database required. The repository includes a cached snapshot of all source data (`output/frames/raw_tables.rds`). When `DATABASE_URL` is not set, the pipeline builds everything from this cache: all canonical data frames, 21 charts, the 8-tab Excel workbook, and the Quarto artifacts. Total run time is approximately two minutes.

The Shiny calculator runs separately: `Rscript -e "shiny::runApp('shiny/')"`.

**Refreshing source data** from the Cinderhaven Data Platform (Postgres):

```bash
flyctl proxy 5434 -a cinderhaven-db          # in another terminal
POSTGRES_PASSWORD=... python scripts/export_from_postgres.py
Rscript R/run_all.R
```

The export script runs mart-level transformations and writes `data/cinderhaven_product_master.db` (SQLite); the R pipeline detects it and refreshes the cache. Alternatively, set `DATABASE_URL` in `.Renviron` to connect the R pipeline directly to Postgres marts.

## Tech stack

- **R** — data prep, analytical frames, charts, workbook generation
- **Quarto** — HTML and PDF rendering for report, tearsheet, dashboard, shareable artifacts (chosen over Jupyter for native multi-format, multi-artifact rendering and first-class R support)
- **Postgres** — Cinderhaven Data Platform (1.4M scan data rows, 2,873 chargebacks; optional — SQLite snapshot included)
- **ggplot2 / plotly / reactable** — static charts, interactive charts, interactive tables
- **openxlsx2** — Excel workbook generation
- **R/Shiny** — Data Debt Calculator standalone app
- **renv** — dependency management and reproducibility

## How the synthetic data was engineered

The dataset mimics real retail product data, including the ways real data breaks. `data_generation_log.md` documents every intentional defect and the real-world pattern it simulates. Key decisions:

- GTIN-14 check digits invalid on ~24% of SKUs (GS1-compliant computation with stochastic corruption)
- Chargeback concentrations follow a quality-weighted Pareto distribution: the worst-quality 10% of SKUs carry 49% of chargeback dollars
- Field missingness at controlled rates: case dimensions 10–18%, weights 6%, country of origin 2%
- Serving size strings varied across 14 formats to simulate inconsistent multi-source entry

With real data the frameworks work identically; chargeback-to-defect linkage would become mechanical because retailers name the failing field.

## Running this for a different company

The pipeline reads company-specific parameters from `config.yml`. To reuse the methodology: replace the `config.yml` values, populate a Postgres database with the same raw schema, update the Quarto front matter (title/author/date in the `.qmd` files), rewrite the report prose for the new findings, and run `Rscript R/run_all.R`. The R scripts, chart logic, workbook structure, and analytical frameworks carry over unchanged. The Shiny calculator is already company-agnostic.

## Project structure

```
config.yml                       Company-specific parameters
scripts/export_from_postgres.py  Postgres → SQLite export with mart transforms
data/                            SQLite snapshot (gitignored)
R/                               00_theme → 06_excel_workbook pipeline + run_all.R orchestrator
quarto/                          report.qmd, tearsheet.qmd, dashboard.qmd, shareable artifacts
shiny/app.R                      Data Debt Calculator
output/                          All generated artifacts (gitignored, rebuilt by pipeline)
data_generation_log.md           How the synthetic data was built
renv.lock                        Dependency snapshot
```

## How Claude was used

Claude Code handled all technical implementation (R scripts, Quarto scaffolding, charts, Excel generation, Shiny app, orchestration); Claude Chat drafted all reader-facing prose. The division was strict, and the user made all structural and editorial decisions. Total build time: approximately two weeks of part-time work.

## License

MIT — see [LICENSE](LICENSE).
