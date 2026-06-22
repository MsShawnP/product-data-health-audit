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
source(file.path(ROOT, "R", "00_setup.R"))
source(file.path(ROOT, "R", "00_theme.R"))

OUT_DIR <- file.path(ROOT, "output", "charts")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
sku_master_full   <- read_frame("sku_master_full")
time_to_shelf_sku <- read_frame("time_to_shelf_sku")
retailer_pnl      <- read_frame("retailer_pnl")
chargebacks_enriched     <- read_frame("chargebacks_enriched")

save_chart <- function(p, name, w = 10, h = 5.5, dpi = 300) {
  rds_path <- file.path(OUT_DIR, paste0(name, ".rds"))
  png_path <- file.path(OUT_DIR, paste0(name, ".png"))
  svg_path <- file.path(OUT_DIR, paste0(name, ".svg"))
  saveRDS(p, rds_path)
  ggsave(png_path, p, width = w, height = h, dpi = dpi, bg = LL_CANVAS)
  ggsave(svg_path, p, width = w, height = h, bg = LL_CANVAS, device = svglite::svglite)
  cat(sprintf("  %s.rds (%4.1f KB)  +  %s.png (%4.0f KB)  +  %s.svg (%4.0f KB)\n",
              name, file.info(rds_path)$size / 1024,
              name, file.info(png_path)$size / 1024,
              name, file.info(svg_path)$size / 1024))
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
           fill  = LL_BAR_HIGHLIGHT,
           label.size = 0,
           label.padding = unit(0.30, "lines"),
           label.r = unit(0.05, "lines")) +
  annotate("label",
           x = n80, y = 0.80,
           label = sprintf("%d SKUs · 80%%", n80),
           hjust = -0.10, vjust = 1.4,
           size = 3.8, fontface = "bold",
           color = cinderhaven_palette$white,
           fill  = LL_BAR_HIGHLIGHT,
           label.size = 0,
           label.padding = unit(0.30, "lines"),
           label.r = unit(0.05, "lines")) +

  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, 1.02),
                     expand = expansion(mult = c(0, 0))) +
  scale_x_continuous(breaks = pretty_breaks(),
                     expand = expansion(mult = c(0.01, 0.02))) +

  labs(title    = sprintf("%d SKUs drive half the total chargeback bill", n50),
       subtitle = "Cumulative share of chargeback dollars by SKU rank, 18 months",
       x        = "SKUs ranked from highest chargeback total to lowest",
       y        = NULL,
       caption  = src_caption("Cinderhaven chargeback ledger, 18 months")) +
  theme_cinderhaven()

save_chart(p1, "01_chargeback_pareto", h = 5.5)

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

  scale_fill_manual(values = risk_band_colors, guide = "none") +
  scale_x_continuous(limits = c(0, max(tier_summary$mean_days) * 1.25),
                     breaks = seq(0, 50, 10),
                     expand = expansion(mult = c(0, 0))) +
  scale_y_discrete(expand = expansion(add = c(0.6, 1.0))) +
  coord_cartesian(clip = "off") +

  labs(title    = wrap_title("Worst-data SKUs take three times as long to reach the shelf"),
       subtitle = "Days from store authorization to first sale, by data-quality tier",
       x        = "Mean days from authorization to first sale",
       y        = NULL,
       caption  = src_caption("Cinderhaven authorization log + sales data; tier mean across SKUs in tier")) +
  theme_cinderhaven_horizontal() +
  theme(axis.text.y = element_text(size = 11, face = "bold"))

save_chart(p2, "02_time_to_shelf", h = 5.5)

# ---- 3. True net margin by retailer (grouped bars) -----------------------

cat("\n[3/4] True net margin by retailer (grouped bars)\n")

contracted <- c("Walmart", "Whole Foods", "Costco")

c3_pnl <- retailer_pnl |>
  filter(retailer %in% contracted) |>
  arrange(desc(gross_revenue)) |>
  mutate(retailer = factor(retailer, levels = retailer))

c3_long <- c3_pnl |>
  transmute(retailer,
            "Gross revenue"    = gross_revenue,
            "Trade spend"      = trade_spend_total,
            "Chargebacks"      = chargeback_total,
            "Net contribution" = net_contribution) |>
  pivot_longer(-retailer, names_to = "component", values_to = "value") |>
  mutate(component = factor(component,
    levels = c("Gross revenue", "Trade spend",
               "Chargebacks", "Net contribution")))

bar_palette <- c(
  "Gross revenue"    = LL_CHICAGO,
  "Trade spend"      = LL_CHICAGO_LIGHT,
  "Chargebacks"      = LL_TOKYO,
  "Net contribution" = LL_CHICAGO)

c3_long$label <- fmt_dollar_short(c3_long$value)

p3 <- ggplot(c3_long, aes(x = value, y = fct_rev(component), fill = component)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = label),
            hjust = 1.1, color = "white", fontface = "bold", size = 3.6) +
  scale_fill_manual(values = bar_palette, guide = "none") +
  scale_x_continuous(labels = label_dollar(scale = 1e-6, suffix = "M"),
                     expand = expansion(mult = c(0, 0.08))) +
  facet_wrap(~ retailer, ncol = 1, scales = "free_x") +
  labs(title    = wrap_title("Walmart wins on dollars; Whole Foods wins on margin"),
       subtitle = "Gross revenue, trade spend, chargebacks, and net contribution by retailer",
       x        = NULL,
       y        = NULL,
       caption  = src_caption("Cinderhaven sales + cost data + chargeback ledger, trailing 12 months")) +
  theme_cinderhaven_horizontal() +
  theme(axis.text.y = element_text(size = 11),
        strip.text  = element_text(size = 12, face = "bold",
                                   color = LL_INK,
                                   family = "Playfair Display"))

save_chart(p3, "03_retailer_net_margin", h = 7)

# ---- 4. Fix ROI ----------------------------------------------------------

cat("\n[4/4] Fix ROI\n")

# Numbers come from chargebacks_enriched (canonical source) and
# sku_master_full (defect counts). Effort-per-defect minutes are from
# the methodology appendix; SKU counts and hours are computed from data.

reason_amts <- chargebacks_enriched |>
  group_by(reason) |>
  summarise(amt_36mo = sum(amount), .groups = "drop")

amt_36 <- function(r) {
  v <- reason_amts$amt_36mo[reason_amts$reason == r]
  if (length(v) == 0) 0 else v
}

n_barcode_skus <- sum(!sku_master_full$gtin_valid | !sku_master_full$upc_valid, na.rm = TRUE)
barcode_hours  <- sum((!sku_master_full$gtin_valid) * 10 +
                      (!sku_master_full$upc_valid)  * 10, na.rm = TRUE) / 60

n_proddata_skus <- sum(sku_master_full$missing_brand_owner |
                       sku_master_full$missing_country, na.rm = TRUE)
proddata_hours  <- sum(sku_master_full$missing_brand_owner * 10 +
                       sku_master_full$missing_country     * 30, na.rm = TRUE) / 60

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
  amt_36mo = c(amt_36("Label / barcode fine"),
               amt_36("Pricing error"),
               amt_36("Damaged goods"))
) |>
  filter(hours > 0) |>
  mutate(annual_saved = amt_36mo * 12 / 36,
         per_hour     = ifelse(hours > 0, annual_saved / hours, 0),
         is_top       = per_hour == max(per_hour),
         label        = sprintf(
           "%s saved per hour  ·  %s/year  ·  %.1f hours total",
           fmt_dollar_short(per_hour),
           fmt_dollar_short(annual_saved),
           hours))

if (nrow(fix_roi) > 0 && any(fix_roi$per_hour > 0)) {
  fix_roi <- fix_roi |> mutate(action = fct_reorder(action, per_hour))
}

p4 <- ggplot(fix_roi, aes(per_hour, action, fill = is_top)) +
  geom_col(width = 0.55) +
  scale_fill_manual(values = c(`TRUE` = LL_BAR_HIGHLIGHT,
                               `FALSE` = LL_BAR_DEFAULT),
                    guide = "none") +
  geom_text(aes(label = label),
            hjust = -0.04, size = 3.7,
            color = cinderhaven_palette$text) +

  scale_x_continuous(labels = label_dollar(scale = 1e-3, suffix = "k"),
                     expand = expansion(mult = c(0, 0.65))) +

  labs(title    = wrap_title(sprintf("%.0f hours of barcode fixes address the data-attributable chargebacks",
                          barcode_hours)),
       subtitle = "Annualized chargeback dollars saved per hour of effort, by fix action",
       x        = "Saved per hour of effort",
       y        = NULL,
       caption  = src_caption("Cinderhaven chargeback ledger; effort estimates per the methodology appendix")) +
  theme_cinderhaven_horizontal() +
  theme(axis.text.y = element_text(size = 10))

save_chart(p4, "04_fix_roi", h = 4.5)

cat("\nDone. ", length(list.files(OUT_DIR, pattern = "^0[1-4]_.*\\.rds$")),
    " ggplot objects + ", length(list.files(OUT_DIR, pattern = "^0[1-4]_.*\\.png$")),
    " PNGs in: ", OUT_DIR, "\n", sep = "")
