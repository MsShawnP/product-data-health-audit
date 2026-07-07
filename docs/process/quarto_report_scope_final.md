# Product Data Readiness — Quarto Report Scope (Final)

> **Note on scope drift.** This is the original scope brief.  Two
> sub-deliverables changed in execution:
> (a) the dashboard ships as an interactive HTML dashboard
> (`quarto/dashboard.html`) instead of a `.pbix`; and
> (b) charts 10 and 18 in the chart list are deliberately not
> built — see the methodology appendix in the rendered report for
> the rationale. The body of this brief is preserved unchanged for
> historical reference.

**Project:** Product Data Health Audit — Cinderhaven Provisions
**Deliverable:** Portfolio-grade audit report built in R/Quarto
**Output formats:** HTML (primary, interactive), PDF (secondary, intentionally designed), Excel workbook (CEO's working copy)
**Writing style:** Economist data-analyst — clean prose, plain English, dramatic where earned by the data, every claim tied to specific findings. No hedging when the data is clear. No overclaiming when it's not. Methodology assumptions stated inline at point of claim, not buried in footnotes.
**Fictional company:** Cinderhaven Provisions (~$25M revenue, 50 SKUs, 5 product lines, ~902 stores)
**Audience:** Portfolio piece targeting specialty food CEOs at $10M–$100M scaling into national retail. Secondary audience: technical evaluators (hiring managers, recruiters) assessing data skills.

---

## Data Sources

The full Cinderhaven database — 8 tables spanning original product master data and expanded velocity dataset. The Quarto report joins across both, which is what makes it a business intelligence deliverable rather than a data quality diagnostic.

### Tables

**Original (product data audit):**
- `product_master` (50 rows) — SKU attributes, GTIN, UPC, dimensions, nutritional, governance fields
- `retailer_requirements` (29 rows) — required fields by retailer
- `chargebacks` (464 rows) — 18 months of chargeback history by SKU, retailer, reason

**Expanded (velocity dataset):**
- `stores` (~902 rows) — store-level detail by retailer, region, volume tier
- `distribution_log` (~12,595 rows) — authorization and deauthorization dates by SKU × store
- `sku_costs` (50 rows) — COGS, landed cost, wholesale price, trade spend % by retailer
- `promotions` (~75 rows) — promo events by SKU, retailer, discount depth, duration
- `scan_data` (~1.19M rows) — weekly unit and dollar sales by SKU × store

---

## Report Structure

### 1. The Diagnostic — "10 Signs Your Product Data Will Break Before You Hit $50M"

Universal framing section. No Cinderhaven data. Written so any specialty food CEO recognizes their own company. Each sign gets 2–3 sentences explaining what actually happens operationally. This is the hook that makes the piece work as a portfolio artifact, not just a client deliverable.

### 2. Company Profile — Cinderhaven Provisions

Narrative introduction. ~$25M revenue, 50 SKUs across 5 product lines (Artisan Sauces, Pantry Staples, Specialty Condiments, Dried Goods, Snack Bites), ~902 stores across Walmart, Costco, Whole Foods, Sprouts, Kroger, Regional Group, UNFI, KeHE, DTC. Growth trajectory toward $55M. Written as a story, not a spec sheet.

### 3. TL;DR Tear-Sheet

One-page BLUF for the C-suite. Three numbers:
- Total revenue at risk from data quality issues
- Total margin lost to data-driven chargebacks + lost sales + rework
- Estimated cost of remediation (the 8-week engagement)

This is the page the CEO reads. Everything after it is evidence.

### 4. Revenue-Weighted Data Quality Assessment

Every finding tied to revenue using `scan_data` and `sku_costs`. This is where the Quarto report diverges from the HTML report.

- GTIN/UPC failures with revenue exposure: "These 15 SKUs generated $X in revenue last 12 months. Every dollar is at risk on resubmission."
- Attribute completeness ranked by revenue, not SKU count: "The 29 SKUs missing case dimensions represent $Z in annual sales — X% of the catalog's revenue."
- Data consistency findings (serving size mismatches, weight plausibility failures) tied to specific retailers and stores where those SKUs are selling.

### 5. Data Debt by Product Line

Artisan Sauces vs. Specialty Condiments vs. Pantry Staples. Data quality issues normalized by revenue contribution. Which product line carries the most data debt per dollar of revenue? Narrative explaining where operational discipline broke down — team, process, timing of SKU additions.

### 6. Velocity vs. Data Quality — The Correlation

The question: are the highest-velocity SKUs also the cleanest, or is it the opposite? If the best sellers have the worst data, that's a ticking time bomb. If the worst sellers have the worst data, that's a rationalization conversation. The correlation itself is the insight.

### 7. Retailer Readiness — Framed as Revenue at Risk

Join `product_master` → `retailer_requirements` → `scan_data` → `sku_costs`.

For each retailer: not just "5/50 SKUs would pass Walmart" but "the 45 that wouldn't represent $X in current Walmart revenue exposed to disruption."

For expansion: "35 SKUs have data ready for Walmart submission. Based on velocity at comparable retailers, those represent an estimated $Y in addressable annual revenue blocked by incomplete data."

### 8. True Net Margin by Retailer

The retailer P&L most specialty food brands don't have. Gross revenue → minus trade spend (from `sku_costs`) → minus chargebacks → net contribution by retailer. The CEO thinks they know which retailer is most profitable. This might prove them wrong.

### 9. The Velocity–Data Quality Connection

The section that only exists because the expanded dataset exists.

- Time-to-shelf: SKUs with complete data vs. incomplete data — how many weeks from authorization to first scan?
- Velocity trajectory after launch: do SKUs with data issues show slower Week 1–4 ramp?
- Promotional effectiveness degraded by data: join `promotions` → `scan_data` → `product_master`. Do SKUs with data quality issues show lower promo lift?

Only include findings the data supports. Don't force it.

### 10. Process Debt — Where Data Breaks Down

Data doesn't break itself. Connect `updated_by` source to chargeback rates and data quality scores. "SKUs onboarded via `broker_upload` and `import_script` show 2x the chargeback rate of manually entered SKUs." Show which data entry pathways produce the most downstream damage. This demonstrates understanding of human workflows, not just SQL joins.

### 11. Are New SKUs Entering Cleaner or Dirtier?

Join `distribution_log` authorized dates to data quality scores. If recently authorized SKUs have worse data than older ones, governance is degrading with scale. If they're cleaner, something is working. Only include if the finding is clear.

### 12. Shelf Loss — Deauthorizations Correlated with Data Quality

Using `distribution_log` deauthorization dates. Are SKUs getting dropped from stores? Correlate deauthorizations with data quality scores and chargeback history. If retailers are quietly deauthorizing SKUs that had data issues, that's the most alarming finding in the report: "You didn't just pay a chargeback. You lost the shelf." Only include if the deauthorization data supports a clear pattern.

### 13. Chargeback Analysis — Tied to Margin

- Chargebacks as % of gross margin per SKU, not just raw dollars.
- Chargebacks by retailer as % of net revenue after trade spend.
- Repeat offenders reframed with margin impact.

### 14. Chargeback Concentration

Pareto analysis. Are 10 SKUs responsible for 60% of all chargeback dollars? Are 2 retailers generating 70%? The concentration tells you whether this is a systemic problem or a targeted cleanup sprint.

### 15. The Full Cost Model

Synthesize everything into a single view:
- Direct chargebacks (from data)
- Lost sales from delayed launches (estimated from velocity data at comparable SKUs/retailers, not catalog averages)
- Manual rework hours (estimated, assumptions stated)
- Margin erosion from trade spend on data-impaired SKUs (calculated from `sku_costs`)
- Total cost as % of EBITDA

### 16. Growth Projection — The Combinatorial Explosion

Project current error rates forward against growth targets (50 → 225 SKUs, 6 → 10 retailers). Chargeback scaling curve. Revenue-at-risk scaling curve. Grounded in actual velocity data as baseline.

### 17. The Contrarian Finding

Every good audit surfaces something the reader didn't expect. Explicitly look for one of these:
- A SKU with perfect data quality but terrible velocity (data isn't the problem — the product is)
- A retailer that generates the most chargebacks but is still the most profitable after chargebacks (worth the pain)
- The newest product line has cleaner data than the oldest (something is actually working)
- The highest-margin SKUs have the worst data (premium products got the least operational attention)

Surface whichever one the data supports. Name it. This is the moment the reader realizes the report sees things they can't see on their own.

### 18. Which SKUs to Fix First — Revenue-Weighted Triage

Composite "fix priority score" weighing data quality issues × revenue exposure × chargeback history × retailer breadth × gross margin. The top 10 list changes when you weight by revenue. That's the insight. Interactive table (`reactable` or `DT`) so the reader can re-sort by any axis.

### 19. The "After" Picture

What Cinderhaven looks like post-remediation. Not just projected savings — the operational picture:
- New retailer onboarding timeline drops from X weeks to Y
- 1WorldSync sync rate goes from 19% to 95%+
- Chargebacks decline by ~72%
- Ops team gets 15–20 hours/month back
- Monday velocity report becomes trustworthy — no more manual assembly, no more inconsistent definitions
- Data infrastructure supports growth to $55M without compounding data debt

### 20. Remediation Framework

Four phases, sequenced by the revenue-weighted triage list. Phase 1 fixes ranked by dollar impact:
- Phase 1: Audit + triage (Weeks 1–2)
- Phase 2: Single source of truth (Weeks 3–4)
- Phase 3: Governance + process (Weeks 5–6)
- Phase 4: PIM evaluation + scale planning (Weeks 7–8)

### 21. Benchmarking Context

Industry framing: first-pass item setup success rates, typical GTIN failure rates, 1WorldSync registration norms. Directional, not rigorous — consulting report, not research paper.

### 22. What This Report Does Not Cover

Explicitly scope what's out of bounds: product images/rich media, EDI transaction data, distributor-specific portal requirements beyond the six retailers, Amazon-specific data, food service channel data. Signals judgment about scope boundaries.

### 23. Engagement Options

Not a hard sell. A clearly labeled section describing the productized offering: "Product Data Health Audit" — scope, timeline, deliverables, what the client gets. The prospect reads it and thinks "I should call this person" rather than "I'm being pitched."

### 24. Technical Appendix

- SQL queries used, with links to the GitHub repo
- Reference to the GTIN Validator tool (live)
- Data model overview showing how the 8 tables relate
- Methodology notes for all estimates and projections
- "How I'd Do This Differently With Real Data" — acknowledges the synthetic dataset and explains what changes with real client data (messier joins, partial records, data arriving in 14 different Excel formats, the politics of getting ops to measure case dimensions)
- Note on dataset construction

---

## Charts

No artificial limit on chart count. Include every chart that supports the findings and makes sense for the audit. Charts should earn their place by making a point — if a chart doesn't change the reader's understanding, cut it.

### Hero Charts (in main narrative, interactive via plotly/ggiraph)

1. **Velocity vs. data quality scatterplot** — data quality score (x) vs. annual revenue (y) for all 50 SKUs. Interactive tooltips showing SKU name, revenue, missing attributes on hover.
2. **Chargeback Pareto** — cumulative % of chargeback cost by SKU rank. Shows concentration.
3. **Fix priority bubble matrix** — data quality issues (x) vs. revenue (y), bubble size = chargeback cost.
4. **True net margin by retailer** — waterfall chart: gross revenue → trade spend → chargebacks → net contribution.

### Supporting Charts (include wherever they support findings)

5. Revenue-weighted field completeness (% of revenue affected, not just % of SKUs)
6. Retailer readiness scorecard with revenue at risk per retailer
7. Data debt by product line — issues per dollar of revenue
8. Chargeback cost as % of gross margin by SKU (top 15)
9. Time-to-shelf: data-complete vs. data-incomplete SKUs
10. New vs. old SKU data quality trend (if finding is clear)
11. Deauthorization rate by data quality tier (if finding is clear)
12. Growth projection — chargebacks + revenue-at-risk at 1x, 2x, 3x scale
13. GTIN validation pass/fail by product line
14. Chargeback by reason
15. Monthly chargeback trend
16. Seasonal chargeback overlay with sales volume (if pattern is visible)
17. Data quality by `updated_by` source (process debt visualization)
18. Cost of doing nothing — EBITDA waterfall
19. 1WorldSync status distribution
20. Retailer item setup readiness (stacked bar)
21. Data staleness distribution
22. Serving size variants
23. SKU risk distribution

Add additional charts as findings warrant. The constraint is analytical value, not count.

---

## Excel Workbook Export

A structured workbook the CEO uses every Monday. Not a raw data dump — tabs designed for pivot tables.

### Tabs

1. **Velocity Summary** — SKU × retailer, units/store/week for most recent 4-week and 12-week periods, % change, distribution (store count), data quality flag. This tab replaces his hand-built velocity pivot table.

2. **SKU Master + Data Quality Scores** — one row per SKU, all product master fields, data quality score, issue flags, chargeback totals, annual revenue, gross margin, fix priority score.

3. **Retailer Readiness Matrix** — SKU × retailer grid showing pass/fail for each required field. Filterable to "show me everything that would fail Walmart."

4. **Chargeback Detail** — every chargeback record with SKU, retailer, reason, amount, month. Ready to pivot by any dimension.

5. **Revenue by SKU × Retailer** — aggregated from scan data. Annual revenue, units, store count by SKU by retailer.

6. **Triage List** — fix priority ranking with all scoring dimensions visible so he can re-sort by whatever axis matters.

7. **Data Dictionary** — every column, every score, every flag explained.

Generated programmatically from the same R pipeline via `openxlsx2` or `writexl`. Not a separate manual build.

---

## HTML-Specific Features

- Interactive tooltips on hero charts via `plotly` or `ggiraph`
- Filterable/sortable triage table via `reactable` or `DT`
- Collapsible `<details>` blocks for supporting detail tables and secondary charts
- Cross-references between sections as clickable internal links
- High-res PNG exports of hero charts available alongside interactive versions (for board decks, emails)

---

## PDF Design

Not an afterthought. The PDF version should look intentionally designed:
- Static versions of hero charts (clean, high-res)
- Clean page breaks
- Cover page
- Tables that don't overflow
- Print-friendly color palette

---

## Reproducibility

- `renv.lock` for R package dependencies
- `run_all.R` orchestrator script: one command to regenerate analytical files, render Quarto HTML, render PDF, generate Excel workbook, export chart PNGs
- Clear directory structure: `data/`, `R/`, `output/`, `quarto/`

---

## README.md — Portfolio-Facing "Director's Commentary"

Because this is a portfolio piece, the README explains the craft:
- Why Quarto over Jupyter Notebook
- How the synthetic data was engineered (and what would change with real data)
- How Claude Code was used to accelerate the build
- Technical stack: R, Quarto, SQLite, plotly/ggiraph, reactable, openxlsx2
- How to reproduce: clone → `run_all.R` → done
- Links to companion artifacts: GTIN Validator (live), SQL query library (GitHub), HTML audit report

---

## Separate Deliverables (not in the Quarto report)

- Power BI dashboard (.pbix file)
- Power BI instruction doc with screenshots — standalone document explaining how to open and use the dashboard

---

## Claude Code Execution Phasing

Do not feed this entire scope at once. Build iteratively:

**Phase 1 — Data Prep:** R scripts that connect to SQLite, build the analytical joins across 8 tables, output flat analytical data frames. Verify data distributions (Pareto in chargebacks, realistic missingness patterns, etc.).

**Phase 2 — Hero Charts:** Build the 4 hero charts first (velocity vs. quality scatterplot, chargeback Pareto, fix priority bubble matrix, net margin waterfall). Get these right before moving on.

**Phase 3 — Supporting Charts:** Build remaining charts as needed by section.

**Phase 4 — Narrative Assembly:** `.qmd` structure, prose sections, embed charts. Write section by section.

**Phase 5 — Interactive Elements + Excel:** plotly conversion, reactable tables, collapsible sections, Excel workbook generation.

**Phase 6 — Polish:** PDF stylesheet, cross-references, README, renv, orchestrator script.

---

## What a Real Velocity Report Looks Like (Reference for Writing)

The CEO asks for velocity reports every Monday. His friend pulls data fields from retailer portals and the CEO builds pivot tables by hand. A real velocity report in specialty food CPG shows:

**Core fields:** SKU/UPC, retailer, time period (week ending), units sold, dollar sales, store count (ACV distribution), units per store per week (velocity), dollar sales per store per week.

**Comparisons:** Current vs. prior period, % change in velocity, % change in distribution, category average velocity, rank within category.

**Sophisticated additions:** Baseline vs. promoted velocity, promo flags, out-of-stock rate, price per unit, gross margin per unit.

**Common problems with hand-built velocity reports:**
- Not normalizing for distribution changes (velocity up but stores lost = misleading)
- Not separating promo velocity from baseline (a BOGO spike isn't growth)
- Comparing across retailers without adjusting (Walmart velocity ≠ Whole Foods velocity)
- Not looking at velocity per point of distribution
- Inconsistent definitions across data sources (UNFI weekly, Walmart weekly different calendar, Whole Foods 4-week periods)

The Quarto report should reference velocity naturally where relevant and the Excel export's Velocity Summary tab should be a better version of what the CEO currently builds by hand.
