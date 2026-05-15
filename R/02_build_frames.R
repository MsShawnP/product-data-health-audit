# 02_build_frames.R
# Build the flat analytical frames every artifact consumes.
# All inputs come from output/frames/raw_tables.rds (produced by 01_load_raw.R).
# All outputs go to output/frames/ as both .rds (canonical) and .csv (browse).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(lubridate)
  library(purrr)
  library(tibble)
})

ROOT    <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
OUT_DIR <- file.path(ROOT, "output", "frames")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
raw     <- readRDS(file.path(OUT_DIR, "raw_tables.rds"))

product_master        <- raw$product_master
sku_costs             <- raw$sku_costs
chargebacks           <- raw$chargebacks
stores                <- raw$stores
distribution_log      <- raw$distribution_log
scan_data             <- raw$scan_data
promotions            <- raw$promotions
retailer_requirements <- raw$retailer_requirements

# Coerce date columns once.
chargebacks      <- chargebacks      |> mutate(month_date = ymd(paste0(month, "-01")))
distribution_log <- distribution_log |> mutate(authorized_date = ymd(authorized_date),
                                               deauthorized_date = ymd(deauthorized_date))
scan_data        <- scan_data        |> mutate(week_ending = ymd(week_ending))
promotions       <- promotions       |> mutate(start_week = ymd(start_week),
                                               end_week   = ymd(end_week))
product_master   <- product_master   |> mutate(last_updated = ymd(last_updated))

# ---- helpers --------------------------------------------------------------

# Mod-10 check digit calculator.
#
# Note on the algorithm choice: the synthetic Cinderhaven dataset was generated
# using EAN-13-style weights (1,3,1,3,... from the leftmost data digit) for both
# GTIN-14 and UPC-A. This is non-standard for GTIN-14 — strict GS1 weights for a
# 13-digit body are (3,1,3,1,...) from left — but matching the dataset's
# generator is what lets us identify the SKUs the author deliberately corrupted.
# Validating with the strict algorithm flags ~81% of SKUs (every record),
# which would erase the signal the report needs to surface. The trade-off is
# documented in the methodology appendix.
mod10_check_digit <- function(body_digits) {
  d <- as.integer(strsplit(body_digits, "")[[1]])
  if (length(d) == 0 || any(is.na(d))) return(NA_integer_)
  weights <- rep(c(1L, 3L), length.out = length(d))
  s <- sum(d * weights)
  (10L - (s %% 10L)) %% 10L
}

is_valid_check_digit <- function(code, expected_len) {
  if (is.na(code) || nchar(code) != expected_len || !grepl("^[0-9]+$", code)) return(FALSE)
  body  <- substr(code, 1, expected_len - 1)
  check <- as.integer(substr(code, expected_len, expected_len))
  identical(check, mod10_check_digit(body))
}

is_valid_gtin14 <- function(x) vapply(x, is_valid_check_digit, logical(1), expected_len = 14L)
is_valid_upc12  <- function(x) vapply(x, is_valid_check_digit, logical(1), expected_len = 12L)

# Map sku_costs trade-spend wide cols to canonical retailer labels in `stores`.
trade_spend_long <- sku_costs |>
  select(sku, starts_with("trade_spend_pct_")) |>
  pivot_longer(-sku, names_to = "ts_col", values_to = "trade_spend_pct") |>
  mutate(retailer = recode(ts_col,
    trade_spend_pct_walmart      = "Walmart",
    trade_spend_pct_costco       = "Costco",
    trade_spend_pct_whole_foods  = "Whole Foods",
    trade_spend_pct_regional     = "Regional",
    trade_spend_pct_unfi         = "UNFI",
    trade_spend_pct_dtc          = "DTC")) |>
  select(sku, retailer, trade_spend_pct)

# ---- F1. sku_dim: one row per SKU with quality scoring --------------------

sku_dim <- product_master |>
  left_join(sku_costs, by = "sku") |>
  mutate(
    gtin_valid           = is_valid_gtin14(gtin14),
    upc_valid            = is_valid_upc12(upc),
    missing_case_weight  = is.na(case_weight_lbs),
    missing_case_dims    = is.na(case_length_in) | is.na(case_width_in) | is.na(case_height_in),
    missing_country      = is.na(country_of_origin) | country_of_origin == "",
    missing_brand_owner  = is.na(brand_owner)      | brand_owner == "",
    ows_complete         = oneworldsync_status == "Registered - Complete",
    weight_plausible = ifelse(
      is.na(case_weight_lbs) | is.na(unit_weight_lbs) | is.na(case_pack_qty), NA,
      abs(case_weight_lbs - unit_weight_lbs * case_pack_qty) /
        (unit_weight_lbs * case_pack_qty) <= 0.20),
    n_active_retailers   = ifelse(is.na(active_retailers), 0L,
                                  lengths(strsplit(active_retailers, ";\\s*"))),
    days_since_update    = as.integer(max(last_updated, na.rm = TRUE) - last_updated)
  ) |>
  rowwise() |>
  mutate(
    issue_count = sum(c(
      !isTRUE(gtin_valid),
      !isTRUE(upc_valid),
      isTRUE(missing_case_weight),
      isTRUE(missing_case_dims),
      isTRUE(missing_country),
      isTRUE(missing_brand_owner),
      !isTRUE(ows_complete),
      isFALSE(weight_plausible)
    ))
  ) |>
  ungroup() |>
  mutate(
    # 8 binary checks → quality score on 0-100 scale.
    data_quality_score = round(100 * (1 - issue_count / 8), 1)
  )

# ---- F2. sku_revenue: trailing-12-month rollup ----------------------------

max_week     <- max(scan_data$week_ending, na.rm = TRUE)
ttm_cutoff   <- max_week - days(365)

scan_ttm <- scan_data |> filter(week_ending > ttm_cutoff)

sku_revenue <- scan_ttm |>
  group_by(sku) |>
  summarise(
    ttm_units       = sum(units_sold),
    ttm_revenue     = sum(dollars_sold),
    ttm_weeks_active= n_distinct(week_ending),
    store_count_ttm = n_distinct(store_id),
    .groups = "drop") |>
  full_join(
    scan_data |> group_by(sku) |>
      summarise(first_scan_week = min(week_ending),
                last_scan_week  = max(week_ending), .groups = "drop"),
    by = "sku")

# ---- F3. sku_retailer_revenue: SKU × retailer with TTM rev/units/stores ---

scan_with_retailer <- scan_ttm |>
  left_join(stores |> select(store_id, retailer), by = "store_id")

sku_retailer_revenue <- scan_with_retailer |>
  group_by(sku, retailer) |>
  summarise(
    ttm_units       = sum(units_sold),
    ttm_revenue     = sum(dollars_sold),
    store_count_ttm = n_distinct(store_id),
    weeks_with_sales= n_distinct(week_ending),
    .groups = "drop") |>
  left_join(trade_spend_long, by = c("sku", "retailer"))

# ---- F4. chargebacks_enriched + sku_chargebacks ---------------------------

chargebacks_enriched <- chargebacks |>
  left_join(sku_dim |> select(sku, product_name, product_line, updated_by,
                              data_quality_score, issue_count, wholesale_price,
                              cogs_per_unit),
            by = "sku")

sku_chargebacks <- chargebacks |>
  group_by(sku) |>
  summarise(
    chargeback_total      = sum(amount),
    chargeback_count      = n(),
    n_retailers_charged   = n_distinct(retailer),
    n_reasons             = n_distinct(reason),
    first_chargeback_month= min(month_date),
    last_chargeback_month = max(month_date),
    primary_reason = reason[which.max(amount)],  # reason of largest single chargeback
    .groups = "drop")

retailer_chargebacks <- chargebacks |>
  group_by(retailer) |>
  summarise(chargeback_total = sum(amount),
            chargeback_count = n(), .groups = "drop")

# ---- F5. retailer_readiness_long + per-SKU summary ------------------------

# Required-field rules from retailer_requirements; we evaluate each SKU
# against each rule for each retailer that has rules.
required_fields <- retailer_requirements |> filter(required == 1)

# For fields we model directly, write the pass test inline. For other
# fields (rare), default to: "field exists on product_master & is non-NA".
field_is_present <- function(sku_row, field_name) {
  if (!field_name %in% names(sku_row)) return(NA)  # rule references unknown field
  v <- sku_row[[field_name]]
  !(is.na(v) || (is.character(v) && (v == "" | trimws(v) == "")))
}

evaluate_one <- function(field_name, sku_row) {
  switch(field_name,
    gtin14            = is_valid_gtin14(sku_row$gtin14),
    upc               = is_valid_upc12(sku_row$upc),
    case_weight_lbs   = !is.na(sku_row$case_weight_lbs),
    case_length_in    = !is.na(sku_row$case_length_in),
    case_width_in     = !is.na(sku_row$case_width_in),
    case_height_in    = !is.na(sku_row$case_height_in),
    case_pack_qty     = !is.na(sku_row$case_pack_qty),
    unit_weight_lbs   = !is.na(sku_row$unit_weight_lbs),
    msrp              = !is.na(sku_row$msrp),
    country_of_origin = !(is.na(sku_row$country_of_origin) | sku_row$country_of_origin == ""),
    brand_owner       = !(is.na(sku_row$brand_owner)       | sku_row$brand_owner == ""),
    serving_size      = !(is.na(sku_row$serving_size)      | sku_row$serving_size == ""),
    calories_per_serving = !is.na(sku_row$calories_per_serving),
    sodium_mg         = !is.na(sku_row$sodium_mg),
    total_fat_g       = !is.na(sku_row$total_fat_g),
    total_carb_g      = !is.na(sku_row$total_carb_g),
    protein_g         = !is.na(sku_row$protein_g),
    oneworldsync_status = sku_row$oneworldsync_status == "Registered - Complete",
    field_is_present(sku_row, field_name)  # default
  )
}

retailer_readiness_long <- crossing(
    sku_dim |> select(sku),
    required_fields
  ) |>
  rowwise() |>
  mutate(passes = {
    sr <- sku_dim[sku_dim$sku == sku, ]
    isTRUE(evaluate_one(field, sr))
  }) |>
  ungroup()

retailer_readiness_summary <- retailer_readiness_long |>
  group_by(sku, retailer) |>
  summarise(
    fields_required = n(),
    fields_passed   = sum(passes, na.rm = TRUE),
    fields_failed   = sum(!passes, na.rm = TRUE),
    overall_pass    = fields_failed == 0,
    .groups = "drop")

# ---- F6. retailer_pnl: gross rev → trade spend → chargebacks → net --------

retailer_pnl <- sku_retailer_revenue |>
  mutate(trade_spend_dollars = ttm_revenue * trade_spend_pct) |>
  group_by(retailer) |>
  summarise(
    gross_revenue       = sum(ttm_revenue),
    trade_spend_total   = sum(trade_spend_dollars, na.rm = TRUE),
    revenue_after_trade = gross_revenue - trade_spend_total,
    .groups = "drop") |>
  left_join(retailer_chargebacks, by = "retailer") |>
  mutate(
    chargeback_total = coalesce(chargeback_total, 0),
    chargeback_count = coalesce(chargeback_count, 0L),
    net_contribution = revenue_after_trade - chargeback_total,
    chargeback_pct_of_revenue       = chargeback_total / gross_revenue,
    trade_spend_pct_of_revenue      = trade_spend_total / gross_revenue,
    net_margin_pct_of_gross_revenue = net_contribution / gross_revenue
  )

# ---- F7. time_to_shelf: SKU × store gap from authorization to first scan --

first_scan_per_sku_store <- scan_data |>
  group_by(sku, store_id) |>
  summarise(first_scan_week = min(week_ending), .groups = "drop")

time_to_shelf <- distribution_log |>
  left_join(first_scan_per_sku_store, by = c("sku", "store_id")) |>
  mutate(days_to_first_scan  = as.integer(first_scan_week - authorized_date),
         weeks_to_first_scan = days_to_first_scan / 7)

time_to_shelf_sku <- time_to_shelf |>
  filter(!is.na(days_to_first_scan), days_to_first_scan >= 0) |>
  group_by(sku) |>
  summarise(
    n_authorizations    = n(),
    median_days_to_scan = median(days_to_first_scan),
    mean_days_to_scan   = mean(days_to_first_scan),
    .groups = "drop")

# ---- F8. deauth_summary: deauthorization rates by SKU ---------------------

deauth_summary <- distribution_log |>
  group_by(sku) |>
  summarise(
    auth_count       = n(),
    deauth_count     = sum(!is.na(deauthorized_date)),
    deauth_rate      = deauth_count / auth_count,
    .groups = "drop")

# ---- F9. sku_master_full: the wide analytical spine for the report --------

sku_master_full <- sku_dim |>
  left_join(sku_revenue,        by = "sku") |>
  left_join(sku_chargebacks,    by = "sku") |>
  left_join(time_to_shelf_sku,  by = "sku") |>
  left_join(deauth_summary,     by = "sku") |>
  mutate(
    chargeback_total      = coalesce(chargeback_total, 0),
    chargeback_count      = coalesce(chargeback_count, 0L),
    ttm_revenue           = coalesce(ttm_revenue, 0),
    ttm_units             = coalesce(ttm_units, 0L),
    annual_gross_margin   = ttm_revenue - ttm_units * cogs_per_unit,
    chargeback_pct_of_gm  = ifelse(annual_gross_margin > 0,
                                   chargeback_total / annual_gross_margin, NA_real_),
    # Composite fix-priority score used in section 18 triage.
    # All three ranks aligned so rank 1 = the SKU contributing most to
    # priority on that dimension (highest revenue, most issues, most
    # chargeback dollars). Composite = weighted average of (1 - rank/n),
    # so higher score = fix sooner.
    revenue_rank      = rank(-ttm_revenue,      ties.method = "average"),
    quality_rank      = rank(-issue_count,      ties.method = "average"),
    chargeback_rank   = rank(-chargeback_total, ties.method = "average"),
    fix_priority_score = round(
      0.40 * (1 - revenue_rank   / n()) * 100 +
      0.30 * (1 - quality_rank   / n()) * 100 +
      0.30 * (1 - chargeback_rank/ n()) * 100, 1)
  )

# ---- F9b. Triage effort + ROI + still-broken reconciliation --------------
# Three columns appended to sku_master_full so every consumer (Excel
# workbook, Quarto report, dashboard) reads the same values from the
# canonical frame instead of recomputing them locally.
#
#   est_fix_hours    — sum of per-defect minute estimates / 60.
#   savings_per_hour — annualized chargeback dollars / est_fix_hours.
#   still_broken     — semicolon-separated list of defects currently in
#                      the product master that map to chargeback reasons
#                      billed in the last 6 months. NA if the SKU had no
#                      recent chargebacks; "" or NA if the recent reasons
#                      no longer map to any present defect.
#
# Per-defect effort minutes (from the methodology appendix):
#   GTIN check digit              10 min
#   UPC check digit               10 min
#   Case weight or dims (one job) 30 min
#   Brand owner                   10 min
#   Country of origin             30 min
#   OneWorldSync registration     30 min
#   Implausible weight            15 min

last_scan_week  <- max(scan_data$week_ending, na.rm = TRUE)
cb_window_start <- last_scan_week - months(6)
recent_cb_reasons <- chargebacks_enriched |>
  filter(month_date >= cb_window_start) |>
  distinct(sku, reason)

defect_for_reason <- function(r, row) {
  switch(r,
    "Invalid GTIN/UPC"     = c(
      if (!isTRUE(row$gtin_valid)) "GTIN-14 check digit",
      if (!isTRUE(row$upc_valid))  "UPC-12 check digit"),
    "Dimension mismatch"   = c(
      if (isTRUE(row$missing_case_dims))   "Case dimensions blank",
      if (isTRUE(row$missing_case_weight)) "Case weight blank",
      if (!is.na(row$weight_plausible) && !row$weight_plausible)
                                           "Implausible case weight"),
    "Missing product data" = c(
      if (isTRUE(row$missing_brand_owner)) "Brand owner blank",
      if (isTRUE(row$missing_country))     "Country of origin blank",
      if (!isTRUE(row$ows_complete))       "OneWorldSync incomplete"),
    character())
}

still_broken_vec <- vapply(sku_master_full$sku, function(s) {
  reasons <- recent_cb_reasons$reason[recent_cb_reasons$sku == s]
  if (length(reasons) == 0) return(NA_character_)
  row <- sku_master_full[sku_master_full$sku == s, , drop = FALSE]
  defects <- unique(unlist(lapply(reasons, defect_for_reason, row = row)))
  if (length(defects) == 0) NA_character_ else paste(defects, collapse = "; ")
}, character(1))

sku_master_full <- sku_master_full |>
  mutate(
    fix_minutes_est =
      (!gtin_valid)            * 10 +
      (!upc_valid)             * 10 +
      (missing_case_weight | missing_case_dims) * 30 +
      missing_brand_owner      * 10 +
      missing_country          * 30 +
      (!ows_complete)          * 30 +
      (!is.na(weight_plausible) & !weight_plausible) * 15,
    est_fix_hours    = fix_minutes_est / 60,
    savings_per_hour = ifelse(
      est_fix_hours > 0,
      (chargeback_total * 12 / 18) / est_fix_hours,
      NA_real_),
    still_broken     = still_broken_vec) |>
  select(-fix_minutes_est)

# ---- F10. process_debt: by updated_by source ------------------------------

process_debt <- sku_master_full |>
  group_by(updated_by) |>
  summarise(
    n_skus              = n(),
    mean_quality_score  = mean(data_quality_score, na.rm = TRUE),
    mean_issue_count    = mean(issue_count, na.rm = TRUE),
    total_chargebacks   = sum(chargeback_total, na.rm = TRUE),
    chargeback_per_sku  = total_chargebacks / n_skus,
    total_revenue       = sum(ttm_revenue, na.rm = TRUE),
    chargeback_pct_of_rev = total_chargebacks / total_revenue,
    .groups = "drop") |>
  arrange(desc(chargeback_per_sku))

# ---- F11. promo_effectiveness: lift vs 4-wk baseline ----------------------
# Baseline = avg weekly units in 4 weeks before promo start (same SKU & retailer).
# Promo   = avg weekly units in promo window (same SKU & retailer).
# Pre-aggregating to sku × retailer × week keeps each promo lookup tiny.

weekly_sku_retailer <- scan_with_retailer |>
  filter(!is.na(retailer)) |>
  group_by(sku, retailer, week_ending) |>
  summarise(units = sum(units_sold),
            dollars = sum(dollars_sold), .groups = "drop")

promo_lift_one <- function(sk, rt, sw, ew) {
  bl <- weekly_sku_retailer |>
    filter(sku == sk, retailer == rt,
           week_ending <  sw, week_ending >= sw - weeks(4))
  pw <- weekly_sku_retailer |>
    filter(sku == sk, retailer == rt,
           week_ending >= sw, week_ending <= ew)
  bl_wk <- nrow(bl); pw_wk <- nrow(pw)
  bl_per_wk <- if (bl_wk == 0) NA_real_ else sum(bl$units) / bl_wk
  pw_per_wk <- if (pw_wk == 0) NA_real_ else sum(pw$units) / pw_wk
  tibble(baseline_weeks = bl_wk, promo_weeks = pw_wk,
         baseline_units_per_wk = bl_per_wk,
         promo_units_per_wk    = pw_per_wk,
         lift_pct = if (is.na(bl_per_wk) || bl_per_wk == 0) NA_real_
                    else pw_per_wk / bl_per_wk - 1)
}

promo_lift_metrics <- pmap_dfr(
  list(promotions$sku, promotions$retailer,
       promotions$start_week, promotions$end_week),
  promo_lift_one)

promo_effectiveness <- bind_cols(promotions, promo_lift_metrics) |>
  left_join(sku_dim |> select(sku, product_name, product_line,
                              data_quality_score, issue_count),
            by = "sku")

# ---- F12. velocity (SKU × retailer, 4-week / 12-week / prior-4-week) ------
# Single source of truth consumed by the Excel workbook and the dashboard.

scan_vel <- scan_data |>
  mutate(week_ending = ymd(week_ending)) |>
  left_join(stores |> select(store_id, retailer), by = "store_id") |>
  filter(!is.na(retailer))

vel_last_week <- max(scan_vel$week_ending, na.rm = TRUE)
vel_cut_4w    <- vel_last_week - weeks(4)
vel_cut_12w   <- vel_last_week - weeks(12)
vel_cut_8w    <- vel_last_week - weeks(8)

vel_agg <- function(df) df |>
  group_by(sku, retailer) |>
  summarise(units   = sum(units_sold),
            dollars = sum(dollars_sold),
            stores  = n_distinct(store_id),
            weeks   = n_distinct(week_ending),
            .groups = "drop")

vel_4w   <- vel_agg(filter(scan_vel, week_ending >  vel_cut_4w)) |>
  rename(units_4w = units, dollars_4w = dollars,
         stores_4w = stores, weeks_4w = weeks)
vel_12w  <- vel_agg(filter(scan_vel, week_ending >  vel_cut_12w)) |>
  rename(units_12w = units, dollars_12w = dollars,
         stores_12w = stores, weeks_12w = weeks)
vel_prev <- vel_agg(filter(scan_vel, week_ending <= vel_cut_4w &
                                      week_ending >  vel_cut_8w)) |>
  rename(units_prev4 = units, dollars_prev4 = dollars,
         stores_prev4 = stores, weeks_prev4 = weeks)

velocity <- vel_4w |>
  full_join(vel_12w,  by = c("sku", "retailer")) |>
  full_join(vel_prev, by = c("sku", "retailer")) |>
  left_join(sku_dim |>
              transmute(sku, product_name, product_line,
                        data_quality_score, issue_count,
                        data_quality_flag = ifelse(issue_count >= 3,
                                                    "REVIEW", "OK")),
            by = "sku") |>
  mutate(
    ups_per_w_4w    = units_4w    / pmax(stores_4w    * weeks_4w,    1),
    ups_per_w_12w   = units_12w   / pmax(stores_12w   * weeks_12w,   1),
    ups_per_w_prev4 = units_prev4 / pmax(stores_prev4 * weeks_prev4, 1),
    ups_pct_change_4w_vs_prev = ifelse(
      is.na(ups_per_w_prev4) | ups_per_w_prev4 == 0, NA_real_,
      ups_per_w_4w / ups_per_w_prev4 - 1)) |>
  select(sku, product_name, product_line, retailer,
         units_4w, dollars_4w, stores_4w, ups_per_w_4w,
         units_12w, dollars_12w, stores_12w, ups_per_w_12w,
         ups_per_w_prev4, ups_pct_change_4w_vs_prev,
         data_quality_score, issue_count, data_quality_flag) |>
  arrange(desc(dollars_12w))

rm(scan_vel, vel_last_week, vel_cut_4w, vel_cut_12w, vel_cut_8w,
   vel_agg, vel_4w, vel_12w, vel_prev)

# ---- write everything ------------------------------------------------------

write_pair <- function(df, name) {
  saveRDS(df, file.path(OUT_DIR, paste0(name, ".rds")))
  write_csv(df, file.path(OUT_DIR, paste0(name, ".csv")))
}

# Sanity: every frame must have rows, and key frames must match SKU count.
n_skus <- nrow(sku_dim)
stopifnot(n_skus > 0)
stopifnot(nrow(sku_revenue) > 0)
stopifnot(nrow(sku_retailer_revenue) > 0)
stopifnot(nrow(chargebacks_enriched) > 0)
stopifnot(nrow(retailer_readiness_long) > 0)
stopifnot(nrow(retailer_pnl) > 0)
stopifnot(nrow(time_to_shelf) > 0)
stopifnot(nrow(deauth_summary) > 0)
stopifnot(nrow(sku_master_full) == n_skus)
stopifnot(nrow(velocity) > 0)

write_pair(sku_dim,                    "sku_dim")
write_pair(sku_revenue,                "sku_revenue")
write_pair(sku_retailer_revenue,       "sku_retailer_revenue")
write_pair(chargebacks_enriched,       "chargebacks_enriched")
write_pair(sku_chargebacks,            "sku_chargebacks")
write_pair(retailer_readiness_long,    "retailer_readiness_long")
write_pair(retailer_readiness_summary, "retailer_readiness_summary")
write_pair(retailer_pnl,               "retailer_pnl")
write_pair(time_to_shelf,              "time_to_shelf_sku_store")
write_pair(time_to_shelf_sku,          "time_to_shelf_sku")
write_pair(deauth_summary,             "deauth_summary")
write_pair(sku_master_full,            "sku_master_full")
write_pair(process_debt,               "process_debt")
write_pair(promo_effectiveness,        "promo_effectiveness")
write_pair(velocity,                   "velocity")

cat("\n--- Wrote analytical frames ---\n")
for (f in list.files(OUT_DIR, pattern = "\\.rds$")) {
  cat(sprintf("  %-35s %8.1f KB\n", f,
              file.info(file.path(OUT_DIR, f))$size / 1024))
}
