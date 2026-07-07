---
title: "Backward-Compatible Palette Aliases for Multi-Surface Design Token Migration"
date: 2026-05-20
category: docs/solutions/design-patterns/
module: frontend
problem_type: design_pattern
component: frontend_stimulus
severity: medium
applies_when:
  - Migrating a multi-surface project from ad-hoc colors to a formal design system
  - Downstream references (80+) use old palette names that would require line-by-line edits
  - Multiple rendering surfaces share a single palette definition file
tags:
  - design-tokens
  - backward-compatibility
  - palette-migration
  - multi-surface
  - r-ggplot2
  - shiny
  - quarto
  - css-custom-properties
related_components:
  - documentation
  - tooling
---

# Backward-Compatible Palette Aliases for Multi-Surface Design Token Migration

## Context

This project (Product Data Health Audit) has five rendering surfaces that consume color tokens: R/ggplot2 charts, a Shiny dashboard, a Quarto HTML report, a Quarto executive dashboard, and a static landing page. All five originally used an ad-hoc palette (`cinderhaven_palette`) with generic names like `navy`, `coral`, `teal`.

When the Lailara Design System v2 was adopted, every surface needed to move to the canonical token set (Chicago blue `#1f2e7a`, Hong Kong teal `#158f75`, Tokyo berry `#b82d4a`, etc.). A naive migration would have required editing 80+ downstream references across R scripts, Shiny UI code, and Quarto documents — high risk of missed references and regressions.

Prior sessions (session history) showed that the alias pattern had already been used opportunistically for column renames (`dollar_short`, `velocity`) and a `theme_audit` to `theme_cinderhaven` rename across 11 call sites. The systematic design-token migration formalized this pattern project-wide.

## Guidance

Define all canonical design tokens once in a single foundation file, then create a backward-compatible alias map that points old names at new tokens. Downstream code keeps working unchanged; new code uses the canonical names directly.

### R foundation file (`R/00_theme.R`)

```r
# Canonical Lailara Design System v2 tokens
LL_CANVAS      <- "#f5f3ee"
LL_INK         <- "#0d0d0d"
LL_RED         <- "#cc100a"
LL_CHICAGO     <- "#1f2e7a"
LL_HK          <- "#158f75"
LL_TOKYO       <- "#b82d4a"
LL_SINGAPORE   <- "#d97b2a"
# ... (full set in R/00_theme.R)

# Backward-compatible alias map
cinderhaven_palette <- list(
  navy       = LL_CHICAGO,
  red        = LL_RED,
  coral      = LL_TOKYO,
  teal       = LL_HK,
  blue       = LL_CHICAGO,
  blue_muted = LL_CHICAGO_LIGHT,
  text       = LL_TEXT,
  text_muted = LL_TEXT_SEC,
  bg_pale    = LL_GRIDLINE,
  bg_paler   = LL_SURFACE,
  white      = LL_CANVAS
)

# Theme alias
theme_cinderhaven <- theme_lailara
```

### CSS custom properties (HTML surfaces)

```css
:root {
  --ll-canvas:     #f5f3ee;
  --ll-ink:        #0d0d0d;
  --ll-red-42:     #cc100a;
  --ll-chicago-20: #1f2e7a;
  /* ... full token set */
}
```

### Shiny PAL list (`shiny/app.R`)

```r
PAL <- list(
  # Canonical tokens
  canvas = "#f5f3ee",
  chicago = "#1f2e7a",
  hk = "#158f75",
  # ...
  # Backward-compatible aliases
  navy = "#1f2e7a",
  coral = "#b82d4a",
  teal = "#158f75"
)
```

## Why This Matters

**Risk reduction**: Editing 80+ color references across five surfaces is error-prone. Missed references produce subtle visual regressions — wrong chart color, off-brand background — that are hard to catch in code review. The alias pattern reduces the migration to editing one file per surface.

**Incremental adoption**: New code written after the migration uses canonical `LL_*` names directly. Old code continues working through aliases. Over time, aliases can be deprecated as old references are naturally encountered and updated.

**Single source of truth**: Every surface resolves to the same hex values defined in one place. A future design system update (e.g., adjusting Chicago blue) requires changing one constant, not hunting through 80+ files.

**Session history note**: Prior sessions revealed that color divergence (`#2e8b57` vs `#1E8C7E` for teal) had already crept in when colors were defined inline. The alias pattern prevents this class of drift by construction. (session history)

## When to Apply

- Migrating from ad-hoc or legacy color palettes to a formal design system
- Project has multiple rendering surfaces (R, Shiny, Quarto, HTML, Excel) sharing color tokens
- Downstream reference count is high enough (20+) that line-by-line edits carry meaningful regression risk
- The old palette names are well-established in the codebase and changing them all at once would create a noisy diff that obscures the actual design changes

## Examples

### Before: ad-hoc colors scattered across surfaces

```r
# R/00_theme.R — old approach
cinderhaven_palette <- list(
  navy = "#1f4e79",    # not from any system
  coral = "#c0504d",   # eyeballed
  teal = "#2e8b57"     # drifted from other surfaces
)
```

```css
/* index.html — different values for "the same" colors */
.hero { background: #1a1a2e; }
.btn  { background: #c0504d; }
```

### After: canonical tokens with aliases

```r
# R/00_theme.R — single source of truth
LL_CHICAGO <- "#1f2e7a"
LL_TOKYO   <- "#b82d4a"
LL_HK      <- "#158f75"

cinderhaven_palette <- list(
  navy  = LL_CHICAGO,   # resolves to design system
  coral = LL_TOKYO,
  teal  = LL_HK
)
```

```css
/* index.html — same tokens via CSS custom properties */
:root { --ll-chicago-20: #1f2e7a; --ll-red-42: #cc100a; }
.hero { background: var(--ll-chicago-20); }
.btn  { background: var(--ll-red-42); }
```

### Surfaces migrated in this project

| Surface | Token mechanism | File |
|---------|----------------|------|
| R/ggplot2 | `LL_*` constants + `cinderhaven_palette` alias list | `R/00_theme.R` |
| Shiny | `PAL` list with canonical + alias keys | `shiny/app.R` |
| Landing page | CSS custom properties (`--ll-*`) | `index.html` |
| Quarto report | CSS custom properties + R palette constants | `quarto/assets/report.css`, `quarto/report.qmd` |
| Quarto dashboard | CSS custom properties + R palette constants | `quarto/assets/dashboard.css`, `quarto/dashboard.qmd` |
| Excel workbook | Single header fill constant | `R/06_excel_workbook.R` |

## Related

- Lailara Design System v2: `C:\Users\mssha\projects\active\lailara-design-system\LAILARA_DESIGN_SYSTEM.md`
- Known gap: fonts loaded via Google Fonts CDN; design system specifies self-hosting — flagged for follow-up
