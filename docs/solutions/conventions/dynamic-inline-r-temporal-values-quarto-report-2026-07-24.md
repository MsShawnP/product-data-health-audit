---
title: "Dynamic inline R for temporal values and narrative accuracy in Quarto reports"
date: 2026-07-24
category: conventions
module: quarto-report
problem_type: convention
component: rails_view
severity: medium
applies_when:
  - Report prose references computed temporal spans (month counts, date ranges) derived from underlying data
  - Underlying dataset is reseeded, refreshed, or re-pulled after the narrative was originally written
  - A Quarto or R Markdown document mixes hardcoded narrative claims with computed statistics
  - Prose characterizes pass/fail rates or severity in qualitative terms that can drift from computed values
  - Methodology or context explanation is repeated redundantly across multiple report sections
tags:
  - quarto
  - inline-r
  - dynamic-values
  - data-reseed
  - stale-narrative
  - report-accuracy
  - r-markdown
related_components:
  - documentation
  - tooling
---

# Dynamic inline R for temporal values and narrative accuracy in Quarto reports

## Context

`quarto/report.qmd` (~920 lines) is a data-driven report that mixes static prose with inline R expressions computed from data frames loaded in the setup chunk. A June 2026 Cinderhaven data reseed changed the underlying dataset, and a prior session (DECISIONS.md, 2026-06-22) caught that three hardcoded dollar figures (`$228,845`) had gone stale and survived undetected. That session established the convention: dynamic inline R over hardcoded dollar figures.

This session found the same failure mode in categories the prior fix didn't cover:

1. **Hardcoded month count.** Four prose locations said "36 months" when the chargeback data actually spans 37 months (January 2023 – January 2026). The annualization *divisor* was already dynamic (`n_chargeback_months <- length(unique(cbe$month))`), but the human-readable prose was hardcoded.

2. **Hardcoded date range.** The observation-period sentence read "January 2023 through December 2025" — one month short of the actual end date.

3. **Stale narrative summary.** The readiness paragraph described near-universal failure when post-reseed data shows 38 of 50 SKUs pass, 12 fail all 6 retailers, and retailer pass rates range 46–76%. Unlike a wrong number, this was a hardcoded *conclusion* — prose asserting a shape of the data that the data no longer had.

4. **Redundant methodology prose.** The three-tier score distribution was described in full three separate times (deauthorization analysis, cost model, data quality scoring), creating three places that could drift out of sync.

The common root cause: prose in a data-driven report is either computed from the same variables the numbers come from, or it is a landmine that goes off silently on the next data refresh.

## Guidance

### Compute temporal descriptors once, in the setup chunk

```r
# quarto/report.qmd, setup chunk (lines 107-109)
n_chargeback_months <- length(unique(cbe$month))
cb_start_date <- format(min(cbe$month_date), "%B %Y")
cb_end_date   <- format(max(cbe$month_date), "%B %Y")
```

Place these immediately after the data frames are loaded and before any dependent calculation, so every downstream figure and sentence reads from the same source.

### Replace hardcoded numbers AND date ranges with inline R

```
# Before
covering January 2023 through December 2025

# After
covering `r cb_start_date` through `r cb_end_date` — `r n_chargeback_months` months
```

```
# Before (three separate phrasings across the document)
over the past 36 months
Thirty-six months.
over 36 months

# After
over the past `r n_chargeback_months` months
`r n_chargeback_months` months.
over `r n_chargeback_months` months
```

Grep for the literal number across the whole `.qmd` to find every instance — phrasings vary, so a single find-and-replace misses variants.

### Treat narrative summaries as computed values, not just the numbers inside them

A sentence describing the *shape* of the data ("near-universal failure") is itself a claim that can go stale even if every number in it is dynamic. When the underlying distribution changes materially, rewrite the sentence:

```
# Readiness paragraph — all figures dynamic (report.qmd line 209)
These two deadlines land on a company whose product master is split:
`r n_skus - n_sku_fail_all` of `r n_skus` SKUs pass readiness checks
at every retailer, but `r n_sku_fail_all` fail all `r n_retailers`.
Retailer pass rates range from `r min(rr_stats$pass_rate)`% to
`r max(rr_stats$pass_rate)`%, which means the catalog is not uniformly
broken, but the broken portion is completely blocked.
```

### When explanation appears in multiple sections, state it once and cross-reference

```
# Before (deauthorization analysis — full re-description)
[full three-tier score distribution description]

# After
The three-tier score distribution (see Data quality scoring below)
enables basic quality-tier comparison.
```

The canonical description lives once in "Data quality scoring"; other sections reference it.

## Why This Matters

**Silent staleness compounds.** The dollar-figure fix and this month/date-range fix are the same bug in different fields. Every hardcoded literal in prose is a value that was correct once and has no mechanism to notice when it stops being correct. A Quarto report with inline R support has no excuse: the computed value is one `` `r var` `` away.

**Narrative claims are a hardcoding risk too.** Making the *numbers* in a sentence dynamic is necessary but not sufficient if the sentence's *thesis* was written for a different data shape. "Near-universal failure" doesn't self-correct just because the failure count is dynamic — someone still has to notice the shape changed and rewrite the sentence. This is a category dynamic inline R alone doesn't solve; it requires periodic rereading of prose against current data.

**Redundant explanation is a maintenance liability.** Three copies of the same methodology description means three places to update. Consolidating to one canonical description plus cross-references removes the opportunity for copies to disagree — the exact mechanism that let the month-count and dollar-figure bugs happen.

**Grep-ability matters more than one-off correctness.** Fixing four instances of "36 months" only works if you find all four; phrasing varied ("36 months," "Thirty-six months," "over 36 months"), so a literal string replace would have missed some. The durable fix is removing the literal from prose entirely.

## When to Apply

- Any Quarto/R Markdown report where prose states a count, date, date range, or duration derived from a data frame already loaded in the document.
- Any report that has already survived one data reseed and revealed hardcoded values — once you find one class of hardcoded literal, audit for siblings: dates, counts, percentages, superlatives like "worst," "highest," "near-universal."
- Any section where the same explanatory paragraph is written out more than once — consolidate to one canonical location with cross-references before the next edit causes them to drift.
- Does NOT apply to values inside contexts Quarto inline R can't reach (e.g., inside a `fig-alt` string) — hardcode those but leave a comment naming the source variable so grep can find them on the next refresh. (Existing DECISIONS.md guidance, still valid.)

## Examples

**Before/after — hardcoded month count (4 sites, `quarto/report.qmd`):**

| Line | Before | After |
|---|---|---|
| 207 | `covering January 2023 through December 2025` | `` covering `r cb_start_date` through `r cb_end_date` — `r n_chargeback_months` months `` |
| 232 | `over the past 36 months` | `` over the past `r n_chargeback_months` months `` |
| 317 | `Thirty-six months.` | `` `r n_chargeback_months` months. `` |
| 369 | `over 36 months` | `` over `r n_chargeback_months` months `` |

**Before/after — stale narrative conclusion (line 209):**

Before: prose asserting near-universal readiness failure.
After: prose stating the actual split — `` `r n_skus - n_sku_fail_all` `` of `` `r n_skus` `` pass everywhere, `` `r n_sku_fail_all` `` fail everywhere, retailer pass rates range `` `r min(rr_stats$pass_rate)`% `` to `` `r max(rr_stats$pass_rate)`% `` — with the interpretive sentence rewritten to match the data shape, not just the numbers swapped in.

**Before/after — redundant methodology (3 sections → 1 canonical + 2 cross-references):**

Deauthorization analysis: removed full description, replaced with `(see Data quality scoring below)`.
Cost model: replaced "three-tier data quality distribution provides directional support" with the actual limitation: "the dataset lacks the defect variety needed to model their contribution with precision."
Data quality scoring: retained as the single canonical description.

## Related

- DECISIONS.md, 2026-06-22: "Dynamic inline R over hardcoded dollar figures in narrative" — direct precedent; this doc extends from dollar amounts to temporal values and narrative summaries
- DECISIONS.md, 2026-06-22: "Post-reseed Postgres data is canonical ($146,961 annual)" — the reseed event that triggered the dollar-figure precedent
- DECISIONS.md, 2026-06-22: "Part 4 methodology: single collapsible section, not individual callouts" — related consolidation precedent (structural, not textual)
- docs/solutions/design-patterns/backward-compatible-palette-alias-multi-surface-migration-2026-05-20.md — same subject file (`quarto/report.qmd`), different value class (color tokens vs. computed stats), shared "single source of truth" philosophy
