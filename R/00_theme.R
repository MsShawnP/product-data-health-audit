# 00_theme.R
# Lailara Design System v2 — single source of truth for every chart.
# Sourced by every chart-producing script and by every Quarto setup chunk.

suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
  library(showtext)
  library(sysfonts)
})

# ---- Lailara brand fonts via Google Fonts -----------------------------------
# showtext renders them into PNG/SVG output on any system, including CI.
font_add_google("Playfair Display", "Playfair Display")
font_add_google("Source Sans 3", "Source Sans 3")
showtext_auto()

# ---- Lailara Design System v2 — Color Families ----------------------------

LL_CANVAS     <- "#f5f3ee"

# Brand red (default = 42)
LL_RED        <- "#cc100a"
LL_RED_LIGHT  <- "#ee8880"
LL_RED_DARK   <- "#8e0b07"

# Chicago accent (default = 20)
LL_CHICAGO       <- "#1f2e7a"
LL_CHICAGO_LIGHT <- "#8e9ad0"

# Hong Kong teal (default = 35)
LL_HK         <- "#158f75"
LL_HK_LIGHT   <- "#6dcdb5"
LL_HK_DARK    <- "#0c6552"

# Tokyo berry (default = 40)
LL_TOKYO       <- "#b82d4a"
LL_TOKYO_LIGHT <- "#e68a9a"
LL_TOKYO_DARK  <- "#7e1f34"

# Singapore orange (default = 55)
LL_SG         <- "#ee8a2a"
LL_SG_LIGHT   <- "#f6b97c"
LL_SG_DARK    <- "#7a3d10"

# London greyscale
LL_INK        <- "#0d0d0d"
LL_TEXT        <- "#333333"
LL_TEXT_SEC    <- "#595959"
LL_REFERENCE  <- "#666666"
LL_GRIDLINE   <- "#d9d9d9"
LL_DISABLED   <- "#b3b3b3"
LL_SURFACE    <- "#f2f2f2"

# ---- Chart-role aliases (semantic names for one-accent pattern) -------------
# Focal element gets LL_RED; everything else recedes to these.
LL_RECEDE       <- LL_GRIDLINE   # non-focal bars, secondary series
LL_RECEDE_MID   <- LL_DISABLED   # medium-emphasis (e.g. "High" tier)
LL_RECEDE_DARK  <- LL_REFERENCE  # stronger receding (e.g. trade spend)

# ---- Categorical chart palette (10 slots, paired) -------------------------
LL_CAT_10 <- c(
  "#1f2e7a", "#8e9ad0",
  "#0c6552", "#6dcdb5",
  "#7e1f34", "#e68a9a",
  "#7a3d10", "#f6b97c",
  "#8e0b07", "#ee8880"
)

LL_CAT_10_TEXT <- c(
  "#ffffff", "#0a0f29",
  "#ffffff", "#063d32",
  "#ffffff", "#6e1a2c",
  "#ffffff", "#4a2508",
  "#ffffff", "#4d0604"
)

# ---- Sequential palette (Hong Kong ramp, darkest first) --------------------
LL_SEQ <- c(
  "#063d32", "#0a5c4b", "#0e6e5a", "#158f75",
  "#1fa282", "#35b595", "#6dcdb5", "#b5e4d8"
)

# ---- Divergent palette (HK positive / London neutral / Tokyo negative) -----
LL_DIV_POS <- c("#0a5c4b", "#158f75", "#6dcdb5")
LL_DIV_NEU <- "#d9d9d9"
LL_DIV_NEG <- c("#e68a9a", "#b82d4a", "#6e1a2c")

# ---- product-line colors ---------------------------------------------------
# Three product lines → dark stops from three families.
product_line_colors <- c(
  "Artisan Sauces"       = LL_CHICAGO,
  "Specialty Condiments" = LL_TOKYO,
  "Pantry Staples"       = LL_HK
)

# ---- retailer colors -------------------------------------------------------
# Four retailers → dark stops from four families.
retailer_colors <- c(
  "Walmart"     = LL_CHICAGO,
  "Costco"      = LL_TOKYO,
  "UNFI"        = LL_SG_DARK,
  "Whole Foods" = LL_HK_DARK
)

# ---- pass / fail and risk-tier colors --------------------------------------
passfail_colors <- c(
  "Pass" = LL_HK,
  "Fail" = LL_RED
)

risk_band_colors <- c(
  "Worst 25%"     = LL_RED,
  "Below average" = LL_TOKYO,
  "Above average" = LL_CHICAGO_LIGHT,
  "Best 25%"      = LL_HK
)

# ---- the theme -------------------------------------------------------------
theme_lailara <- function(base_size = 12) {
  theme_minimal(base_size = base_size, base_family = "Source Sans 3") +
    theme(
      plot.background    = element_rect(fill = LL_CANVAS, color = NA),
      panel.background   = element_rect(fill = LL_CANVAS, color = NA),
      panel.grid.major.y = element_line(color = LL_GRIDLINE, linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      plot.title         = element_text(
        family = "Playfair Display", face = "bold",
        size = rel(1.6), color = LL_INK, margin = margin(b = 4)
      ),
      plot.subtitle      = element_text(
        size = rel(1.0), color = LL_TEXT_SEC, margin = margin(b = 12)
      ),
      plot.caption       = element_text(
        size = rel(0.75), color = LL_TEXT_SEC, hjust = 0,
        face = "italic", margin = margin(t = 8)
      ),
      axis.text          = element_text(color = LL_TEXT_SEC, size = rel(0.85)),
      axis.title         = element_text(color = LL_TEXT_SEC, size = rel(0.9)),
      legend.position    = "top",
      legend.title       = element_blank(),
      legend.text        = element_text(color = LL_TEXT_SEC),
      legend.key         = element_rect(fill = LL_CANVAS, color = NA),
      legend.background  = element_rect(fill = LL_CANVAS, color = NA),
      legend.margin      = margin(b = 4),
      strip.background   = element_rect(fill = LL_CANVAS, color = NA),
      strip.text         = element_text(face = "bold", color = LL_INK,
                                        hjust = 0, margin = margin(b = 4)),
      plot.title.position = "plot",
      plot.caption.position = "plot"
    )
}

theme_lailara_horizontal <- function(base_size = 12) {
  theme_lailara(base_size = base_size) +
    theme(
      panel.grid.major.x = element_line(color = LL_GRIDLINE, linewidth = 0.3),
      panel.grid.major.y = element_blank()
    )
}

# Backward-compatible aliases so chart scripts don't need line-by-line edits
theme_cinderhaven            <- theme_lailara
theme_cinderhaven_horizontal <- theme_lailara_horizontal

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
  white      = LL_CANVAS,
  recede     = LL_RECEDE,
  recede_mid = LL_RECEDE_MID,
  recede_dark = LL_RECEDE_DARK
)

# ---- formatters ------------------------------------------------------------

fmt_dollar_short <- function(x) {
  ifelse(is.na(x), "—",
   ifelse(abs(x) >= 1e6, sprintf("$%.2fM", x / 1e6),
    ifelse(abs(x) >= 1e3, sprintf("$%.0fk", x / 1e3),
                           paste0("$", formatC(round(x), big.mark = ",",
                                               format = "d")))))
}

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

# ---- caption helper --------------------------------------------------------
src_caption <- function(text) {
  paste0("Source: ", text)
}

# ---- product-line / retailer scale shortcuts -------------------------------
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

# ---- self-test -------------------------------------------------------------
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
    theme_lailara()

  p2 <- ggplot(d_ret, aes(revenue, retailer, fill = retailer)) +
    geom_col(width = 0.7) +
    scale_x_dollar_m() +
    scale_retailer_fill(guide = "none") +
    labs(title = "Retailer palette",
         subtitle = "Walmart is the dominant share",
         x = NULL, y = NULL,
         caption = src_caption("test data")) +
    theme_lailara_horizontal()

  p3 <- ggplot(tibble(x = c("Pass", "Fail"), y = c(63, 27)),
               aes(y, x, fill = x)) +
    geom_col(width = 0.55) +
    scale_passfail_fill(guide = "none") +
    labs(title = "Pass / fail palette",
         subtitle = "Used wherever a SKU passes or fails a check",
         x = "SKU count", y = NULL,
         caption = src_caption("test data")) +
    theme_lailara_horizontal()

  d_risk <- tibble(
    band = factor(names(risk_band_colors), levels = names(risk_band_colors)),
    n    = c(23, 23, 22, 22))
  p4 <- ggplot(d_risk, aes(band, n, fill = band)) +
    geom_col(width = 0.65) +
    scale_risk_band_fill(guide = "none") +
    labs(title = "Risk-band palette",
         subtitle = "Plain-English tier labels only",
         x = NULL, y = "SKU count",
         caption = src_caption("test data")) +
    theme_lailara()

  out <- (p1 | p2) / (p3 | p4)
  ggsave(file.path(TEST_OUT, "00_theme_smoketest.png"), out,
         width = 12, height = 8, dpi = 150, bg = LL_CANVAS)
  cat("theme smoketest written:",
      file.path(TEST_OUT, "00_theme_smoketest.png"), "\n")
}
