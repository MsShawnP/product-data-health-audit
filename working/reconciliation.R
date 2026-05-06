suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(stringr); library(lubridate); library(knitr)
})

ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
sku_master_full <- readRDS(file.path(ROOT, "output/frames/sku_master_full.rds"))
ce              <- readRDS(file.path(ROOT, "output/frames/chargebacks_enriched.rds"))

CUTOFF <- as.Date("2025-11-01")    # last 6 months: today is 2026-05-05
DATA_DEFECT_REASONS <- c("Invalid GTIN/UPC", "Missing product data", "Dimension mismatch")

# ===========================================================================
# QUERY 1 — SKUs with recent chargebacks AND defect still present today
# ===========================================================================

# Recent chargebacks by (sku, reason)
recent <- ce |>
  filter(month_date >= CUTOFF, reason %in% DATA_DEFECT_REASONS) |>
  group_by(sku, reason) |>
  summarise(recent_cb = sum(amount), n_events = n(), .groups = "drop")

# Per-SKU defect snapshot from current product master
sku_status <- sku_master_full |>
  select(sku, product_name,
         gtin14, upc, gtin_valid, upc_valid,
         missing_case_dims, missing_case_weight,
         case_length_in, case_width_in, case_height_in, case_weight_lbs,
         missing_brand_owner, missing_country,
         brand_owner, country_of_origin)

# Determine, per (sku, reason), whether the underlying defect is still present
# and which specific field is broken.
broken <- recent |>
  inner_join(sku_status, by = "sku") |>
  rowwise() |>
  mutate(
    still_broken_field = case_when(
      reason == "Invalid GTIN/UPC" & !gtin_valid & !upc_valid ~ "GTIN-14 + UPC-12 (both fail check digit)",
      reason == "Invalid GTIN/UPC" & !gtin_valid              ~ "GTIN-14 (invalid check digit)",
      reason == "Invalid GTIN/UPC" & !upc_valid               ~ "UPC-12 (invalid check digit)",
      reason == "Dimension mismatch" & missing_case_dims & missing_case_weight ~ "case dims + case weight (all blank)",
      reason == "Dimension mismatch" & missing_case_dims      ~ "case_length/width/height_in (one or more blank)",
      reason == "Dimension mismatch" & missing_case_weight    ~ "case_weight_lbs (blank)",
      reason == "Missing product data" & missing_brand_owner & missing_country ~ "brand_owner + country_of_origin (both blank)",
      reason == "Missing product data" & missing_brand_owner  ~ "brand_owner (blank/'NA')",
      reason == "Missing product data" & missing_country      ~ "country_of_origin (blank)",
      TRUE                                                    ~ NA_character_),
    still_broken = !is.na(still_broken_field)) |>
  ungroup() |>
  filter(still_broken)

# Estimated fix time per record (in minutes), per the methodology used in
# 04_hero_charts.R Fix-ROI calculation.
fix_minutes <- function(reason) {
  case_when(reason == "Invalid GTIN/UPC"     ~ 10L,
            reason == "Missing product data" ~ 30L,
            reason == "Dimension mismatch"   ~ 30L,
            TRUE                              ~ NA_integer_)
}

# Aggregate to SKU level — top 15 by recent_cb
top15 <- broken |>
  mutate(fix_min = fix_minutes(reason)) |>
  group_by(sku, product_name) |>
  summarise(
    recent_cb_total = sum(recent_cb),
    reasons         = paste(unique(reason), collapse = " + "),
    fields_broken   = paste(unique(still_broken_field), collapse = " | "),
    fix_minutes_est = sum(fix_min),
    .groups = "drop"
  ) |>
  arrange(desc(recent_cb_total)) |>
  slice(1:15) |>
  mutate(fix_time_est = sprintf("%d min", fix_minutes_est),
         recent_cb_total = sprintf("$%s",
                                   formatC(round(recent_cb_total),
                                           big.mark = ",", format = "d")))

cat("\n", strrep("=", 95), "\n", sep = "")
cat("QUERY 1 — Top 15 SKUs with recent chargebacks AND defect still present today\n")
cat("Cutoff: chargeback month_date >= ", as.character(CUTOFF), " (last 6 months)\n", sep = "")
cat(strrep("=", 95), "\n\n", sep = "")

print(kable(top15 |> select(sku, product_name, reason = reasons,
                            recent_cb = recent_cb_total,
                            field_still_broken = fields_broken,
                            fix_time = fix_time_est),
            format = "pipe", align = "lllrll"))

# Coverage stats for context
total_recent <- ce |>
  filter(month_date >= CUTOFF) |>
  pull(amount) |>
  sum()
recent_data_defect <- ce |>
  filter(month_date >= CUTOFF, reason %in% DATA_DEFECT_REASONS) |>
  pull(amount) |>
  sum()
still_broken_total <- broken |> pull(recent_cb) |> sum()

cat("\nContext:\n")
cat(sprintf("  Total chargebacks last 6 mo (all reasons):   $%s\n",
            formatC(round(total_recent), big.mark = ",", format = "d")))
cat(sprintf("  Last-6-mo data-defect chargebacks:           $%s (%.0f%% of recent)\n",
            formatC(round(recent_data_defect), big.mark = ",", format = "d"),
            100 * recent_data_defect / total_recent))
cat(sprintf("  Of those, on SKUs still broken today:        $%s (%.0f%% of recent data-defect)\n",
            formatC(round(still_broken_total), big.mark = ",", format = "d"),
            100 * still_broken_total / recent_data_defect))
cat(sprintf("  Distinct SKUs still broken: %d\n",
            length(unique(broken$sku))))

# ===========================================================================
# QUERY 2 — % of total chargeback dollars eliminated by each fix action
# ===========================================================================

cat("\n", strrep("=", 95), "\n", sep = "")
cat("QUERY 2 — % of TOTAL chargeback dollars eliminated by each fix action (18 mo)\n")
cat(strrep("=", 95), "\n\n", sep = "")

total_18mo <- sum(ce$amount)

q2 <- ce |>
  group_by(reason) |>
  summarise(amount = sum(amount),
            n_events = n(),
            n_skus = n_distinct(sku), .groups = "drop") |>
  mutate(pct_of_total = amount / total_18mo) |>
  arrange(desc(amount))

# Map to fix-action friendly labels
q2_labeled <- q2 |>
  mutate(fix_action = case_when(
           reason == "Invalid GTIN/UPC"     ~ "(a) Fix invalid GTIN/UPC check digits",
           reason == "Missing product data" ~ "(b) Complete missing product data fields",
           reason == "Dimension mismatch"   ~ "(c) Reconcile case dimensions",
           TRUE                              ~ paste0("(non-data) ", reason)),
         fix_amount  = sprintf("$%s",
                               formatC(round(amount), big.mark = ",", format = "d")),
         fix_pct     = sprintf("%.1f%%", 100 * pct_of_total))

# Print all reasons (so the non-data baseline is visible)
print(kable(q2_labeled |> select(fix_action, dollars = fix_amount,
                                 pct_of_total_cb = fix_pct,
                                 n_skus, n_events),
            format = "pipe", align = "lrrrr"))

# Combined fix coverage
combined <- q2_labeled |>
  filter(reason %in% DATA_DEFECT_REASONS) |>
  summarise(amount = sum(amount), .groups = "drop")

cat(sprintf("\nTotal 18-month chargeback dollars: $%s\n",
            formatC(round(total_18mo), big.mark = ",", format = "d")))
cat(sprintf("Three data-defect actions combined: $%s (%.1f%% of total)\n",
            formatC(round(combined$amount), big.mark = ",", format = "d"),
            100 * combined$amount / total_18mo))
cat(sprintf("Non-data residual (Late delivery + Short shipment): $%s (%.1f%%)\n",
            formatC(round(total_18mo - combined$amount), big.mark = ",", format = "d"),
            100 * (total_18mo - combined$amount) / total_18mo))
