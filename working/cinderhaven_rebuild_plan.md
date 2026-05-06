# Cinderhaven Product Data Readiness — Complete Rebuild Plan

**Created:** May 3, 2026
**Purpose:** Master plan for rebuilding the Product Data Readiness case study from scratch. Covers all artifacts, build phases, quality standards, and the division of labor between Claude Code (builds) and Claude Chat (writes narrative).

---

## What This Project Is

A portfolio piece for a data consulting practice targeting specialty food CEOs at $10M–$100M scaling into national retail. The fictional company is Cinderhaven Provisions (~$25M revenue, 90 SKUs, 3 product lines, ~902 stores). The dataset is synthetic; the methodology is real.

**The thesis:** Product data quality isn't a back-office hygiene problem — it's a revenue multiplier that determines how fast SKUs reach the shelf, how much promotions return, and whether you keep the slots you already have. At Cinderhaven's scale, the gap between clean data and dirty data is $371k per year. At the growth target, it's over $600k. And in 18 months, the entire retail industry transitions to 2D barcodes that require clean GTINs as the foundation — a company that can't handle a 12-digit UPC will fail a GS1 Digital Link QR code.

**The audience:**
- Primary: Specialty food CEOs at $10M–$100M who love data and Excel but are not data scientists
- Secondary: Technical evaluators (hiring managers, recruiters) assessing data and consulting skills

**What this is NOT:**
- Not a sales brochure. No pricing anywhere. No "engagement options." No "$48k for 8 weeks."
- Not an academic paper. No Spearman coefficients, no p-values, no statistical jargon in any reader-facing text.
- Not a chart gallery. Every visualization answers "so what?" and connects to a decision the reader needs to make.

---

## The Quality Standard

**Every finding must answer three questions:**
1. How much is this costing me? (dollars, not percentages — percentages are for context)
2. Why is it happening? (root cause, not symptom)
3. What do I fix first, and what happens when I do? (action, not observation)

If a chart or a paragraph doesn't answer at least one of those three, it gets cut or reframed until it does.

**"Actionable" means the reader knows what to do Monday morning after reading each section.** Not "data quality needs improvement." Instead: "These 9 SKUs have invalid GTINs. Fixing the check digits takes 2 hours. That eliminates 53% of your chargeback dollars. Here are the 9 SKUs by name."

**Writing style:** Economist data-analyst. Clean prose, plain English. Dramatic language is allowed when earned by the data. Every conclusion backed by specific findings. Methodology assumptions stated inline at point of claim. No hedging when the data is clear. No overclaiming when it's not. No jargon: no "Spearman rho," no "n=90," no "P75," no quartile labels (use "Worst 25%," "Best 25%"). Stats live in the R code and in the methodology appendix, never in prose or chart labels.

---

## The Five Artifacts

All generated from one R/Quarto pipeline. One `run_all.R` command regenerates everything.

### Artifact 1 — The Audit Report (HTML primary, PDF secondary)

The flagship case study. 8–10 pages of core narrative with collapsible appendix sections in HTML.

### Artifact 2 — The Executive Tearsheet (PDF only, 2 pages)

A separate document for a different moment — what gets emailed to a board member or printed for a meeting.

### Artifact 3 — The Monday Morning Dashboard (HTML, separate Quarto doc)

The velocity report the CEO currently builds by hand, rebuilt as a working interactive tool.

### Artifact 4 — The Excel Workbook

Seven tabs, generated programmatically. The CEO's working copy. Includes the broker intake checklist as a tab.

### Artifact 5 — Data Debt Calculator (R/Shiny, deployed)

Standalone interactive tool. Not Cinderhaven-specific — any specialty food brand can use it.

---

## Artifact 1: The Audit Report — Detailed Structure

### Part 1: The Money (pages 1–3)

Lead with dollars. Every finding framed as cost or revenue opportunity.

**The cost story (the stick):**

- **Chargeback concentration.** 8 SKUs drive 50% of chargeback dollars. 19 SKUs drive 80%. 27 of 90 SKUs have zero chargebacks — this is a 19-SKU problem, not a catalog-wide problem. Chart: Pareto curve with annotations.
- **Revenue at risk from retailer readiness failures.** 50 of 90 SKUs would fail Walmart's required-field check today. Those 50 SKUs carry $18.2M in TTM revenue — 71% of the catalog. Chart: horizontal bar by retailer with revenue-at-risk annotations.
- **Velocity drag.** SKUs with the worst data take 3× longer to reach the shelf (32 days vs. 10 days). Promotional spend on data-impaired SKUs returns less lift. Chart: dot strip plot showing time-to-shelf by quality tier (labeled "Worst 25%," "Below average," "Above average," "Best 25%" — NOT Q1/Q2/Q3/Q4).
- **Shelf loss.** Bottom-half quality SKUs are dropped from stores at 4–5× the rate of top-half SKUs. A chargeback is a fee. A deauthorization is a slot — a slot that gets filled by a competitor and takes 12–24 months to win back. "You didn't just pay a chargeback. You lost the shelf." Chart: deauthorization rate by quality tier (bottom-half vs. top-half framing, NOT quartile labels). Caveat the synthetic data rate honestly; note that real rates are typically higher, which makes the dollar implication worse.
- **Full cost model.** $371k/year in quantifiable annual cost = 12.1% of EBITDA. Four buckets: direct chargebacks ($69k, from data), lost revenue from delayed launches ($234k, estimated with assumptions stated), manual rework ($68k, estimated), trade-spend erosion (not quantified, qualitative flag). Sensitivity ranges provided.
- **The compliance cliff.** GS1 Sunrise 2027: the entire retail industry transitions to 2D barcodes (QR codes built on GS1 Digital Link) by end of 2027. A company that can't handle a 12-digit UPC will fail a GS1 Digital Link QR code. FSMA Rule 204: FDA food traceability requires accurate GTINs as the product identifier backbone. Fixing the product master isn't just about recovering chargebacks — it's the prerequisite for surviving two industry-wide transitions already underway.

**The revenue story (the carrot):**

- **Revenue you could capture.** 35 SKUs have data ready for Walmart submission today. Based on velocity at comparable retailers, those represent an estimated $Y in addressable annual revenue you could begin capturing in 90 days. The 50 that fail are the remediation queue; the 35 that pass are the immediate opportunity.
- **Frame both stories back to back.** The stick (what dirty data costs) and the carrot (what clean data unlocks). The CEO should feel both the pain and the possibility.

**The SKU that should be killed (centerpiece moment):**

- CHP-0082 (Sherry Vinegar – Aged) has a chargeback total of $3,867 against $874 in TTM gross margin — 442.7% of the SKU's gross margin going to chargebacks. Three SKUs in the catalog are losing money on every unit sold once chargebacks are subtracted.
- This is a business strategy recommendation, not a data recommendation. The question isn't how to fix this SKU's data — it's whether this SKU should exist. A data audit that has the guts to recommend killing a product crosses from data work into business strategy. That's what makes this remarkable.
- **Do not bury this.** This finding should land as a distinct narrative beat — a moment where the reader realizes the report sees things they can't see on their own. It is not a bullet point in a list. It gets its own short subsection with its own chart callout (the 442% bar in the chargebacks-as-%-of-margin chart). The prose should be the single most quotable passage in the report.

### Part 2: Why It Happens (pages 4–6)

Three root causes, each with one chart and a clear "so what."

**Root cause 1: Process debt.**
- Broker-uploaded SKUs cost 3.3× more in chargebacks ($2,050/SKU) than production-admin entries ($619/SKU).
- The "so what": here is the one-page intake checklist that would have prevented $26,700 in broker-related chargebacks. It takes 5 minutes to fill out. If your broker won't fill it out, that tells you something about the broker.
- The broker intake checklist is included as a deliverable artifact (tab in the Excel workbook + appendix in the report).
- Chart: process debt by data-entry source.

**Root cause 2: The contrarian finding.**
- The highest-revenue SKUs are the dirtiest, not the cleanest.
- Top 15 SKUs by revenue: mean quality score 66.7. Full catalog mean: 70.0.
- The "so what": do not assume the data work is low priority because the best sellers are fine. The best sellers are not particularly fine. A revenue-weighted triage list is necessary because sorting by quality score alone would mis-rank the catalog.
- The operational explanation: clerical work (case dimensions, GTIN check digits, brand-owner fields) gets allocated by who has time, not by what the SKU is worth. The fix is to put the revenue weight in front of the people doing the clerical work.

**Root cause 3: The retailer margin story.**
- The CEO thinks Walmart is the most profitable retailer. Whole Foods wins on margin density (86.9% net margin vs. 78.4%).
- Costco generates chargebacks at 3× every other retailer's rate (1.15% vs. 0.35%).
- Trade spend dominates the margin story (12.5%–21.3% of gross). Chargebacks are 0.35%–1.15%. But chargebacks are the high-leverage place to act — entirely under the company's operational control, unlike trade spend.
- Chart: waterfall per retailer (gross → trade spend → chargebacks → net contribution).

**Root cause 4: Data debt is concentrated in one product line.**
- Pantry Staples carries the most data debt per dollar of revenue: 11.3 issues per $1M vs. 6.67 for Artisan Sauces. Chargebacks per $1M confirm it: $4,318 (Pantry Staples) vs. $3,712 (Artisan Sauces).
- The "so what": Pantry Staples and Specialty Condiments should be treated as one remediation tier. Artisan Sauces is doing something materially different — interview that team during remediation, because their playbook is the closest thing to a working internal model.
- Chart: issues per $1M revenue by product line.

### Part 3: What to Do About It (pages 7–8)

**Fix ROI analysis.** Ranking fixes by chargeback savings per hour of effort. Fixing GTIN check digits: 2 hours of work, eliminates 53% of chargeback dollars ($14,114 saved per hour of effort). This is the chart that makes the reader think "why haven't we done this already?"

**The "still broken today" reconciliation.** Linking each active chargeback to a specific field that's still missing right now. "You're paying this chargeback because this field is still blank. Fill it in. The chargeback stops." With specific SKU names and specific missing fields.

**Revenue-weighted triage list.** Interactive reactable — sortable, filterable, all 90 SKUs. Composite score weights: revenue rank (40%), quality rank (30%), chargeback rank (30%). Effort is NOT baked into the composite — it's shown as a separate column alongside the score (estimated hours to fix + savings per hour). The composite answers "what matters most to your business?" Effort answers "where do you get the fastest win?" Keeping them separate lets the reader see strategic priority AND tactical sequencing without one contaminating the other.

**The "after" picture — operational, not financial.** What Monday morning looks like post-remediation:
- Monday velocity report becomes trustworthy — no more manual assembly, no more inconsistent definitions
- New retailer onboarding timeline drops from X weeks to Y
- 1WorldSync sync rate goes from 10% to 95%+
- Chargebacks decline by ~72%
- Ops team gets 15–20 hours/month back
- Data infrastructure supports growth to $55M without compounding data debt

**The Monday Morning before/after narrative.** Not just metrics — the operational workflow. "Here's what your Monday looks like today: you open three retailer portals, pull four exports, paste them into Excel, spend 90 minutes building the pivot table, and the numbers still don't agree with what your broker sent. Here's what it looks like after: you open one page." Make the CEO feel the 90 minutes they waste every Monday.

**"What happens next."** Describes the remediation work operationally — four phases, what each phase does, what it produces. No pricing. No timeline attached. No "engagement options." The reader's takeaway is "I need this done" — they do their own ROI math because they convinced themselves.

### Part 4: The Evidence (collapsible appendix sections in HTML, separate pages in PDF)

Everything that supports Parts 1–3 but doesn't belong in the main narrative:
- Revenue-weighted field completeness detail (the grey dot / red dot chart)
- Retailer readiness per-retailer breakdown (pass/fail counts, mean missing fields)
- Chargeback trend analysis + seasonal overlay with revenue
- Growth projection with assumptions and sensitivity
- "New vs. old SKU" null finding (one paragraph — tested the hypothesis, data showed nothing, rules out age-based prioritization)
- Benchmarking context (directional industry comparisons)
- What this report does not cover (scope boundaries)
- How I'd do this differently with real data (the section that builds credibility with the portfolio audience)
- Data model diagram + SQL query links
- Note on dataset construction
- **Data generation log (`data_generation_log.md`)** — explicitly documents how the synthetic data was intentionally "broken" to mimic reality. Examples: "Misaligned UPC check digits on 10% of SKUs to mirror human data-entry errors." "Simulated 3-week lag in 1WorldSync status updates." "Seeded chargeback concentrations to follow Pareto distribution observed in real engagements." This proves knowledge of what real retail data looks like in the wild — not just what clean SQLite tables look like. Lives in the repo root and is referenced from the README and the technical appendix.
- Methodology notes for all estimates

---

## Artifact 2: Executive Tearsheet — Detailed Structure

**Page 1:**
- Three-number summary: annual cost of data debt ($371k), revenue at risk ($18.2M at Walmart), cost trajectory at growth target ($258k+ chargebacks alone)
- Three static charts: chargeback Pareto, retailer readiness exposure, growth projection
- One summary paragraph
- Compliance cliff: GS1 Sunrise 2027 and FSMA 204 deadlines

**Page 2:**
- Triage top 10 with fix ROI (savings per hour)
- Three root causes in one sentence each
- The SKU kill recommendation in one sentence
- "What happens next" in three bullets

---

## Artifact 3: Monday Morning Dashboard — Detailed Structure

Separate Quarto HTML document. Three tabs. Sources the same data frames.

**Tab 1 — Velocity Report**
- reactable: SKU × retailer, units/store/week (4-week, 12-week), % change, store count, data quality flag
- Filterable by retailer, product line, quality tier
- Contextual header explaining what this replaces and how to read it

**Tab 2 — Retailer P&L**
- Waterfall chart, filterable by time period
- Table with the numbers
- Context explaining the margin story

**Tab 3 — Triage Tracker**
- Fix-priority list with all scoring dimensions including effort
- Sortable by any column
- "Still broken today" reconciliation embedded

---

## Artifact 4: Excel Workbook — Detailed Structure

Seven tabs + one bonus tab, generated via `openxlsx2`:

1. **Velocity Summary** — SKU × retailer, units/store/week (4-week, 12-week), % change, store count, data quality flag
2. **SKU Master + Data Quality Scores** — one row per SKU, all fields, quality score, issue flags, chargeback totals, annual revenue, gross margin, fix priority score
3. **Retailer Readiness Matrix** — SKU × retailer grid, pass/fail per required field
4. **Chargeback Detail** — every chargeback record, ready to pivot
5. **Revenue by SKU × Retailer** — aggregated from scan data
6. **Triage List** — fix priority ranking with effort estimates and savings-per-hour
7. **Data Dictionary** — every column, score, and flag explained
8. **Broker Intake Checklist** — the one-page checklist that gates broker submissions. 8 required fields. Fillable. This is the artifact that solves the broker problem, not just diagnoses it.

---

## Artifact 5: Data Debt Calculator (R/Shiny) — Detailed Structure

Standalone app. Not Cinderhaven-specific.

**Inputs:**
- SKU count (default 90, range 20–500)
- Retailer count (default 4, range 1–12)
- Estimated annual chargebacks (default $69k)
- Estimated data quality pass rate (default 44%)
- Average annual revenue per SKU (default $284k)

**Outputs:**
- Estimated annual cost of data debt at current inputs
- Projected cost at 2× and 3× scale
- Sensitivity: which input lever moves the number most
- Data-debt-density score (chargebacks per $1M revenue)
- Compliance timeline: where they stand relative to GS1 Sunrise 2027 and FSMA 204
- **Cost of Delay tab:** time-decay element tied to compliance deadlines. "Fixing this in Month 1 costs $X. Waiting until Month 12 costs $3X due to lost shelf space, emergency remediation rates, and compounding chargebacks." Shows how the cost curves accelerate as GS1 Sunrise 2027 approaches. This is what makes the calculator extraordinary rather than just useful.
- One-paragraph dynamically generated interpretation

**Design:** Uses the same visual theme as report charts. Deployed to shinyapps.io.

---

## Shareable Artifacts for Operators

Two standalone pieces designed to be shared by a CEO to another CEO. Both get built — once the compliance cliff narrative exists, the timeline is low effort, and once the scoring methodology exists, the scorecard is low effort.

**Artifact A — GS1 Sunrise 2027 / FSMA 204 Compliance Timeline.** A one-page visual timeline showing the key deadlines, what each requires, and what product data capabilities are prerequisites. Any specialty food brand can use it. Print-friendly. Shareable. Connects directly to the compliance cliff section in Part 1.

**Artifact B — Product Data Health Scorecard Template.** A one-page self-assessment. "Score your product master against these 8 dimensions. If you score below X, your data will break before you hit $50M." Fillable PDF or a tab in a downloadable Excel file. More useful as a standalone — an ops manager can fill this out in 15 minutes without needing any tools.

---

## Visual Language

One custom ggplot2 theme (`00_theme.R`) used across every artifact.

**Design rules:**
- No vertical gridlines. Light horizontal gridlines only.
- Background: white (no grey panel fill)
- Font: system sans-serif (Arial or Helvetica fallback)
- Legend position: top, single row. Or killed entirely with direct labels.
- Primary dark navy: **#1B2A4A**
- Accent red ("at risk" / "problem" / "cost"): **#C0221F**
- Accent coral/orange (secondary warning): **#D35830**
- Teal/green (positive / "clean" / "passing"): **#1E8C7E**
- Medium blue: **#3D5A80**
- Muted blue: **#576D91**
- Mid grey (secondary text, gridlines): **#636E72**
- Near-black (body text): **#2D3436**
- Light grey backgrounds: **#E8ECF0**, **#DFE6E9**
- White: **#FFFFFF**
- Product line colors locked across all charts: Artisan Sauces, Specialty Condiments, Pantry Staples — three fixed colors from the palette above, same everywhere (assign during Phase 0B theme build)
- Titles: left-aligned, bold, state the insight (not the metric). "8 SKUs drive half your chargeback costs" not "Chargeback concentration by SKU rank"
- Subtitles: left-aligned, lighter weight, state the context
- Captions: right-aligned, small, source in plain English ("Source: Cinderhaven product master + sales data" not "Source: sku_master_full")
- No bold axis labels. Minimal tick marks.
- Y-axis labels formatted as currency/percentage with scales package
- No log scales. If the data range is too wide, use a different chart type or annotate outliers.
- No box plots, violin plots, or radar charts.
- No pie charts (use horizontal bar or donut with max 4 segments).
- No statistical notation visible to the reader. No Spearman, no n=, no p-values, no quartile labels.
- Chart types allowed: horizontal bar, vertical bar, dot plots, waterfall, Pareto curves, line charts, strip plots (dots without boxes), simple tables when a chart adds no value.

**Accessibility (a11y):**
- All color choices must pass WCAG 2.1 AA contrast ratio (4.5:1 minimum for text, 3:1 for large text and graphical elements).
- Never rely on color alone to convey meaning — always pair with labels, patterns, or position.
- All HTML chart images include meaningful alt text describing the insight, not just "chart."
- Shiny app must be keyboard-navigable.
- Test the accent red/coral against white background AND against the muted greys to ensure sufficient contrast in all chart contexts.

---

## Chart Inventory

Every chart earns its place by answering "so what?"

### Hero Charts (in main narrative, interactive via plotly in HTML)

1. **Chargeback Pareto** — cumulative % of chargeback cost by SKU rank. Annotations: "8 SKUs → 50%" and "19 SKUs → 80%." Insight title.
2. **Time-to-shelf by data quality tier** — dot strip plot, plain-English tier labels, mean annotated per tier, 3× gap highlighted.
3. **True net margin by retailer** — four-panel waterfall. Free y-scale. Annotation: Walmart wins dollars, Whole Foods wins margin.
4. **Fix ROI** — horizontal bar: chargeback savings per hour of effort by fix action. "Fixing GTIN check digits: 2 hours, $14,114/hour saved."

### Supporting Charts (included where they support findings)

5. Revenue-weighted field completeness (grey dot vs. red dot — this chart is already good, keep the design)
6. Retailer readiness — revenue at risk by retailer (horizontal bar with annotations)
7. Revenue at risk vs. revenue opportunity (back-to-back: cost of failure + revenue if clean)
8. Chargebacks as % of gross margin, top 15 SKUs (horizontal bar — the 442% SKU)
9. Process debt by data-entry source (bar height = quality, color = chargebacks per SKU)
10. Chargeback dollars by reason (horizontal bar, data-defect reasons highlighted)
11. Data debt by product line (issues per $1M revenue)
12. Growth projection (bar chart: current → Stage 2 → Stage 3 with sensitivity)
13. Monthly chargeback trend with revenue overlay
14. Deauthorization rate by quality tier (bottom-half vs. top-half framing, NOT quartile labels)
15. Compliance cliff timeline (GS1 Sunrise 2027 + FSMA 204 visual)
16. Retailer item setup readiness (stacked bar, pass/fail counts)
17. Data staleness distribution
18. 1WorldSync status (horizontal bar, NOT a pie chart)
19. **Data quality vs. revenue — simple comparison chart.** REPLACES the scatterplot. Instead of 90 dots on a noisy scatterplot proving a negative, use a grouped bar or split view: "Top 15 SKUs by revenue: mean quality score 66.7. Full catalog: 70.0. The best sellers aren't cleaner — they're slightly dirtier." The underlying insight (quality doesn't track revenue, but quality DOES track chargebacks) gets stated in prose with two comparison numbers, not forced through a chart type that asks the reader to see the absence of a pattern.
20. Shelf loss — deauthorization rate chart for Part 1

Additional charts as findings warrant. The constraint is analytical value, not count.

---

## How the HTML Report and Quarto Report Relate

The HTML audit report (Python-generated, already built) and the Quarto report are two layers of the same practice offering, not two versions of the same document.

**HTML audit report = the fast diagnostic.** Scope: product master validation, chargeback reconciliation, retailer readiness, triage list. No velocity data, no retailer P&Ls, no time-to-shelf analysis, no Monday dashboard. This is what a prospect could receive in week 1 of a lightweight engagement. It answers: "Is your product data broken, and what is it costing you?"

**Quarto report = the full case study.** Everything in the HTML report plus: velocity × data quality analysis, retailer margin story, process debt traceability, shelf loss correlation, promotional lift, the Monday dashboard, the Excel workbook. This is the portfolio piece that demonstrates the full depth of an engagement. It answers: "How is broken data affecting every part of your business, and what's the complete fix?"

A prospect who sees both should feel like they got the X-ray first and the full MRI second — same patient, deeper picture, more actionable conclusions.

**Numbers must be consistent.** Both reports will be regenerated from the same canonical data frames in Phase 0. Any discrepancy is a credibility problem.

---

## Writing Registers

Different artifacts use different writing registers. The voice is always the same person — but the register adapts to context.

**The audit report:** Economist data-analyst editorial. Full sentences, argumentative prose, narrative threading between sections. Dramatic where earned. This is writing meant to persuade.

**The executive tearsheet:** Board-memo register. Shorter sentences. No narrative — just findings, numbers, and recommendations. Dense. Every word earns its place.

**The Monday dashboard:** Functional/instructional. Short contextual headers. "This tab shows X. Filter by Y. The data updates from Z." No narrative voice. Designed to be scanned at 7am on Monday, not read.

**The Excel workbook:** Column headers and the Data Dictionary tab. Plain, precise, no personality. "TTM_revenue: trailing twelve-month revenue per SKU in USD, calculated from scan_data over the most recent 365 days."

**The Shiny calculator:** Conversational/accessible. The user is a stranger who landed on this tool cold. Plain English, no jargon, brief explanations of what each input means and how to interpret the output.

**The README:** Technical but human. Speaking to a developer, hiring manager, or data person who wants to understand the craft behind the project. Can be more casual than the report.

---

## Shiny Calculator ↔ Case Study Connection

The calculator defaults use Cinderhaven's numbers (90 SKUs, 4 retailers, $69k chargebacks, 44% pass rate, $284k average revenue per SKU) so that a user who has also read the case study sees the same baseline. But the tool never mentions Cinderhaven by name — the defaults are just defaults.

The calculator includes a link to the full case study: "See what a complete product data audit looks like →" with a URL to the Quarto HTML report. The case study includes a link to the calculator: "Estimate your own data debt →" with a URL to the Shiny app. The connection is bidirectional but light — neither artifact requires the other to be useful.

---

## README Specification

Two separate README contexts:

**Repo-level README.md (in the GitHub repo):** The "director's commentary" for technical readers.
- What this project is (one paragraph)
- Why Quarto over Jupyter Notebook
- How the synthetic data was engineered (and what would change with real data)
- How Claude Code was used to accelerate the build
- Technical stack: R, Quarto, SQLite, plotly, reactable, openxlsx2, Shiny
- How to reproduce: clone → `run_all.R` → done
- Directory structure explanation
- Links to companion artifacts: GTIN Validator (live), SQL query library (GitHub), HTML audit report, Shiny calculator

**Portfolio-page description (wherever the project lives online):** Short, non-technical.
- One paragraph: what the project demonstrates
- Links to: HTML report, Quarto report, Monday dashboard, Shiny calculator, GTIN Validator, GitHub repo
- "Built with R, Quarto, and SQLite. One command reproduces everything."

---

## Numbers Consistency

**Critical requirement:** All artifacts pull from the same canonical data frames generated in Phase 0.

The existing HTML audit report (Python-generated) uses numbers from an older version of the database. The Quarto report was built against the updated database. The canonical numbers come from Phase 0 queries against the current SQLite file.

If the HTML report needs to be regenerated from the updated database, that happens as part of the build so all Cinderhaven artifacts agree.

---

## Division of Labor

### Claude Code builds:
- Custom ggplot2 theme
- All R scripts (data prep, analytical frames, charts, workbook generation)
- Quarto scaffolding (.qmd files, YAML config, layout)
- reactable/plotly interactivity
- Excel workbook via openxlsx2
- Shiny calculator app
- `run_all.R` orchestrator
- renv, directory structure

### Claude Chat writes:
- All narrative prose — every sentence the reader sees
- Chart titles, subtitles, and annotations (insight lines)
- Executive tearsheet text
- "How I'd Do This Differently With Real Data" appendix
- "What This Report Does Not Cover" section
- The Monday morning before/after narrative
- The broker intake checklist content
- The SKU kill recommendation prose
- The compliance cliff narrative
- README "director's commentary"
- Portfolio-page description (short, non-technical)
- Data Dictionary tab content
- Monday dashboard contextual text (tab headers, explanatory notes)
- Compliance timeline content (deadlines, requirements, prerequisites)
- Scorecard template content (8 dimensions, scoring rubric, interpretation guide)
- Data generation log content (how the synthetic data was intentionally broken)

### User decides:
- Final structure calls
- Which findings to promote vs. demote
- Tone and voice calibration
- When each artifact is done

---

## Build Phases

### Phase 0 — Foundation (Claude Code)

**Goal:** Everything that every artifact depends on.

**0A — Directory structure**
```
cinderhaven-audit/
├── data/
│   └── cinderhaven_product_master.db
├── R/
│   ├── 00_theme.R
│   ├── 01_load_raw.R
│   ├── 02_build_frames.R
│   ├── 03_verify.R
│   ├── 04_hero_charts.R
│   ├── 05_supporting_charts.R
│   ├── 06_excel_workbook.R
│   └── run_all.R
├── quarto/
│   ├── report.qmd
│   ├── tearsheet.qmd
│   ├── dashboard.qmd
│   └── _quarto.yml
├── shiny/
│   └── app.R
├── output/
└── renv.lock
```

**0B — Custom ggplot2 theme** per visual language spec above.

**0C — Data prep scripts** — connect to SQLite, build all canonical data frames, save as .rds. Verify distributions before charting.

**0D — Reconcile numbers** — run the same queries the HTML report used. Document any discrepancies. Establish which numbers are canonical.

**Deliverable:** All data frames in `output/`. Theme tested. Numbers verified.

### Phase 1 — Charts (Claude Code builds, Claude Chat writes annotations)

Build all charts from the chart inventory. Hero charts first, then supporting.

Each chart reviewed by Claude Chat for:
- Does the title state the insight?
- Does the subtitle provide context in plain English?
- Is the "so what" immediately clear to a non-technical reader?
- Does it connect to a decision?

Charts revised until they pass all four checks.

**Deliverable:** All charts as ggplot2 objects + static PNGs.

### Phase 2 — Report Narrative (Claude Chat writes, Claude Code assembles)

Claude Chat drafts each section of Parts 1–4 in conversation. User reviews, revises, approves. Approved prose goes to Claude Code for assembly into `report.qmd`.

**Key prose pieces to write:**
- Opening hook (one-sentence summary)
- The cost story (Part 1 — chargeback concentration, retailer readiness, velocity drag, cost model, compliance cliff)
- The revenue story (Part 1 — addressable revenue from clean data)
- The SKU kill recommendation (Part 1)
- Root cause narratives × 3 (Part 2)
- Monday morning before/after (Part 3)
- "What happens next" (Part 3)
- All appendix section prose (Part 4)
- 10–15 "stop and screenshot" sentences distributed across the report

**Deliverable:** Working HTML report + PDF version.

### Phase 3 — Monday Dashboard (Claude Code builds, Claude Chat writes headers)

Three tabs sourcing the same data frames. Claude Chat writes tab headers and contextual notes.

**Deliverable:** Standalone HTML file.

### Phase 4 — Excel Workbook (Claude Code builds, Claude Chat writes data dictionary + checklist)

Eight tabs via openxlsx2. Claude Chat writes the Data Dictionary and the Broker Intake Checklist content.

**Deliverable:** .xlsx in `output/`.

### Phase 5 — Executive Tearsheet (Claude Chat writes, Claude Code renders)

Claude Chat writes all text. Claude Code builds `tearsheet.qmd` with PDF-only output.

**Deliverable:** 2-page PDF.

### Phase 6 — Shiny Calculator (Claude Code builds)

Standalone app per spec. Uses the same visual theme.

**Deliverable:** Deployed app on shinyapps.io.

### Phase 7 — Shareable Artifacts

Build both the compliance timeline and the scorecard template.

**Deliverable:** Two one-page artifacts (PDF and/or standalone HTML).

### Phase 8 — Polish

**Claude Code:**
- `run_all.R` orchestrator, renv.lock, clean up paths
- **GitHub Actions workflow:** automatic rendering of Quarto documents and deployment of Shiny app on push. Proves to technical evaluators that this is a production-ready system, not a local script. (Nice-to-have, not a blocker for shipping.)
- **Scrollytelling attempt:** if using Quarto `closeread` or equivalent, attempt scrollytelling on the chargeback Pareto and retailer waterfall charts. If it works cleanly, keep it — the narrative becomes physically engaging as charts update while the reader scrolls. If it fights the toolchain, fall back to standard interactive plotly. Don't let this block shipping.

**Claude Chat:**
- README director's commentary
- Portfolio-page description
- Data generation log (`data_generation_log.md`)
- Final prose pass on all sections
**Both:** Regenerate HTML audit report from updated database if needed for number consistency.

**Deliverable:** Complete repo, reproducible from clone.

---

## What Makes This Remarkable

Seven things that elevate this from "competent audit" to "the reader can't stop thinking about it":

1. **The SKU kill recommendation.** A data audit that recommends killing a product crosses from data work into business strategy.
2. **The revenue upside frame.** Not just what dirty data costs — what clean data unlocks. The stick and the carrot, back to back.
3. **The broker intake checklist.** An actual deliverable artifact that solves the broker problem, not just diagnoses it.
4. **The compliance cliff.** GS1 Sunrise 2027 and FSMA 204 create regulatory urgency the data alone doesn't.
5. **The Monday morning before/after.** An operational narrative that makes the CEO feel the 90 minutes they waste every week.
6. **The shareable artifacts.** Two pieces designed to be forwarded to another CEO — a compliance timeline and a scorecard template that work for any brand.
7. **10–15 sentences of prose that make the reader stop.** The kind of sentences that get screenshotted and shared.

---

## Related Artifacts (already built, separate repos)

- GTIN Validator — live web tool
- SQL diagnostic query library — 53 queries in product-data-audit-queries repo
- HTML audit report — generated by Python (to be regenerated against current database)
- Cinderhaven SQLite database — in product-data-audit-queries repo

---

## What's NOT in This Project

- No Power BI. Killed.
- No "10 Signs" diagnostic section in the report. Can be written later as standalone content.
- No pricing, timelines, or "engagement options" anywhere.
- No statistical notation in reader-facing text.
- No box plots, violin plots, pie charts, radar charts, or log scales.
