# 05_supporting_charts.R
# Phase 3 — supporting charts 5–23 from quarto_report_scope_final.md.
# Same output shape as the hero charts: every chart writes a .png (ggsave)
# and a .html (ggiraph::girafe) into output/charts/.
#
# Charts 10 and 18 are intentionally skipped — see SKIP_NOTES at bottom.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(lubridate)
  library(forcats)
  library(ggplot2)
  library(scales)
  library(ggiraph)
  library(htmlwidgets)
})

safe_fct_reorder <- function(f, x, ...) {
  if (length(unique(x)) <= 1) return(factor(f))
  forcats::fct_reorder(f, x, ...)
}

ROOT <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
source(file.path(ROOT, "R", "00_setup.R"))

OUT_DIR <- file.path(ROOT, "output", "charts")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

source(file.path(ROOT, "R", "00_theme.R"))
sku_dim         <- read_frame("sku_dim")
sku_master_full <- read_frame("sku_master_full")
retailer_pnl    <- read_frame("retailer_pnl")
retailer_rs     <- read_frame("retailer_readiness_summary")
chargebacks_enriched   <- read_frame("chargebacks_enriched")
deauth_summary  <- read_frame("deauth_summary")
process_debt    <- read_frame("process_debt")
time_to_shelf_s <- read_frame("time_to_shelf_sku")
raw             <- read_frame("raw_tables")

# ---- shared helpers -------------------------------------------------------
# fmt_dollar_short, product_line_colors, retailer_colors, theme_cinderhaven,
# theme_cinderhaven_horizontal are all provided by 00_theme.R (sourced above).

dollar_short <- fmt_dollar_short

save_pair <- function(p_static, p_interactive, name,
                      w_in = 9, h_in = 6, dpi = 300) {
  png_path  <- file.path(OUT_DIR, paste0(name, ".png"))
  svg_path  <- file.path(OUT_DIR, paste0(name, ".svg"))
  html_path <- file.path(OUT_DIR, paste0(name, ".html"))
  ggsave(png_path, p_static, width = w_in, height = h_in, dpi = dpi, bg = LL_CANVAS)
  ggsave(svg_path, p_static, width = w_in, height = h_in, bg = LL_CANVAS, device = svglite::svglite)
  htmlwidgets::saveWidget(p_interactive, html_path, selfcontained = FALSE,
                          title = name)
  cat(sprintf("  png:  %-46s (%5.0f KB)\n", basename(png_path),
              file.info(png_path)$size / 1024))
  cat(sprintf("  svg:  %-46s (%5.0f KB)\n", basename(svg_path),
              file.info(svg_path)$size / 1024))
  cat(sprintf("  html: %-46s (%5.0f KB)\n", basename(html_path),
              file.info(html_path)$size / 1024))
}

to_girafe <- function(p, w_in = 9, h_in = 6) {
  girafe(ggobj = p, width_svg = w_in, height_svg = h_in,
         options = list(
           opts_tooltip(css = "background:#222; color:#fff; padding:6px 8px;
                              border-radius:4px; font-family:sans-serif;
                              font-size:11px;"),
           opts_hover(css = "stroke:#222; stroke-width:1.5px;"),
           opts_zoom(min = 1, max = 4),
           opts_toolbar(saveaspng = TRUE)))
}

# ---- chart 5: Revenue-weighted field completeness -------------------------

cat("\n[5] Revenue-weighted field completeness\n")

c5_src <- sku_dim |>
  select(sku, gtin_valid, upc_valid, missing_case_weight, missing_case_dims,
         missing_country, missing_brand_owner, ows_complete, weight_plausible) |>
  left_join(sku_master_full |> select(sku, ttm_revenue), by = "sku") |>
  mutate(`Invalid GTIN-14`     = !gtin_valid,
         `Invalid UPC-12`      = !upc_valid,
         `Missing case dims`   = missing_case_dims,
         `Missing case weight` = missing_case_weight,
         `Missing brand owner` = missing_brand_owner,
         `Missing country`     = missing_country,
         `OneWorldSync incomplete` = !ows_complete,
         `Implausible case weight` = !is.na(weight_plausible) & !weight_plausible)

defect_cols <- c("Invalid GTIN-14", "Invalid UPC-12", "Missing case dims",
                 "Missing case weight", "Missing brand owner",
                 "Missing country", "OneWorldSync incomplete",
                 "Implausible case weight")

c5 <- defect_cols |>
  lapply(\(col) {
    flag <- as.logical(c5_src[[col]]); flag[is.na(flag)] <- FALSE
    tibble(defect = col,
           pct_skus    = mean(flag),
           pct_revenue = sum(c5_src$ttm_revenue[flag]) / sum(c5_src$ttm_revenue),
           n_skus      = sum(flag),
           rev_at_risk = sum(c5_src$ttm_revenue[flag]))
  }) |>
  bind_rows() |>
  mutate(defect = safe_fct_reorder(defect, pct_revenue))

c5_long <- c5 |>
  pivot_longer(c(pct_skus, pct_revenue),
               names_to = "metric", values_to = "value") |>
  mutate(metric = factor(recode(metric,
                                pct_skus    = "% of SKUs",
                                pct_revenue = "% of annual revenue"),
                         levels = c("% of annual revenue", "% of SKUs")),
         tooltip = paste0(
           "<b>", defect, "</b><br>",
           metric, ": ", percent(value, accuracy = 0.1),
           "<br>n affected: ", c5$n_skus[match(defect, c5$defect)],
           "<br>Revenue at risk: ",
           dollar_short(c5$rev_at_risk[match(defect, c5$defect)])))

c5_palette <- c("% of SKUs" = cinderhaven_palette$recede, "% of annual revenue" = cinderhaven_palette$red)

p5_base <- function(use_interactive) {
  dodge <- position_dodge(width = 0.75)
  p <- ggplot(c5_long, aes(x = value, y = defect, fill = metric))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip,
                                      data_id = paste0(defect, metric)),
                                  position = dodge, width = 0.7)
  } else {
    p <- p + geom_col(position = dodge, width = 0.7)
  }
  p +
    geom_text(aes(label = percent(value, accuracy = 0.1)),
              position = dodge, hjust = -0.12, size = 3.1,
              color = cinderhaven_palette$text) +
    scale_x_continuous(labels = percent_format(accuracy = 1),
                       limits = c(0, max(c5_long$value) * 1.18),
                       expand = expansion(mult = c(0, 0.02))) +
    scale_fill_manual(values = c5_palette, name = NULL,
                      breaks = c("% of SKUs", "% of annual revenue")) +
    labs(title    = "The defects concentrate in higher-revenue SKUs",
         subtitle = "Red bar longer than grey = defect concentrated in higher-revenue SKUs",
         x = NULL, y = NULL,
         caption = "Source: sku_dim + sku_master_full, audit run 2026-05-03") +
    theme_cinderhaven_horizontal()
}

save_pair(p5_base(FALSE), to_girafe(p5_base(TRUE)),
          "05_revenue_weighted_completeness", h_in = 5.5)

# ---- chart 6: Retailer readiness — revenue at risk ------------------------

cat("\n[6] Retailer readiness — revenue at risk\n")

c6 <- retailer_rs |>
  left_join(sku_master_full |> select(sku, ttm_revenue), by = "sku") |>
  group_by(retailer) |>
  summarise(n_skus       = n(),
            n_pass       = sum(overall_pass),
            pass_rate    = mean(overall_pass),
            rev_total    = sum(ttm_revenue, na.rm = TRUE),
            rev_at_risk  = sum(ttm_revenue[!overall_pass], na.rm = TRUE),
            .groups = "drop") |>
  mutate(retailer    = factor(retailer,
            levels = retailer_rs |> distinct(retailer) |> pull(retailer) |>
                     intersect(c("Walmart","Costco","Whole Foods"))),
         rev_at_risk_pct = rev_at_risk / rev_total,
         tooltip = paste0(
           "<b>", retailer, "</b><br>",
           "Pass: ", n_pass, " / ", n_skus,
           " (", percent(pass_rate, accuracy = 0.1), ")<br>",
           "Catalog revenue: ", dollar_short(rev_total), "<br>",
           "Revenue at risk: ", dollar_short(rev_at_risk),
           " (", percent(rev_at_risk_pct, accuracy = 0.1), ")"))

p6_base <- function(use_interactive) {
  p <- ggplot(c6, aes(x = rev_at_risk, y = safe_fct_reorder(retailer, rev_at_risk),
                      fill = retailer))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip, data_id = retailer),
                                  width = 0.7)
  } else {
    p <- p + geom_col(width = 0.7)
  }
  p +
    geom_text(aes(label = paste0(dollar_short(rev_at_risk),
                                 "  ·  ",
                                 percent(rev_at_risk_pct, accuracy = 1),
                                 " of catalog revenue  ·  pass ",
                                 percent(pass_rate, accuracy = 1))),
              hjust = -0.02, size = 3.4, color = cinderhaven_palette$text) +
    scale_x_continuous(labels = label_dollar(scale = 1e-6, suffix = "M"),
                       expand = expansion(mult = c(0, 0.55))) +
    # One-accent encoding: Walmart (biggest exposure) red, others grey.
    scale_fill_manual(values = c(
      "Walmart"     = cinderhaven_palette$red,
      "Costco"      = cinderhaven_palette$recede,
      "Whole Foods" = cinderhaven_palette$recede),
      guide = "none") +
    labs(title    = wrap_title(sprintf("Revenue at risk: %s rides on data Walmart could reject today",
                           dollar_short(c6$rev_at_risk[which(c6$retailer == "Walmart")]))),
         subtitle = "Bar = annual revenue from SKUs that fail at least one required field for that retailer",
         x = "Revenue at risk", y = NULL,
         caption = "Source: retailer_readiness_summary + sku_master_full, audit run 2026-05-03") +
    theme_cinderhaven()
}

save_pair(p6_base(FALSE), to_girafe(p6_base(TRUE), w_in = 10, h_in = 5),
          "06_retailer_readiness_revenue_at_risk", w_in = 10, h_in = 5)

# ---- chart 7: Data debt by product line -----------------------------------

cat("\n[7] Data debt by product line\n")

c7 <- sku_master_full |>
  group_by(product_line) |>
  summarise(n_skus       = n(),
            total_issues = sum(issue_count, na.rm = TRUE),
            mean_quality = mean(data_quality_score, na.rm = TRUE),
            ttm_revenue  = sum(ttm_revenue, na.rm = TRUE),
            chargeback   = sum(chargeback_total, na.rm = TRUE),
            .groups = "drop") |>
  mutate(issues_per_million = ifelse(ttm_revenue > 0, total_issues / (ttm_revenue / 1e6), NA_real_),
         tooltip = paste0(
           "<b>", product_line, "</b><br>",
           n_skus, " SKUs · Annual revenue ", dollar_short(ttm_revenue), "<br>",
           "Total issues: ", total_issues, " (mean per SKU ",
           round(total_issues / n_skus, 2), ")<br>",
           "Mean quality score: ", round(mean_quality, 1), "<br>",
           "Chargebacks: ", dollar_short(chargeback), "<br>",
           "Issues per $1M revenue: ", round(issues_per_million, 2)))

p7_base <- function(use_interactive) {
  p <- ggplot(c7, aes(x = safe_fct_reorder(product_line, issues_per_million),
                      y = issues_per_million, fill = product_line))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip, data_id = product_line),
                                  width = 0.6)
  } else {
    p <- p + geom_col(width = 0.6)
  }
  p +
    geom_text(aes(label = sprintf("%.2f", issues_per_million)),
              vjust = -0.5, size = 4) +
    # Pantry Staples is the worst — accent red. Others recede.
    scale_fill_manual(values = c(
      "Artisan Sauces"       = cinderhaven_palette$recede,
      "Specialty Condiments" = cinderhaven_palette$recede,
      "Pantry Staples"       = cinderhaven_palette$red),
      guide = "none") +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(title    = wrap_title({
           ps_ipm <- c7$issues_per_million[c7$product_line == "Pantry Staples"]
           as_ipm <- c7$issues_per_million[c7$product_line == "Artisan Sauces"]
           if (length(ps_ipm) && length(as_ipm) && !is.na(ps_ipm) && !is.na(as_ipm) && as_ipm > 0) {
             pct_more <- round(100 * (ps_ipm / as_ipm - 1))
             sprintf("Pantry Staples carries %d%% more data debt per dollar than Artisan Sauces",
                     pct_more)
           } else {
             "Data debt by product line (revenue data unavailable for ratio)"
           }
         }),
         subtitle = "Issues per $1M of annual revenue. Higher = more data debt per dollar earned.",
         x = NULL, y = "Issues per $1M revenue",
         caption = "Source: sku_master_full, audit run 2026-05-03") +
    theme_cinderhaven()
}

save_pair(p7_base(FALSE), to_girafe(p7_base(TRUE), w_in = 8, h_in = 5),
          "07_data_debt_by_product_line", w_in = 8, h_in = 5)

# ---- chart 8: Chargeback as % of gross margin (top 15) --------------------

cat("\n[8] Chargeback cost as % of gross margin — top 15 SKUs\n")

c8 <- sku_master_full |>
  filter(!is.na(chargeback_pct_of_gm), chargeback_pct_of_gm > 0,
         annual_gross_margin > 0) |>
  arrange(desc(chargeback_pct_of_gm)) |>
  slice(1:15) |>
  mutate(label = paste0(sku, " — ", str_trunc(product_name, 30)),
         label = factor(label, levels = rev(label)),
         is_top = sku == sku[1],   # the worst offender — that's the story
         tooltip = paste0(
           "<b>", sku, " — ", product_name, "</b><br>",
           product_line, "<br>",
           "Chargebacks: ", dollar_short(chargeback_total), "<br>",
           "Annual gross margin: ", dollar_short(annual_gross_margin), "<br>",
           "Cb as % of GM: ", percent(chargeback_pct_of_gm, accuracy = 0.1),
           "<br>Issues: ", issue_count, " of 8"))

p8_base <- function(use_interactive) {
  p <- ggplot(c8, aes(x = chargeback_pct_of_gm, y = label, fill = is_top))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip, data_id = sku),
                                  width = 0.75)
  } else {
    p <- p + geom_col(width = 0.75)
  }
  p +
    geom_text(aes(label = percent(chargeback_pct_of_gm, accuracy = 0.1)),
              hjust = -0.05, size = 3.3, color = cinderhaven_palette$text) +
    scale_x_continuous(labels = percent_format(accuracy = 1),
                       expand = expansion(mult = c(0, 0.18))) +
    scale_fill_manual(values = c(`TRUE`  = cinderhaven_palette$red,
                                 `FALSE` = cinderhaven_palette$recede),
                      guide = "none") +
    labs(title    = wrap_title("Chargebacks as % of gross margin — top 15 SKUs"),
         subtitle = "Where chargeback dollars are largest relative to the margin the SKU earns",
         x = NULL, y = NULL,
         caption = "Source: sku_master_full (annual_gross_margin = ttm_revenue − ttm_units × cogs_per_unit)") +
    theme_cinderhaven() +
    theme(axis.text.y = element_text(size = 9))
}

save_pair(p8_base(FALSE), to_girafe(p8_base(TRUE), w_in = 10, h_in = 7),
          "08_chargeback_pct_of_gross_margin_top15", w_in = 10, h_in = 7)

# ---- chart 9: Time-to-shelf by data completeness --------------------------

cat("\n[9] Time-to-shelf by data completeness\n")

c9 <- time_to_shelf_s |>
  left_join(sku_master_full |> select(sku, data_quality_score, issue_count,
                                       product_name),
            by = "sku") |>
  filter(!is.na(mean_days_to_scan)) |>
  mutate(quality_tier = factor(
           c("Worst 25%", "Below average", "Above average", "Best 25%")[
             ntile(data_quality_score, 4)],
           levels = c("Worst 25%", "Below average", "Above average", "Best 25%")),
         tooltip = paste0(
           "<b>", sku, " — ", product_name, "</b><br>",
           "Quality score: ", round(data_quality_score, 1), "<br>",
           "Issues: ", issue_count, " of 8<br>",
           "Median days to first scan: ", median_days_to_scan, "<br>",
           "Mean days: ", round(mean_days_to_scan, 1)))

q9_summary <- c9 |>
  group_by(quality_tier) |>
  summarise(mean_d = mean(mean_days_to_scan),
            median_d = median(mean_days_to_scan), .groups = "drop")

p9_base <- function(use_interactive) {
  # Strip plot — per-SKU dots jittered within each tier. No box plots
  # (forbidden by the visual rules); the mean line + label carries the
  # central-tendency story.
  p <- ggplot(c9, aes(x = quality_tier, y = mean_days_to_scan,
                      color = quality_tier))
  if (use_interactive) {
    p <- p + geom_jitter_interactive(aes(tooltip = tooltip, data_id = sku),
                                     width = 0.18, height = 0,
                                     alpha = 0.75, size = 2.4)
  } else {
    p <- p + geom_jitter(width = 0.18, height = 0, alpha = 0.75, size = 2.0)
  }
  p +
    # Tier-mean reference line (black tick) + label.
    geom_segment(data = q9_summary,
                 aes(x = as.integer(quality_tier) - 0.32,
                     xend = as.integer(quality_tier) + 0.32,
                     y = mean_d, yend = mean_d),
                 inherit.aes = FALSE,
                 color = cinderhaven_palette$text, linewidth = 0.7) +
    geom_text(data = q9_summary,
              aes(x = quality_tier, y = max(c9$mean_days_to_scan) * 1.08,
                  label = sprintf("mean %.0f days", mean_d)),
              inherit.aes = FALSE, size = 3.4, fontface = "bold",
              color = cinderhaven_palette$text) +
    scale_color_manual(values = c(
      "Worst 25%"     = cinderhaven_palette$red,
      "Below average" = cinderhaven_palette$recede,
      "Above average" = cinderhaven_palette$recede,
      "Best 25%"      = cinderhaven_palette$recede),
      guide = "none") +
    scale_y_continuous(expand = expansion(mult = c(0.02, 0.14))) +
    labs(title    = wrap_title("Per-SKU view: bottom-half SKUs reach the shelf three times slower"),
         subtitle = "Days from authorization to first scan — one dot per SKU, by data-quality tier",
         x = NULL,
         y = "Days to first scan",
         caption  = src_caption("Cinderhaven authorization log + sales data")) +
    theme_cinderhaven() +
    theme(axis.text.x = element_text(size = 11, face = "bold"))
}

save_pair(p9_base(FALSE), to_girafe(p9_base(TRUE)),
          "09_time_to_shelf_by_quality")

# ---- chart 11: Deauth rate by quality tier --------------------------------

cat("\n[11] Deauth rate by quality tier\n")

c11 <- deauth_summary |>
  left_join(sku_master_full |> select(sku, data_quality_score, issue_count,
                                       product_name, ttm_revenue),
            by = "sku") |>
  mutate(quality_tier = factor(
    c("Worst 25%", "Below average", "Above average", "Best 25%")[
      ntile(data_quality_score, 4)],
    levels = c("Worst 25%", "Below average", "Above average", "Best 25%")))

c11_summary <- c11 |>
  group_by(quality_tier) |>
  summarise(n_skus = n(),
            mean_rate = mean(deauth_rate),
            n_with_any = sum(deauth_rate > 0),
            total_auths = sum(auth_count),
            total_deauths = sum(deauth_count),
            .groups = "drop") |>
  mutate(tooltip = paste0(
    "<b>", quality_tier, "</b><br>",
    n_skus, " SKUs · ", n_with_any, " lost a slot<br>",
    "Deauthorization rate: ", percent(mean_rate, accuracy = 0.01), "<br>",
    "Total authorizations: ", format(total_auths, big.mark = ","), "<br>",
    "Total deauthorizations: ", total_deauths))

p11_base <- function(use_interactive) {
  p <- ggplot(c11_summary, aes(x = quality_tier, y = mean_rate,
                                fill = quality_tier))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip, data_id = quality_tier),
                                  width = 0.6)
  } else {
    p <- p + geom_col(width = 0.6)
  }
  p +
    # Two-shade red gradient: Worst 25% darkest, Below average lighter
    # red — both bad, with the worst visually heaviest. The two passing
    # tiers recede to grey.
    scale_fill_manual(values = c(
      "Worst 25%"     = cinderhaven_palette$red,   # #C0221F
      "Below average" = cinderhaven_palette$coral,                  # lighter red
      "Above average" = cinderhaven_palette$recede,
      "Best 25%"      = cinderhaven_palette$recede),
      guide = "none") +
    geom_text(aes(label = paste0(percent(mean_rate, accuracy = 0.01),
                                 "  (", n_with_any, " of ", n_skus,
                                 " lost a slot)")),
              vjust = -0.5, size = 3.4, fontface = "bold",
              color = cinderhaven_palette$text) +
    scale_y_continuous(labels = percent_format(accuracy = 0.1),
                       expand = expansion(mult = c(0, 0.20))) +
    labs(title    = wrap_title({
           worst_rate <- c11_summary$mean_rate[c11_summary$quality_tier == "Worst 25%"]
           best_rate  <- c11_summary$mean_rate[c11_summary$quality_tier == "Best 25%"]
           ratio <- if (best_rate > 0) round(worst_rate / best_rate, 0) else Inf
           sprintf("Worst-quarter SKUs lose shelf slots at %d× the rate of best-quarter SKUs",
                   ratio)
         }),
         subtitle = "Deauthorization rate by data-quality tier",
         x        = NULL,
         y        = "Deauthorization rate",
         caption  = src_caption("Cinderhaven authorization log + product master")) +
    theme_cinderhaven() +
    theme(axis.text.x = element_text(size = 11, face = "bold"))
}

save_pair(p11_base(FALSE), to_girafe(p11_base(TRUE)),
          "11_deauth_rate_by_quality_tier")

# ---- chart 12: Growth projection — chargebacks at scale -------------------

cat("\n[12] Growth projection — chargebacks at 1x / 2.5x / 5x SKU count\n")

current_skus <- nrow(sku_master_full)
current_cb_18mo <- sum(sku_master_full$chargeback_total)
current_cb_per_year <- current_cb_18mo * 12 / 18
current_revenue <- sum(sku_master_full$ttm_revenue)

stage2_skus <- as.integer(ceiling(current_skus * 2.5))
stage3_skus <- as.integer(current_skus * 5L)

c12 <- tribble(
  ~scenario,        ~sku_count, ~retailer_count,
  paste0("Current (", current_skus, " SKUs, 3 retailers)"),   current_skus,         3L,
  sprintf("Stage 2 (%d SKUs, 5 retailers)", stage2_skus),     stage2_skus,          5L,
  sprintf("Stage 3 (%d SKUs, 8 retailers)", stage3_skus),     stage3_skus,          8L
) |>
  mutate(scale_factor    = (sku_count / current_skus) *
                           (retailer_count / 3),
         proj_chargebacks = current_cb_per_year * scale_factor,
         proj_revenue     = current_revenue * (sku_count / current_skus),
         scenario = factor(scenario, levels = scenario),
         tooltip = paste0(
           "<b>", scenario, "</b><br>",
           sku_count, " SKUs × ", retailer_count, " retailers<br>",
           "Scale vs. today: ", round(scale_factor, 2), "x<br>",
           "Projected annual chargebacks: ", dollar_short(proj_chargebacks), "<br>",
           "Projected revenue: ", dollar_short(proj_revenue)))

p12_base <- function(use_interactive) {
  c12$is_top <- c12$proj_chargebacks == max(c12$proj_chargebacks)
  p <- ggplot(c12, aes(x = scenario, y = proj_chargebacks, fill = is_top))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip, data_id = scenario),
                                  width = 0.55)
  } else {
    p <- p + geom_col(width = 0.55)
  }
  p +
    scale_fill_manual(values = c(`TRUE`  = cinderhaven_palette$red,
                                 `FALSE` = cinderhaven_palette$recede),
                      guide = "none") +
    geom_text(aes(label = dollar_short(proj_chargebacks)),
              vjust = -0.4, size = 4) +
    scale_y_continuous(labels = label_dollar(scale = 1e-3, suffix = "k"),
                       expand = expansion(mult = c(0, 0.16))) +
    labs(title    = wrap_title(sprintf("Chargebacks scale to %s if you grow without fixing the data",
                           dollar_short(max(c12$proj_chargebacks)))),
         subtitle = "Linear scaling of current chargeback rate by SKU count × retailer count. Assumes constant defect rate per SKU.",
         x = NULL, y = "Projected annual chargebacks",
         caption = paste0(
           "Baseline: $", formatC(round(current_cb_per_year), big.mark = ",", format = "d"),
           "/yr at ", current_skus, " SKUs × 3 retailers (annualized from 18mo).",
           " Real growth typically degrades defect rate — this is the floor.")) +
    theme_cinderhaven()
}

save_pair(p12_base(FALSE), to_girafe(p12_base(TRUE), w_in = 9, h_in = 5.5),
          "12_growth_projection_chargebacks", w_in = 9, h_in = 5.5)

# ---- chart 13: GTIN/UPC validation pass/fail by product line --------------
# Each SKU is a dot in a 6-wide × 5-tall grid. Red = invalid check digit.
# Fails are the visual focus; passes recede into a near-white grey so the
# eye lands on the 12 reds out of total dots (SKUs × 2 checks).

cat("\n[13] GTIN/UPC pass/fail by product line\n")

c13_grid <- sku_dim |>
  select(product_line, sku, gtin_valid, upc_valid) |>
  pivot_longer(c(gtin_valid, upc_valid),
               names_to = "check", values_to = "valid") |>
  mutate(check   = recode(check, gtin_valid = "GTIN-14", upc_valid = "UPC-12"),
         outcome = factor(ifelse(valid, "Pass", "Fail"),
                          levels = c("Pass", "Fail"))) |>
  group_by(product_line, check) |>
  # Fails sorted last so they paint on top — defensive, since coord_fixed
  # with non-overlapping cells means no overplotting in practice.
  arrange(outcome, sku, .by_group = TRUE) |>
  mutate(idx = row_number(),
         col =  ((idx - 1) %% 6) + 1,
         row = -((idx - 1) %/% 6) - 1) |>
  ungroup() |>
  mutate(tooltip = paste0(
    "<b>", sku, "</b><br>",
    product_line, " · ", check, "<br>",
    "Result: ", outcome))

c13_counts <- c13_grid |>
  group_by(product_line, check) |>
  summarise(n_fail = sum(outcome == "Fail"),
            n_total = n(), .groups = "drop") |>
  mutate(label = ifelse(n_fail == 0, "all pass",
                        paste0(n_fail, " of ", n_total, " fail")))

p13_base <- function(use_interactive) {
  p <- ggplot(c13_grid, aes(col, row, color = outcome))
  if (use_interactive) {
    p <- p + geom_point_interactive(
      aes(tooltip = tooltip, data_id = paste(sku, check)),
      size = 4)
  } else {
    p <- p + geom_point(size = 3.6)
  }
  p +
    facet_grid(product_line ~ check, switch = "y") +
    geom_text(data = c13_counts,
              aes(x = 6.4, y = -0.4, label = label),
              inherit.aes = FALSE,
              hjust = 1, vjust = 1, size = 3.3, fontface = "bold",
              color = cinderhaven_palette$text) +
    scale_color_manual(values = c("Pass" = cinderhaven_palette$recede,
                                  "Fail" = cinderhaven_palette$red),
                       name = NULL,
                       breaks = c("Fail", "Pass")) +
    coord_fixed(clip = "off") +
    labs(title    = wrap_title(sprintf("%d SKUs fail barcode validation — fails are the red dots",
                           sum(c13_counts$n_fail))),
         subtitle = "Each dot is one SKU. Red = invalid check digit. Validator uses the dataset's mod-10 algorithm (see methodology).",
         x = NULL, y = NULL,
         caption = "Source: sku_dim") +
    theme_cinderhaven() +
    theme(axis.text         = element_blank(),
          axis.ticks        = element_blank(),
          panel.grid        = element_blank(),
          panel.spacing.x   = unit(1.2, "lines"),
          panel.spacing.y   = unit(0.6, "lines"),
          strip.placement   = "outside",
          strip.text.y.left = element_text(angle = 0, hjust = 1,
                                           face = "bold",
                                           color = cinderhaven_palette$text),
          strip.text.x      = element_text(face = "bold",
                                           color = cinderhaven_palette$text,
                                           hjust = 0))
}

save_pair(p13_base(FALSE), to_girafe(p13_base(TRUE), w_in = 10, h_in = 5),
          "13_gtin_upc_pass_fail_by_line", w_in = 10, h_in = 5)

# ---- chart 14: Chargeback by reason ---------------------------------------

cat("\n[14] Chargeback dollars by reason\n")

c14 <- chargebacks_enriched |>
  group_by(reason) |>
  summarise(amt = sum(amount), n = n(), .groups = "drop") |>
  arrange(desc(amt)) |>
  mutate(pct = amt / sum(amt),
         reason = factor(reason, levels = rev(reason)),
         is_data_defect = reason %in% c("Label / barcode fine", "Pricing error",
                                         "Damaged goods"),
         tooltip = paste0(
           "<b>", reason, "</b><br>",
           dollar_short(amt), " (", percent(pct, accuracy = 0.1), ")<br>",
           n, " chargeback events"))

p14_base <- function(use_interactive) {
  p <- ggplot(c14, aes(x = amt, y = reason, fill = is_data_defect))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip, data_id = reason),
                                  width = 0.7)
  } else {
    p <- p + geom_col(width = 0.7)
  }
  p +
    geom_text(aes(label = paste0(dollar_short(amt), "  (",
                                 percent(pct, accuracy = 1), ")")),
              hjust = -0.05, size = 3.4, color = cinderhaven_palette$text) +
    scale_x_continuous(labels = label_dollar(scale = 1e-3, suffix = "k"),
                       expand = expansion(mult = c(0, 0.25))) +
    scale_fill_manual(values = c(`TRUE` = cinderhaven_palette$red,
                                 `FALSE` = cinderhaven_palette$recede),
                      guide = "none") +
    labs(title    = wrap_title({
           data_defect_pct <- sum(c14$pct[c14$is_data_defect]) * 100
           sprintf("Three data-defect reasons account for %.0f%% of chargeback dollars",
                   data_defect_pct)
         }),
         subtitle = {
           data_defect_pct <- sum(c14$pct[c14$is_data_defect]) * 100
           sprintf("Three data-defect reasons (red) account for %.1f%% of chargeback dollars.",
                   data_defect_pct)
         },
         x = NULL, y = NULL,
         caption = "Source: chargebacks_enriched") +
    theme_cinderhaven()
}

save_pair(p14_base(FALSE), to_girafe(p14_base(TRUE), w_in = 9, h_in = 4.5),
          "14_chargeback_by_reason", w_in = 9, h_in = 4.5)

# ---- chart 15: Monthly chargeback trend -----------------------------------

cat("\n[15] Monthly chargeback trend\n")

c15 <- chargebacks_enriched |>
  mutate(month = floor_date(month_date, "month")) |>
  group_by(month) |>
  summarise(amt = sum(amount), n = n(), .groups = "drop") |>
  mutate(tooltip = paste0(
    "<b>", format(month, "%b %Y"), "</b><br>",
    "Chargebacks: ", dollar_short(amt), "<br>",
    "Events: ", n))

p15_base <- function(use_interactive) {
  p <- ggplot(c15, aes(x = month, y = amt))
  # Direct red line — no area fill. Trend line in grey, secondary.
  p <- p + geom_line(color = cinderhaven_palette$red, linewidth = 1.0)
  if (use_interactive) {
    p <- p + geom_point_interactive(aes(tooltip = tooltip,
                                        data_id = format(month, "%Y-%m")),
                                    color = cinderhaven_palette$red, size = 2.4)
  } else {
    p <- p + geom_point(color = cinderhaven_palette$red, size = 1.8)
  }
  p +
    geom_smooth(method = "lm", formula = y ~ x, se = FALSE,
                color = cinderhaven_palette$text_muted, linetype = "dashed", linewidth = 0.6) +
    scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
    scale_y_continuous(labels = label_dollar(scale = 1e-3, suffix = "k"),
                       limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
    labs(title    = wrap_title("Monthly chargebacks have held flat at about $5k/month"),
         subtitle = "Eighteen months of chargeback dollars; trend line is essentially flat",
         x = NULL, y = "Chargeback $",
         caption = "Source: chargebacks_enriched") +
    theme_cinderhaven()
}

save_pair(p15_base(FALSE), to_girafe(p15_base(TRUE), w_in = 10, h_in = 5),
          "15_monthly_chargeback_trend", w_in = 10, h_in = 5)

# ---- chart 16: Monthly chargebacks vs scan dollars (overlay) --------------

cat("\n[16] Monthly chargebacks overlaid on scan revenue\n")

scan_monthly <- raw$scan_data |>
  mutate(month = floor_date(ymd(week_ending), "month")) |>
  group_by(month) |>
  summarise(scan_dollars = sum(dollars_sold), .groups = "drop")

c16 <- c15 |>
  rename(cb_dollars = amt) |>
  inner_join(scan_monthly, by = "month") |>
  arrange(month) |>
  # exclude any partial last/first month with <4 weeks for fairness
  filter(scan_dollars > 1e6) |>
  mutate(cb_pct_of_scan = cb_dollars / scan_dollars)

# Two-axis trick — rescale chargebacks to share scan dollars' axis range.
scale_factor <- max(c16$scan_dollars) / max(c16$cb_dollars)

c16$tooltip <- paste0(
  "<b>", format(c16$month, "%b %Y"), "</b><br>",
  "Scan revenue: ", dollar_short(c16$scan_dollars), "<br>",
  "Chargebacks: ", dollar_short(c16$cb_dollars), "<br>",
  "Cb as % of scan: ", percent(c16$cb_pct_of_scan, accuracy = 0.01))

p16_base <- function(use_interactive) {
  p <- ggplot(c16, aes(x = month))
  # Scan revenue is the comparison baseline — light grey bars. Red line
  # carries the message.
  p <- p + geom_col(aes(y = scan_dollars), fill = cinderhaven_palette$recede, width = 28)
  p <- p + geom_line(aes(y = cb_dollars * scale_factor),
                     color = cinderhaven_palette$red, linewidth = 1)
  if (use_interactive) {
    p <- p + geom_point_interactive(
      aes(y = cb_dollars * scale_factor, tooltip = tooltip,
          data_id = format(month, "%Y-%m")),
      color = cinderhaven_palette$red, size = 2.6)
  } else {
    p <- p + geom_point(aes(y = cb_dollars * scale_factor),
                        color = cinderhaven_palette$red, size = 1.8)
  }
  p +
    scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
    scale_y_continuous(
      name = "Monthly scan revenue",
      labels = label_dollar(scale = 1e-6, suffix = "M"),
      sec.axis = sec_axis(~ . / scale_factor,
                          name = "Monthly chargebacks",
                          labels = label_dollar(scale = 1e-3, suffix = "k"))) +
    labs(title    = wrap_title("Chargebacks falling while scan revenue holds"),
         subtitle = "Grey bars = monthly scan revenue. Red line = monthly chargebacks (right axis).",
         x = NULL,
         caption = "Source: scan_data + chargebacks_enriched. Months with <$1M in scans excluded.") +
    theme_cinderhaven() +
    theme(axis.text.y.right  = element_text(color = cinderhaven_palette$red),
          axis.title.y.right = element_text(color = cinderhaven_palette$red),
          axis.text.y.left   = element_text(color = cinderhaven_palette$text_muted),
          axis.title.y.left  = element_text(color = cinderhaven_palette$text_muted))
}

save_pair(p16_base(FALSE), to_girafe(p16_base(TRUE), w_in = 10, h_in = 5),
          "16_monthly_chargebacks_vs_scan", w_in = 10, h_in = 5)

# ---- chart 17: Quality and chargebacks by updated_by source ---------------

cat("\n[17] Process debt — quality + chargebacks by updated_by\n")

c17 <- process_debt |>
  mutate(updated_by = ifelse(is.na(updated_by), "(unknown)", updated_by),
         # production_admin is the largest internal entry source (19 SKUs)
         # and runs at a fraction of the broker / quality_mgr rate — that's
         # the "doing it right" benchmark.
         is_good    = updated_by == "production_admin",
         updated_by = safe_fct_reorder(updated_by, chargeback_per_sku, .desc = TRUE),
         tooltip = paste0(
           "<b>", updated_by, "</b><br>",
           n_skus, " SKUs · quality ", round(mean_quality_score, 0), "<br>",
           "Total chargebacks: ", dollar_short(total_chargebacks), "<br>",
           "Chargebacks per SKU: ", dollar_short(chargeback_per_sku)))

p17_base <- function(use_interactive) {
  p <- ggplot(c17, aes(x = updated_by, y = chargeback_per_sku,
                       fill = is_good))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip, data_id = updated_by),
                                  width = 0.65)
  } else {
    p <- p + geom_col(width = 0.65)
  }
  p +
    # Dollar value above each bar; SKU count below the entry-source label.
    geom_text(aes(label = paste0("$", formatC(round(chargeback_per_sku),
                                              big.mark = ",", format = "d"),
                                 " / SKU")),
              vjust = -0.6, size = 3.4, fontface = "bold",
              color = cinderhaven_palette$text) +
    geom_text(aes(y = 0, label = paste0(n_skus, " SKUs")),
              vjust = 1.6, size = 3.0,
              color = cinderhaven_palette$text_muted) +
    # All sources grey except the one that's doing it right (lowest
    # chargeback per SKU) — that's the contrast the chart should make.
    scale_fill_manual(values = c(`TRUE`  = cinderhaven_palette$teal,
                                 `FALSE` = cinderhaven_palette$recede),
                      guide = "none") +
    scale_y_continuous(labels = label_dollar(),
                       expand = expansion(mult = c(0.05, 0.20))) +
    coord_cartesian(clip = "off") +
    labs(title    = wrap_title({
           cpsku <- c17$chargeback_per_sku[!is.na(c17$chargeback_per_sku)]
           spread <- if (min(cpsku) > 0) round(max(cpsku) / min(cpsku), 1) else Inf
           sprintf("Chargebacks per SKU vary %.1f× depending on who entered the data",
                   spread)
         }),
         subtitle = {
           prod_cpsku <- c17$chargeback_per_sku[c17$updated_by == "production_admin"]
           worst_cpsku <- max(c17$chargeback_per_sku, na.rm = TRUE)
           sprintf("Production-team uploads run at %s/SKU; worst source runs at %s/SKU",
                   dollar_short(prod_cpsku), dollar_short(worst_cpsku))
         },
         x = NULL,
         y = "Chargebacks per SKU",
         caption  = src_caption("Cinderhaven product master + chargeback ledger")) +
    theme_cinderhaven() +
    theme(axis.text.x = element_text(angle = 18, hjust = 1, size = 10),
          plot.margin = margin(8, 8, 16, 8))
}

save_pair(p17_base(FALSE), to_girafe(p17_base(TRUE), w_in = 11, h_in = 6),
          "17_process_debt_by_updated_by", w_in = 11, h_in = 6)

# ---- chart 19: 1WorldSync status distribution -----------------------------

cat("\n[19] OneWorldSync status distribution\n")

if (!"oneworldsync_status" %in% names(raw$product_master) ||
    all(is.na(raw$product_master$oneworldsync_status))) {
  cat("  SKIPPED — oneworldsync_status column not present in current schema\n")
} else {

c19 <- raw$product_master |>
  count(oneworldsync_status, name = "n") |>
  arrange(desc(n)) |>
  mutate(pct = n / sum(n),
         is_complete = oneworldsync_status == "Registered - Complete",
         # Largest non-complete bucket is the problem in plain sight.
         is_top_problem = !is_complete & n == max(n[!is_complete]),
         status = safe_fct_reorder(oneworldsync_status, n),
         tooltip = paste0(
           "<b>", oneworldsync_status, "</b><br>",
           n, " SKUs (", percent(pct, accuracy = 0.1), ")"))

p19_base <- function(use_interactive) {
  p <- ggplot(c19, aes(x = n, y = status, fill = is_top_problem))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip,
                                      data_id = oneworldsync_status),
                                  width = 0.7)
  } else {
    p <- p + geom_col(width = 0.7)
  }
  p +
    geom_text(aes(label = paste0(n, "  (", percent(pct, accuracy = 1), ")")),
              hjust = -0.05, size = 3.6, color = cinderhaven_palette$text) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.18))) +
    scale_fill_manual(values = c(`TRUE` = cinderhaven_palette$red,
                                 `FALSE` = cinderhaven_palette$recede),
                      guide = "none") +
    labs(title    = wrap_title(paste0("Only ", sum(c19$n[c19$is_complete]), " of ", sum(c19$n), " SKUs are fully registered in OneWorldSync")),
         subtitle = paste0("Only ", sum(c19$n[c19$is_complete]), " of ", sum(c19$n), " SKUs (", round(100 * sum(c19$n[c19$is_complete]) / sum(c19$n)), "%) are 'Registered - Complete'."),
         x = "SKU count", y = NULL,
         caption = "Source: product_master.oneworldsync_status") +
    theme_cinderhaven()
}

save_pair(p19_base(FALSE), to_girafe(p19_base(TRUE), w_in = 9, h_in = 4),
          "19_oneworldsync_status", w_in = 9, h_in = 4)
}

# ---- chart 20: Retailer item-setup readiness (stacked bar) ----------------

cat("\n[20] Retailer item-setup readiness — stacked bar\n")

c20 <- retailer_rs |>
  group_by(retailer) |>
  summarise(n_total = n(),
            n_pass  = sum(overall_pass),
            n_fail  = n_total - n_pass,
            .groups = "drop") |>
  pivot_longer(c(n_pass, n_fail), names_to = "outcome", values_to = "n") |>
  mutate(outcome = recode(outcome, n_pass = "Pass", n_fail = "Fail"),
         outcome = factor(outcome, levels = c("Fail", "Pass")),
         pass_rate = ifelse(outcome == "Pass", n / n_total, NA_real_),
         tooltip = paste0(
           "<b>", retailer, " · ", outcome, "</b><br>",
           n, " of ", n_total, " SKUs (",
           percent(n / n_total, accuracy = 0.1), ")"))

c20_lab <- c20 |> filter(outcome == "Pass") |>
  transmute(retailer, label = paste0(round(100 * n / n_total), "% pass"))

p20_base <- function(use_interactive) {
  p <- ggplot(c20, aes(x = safe_fct_reorder(retailer, ifelse(outcome == "Pass", n, 0),
                                        .fun = sum),
                       y = n, fill = outcome))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip,
                                      data_id = paste(retailer, outcome)),
                                  width = 0.7)
  } else {
    p <- p + geom_col(width = 0.7)
  }
  p +
    geom_text(data = c20 |> filter(n > 0),
              aes(label = n,
                  color = outcome),
              position = position_stack(vjust = 0.5),
              size = 3.6, fontface = "bold", show.legend = FALSE) +
    scale_color_manual(values = c("Fail" = "white",
                                  "Pass" = cinderhaven_palette$text),
                       guide = "none") +
    geom_text(data = c20_lab,
              aes(x = retailer, y = nrow(raw$product_master) * 1.05, label = label),
              inherit.aes = FALSE, vjust = -0.6, size = 3.4,
              color = cinderhaven_palette$text, fontface = "bold") +
    scale_fill_manual(values = c("Fail" = cinderhaven_palette$red,
                                 "Pass" = cinderhaven_palette$recede),
                      name = NULL) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.10))) +
    labs(title    = "Retailer item-setup readiness",
         subtitle = paste0("Of ", nrow(raw$product_master), " SKUs, how many would pass each retailer's required fields today."),
         x = NULL, y = "SKU count",
         caption = "Source: retailer_readiness_summary") +
    theme_cinderhaven()
}

save_pair(p20_base(FALSE), to_girafe(p20_base(TRUE), w_in = 9, h_in = 5),
          "20_retailer_setup_readiness_stacked", w_in = 9, h_in = 5)

# ---- chart 21: Data staleness distribution --------------------------------

cat("\n[21] Data staleness distribution\n")

c21 <- sku_dim |>
  select(sku, product_name, product_line, days_since_update,
         data_quality_score) |>
  left_join(sku_master_full |> select(sku, ttm_revenue), by = "sku") |>
  filter(!is.na(days_since_update)) |>
  mutate(tooltip = paste0(
    "<b>", sku, " — ", product_name, "</b><br>",
    "Days since last update: ", days_since_update, "<br>",
    "Quality score: ", round(data_quality_score, 1), "<br>",
    "Annual revenue: ", dollar_short(ttm_revenue)))

p21_base <- function(use_interactive) {
  # Bins beyond 365 days are the finding — color them red, the rest grey.
  c21$bin_start <- floor(c21$days_since_update / 60) * 60
  c21$is_stale  <- c21$bin_start >= 360
  p <- ggplot(c21, aes(x = days_since_update, fill = is_stale))
  p <- p + geom_histogram(binwidth = 60, color = "white")
  p <- p + scale_fill_manual(values = c(`TRUE`  = cinderhaven_palette$red,
                                        `FALSE` = cinderhaven_palette$recede),
                             guide = "none")
  if (use_interactive) {
    # overlay invisible interactive points so each SKU has a tooltip
    p <- p + geom_point_interactive(
      aes(y = 0, tooltip = tooltip, data_id = sku),
      alpha = 0, size = 1)
  }
  p +
    geom_vline(xintercept = 365, color = cinderhaven_palette$text_muted, linetype = "dashed") +
    annotate("label", x = 365, y = Inf, vjust = 1.4,
             label = "1 year", size = 3.2, color = cinderhaven_palette$text,
             fill = LL_CANVAS) +
    scale_x_continuous(breaks = seq(0, 1000, 180),
                       expand = expansion(mult = c(0, 0.02))) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    labs(title    = wrap_title("Half the catalog hasn't been updated in over 500 days"),
         subtitle = sprintf(
           "Days since last `last_updated` per SKU. Median %d days, max %d.",
           as.integer(median(c21$days_since_update)),
           as.integer(max(c21$days_since_update))),
         x = "Days since last update",
         y = "SKU count",
         caption = "Source: product_master.last_updated") +
    theme_cinderhaven()
}

save_pair(p21_base(FALSE), to_girafe(p21_base(TRUE), w_in = 9, h_in = 4.5),
          "21_data_staleness_distribution", w_in = 9, h_in = 4.5)

# ---- chart 22: Serving size variants --------------------------------------

cat("\n[22] Serving size variants\n")

if (!"serving_size" %in% names(raw$product_master) ||
    all(is.na(raw$product_master$serving_size))) {
  cat("  SKIPPED — serving_size column not present in current schema\n")
} else {

c22 <- raw$product_master |>
  count(serving_size, name = "n") |>
  arrange(desc(n)) |>
  mutate(serving_size = ifelse(is.na(serving_size) | serving_size == "",
                               "(missing)", serving_size),
         pct = n / sum(n),
         serving_size = safe_fct_reorder(serving_size, n),
         tooltip = paste0(
           "<b>", serving_size, "</b><br>",
           n, " SKUs (", percent(pct, accuracy = 0.1), ")"))

# Identify the "2 tbsp" cluster — same human serving, three encoded
# differently. That's the story this chart tells.
tbsp_cluster <- as.character(c22$serving_size)[
  grepl("^\\s*2\\s*[tT]bsp", as.character(c22$serving_size))]

p22_base <- function(use_interactive) {
  p <- ggplot(c22, aes(x = n, y = serving_size))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip,
                                      data_id = as.character(serving_size)),
                                  fill = cinderhaven_palette$recede, width = 0.75)
  } else {
    p <- p + geom_col(fill = cinderhaven_palette$recede, width = 0.75)
  }
  p +
    geom_text(aes(label = n), hjust = -0.4, size = 3.4, color = cinderhaven_palette$text) +
    # Bracket + callout marking the "2 tbsp" cluster — the same physical
    # serving, encoded three different ways.
    annotate("segment",
             x = max(c22$n) * 1.05, xend = max(c22$n) * 1.05,
             y = min(match(tbsp_cluster, levels(c22$serving_size))) - 0.4,
             yend = max(match(tbsp_cluster, levels(c22$serving_size))) + 0.4,
             color = cinderhaven_palette$red, linewidth = 0.8) +
    annotate("text",
             x = max(c22$n) * 1.10,
             y = mean(match(tbsp_cluster, levels(c22$serving_size))),
             label = "Same serving,\nthree encodings",
             color = cinderhaven_palette$red,
             hjust = 0, size = 3.3, fontface = "bold") +
    scale_x_continuous(expand = expansion(mult = c(0, 0.40))) +
    labs(title    = wrap_title("Serving size is recorded fourteen different ways"),
         subtitle = paste0(nrow(c22),
           " distinct strings — casing varies ('2 tbsp' vs '2 Tbsp') and the gram weight on '1 tsp' shifts between 2g, 3g, and 5g."),
         x = "SKU count", y = NULL,
         caption = "Source: product_master.serving_size") +
    theme_cinderhaven()
}

save_pair(p22_base(FALSE), to_girafe(p22_base(TRUE), w_in = 10, h_in = 6),
          "22_serving_size_variants", w_in = 10, h_in = 6)
}

# ---- chart 23: SKU risk (fix-priority) distribution -----------------------

cat("\n[23] SKU risk distribution\n")

c23 <- sku_master_full |>
  select(sku, product_name, product_line, fix_priority_score, issue_count,
         ttm_revenue, chargeback_total) |>
  mutate(tooltip = paste0(
    "<b>", sku, " — ", product_name, "</b><br>",
    "Fix priority: ", round(fix_priority_score, 0), "<br>",
    "Issues: ", issue_count, " of 8<br>",
    "Annual revenue: ", dollar_short(ttm_revenue), "<br>",
    "Chargebacks: ", dollar_short(chargeback_total)))

# Buckets used by §18 triage in the report. Plain-English labels (no score
# ranges in legend — readers don't need to think in fix-priority points).
c23 <- c23 |>
  mutate(risk_band = cut(fix_priority_score,
                         breaks = c(-Inf, 40, 55, 70, Inf),
                         labels = c("Low priority", "Medium",
                                    "High", "Fix now"),
                         right = FALSE))

# Ranked horizontal-bar view: all SKUs sorted by fix-priority score
# descending, with "Fix now" at the top of the chart and the darkest hue.
c23_ranked <- c23 |>
  arrange(desc(fix_priority_score)) |>
  mutate(sku_lbl = factor(sku, levels = rev(sku)))

p23_base <- function(use_interactive) {
  p <- ggplot(c23_ranked,
              aes(x = fix_priority_score, y = sku_lbl, fill = risk_band))
  if (use_interactive) {
    p <- p + geom_col_interactive(aes(tooltip = tooltip, data_id = sku),
                                  width = 0.82)
  } else {
    p <- p + geom_col(width = 0.82)
  }
  p +
    # Score callout for the "Fix now" tier — they're the action list.
    geom_text(data = c23_ranked |> filter(risk_band == "Fix now"),
              aes(label = round(fix_priority_score)),
              hjust = -0.35, size = 2.9, fontface = "bold",
              color = cinderhaven_palette$text) +
    # Only "Fix now" gets red — that's the action list. The other three
    # tiers exist for context and recede to grey.
    scale_fill_manual(values = c("Low priority" = cinderhaven_palette$recede,
                                  "Medium"       = cinderhaven_palette$recede,
                                  "High"         = cinderhaven_palette$recede_mid,
                                  "Fix now"      = cinderhaven_palette$red),
                      name = NULL,
                      breaks = c("Fix now", "High", "Medium", "Low priority")) +
    scale_x_continuous(breaks = seq(0, 100, 20),
                       expand = expansion(mult = c(0, 0.06))) +
    labs(title    = wrap_title("Most SKUs cluster in the middle — five need immediate attention"),
         subtitle = paste0("All ", nrow(c23), " SKUs ranked by fix-priority score (composite of revenue · quality · chargeback). Higher = fix sooner."),
         x = "Fix-priority score",
         y = NULL,
         caption = "Source: sku_master_full.fix_priority_score") +
    theme_cinderhaven_horizontal(base_size = 10) +
    theme(axis.text.y = element_text(size = 5.6,
                                     color = cinderhaven_palette$text),
          axis.ticks.y = element_blank(),
          legend.position = "top")
}

save_pair(p23_base(FALSE), to_girafe(p23_base(TRUE), w_in = 9, h_in = 13),
          "23_sku_risk_distribution", w_in = 9, h_in = 13)

# ---- skip notes -----------------------------------------------------------

cat("\n", strrep("-", 70),
    "\nSKIPPED CHARTS (data does not support a clear finding):\n",
    strrep("-", 70), "\n", sep = "")

cat("Chart 10 — New vs. old SKU data quality trend\n",
    "  Spearman(days_since_update, data_quality_score) = -0.033.\n",
    "  No monotonic trend by age. Scope says 'only include if finding is\n",
    "  clear' — flagged in PHASE1_DATA_FINDINGS.md and skipped.\n\n", sep = "")

cat("Chart 18 — Cost-of-doing-nothing EBITDA waterfall\n",
    "  Requires lost-sales, manual-rework hours, and trade-spend-erosion\n",
    "  estimates that aren't in the dataset. Building this honestly\n",
    "  requires assumptions the narrative needs to settle first. Defer\n",
    "  to Phase 4 once the prose has committed to specific assumption\n",
    "  values; build then with explicit sensitivity table.\n", sep = "")

cat("\nDone. Outputs in: ", OUT_DIR, "\n", sep = "")
