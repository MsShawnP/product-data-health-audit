# 00_theme.R
# The visual language. One source of truth for every chart, every artifact.
# Sourced by every chart-producing script and by every Quarto setup chunk.
#
# Design rules (from cinderhaven_rebuild_plan.md, "Visual Language"):
#   - White background. No grey panel fill. No vertical gridlines.
#     Light horizontal gridlines only.
#   - System sans-serif (Arial / Helvetica fallback).
#   - Titles state the insight, not the metric: "8 SKUs drive half your
#     chargeback costs" not "Chargeback concentration by SKU rank."
#   - Subtitles state the context. Captions are right-aligned, plain English.
#   - No statistical notation in reader-facing text. No Spearman, no n=,
#     no p-values, no quartile labels (use "Worst 25%" / "Best 25%" instead).
#   - No log scales. No box plots, violin plots, pie charts, or radar charts.
#   - Color is paired with position or label — never the only encoding.
#   - WCAG 2.1 AA contrast: 4.5:1 for text, 3:1 for graphical elements.

suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
})

# ---- the palette ---------------------------------------------------------
# Names match the rebuild-plan spec. Hex values pinned.

cinderhaven_palette <- list(
  # Core brand
  navy        = "#1B2A4A",   # primary dark
  red         = "#C0221F",   # at risk / problem / cost
  coral       = "#D35830",   # secondary warning
  teal        = "#1E8C7E",   # positive / clean / passing
  blue        = "#3D5A80",   # medium accent
  blue_muted  = "#576D91",   # supporting accent

  # Neutrals
  text        = "#2D3436",   # near-black body text
  text_muted  = "#636E72",   # secondary text + gridlines
  bg_pale     = "#E8ECF0",   # light grey background
  bg_paler    = "#DFE6E9",   # lighter grey
  white       = "#FFFFFF"
)

# ---- product-line colors -------------------------------------------------
# Locked across every chart. Three product lines, three fixed hues.
# Choices: Artisan Sauces — navy (the heritage line, most premium look);
# Specialty Condiments — coral (sharper accent, second-tier line);
# Pantry Staples — teal (the everyday line, cleaner positioning).

product_line_colors <- c(
  "Artisan Sauces"       = cinderhaven_palette$navy,
  "Specialty Condiments" = cinderhaven_palette$coral,
  "Pantry Staples"       = cinderhaven_palette$teal
)

# ---- retailer colors -----------------------------------------------------
# Used wherever retailers are shown side-by-side. Walmart gets the muted
# blue (it's the dominant share — let it sit quietly in the chart).
# The other three each get a distinct accent so the eye can compare them.

retailer_colors <- c(
  "Walmart"     = cinderhaven_palette$blue_muted,
  "Costco"      = cinderhaven_palette$red,
  "UNFI"        = cinderhaven_palette$coral,
  "Whole Foods" = cinderhaven_palette$teal
)

# ---- pass / fail and risk-tier colors ------------------------------------

passfail_colors <- c(
  "Pass" = cinderhaven_palette$teal,
  "Fail" = cinderhaven_palette$red
)

# Risk bands used by the triage table + risk distribution histogram.
# Names are reader-facing — "Worst 25%" not "Q1".
risk_band_colors <- c(
  "Worst 25%"     = cinderhaven_palette$red,
  "Below average" = cinderhaven_palette$coral,
  "Above average" = cinderhaven_palette$blue_muted,
  "Best 25%"      = cinderhaven_palette$teal
)

# ---- the theme -----------------------------------------------------------
# Apply with `+ theme_cinderhaven()`. Args let callers override base size
# (e.g. dashboard cards want smaller; tearsheet wants larger).

theme_cinderhaven <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      # White everything — no grey panel fill.
      plot.background    = element_rect(fill = cinderhaven_palette$white,
                                        color = NA),
      panel.background   = element_rect(fill = cinderhaven_palette$white,
                                        color = NA),

      # Horizontal gridlines only, kept light. No vertical gridlines.
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = cinderhaven_palette$bg_pale,
                                        linewidth = 0.4),

      # Titles state the insight, left-aligned.
      plot.title         = element_text(face = "bold",
                                        color = cinderhaven_palette$text,
                                        size = base_size + 2,
                                        hjust = 0,
                                        margin = margin(b = 4)),
      plot.subtitle      = element_text(color = cinderhaven_palette$text_muted,
                                        size = base_size - 1,
                                        hjust = 0,
                                        margin = margin(b = 8)),
      plot.caption       = element_text(color = cinderhaven_palette$text_muted,
                                        size = base_size - 3,
                                        hjust = 1,
                                        margin = margin(t = 8)),
      plot.title.position = "plot",
      plot.caption.position = "plot",

      # Axis text — minimal tick marks, no bold.
      axis.text          = element_text(color = cinderhaven_palette$text,
                                        size = base_size - 1),
      axis.title.x       = element_text(color = cinderhaven_palette$text,
                                        size = base_size - 1,
                                        margin = margin(t = 6)),
      axis.title.y       = element_text(color = cinderhaven_palette$text,
                                        size = base_size - 1,
                                        margin = margin(r = 6)),
      axis.ticks         = element_line(color = cinderhaven_palette$text_muted,
                                        linewidth = 0.3),
      axis.ticks.length  = unit(2, "pt"),

      # Legend — top, single row, no title (use direct labels where possible).
      legend.position    = "top",
      legend.title       = element_blank(),
      legend.text        = element_text(color = cinderhaven_palette$text,
                                        size = base_size - 1),
      legend.key         = element_rect(fill = cinderhaven_palette$white,
                                        color = NA),
      legend.background  = element_rect(fill = cinderhaven_palette$white,
                                        color = NA),
      legend.margin      = margin(b = 4),

      # Strip text (facet labels) — bold, no fill.
      strip.background   = element_rect(fill = cinderhaven_palette$white,
                                        color = NA),
      strip.text         = element_text(face = "bold",
                                        color = cinderhaven_palette$text,
                                        size = base_size,
                                        hjust = 0,
                                        margin = margin(b = 4))
    )
}

# Variant for horizontal-bar charts: switch which axis has gridlines.
theme_cinderhaven_horizontal <- function(base_size = 11) {
  theme_cinderhaven(base_size = base_size) +
    theme(
      panel.grid.major.x = element_line(color = cinderhaven_palette$bg_pale,
                                        linewidth = 0.4),
      panel.grid.major.y = element_blank()
    )
}

# ---- formatters ----------------------------------------------------------
# Pre-baked scales for currency. Use these everywhere instead of
# constructing label_dollar() inline — keeps every chart consistent.

# Compact dollar format: $1.2M / $850k / $642
fmt_dollar_short <- function(x) {
  ifelse(is.na(x), "—",
   ifelse(abs(x) >= 1e6, sprintf("$%.2fM", x / 1e6),
    ifelse(abs(x) >= 1e3, sprintf("$%.0fk", x / 1e3),
                           paste0("$", formatC(round(x), big.mark = ",",
                                               format = "d")))))
}

# Compact y-axis label_dollar, defaults to k. Override scale for M.
scale_y_dollar_k <- function(...) {
  scale_y_continuous(labels = label_dollar(scale = 1e-3, suffix = "k"), ...)
}

scale_y_dollar_m <- function(...) {
  scale_y_continuous(labels = label_dollar(scale = 1e-6, suffix = "M"), ...)
}

scale_x_dollar_k <- function(...) {
  scale_x_continuous(labels = label_dollar(scale = 1e-3, suffix = "k"), ...)
}

scale_x_dollar_m <- function(...) {
  scale_x_continuous(labels = label_dollar(scale = 1e-6, suffix = "M"), ...)
}

# ---- caption helper ------------------------------------------------------
# All chart captions read "Source: <plain English>" — never reference the
# .rds file name or the database table directly.

src_caption <- function(text) {
  paste0("Source: ", text)
}

# ---- product-line / retailer scale shortcuts -----------------------------
# Use these in charts so the color mapping is one line:
#   ggplot(...) + scale_pl_color() + ...

scale_pl_color <- function(...) {
  scale_color_manual(values = product_line_colors, ...)
}
scale_pl_fill <- function(...) {
  scale_fill_manual(values = product_line_colors, ...)
}
scale_retailer_color <- function(...) {
  scale_color_manual(values = retailer_colors, ...)
}
scale_retailer_fill <- function(...) {
  scale_fill_manual(values = retailer_colors, ...)
}
scale_passfail_fill <- function(...) {
  scale_fill_manual(values = passfail_colors, ...)
}
scale_risk_band_fill <- function(...) {
  scale_fill_manual(values = risk_band_colors, ...)
}

# ---- self-test -----------------------------------------------------------
# Set CINDERHAVEN_THEME_TEST=1 to render a 2×2 sample to output/charts/
# proving the theme + palette + helpers all wire up correctly.

if (identical(Sys.getenv("CINDERHAVEN_THEME_TEST"), "1")) {
  suppressPackageStartupMessages({
    library(dplyr); library(tibble); library(patchwork)
  })
  ROOT_TEST <- normalizePath(
    Sys.getenv("PROJECT_ROOT", unset = "."),
    winslash = "/", mustWork = FALSE)
  TEST_OUT  <- file.path(ROOT_TEST, "output", "charts")
  dir.create(TEST_OUT, recursive = TRUE, showWarnings = FALSE)

  set.seed(42)
  d_lines <- tibble(
    line = factor(rep(names(product_line_colors), each = 30),
                  levels = names(product_line_colors)),
    rev  = c(rgamma(30, shape = 2, scale = 50),
             rgamma(30, shape = 2, scale = 70),
             rgamma(30, shape = 2, scale = 40))
  )
  d_ret <- tibble(
    retailer = factor(names(retailer_colors), levels = names(retailer_colors)),
    revenue  = c(13.1, 4.27, 4.05, 2.78))

  p1 <- ggplot(d_lines, aes(line, rev, color = line)) +
    geom_jitter(width = 0.18, alpha = 0.7, size = 2) +
    scale_pl_color() +
    labs(title = "Product-line palette (sample data)",
         subtitle = "Each line gets a fixed hue across every chart in the project",
         x = NULL, y = "Revenue (sample units)",
         caption = src_caption("test data"),
         color = NULL) +
    theme_cinderhaven()

  p2 <- ggplot(d_ret, aes(revenue, retailer, fill = retailer)) +
    geom_col(width = 0.7) +
    scale_x_dollar_m() +
    scale_retailer_fill(guide = "none") +
    labs(title = "Retailer palette — Walmart muted, others accented",
         subtitle = "Walmart is the dominant share — let it sit quietly",
         x = NULL, y = NULL,
         caption = src_caption("test data")) +
    theme_cinderhaven_horizontal()

  p3 <- ggplot(tibble(x = c("Pass", "Fail"), y = c(63, 27)),
               aes(y, x, fill = x)) +
    geom_col(width = 0.55) +
    scale_passfail_fill(guide = "none") +
    labs(title = "Pass / fail palette — teal vs. red",
         subtitle = "Used wherever a SKU passes or fails a check",
         x = "SKU count", y = NULL,
         caption = src_caption("test data")) +
    theme_cinderhaven_horizontal()

  d_risk <- tibble(
    band = factor(names(risk_band_colors), levels = names(risk_band_colors)),
    n    = c(23, 23, 22, 22))
  p4 <- ggplot(d_risk, aes(band, n, fill = band)) +
    geom_col(width = 0.65) +
    scale_risk_band_fill(guide = "none") +
    labs(title = "Risk-band palette — plain-English tier labels only",
         subtitle = "No 'Q1/Q2/Q3/Q4' anywhere reader-facing",
         x = NULL, y = "SKU count",
         caption = src_caption("test data")) +
    theme_cinderhaven()

  out <- (p1 | p2) / (p3 | p4)
  ggsave(file.path(TEST_OUT, "00_theme_smoketest.png"), out,
         width = 12, height = 8, dpi = 150, bg = "white")
  cat("theme smoketest written:",
      file.path(TEST_OUT, "00_theme_smoketest.png"), "\n")
}
