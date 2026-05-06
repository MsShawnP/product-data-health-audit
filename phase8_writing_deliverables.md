# Phase 8: All Writing Deliverables

---

## 1. README.md (Repo-level, director's commentary)

Writing register: Technical but human. Speaking to a developer, hiring manager, or data person.

---

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
git clone <repo-url>
cd product-data-health-audit
Rscript R/run_all.R
```

That's it. The pipeline loads the SQLite database, builds all canonical data frames, generates 21 charts, renders the Excel workbook, and produces the Quarto HTML report, PDF report, dashboard, tearsheet, compliance timeline, and scorecard. Total run time: approximately two minutes.

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

---
---

## 2. Portfolio-page description (short, non-technical)

---

A complete product data health audit for a fictional $25 million specialty food company, demonstrating how dirty product data costs a growing brand $361,000 a year in chargebacks, stalled launches, and lost shelf space, and how 27 hours of data entry fixes nearly all of it. The project produces an interactive HTML report, a two-page executive tearsheet, an operational dashboard, an Excel workbook with triage list and broker intake checklist, and a standalone Data Debt Calculator that any specialty food brand can use to estimate their own exposure. Built with R, Quarto, and SQLite. One command reproduces everything.

[HTML report] · [Monday Dashboard] · [Executive Tearsheet] · [Data Debt Calculator] · [GTIN Validator] · [GitHub]

---
---

## 3. Data Generation Log (data_generation_log.md)

---

# Data Generation Log — Cinderhaven Product Master

This document records how the synthetic dataset was constructed and, more importantly, how it was intentionally broken. Every defect in the Cinderhaven database was placed deliberately to simulate a pattern observed in real retail product data. The purpose is to demonstrate knowledge of what real data looks like in the wild, not just what clean database tables look like.

## Database overview

The Cinderhaven product master database contains 9 tables: product_master (90 rows), sku_costs (90), stores (902), distribution_log (12,507), chargebacks (381), promotions (198), price_history (398), scan_data (1,118,009), and retailer_requirements (29). The database represents a fictional specialty food company at approximately $25 million in trailing twelve-month revenue with 90 SKUs across 3 product lines (Artisan Sauces, Specialty Condiments, Pantry Staples), selling through 4 contracted retailers (Walmart, Costco, UNFI, Whole Foods) across 902 stores.

## Intentional defects and their real-world basis

### GTIN-14 check digit errors

**What was done:** Misaligned the mod-10 check digit on 9 of 90 SKUs (10%).

**Real-world basis:** Human data-entry error rates on numeric fields in product masters typically run 5% to 15%, depending on the entry process and whether any validation exists at point of entry. The most common GTIN error is a transposed or miscalculated check digit, because the check digit is the last field entered and is often typed from memory or from a label that has been photocopied, faxed, or re-keyed from a broker spreadsheet. Most product masters have no check digit validation at entry. The error persists indefinitely because nobody re-validates GTIN fields after initial entry.

**What this enables in the analysis:** The chargeback-to-defect linkage that is the centerpiece of the report. Nine wrong digits generating $53,000 in chargebacks over 18 months, traceable to a specific field in a specific record.

### UPC-12 check digit errors

**What was done:** Misaligned the mod-10 check digit on 3 of 90 SKUs.

**Real-world basis:** Same mechanism as GTIN-14 errors but less common because UPC-12 is the consumer-facing barcode that gets scanned at retail POS. Errors in the UPC are more likely to be caught by in-store scanning during the first week of sales. GTIN-14 errors persist longer because the case-level barcode is scanned at distribution centers where the feedback loop to the vendor is slower.

### Brand owner field: placeholder values

**What was done:** Populated the brand_owner field with the string "NA" on 17 of 90 SKUs.

**Real-world basis:** "NA," "N/A," "TBD," and blank values in text fields are the most common data defect in product masters that accept free-text input without validation. The person entering the SKU didn't know the answer, typed a placeholder, and moved on. Nobody reviewed it. The retailer's system accepted it because the field was not empty. It fails validation when a retailer tightens their required-field rules or when a compliance audit runs against the product master.

### Missing case dimensions

**What was done:** Left case weight, length, width, or height blank on 29 of 90 SKUs (32%).

**Real-world basis:** Case dimensions require physical measurement of the actual product. Unlike text fields that can be typed from a specification sheet, dimensions require someone to pull a case from inventory, put it on a scale, and measure it with a tape. This step is skipped more often than any other because it requires physical access to inventory and because the person entering the data may not have access to a warehouse. The 32% rate mirrors the typical state of a mid-market company that has populated dimensions for products that have gone through a full retailer onboarding process but not for products that were added to the master through informal channels.

### Implausible case weights

**What was done:** Set case weights to values outside a plausible range (too high, too low, or zero) on a subset of SKUs.

**Real-world basis:** When case weights are populated, they are sometimes entered in the wrong unit (pounds instead of kilograms or vice versa), copied from the wrong product, or defaulted to zero by an import script that treats null as zero. These values pass a "field is not blank" check but fail a plausibility check, triggering dimension mismatch chargebacks when the warehouse receives a case that doesn't match the record.

### OneWorldSync registration status

**What was done:** Set 81 of 90 SKUs (90%) to "Not Registered" or "Registered - Incomplete." Only 9 SKUs are "Registered - Complete."

**Real-world basis:** OneWorldSync (1WorldSync) registration is the mechanism for synchronizing product data with retailers via the Global Data Synchronization Network (GDSN). Mid-market specialty food companies typically begin the registration process when a major retailer requires it but do not prioritize completing it across the full catalog. A 10% completion rate is typical for a company at Cinderhaven's scale that has registered its top sellers for one retailer but has not extended the process catalog-wide.

### Serving size format inconsistency

**What was done:** Varied serving size strings across 14 different formats (e.g., "2 tbsp (30 mL)," "30ml," "2 tablespoons," "30 milliliters," "2T").

**Real-world basis:** Serving size is entered as a free-text field in most product masters. Different people enter it differently. Brokers copy it from the product label, which may use abbreviated or non-standard notation. Import scripts may strip or reformat units. The result is a field that contains the correct information in an inconsistent format, making it impossible to validate, compare, or aggregate programmatically without normalization.

### Chargeback concentration (Pareto distribution)

**What was done:** Seeded chargeback event counts and dollar amounts to follow a Pareto distribution: 5 SKUs generate 50% of chargeback dollars, 15 generate 80%, and 40 of 90 SKUs have zero chargebacks.

**Real-world basis:** Chargeback distributions in real retail are consistently Pareto-shaped. A small number of SKUs, typically those with multiple overlapping data defects, generate a disproportionate share of chargeback dollars. The 80/20 pattern (or steeper) is the most commonly observed distribution in chargeback analysis across CPG categories.

### Chargeback assignment logic

**What was done:** Assigned chargebacks only to SKU/retailer pairs with active distribution authorizations, weighted by data quality score (lower quality = more chargebacks), with lognormal variance in event dollar amounts.

**Real-world basis:** Chargebacks can only be issued against products that are actually in distribution at a retailer. The weighting by data quality score ensures that the synthetic chargebacks correlate with data defects, which is the pattern observed in real engagements: SKUs with more data defects generate more compliance penalties. The lognormal variance in dollar amounts reflects the fact that real chargeback amounts vary based on the specific retailer, the type of defect, and the volume of product involved.

### Time-to-shelf quality-dependent lag

**What was done:** Modeled the gap between store authorization date and first scan date with a quality-dependent delay. SKUs with lower data quality scores receive longer delays, calibrated to produce a roughly 3x spread between the worst and best quality tiers (32 days vs. 10 days).

**Real-world basis:** In real retail, the time between a buyer authorizing a product and that product generating its first sale is largely determined by how quickly the product clears automated validation checks in the retailer's item setup system. Products with valid GTINs, complete case dimensions, and registered data pool records clear in days. Products with data defects enter manual review queues, generate correction requests back to the vendor, and wait for resubmission. The 3x spread is conservative. In some retailer systems, a single missing field can add 4 to 6 weeks to the setup process.

### Deauthorization rate by quality tier

**What was done:** Set deauthorization rates to correlate with data quality: bottom-half SKUs lose authorizations at approximately 4.5x the rate of top-half SKUs.

**Real-world basis:** Retailers periodically review product performance and compliance. Products that generate repeated chargebacks, have unresolved data defects, or fail periodic compliance audits are more likely to be removed from store planograms. The correlation between data quality and deauthorization is real but confounded by other factors (poor velocity, category rationalization, planogram resets). The synthetic data isolates the data quality signal by controlling for other variables.

### Data entry source distribution

**What was done:** Assigned each SKU to one of seven data entry sources (broker_upload, production_admin, inventory_admin, import_script, quality_mgr, ops_coordinator, or unknown), with different error profiles per source.

**Real-world basis:** Product masters at mid-market companies are populated through multiple channels, each with different levels of data quality. Broker uploads tend to be lower quality because brokers are entering data for dozens of brands simultaneously with no brand-specific validation. Production admin entries tend to be higher quality because the person entering the data is closer to the product and treats data entry as a primary task rather than a side task. The "unknown" source (9 SKUs with no recorded entry source) represents the common real-world gap where records exist in the product master with no audit trail of who entered them or when.

### Promotional data

**What was done:** Generated 198 promotions across the observation window. Most do not have sufficient pre-promotion scan history to compute lift cleanly. Across computable promotions, median lift is approximately flat (-0.8%), mean lift is 3.0%.

**Real-world basis:** Promotional effectiveness data in real retail is notoriously noisy. Most mid-market specialty food companies cannot isolate promotional lift because they lack control-store methodology, pre-promotion baseline measurement, and consistent promotional calendars. The near-flat median lift is intentional: it reflects the reality that many promotions at this scale do not produce measurable incremental volume, especially when promotional execution varies by store and when the product's baseline velocity is low enough that promotional lift is hard to distinguish from normal variance.

## What the synthetic data cannot do

The synthetic data is designed to support the analytical frameworks in this audit. It cannot fully replicate three aspects of real retail data:

1. **Seasonality.** Real scan data has seasonal patterns (holiday peaks, summer slowdowns) that affect velocity, promotional planning, and chargeback timing. The synthetic data has no meaningful seasonal signal.

2. **Competitive dynamics.** Real category data includes competitor products, market share, and competitive displacement when a SKU loses shelf space. The synthetic data contains only Cinderhaven products.

3. **Retailer system behavior.** Real retailer systems have idiosyncratic validation rules, timing delays, and exception handling that vary by retailer and change over time. The synthetic data applies uniform logic across all retailers, varying only the required-field sets.

These limitations are documented in the report's "How I'd Do This Differently With Real Data" appendix section.
