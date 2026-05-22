# Failures Log

Approaches that didn't work and why, so we don't repeat them.

---

### 2026-05-20 — PowerShell `>` redirect corrupts binary files

- **What happened:** Used `git show HEAD:output/frames/raw_tables.rds > output/frames/raw_tables.rds` in PowerShell to restore a file. The .rds file was silently converted to UTF-16LE encoding, making it unreadable by R.
- **Why it failed:** PowerShell's `>` operator (alias for `Out-File`) defaults to UTF-16LE encoding for all output, including binary data.
- **Fix:** Use `git restore --source HEAD -- path/to/file` instead, which writes raw bytes.
- **Tags:** powershell, git, binary-files, windows

### 2026-05-20 — Pass rate discrepancy: field-presence (60%) vs strict validation (0%)

- **What happened:** When recalibrating the Shiny calculator for 50 SKUs, a raw field-presence check showed ~60% of SKUs passing. But `R/02_build_frames.R` strict validation (GTIN check-digit verification + OneWorldSync registration status) produced a 0% pass rate.
- **Why it failed:** These are two different definitions of "pass." The strict check validates data correctness (check digits match, OWS registration complete), not just field presence. Every SKU in the 50-SKU dataset fails at least one strict validation.
- **Resolution:** Used 60% for Shiny defaults because 0% makes the sensitivity slider useless — users can't explore scenarios when every SKU already fails.
- **Tags:** data-validation, shiny, calibration, pass-rate

### 2026-05-20 — R segfault when invoked through Bash tool on Windows

- **What happened:** Running `"C:\Program Files\R\R-4.6.0\bin\Rscript.exe"` through the Bash tool caused a segfault.
- **Why it failed:** Likely a WSL/bash-to-Windows-exe interop issue. The Bash tool runs through a compatibility layer that doesn't handle Windows-native executables reliably.
- **Fix:** Use the PowerShell tool instead when invoking Windows-native R on this machine.
- **Tags:** R, windows, bash, powershell, tooling

### 2026-05-20 — showtext produces fuzzy chart rendering on CI

- **What happened:** Migrated charts to use `showtext` + `sysfonts` for Playfair Display and Source Sans 3 fonts on headless CI. Charts rendered with fuzzy text that was also too small to read comfortably at browser zoom.
- **Why it failed:** showtext uses its own software rasterizer which produces softer output than the system FreeType renderer. Combined with 200 DPI and base_size 12, labels become unreadable.
- **Fix (not yet applied):** Switch to `ragg::agg_png` as the ggsave device (uses system FreeType with better hinting), bump DPI to 300, increase `theme_lailara` base_size to 14-15, increase all `geom_text` size params from 3.0-4.2 to 4.5-5.5. Also set `showtext_opts(dpi = 300)` to match.
- **Tags:** showtext, ragg, chart-quality, CI, fonts

### 2026-05-22 — Global `dev: "svglite"` in _quarto.yml breaks PDF rendering

- **What happened:** Set `dev: "svglite"` in `_quarto.yml` knitr opts_chunk to get crisp vector charts in HTML. PDF render immediately failed.
- **Why it failed:** Quarto's PDF pipeline needs `rsvg-convert` to convert SVG→PDF for LaTeX embedding. `rsvg-convert` is not installed on this system, and the R `rsvg` package is also not in the renv library.
- **Fix:** Removed `dev: "svglite"` from `_quarto.yml`. Instead, static chart images use a `chart()` R helper in report.qmd that returns `.svg` for HTML and `.png` for PDF. Added `fig.retina: 3` as the high-DPI PNG fallback for any inline chunks.
- **Tags:** quarto, svglite, pdf, rsvg-convert, chart-rendering

### 2026-05-22 — Static .svg paths in ![](…) break PDF render

- **What happened:** Replaced all 15 `![](chart.png)` references in report.qmd with `![](chart.svg)`. HTML rendered fine. PDF render failed with "Could not convert a SVG to a PDF for output."
- **Why it failed:** Same root cause — Quarto calls `rsvg-convert` for SVG→PDF conversion and it's not on PATH.
- **Fix:** Replaced static paths with inline R `chart(name)` calls that return the right extension per output format. Both formats now render from the same .qmd source.
- **Tags:** quarto, svg, pdf, image-paths, format-conditional

### 2026-05-20 — First Shiny deploy crashed: renv lockfile missing shiny

- **What happened:** Deployed `shiny/app.R` to shinyapps.io via `rsconnect::deployApp()`. The deploy bundled only 1 file and the app crashed immediately with "shiny package not found."
- **Why it failed:** The renv lockfile didn't include `shiny` or its transitive dependencies. `rsconnect` uses the lockfile to determine what to install on the server. The deploy warning "The following required packages are not installed: - shiny" was missed.
- **Fix:** Installed shiny + bslib + ggplot2 + dplyr + scales + htmltools + tibble into renv library, ran `renv::snapshot()`, redeployed. Always verify the lockfile includes the app's runtime dependencies before deploying.
- **Tags:** shiny, rsconnect, renv, deployment, shinyapps.io

### 2026-05-22 — PowerShell Set-Content corrupts R source files with BOM and smart quotes

- **What happened:** Used PowerShell `Set-Content -Encoding utf8` to fix a string in `R/00_theme.R`. The file became unparseable by R — `source()` threw "unexpected input" at line 1.
- **Why it failed:** PowerShell 5.1's `-Encoding utf8` adds a UTF-8 BOM (byte order mark) to the file start, and also introduced Unicode smart quotes (`"` `"`) where ASCII quotes (`"`) were needed. R's parser chokes on both the BOM and smart quotes.
- **Fix:** Use `[System.IO.File]::WriteAllText()` with `UTF8Encoding($false)` (no BOM) for byte-level writes. For quote corruption, use PowerShell string replacement: `$text.Replace([char]0x201C, '"').Replace([char]0x201D, '"')`. Better yet, use the Edit tool instead of PowerShell for R source file modifications.
- **Tags:** powershell, encoding, BOM, smart-quotes, R, windows

### 2026-05-22 — DQ score denominator masked all variance

- **What happened:** `checks_passed_6 / 8` in `R/02_build_frames.R:129` gave every SKU a score of 75.0 (6/8 × 100) with zero variance. This looked like a real finding — "uniform data quality" — and the entire narrative was written around it.
- **Why it failed:** The variable name `checks_passed_6` clearly says 6 checks, but the denominator was 8, left over from an earlier version that had 8 checks. All 6 current checks pass for every SKU, so the true score is 100% — the synthetic data has no completeness defects. The real failures (barcode check-digit validation) are not part of the 6-check score.
- **Lesson:** When a metric has zero variance, investigate whether the metric is broken before writing narrative around the uniformity. A variable named `X_6` divided by 8 is a code smell.
- **Tags:** data-quality, denominator-bug, zero-variance, misleading-metric

### 2026-05-22 — Edit tool string-not-found after sequential edits to large file

- **What happened:** After several large edits to report.qmd in sequence, an Edit call failed because the target `old_string` no longer matched the file content. Prior edits had changed surrounding lines, shifting the context.
- **Why it failed:** The Edit tool requires an exact match. Long chains of edits to the same file accumulate drift between what the assistant remembers and what the file actually contains.
- **Fix:** Re-read the file with the Read tool to find the current text before attempting further edits. For large rewrites, periodic re-reads between edit batches prevent this.
- **Tags:** edit-tool, workflow, large-files, context-drift
