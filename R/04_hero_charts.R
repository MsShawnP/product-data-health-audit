# 04_hero_charts.R
# Phase 1 — the four hero charts called out in the rebuild plan:
#
#   1. Chargeback Pareto                 (output/charts/01_chargeback_pareto.{rds,png})
#   2. Time-to-shelf by quality tier     (output/charts/02_time_to_shelf.{rds,png})
#   3. True net margin by retailer       (output/charts/03_retailer_net_margin.{rds,png})
#   4. Fix ROI                            (output/charts/04_fix_roi.{rds,png})
#
# Each chart is saved twice: once as a ggplot2 object (.rds) so a downstream
# .qmd can `readRDS()` and convert via `plotly::ggplotly()` for HTML
# interactivity, and once as a static .png so the same chart embeds cleanly
# in the PDF report and the executive tearsheet.
#
# Titles state the insight, not the metric. No statistical notation.
# Plain-English tier labels ("Worst 25%" / "Best 25%", never Q1 / Q4).
# Captions read "Source: <plain English>" — never reference the .rds path.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(forcats)
  library(ggplot2)
  library(scales)
})

ROOT <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
source(file.path(ROOT, "R", "00_theme.R"))   # palette, theme, helpers

FRM_DIR <- file.path(ROOT, "output", "frames")
OUT_DIR <- file.path(ROOT, "output", "charts")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

read_p <- function(name) readRDS(file.path(FRM_DIR, paste0(name, ".rds")))
sku_master_full   <- read_p("sku_master_full")
time_to_shelf_sku <- read_p("time_to_shelf_sku")
retailer_pnl      <- read_p("retailer_pnl")
chargebacks_e     <- read_p("chargebacks_enriched")

save_chart <- function(p, name, w = 9, h = 5.5, dpi = 200) {
  rds_path <- file.path(OUT_DIR, paste0(name, ".rds"))
  png_path <- file.path(OUT_DIR, paste0(name, ".png"))
  saveRDS(p, rds_path)
  ggsave(png_path, p, width = w, height = h, dpi = dpi, bg = "white")
  cat(sprintf("  %s.rds (%4.1f KB)  +  %s.png (%4.0f KB)\n",
              name, file.info(rds_path)$size / 1024,
              name, file.info(png_path)$size / 1024))
}

# ---- 1. Chargeback Pareto ------------------------------------------------

cat("\n[1/4] Chargeback Pareto\n")

cb_p <- sku_master_full |>
  filter(chargeback_total > 0) |>
  arrange(desc(chargeback_total)) |>
  mutate(rank    = row_number(),
         cum     = cumsum(chargeback_total),
         cum_pct = cum / sum(chargeback_total))

n50 <- min(which(cb_p$cum_pct >= 0.50))
n80 <- min(which(cb_p$cum_pct >= 0.80))

p1 <- ggplot(cb_p, aes(rank, cum_pct)) +
  # Very light grey fill under the curve — present enough to read as
  # cumulative, faint enough not to compete with the threshold callouts.
  geom_area(fill = cinderhaven_palette$bg_pale) +
  geom_line(color = cinderhaven_palette$navy, linewidth = 0.9) +
  geom_point(color = cinderhaven_palette$navy, size = 1.5) +

  # Reference lines at the 50% / 80% thresholds.
  geom_hline(yintercept = c(0.50, 0.80),
             color = cinderhaven_palette$text_muted,
             linetype = "dashed", linewidth = 0.4) +
  geom_vline(xintercept = c(n50, n80),
             color = cinderhaven_palette$text_muted,
             linetype = "dashed", linewidth = 0.4) +

  # The two annotations the plan calls out by name — red callout boxes,
  # white bold text. The annotation IS the accent in this chart.
  annotate("label",
           x = n50, y = 0.50,
           label = sprintf("%d SKUs · 50%%", n50),
           hjust = -0.10, vjust = 1.4,
           size = 3.8, fontface = "bold",
           color = cinderhaven_palette$white,
           fill  = cinderhaven_palette$red,
           label.size = 0,
           label.padding = unit(0.30, "lines"),
           label.r = unit(0.05, "lines")) +
  annotate("label",
           x = n80, y = 0.80,
           label = sprintf("%d SKUs · 80%%", n80),
           hjust = -0.10, vjust = 1.4,
           size = 3.8, fontface = "bold",
           color = cinderhaven_palette$white,
           fill  = cinderhaven_palette$red,
           label.size = 0,
           label.padding = unit(0.30, "lines"),
           label.r = unit(0.05, "lines")) +

  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, 1.02),
                     expand = expansion(mult = c(0, 0))) +
  scale_x_continuous(breaks = pretty_breaks(),
                     expand = expansion(mult = c(0.01, 0.02))) +

  labs(title    = sprintf("%d SKUs drive half your chargeback bill", n50),
       subtitle = "Cumulative share of chargeback dollars by SKU rank, 18 months",
       x        = "SKUs ranked from highest chargeback total to lowest",
       y        = NULL,
       caption  = src_caption("Cinderhaven chargeback ledger, 18 months")) +
  theme_cinderhaven()

save_chart(p1, "01_chargeback_pareto", w = 9, h = 5.5)

# ---- 2. Time-to-shelf by quality tier ------------------------------------

cat("\n[2/4] Time-to-shelf by quality tier\n")

# Build the tier factor with reader-facing names. Matches the risk_band
# palette in 00_theme.R: Worst 25% (red) → Best 25% (teal).
tts <- time_to_shelf_sku |>
  left_join(sku_master_full |> select(sku, product_name, data_quality_score),
            by = "sku") |>
  filter(!is.na(mean_days_to_scan)) |>
  mutate(
    tier_num = ntile(data_quality_score, 4),
    tier = factor(
      c("Worst 25%", "Below average", "Above average", "Best 25%")[tier_num],
      levels = c("Worst 25%", "Below average", "Above average", "Best 25%"))
  )

# Order so Worst 25% is at the TOP of the horizontal chart (highest y).
tier_summary <- tts |>
  group_by(tier) |>
  summarise(mean_days = mean(mean_days_to_scan),
            n = n(), .groups = "drop") |>
  mutate(tier = factor(tier,
                       levels = c("Best 25%", "Above average",
                                  "Below average", "Worst 25%")))

mean_worst <- tier_summary$mean_days[tier_summary$tier == "Worst 25%"]
mean_best  <- tier_summary$mean_days[tier_summary$tier == "Best 25%"]
gap_x      <- mean_worst / mean_best

p2 <- ggplot(tier_summary, aes(mean_days, tier, fill = tier)) +
  geom_col(width = 0.62) +

  # In-bar value labels.
  geom_text(aes(label = sprintf("%.0f days", mean_days)),
            hjust = -0.15, size = 4.2, fontface = "bold",
            color = cinderhaven_palette$text) +

  # 3.2× gap callout: dotted leaders down to the bar ends + arrow + label.
  annotate("segment", x = mean_best, xend = mean_best,
           y = 1, yend = 4.55,
           linetype = "dotted",
           color = cinderhaven_palette$text_muted, linewidth = 0.4) +
  annotate("segment", x = mean_worst, xend = mean_worst,
           y = 4, yend = 4.55,
           linetype = "dotted",
           color = cinderhaven_palette$text_muted, linewidth = 0.4) +
  annotate("segment", x = mean_best, xend = mean_worst,
           y = 4.55, yend = 4.55,
           arrow = arrow(ends = "both", length = unit(0.16, "cm"),
                         type = "closed"),
           color = cinderhaven_palette$text_muted, linewidth = 0.5) +
  annotate("text", x = (mean_best + mean_worst) / 2, y = 4.78,
           label = sprintf("%.1f× gap from best to worst", gap_x),
           color = cinderhaven_palette$text,
           size = 3.9, fontface = "italic") +

  # One-accent encoding: only the Worst 25% bar gets red — that's the
  # finding. The other three tiers exist as comparison baseline and
  # recede into grey.
  scale_fill_manual(values = c(
    "Worst 25%"     = cinderhaven_palette$red,
    "Below average" = "#B0B0B0",
    "Above average" = "#B0B0B0",
    "Best 25%"      = "#B0B0B0"),
    guide = "none") +
  scale_x_continuous(limits = c(0, max(tier_summary$mean_days) * 1.25),
                     breaks = seq(0, 50, 10),
                     expand = expansion(mult = c(0, 0))) +
  scale_y_discrete(expand = expansion(add = c(0.6, 1.0))) +
  coord_cartesian(clip = "off") +

  labs(title    = "Worst-data SKUs take three times as long to reach the shelf",
       subtitle = "Days from store authorization to first sale, by data-quality tier",
       x        = "Mean days from authorization to first sale",
       y        = NULL,
       caption  = src_caption("Cinderhaven authorization log + sales data; tier mean across SKUs in tier")) +
  theme_cinderhaven_horizontal() +
  theme(axis.text.y = element_text(size = 11, face = "bold"))

save_chart(p2, "02_time_to_shelf", w = 9, h = 5.5)

# ---- 3. True net margin by retailer (stacked composition) ----------------

cat("\n[3/4] True net margin by retailer (stacked composition)\n")

contracted <- c("Walmart", "UNFI", "Whole Foods", "Costco")

# One row per retailer, ordered by gross revenue desc so Walmart sits at
# the top of the chart. Both trade and chargeback shares get tiny on
# the smaller retailers — Costco's chargeback is <$30k against $2.25M
# gross. Inflate both to absolute minimum visual widths chosen to fit
# their dollar labels inside the colored segment. Labels still show the
# real dollar amount.
MIN_TRADE_VISUAL <- 0.7e6   # ~ "$646k" + padding fits at size 3.0
MIN_CB_VISUAL    <- 0.5e6   # ~ "$26k" / "$46k" + padding fits at size 3.0

c3_pnl <- retailer_pnl |>
  filter(retailer %in% contracted) |>
  arrange(desc(gross_revenue)) |>
  mutate(retailer     = factor(retailer, levels = retailer),
         trade_visual = pmax(trade_spend_total, MIN_TRADE_VISUAL),
         cb_visual    = pmax(chargeback_total,  MIN_CB_VISUAL),
         bar_end      = net_contribution + trade_visual + cb_visual)

# Long form for the three stack segments. Trade + chargebacks use the
# visual (floored) widths; net contribution is unchanged.
c3_long <- c3_pnl |>
  transmute(retailer,
            "Net contribution" = net_contribution,
            "Trade spend"      = trade_visual,
            "Chargebacks"      = cb_visual) |>
  pivot_longer(-retailer, names_to = "component", values_to = "value") |>
  mutate(component = factor(component,
                            levels = c("Net contribution",
                                       "Trade spend",
                                       "Chargebacks")))

stack_palette <- c(
  "Net contribution" = "#D0D0D0",   # light grey — the calm part
  "Trade spend"      = "#888888",   # medium grey — context, not focus
  "Chargebacks"      = cinderhaven_palette$red)  # the controllable lever

# All three labels go inside their segments at the visual segment
# centers; label text is always the real (un-inflated) dollar amount.
c3_net_lab <- c3_pnl |>
  transmute(retailer,
            x_pos = net_contribution / 2,
            label = fmt_dollar_short(net_contribution))

c3_trade_lab <- c3_pnl |>
  transmute(retailer,
            x_pos = net_contribution + trade_visual / 2,
            label = fmt_dollar_short(trade_spend_total))

c3_cb_lab <- c3_pnl |>
  transmute(retailer,
            x_pos = net_contribution + trade_visual + cb_visual / 2,
            label = fmt_dollar_short(chargeback_total))

# Net margin % annotation, placed just past the right end of each
# (visible) bar. bar_end exceeds gross revenue by the floor adjustments.
c3_margin <- c3_pnl |>
  mutate(margin_label = sprintf("%.0f%% net margin",
                                100 * net_margin_pct_of_gross_revenue))

p3 <- ggplot(c3_long,
             aes(x = value, y = fct_rev(retailer), fill = component)) +
  # Stacked horizontal bar. Total length = gross revenue. reverse=TRUE so
  # the visual order matches the factor levels (Net, Trade, Chargebacks
  # left-to-right) and the legend.
  geom_col(width = 0.65, color = "white", linewidth = 0.5,
           position = position_stack(reverse = TRUE)) +

  # In-segment dollar labels: dark text on the light-grey net segment,
  # white on the medium-grey + red segments where contrast holds.
  geom_text(data = c3_net_lab,
            aes(x = x_pos, y = fct_rev(retailer), label = label),
            inherit.aes = FALSE,
            size = 3.0, color = cinderhaven_palette$text, fontface = "bold") +
  geom_text(data = c3_trade_lab,
            aes(x = x_pos, y = fct_rev(retailer), label = label),
            inherit.aes = FALSE,
            size = 3.0, color = "white", fontface = "bold") +
  geom_text(data = c3_cb_lab,
            aes(x = x_pos, y = fct_rev(retailer), label = label),
            inherit.aes = FALSE,
            size = 3.0, color = "white", fontface = "bold") +

  # Net margin % at the right end of each bar — neutral text now that
  # red is reserved for the chargeback segment.
  geom_text(data = c3_margin,
            aes(x = bar_end, y = fct_rev(retailer),
                label = margin_label),
            inherit.aes = FALSE,
            hjust = -0.06, size = 3.4, fontface = "bold",
            color = cinderhaven_palette$text) +

  scale_fill_manual(values = stack_palette, name = NULL,
                    breaks = c("Net contribution", "Trade spend",
                               "Chargebacks")) +
  scale_x_continuous(labels = label_dollar(scale = 1e-6, suffix = "M"),
                     expand = expansion(mult = c(0, 0.20))) +

  labs(title    = "Walmart wins on dollars; Whole Foods wins on margin",
       subtitle = "Annual gross revenue → trade spend → chargebacks → net contribution, by retailer",
       x        = NULL,
       y        = NULL,
       caption  = src_caption("Cinderhaven sales + cost data + chargeback ledger, trailing 12 months")) +
  theme_cinderhaven_horizontal() +
  theme(axis.text.y = element_text(size = 11, face = "bold"))

save_chart(p3, "03_retailer_net_margin", w = 10, h = 5)

# ---- 4. Fix ROI ----------------------------------------------------------

cat("\n[4/4] Fix ROI\n")

# Numbers come from chargebacks_enriched (canonical source) and
# sku_master_full (defect counts). Effort-per-defect minutes are from
# the methodology appendix; SKU counts and hours are computed from data.

reason_amts <- chargebacks_e |>
  group_by(reason) |>
  summarise(amt_18mo = sum(amount), .groups = "drop")

amt_18 <- function(r) {
  v <- reason_amts$amt_18mo[reason_amts$reason == r]
  if (length(v) == 0) 0 else v
}

n_barcode_skus <- sum(!sku_master_full$gtin_valid | !sku_master_full$upc_valid, na.rm = TRUE)
barcode_hours  <- sum((!sku_master_full$gtin_valid) * 10 +
                      (!sku_master_full$upc_valid)  * 10, na.rm = TRUE) / 60

n_proddata_skus <- sum(sku_master_full$missing_brand_owner |
                       sku_master_full$missing_country |
                       !sku_master_full$ows_complete, na.rm = TRUE)
proddata_hours  <- sum(sku_master_full$missing_brand_owner * 10 +
                       sku_master_full$missing_country     * 30 +
                       (!sku_master_full$ows_complete)     * 30, na.rm = TRUE) / 60

n_dim_skus <- sum(sku_master_full$missing_case_dims |
                  sku_master_full$missing_case_weight, na.rm = TRUE)
dim_hours  <- sum((sku_master_full$missing_case_dims |
                   sku_master_full$missing_case_weight) * 30 +
                  (!is.na(sku_master_full$weight_plausible) &
                   !sku_master_full$weight_plausible)   * 15, na.rm = TRUE) / 60

fix_roi <- tibble(
  action = c(sprintf("Fix invalid barcodes — %d SKUs", n_barcode_skus),
             sprintf("Complete missing product data — %d SKUs", n_proddata_skus),
             sprintf("Reconcile case dimensions — %d SKUs", n_dim_skus)),
  hours  = c(round(barcode_hours, 1),
             round(proddata_hours, 1),
             round(dim_hours, 1)),
  amt_18mo = c(amt_18("Invalid GTIN/UPC"),
               amt_18("Missing product data"),
               amt_18("Dimension mismatch"))
) |>
  mutate(annual_saved = amt_18mo * 12 / 18,
         per_hour     = annual_saved / hours,
         action       = fct_reorder(action, per_hour),
         is_top       = per_hour == max(per_hour),
         label        = sprintf(
           "%s saved per hour  ·  %s/year  ·  %.1f hours total",
           fmt_dollar_short(per_hour),
           fmt_dollar_short(annual_saved),
           hours))

p4 <- ggplot(fix_roi, aes(per_hour, action, fill = is_top)) +
  geom_col(width = 0.55) +
  scale_fill_manual(values = c(`TRUE` = cinderhaven_palette$red,
                               `FALSE` = "#B0B0B0"),
                    guide = "none") +
  geom_text(aes(label = label),
            hjust = -0.04, size = 3.7,
            color = cinderhaven_palette$text) +

  scale_x_continuous(labels = label_dollar(scale = 1e-3, suffix = "k"),
                     expand = expansion(mult = c(0, 0.65))) +

  labs(title    = sprintf("%.0f hours of barcode fixes eliminate half your chargeback bill",
                          barcode_hours),
       subtitle = "Annualized chargeback dollars saved per hour of effort, by fix action",
       x        = "Saved per hour of effort",
       y        = NULL,
       caption  = src_caption("Cinderhaven chargeback ledger; effort estimates per the methodology appendix")) +
  theme_cinderhaven_horizontal() +
  theme(axis.text.y = element_text(size = 10))

save_chart(p4, "04_fix_roi", w = 11, h = 4.5)

cat("\nDone. ", length(list.files(OUT_DIR, pattern = "^0[1-4]_.*\\.rds$")),
    " ggplot objects + ", length(list.files(OUT_DIR, pattern = "^0[1-4]_.*\\.png$")),
    " PNGs in: ", OUT_DIR, "\n", sep = "")
