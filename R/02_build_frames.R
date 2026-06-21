# 02_build_frames.R
# Build the flat analytical frames every artifact consumes.
# All inputs come from output/frames/raw_tables.rds (produced by 01_load_raw.R
# from the dbt mart layer). product_master is dim_products (the canonical
# product master including costs); no separate sku_costs table.
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
raw <- tryCatch(
  readRDS(file.path(OUT_DIR, "raw_tables.rds")),
  error = function(e) stop(
    "Cannot read raw_tables.rds: ", conditionMessage(e),
    "\nRe-run 01_load_raw.R or restore from git.", call. = FALSE)
)

product_master        <- raw$product_master
optional_pm_cols <- list(
  oneworldsync_status = NA_character_, active_retailers = NA_character_,
  updated_by = NA_character_,
  serving_size = NA_character_, calories_per_serving = NA_real_,
  sodium_mg = NA_real_, total_fat_g = NA_real_, total_carb_g = NA_real_,
  protein_g = NA_real_
)
for (col in names(optional_pm_cols)) {
  if (!col %in% names(product_master))
    product_master[[col]] <- optional_pm_cols[[col]]
}
chargebacks           <- raw$chargebacks
stores                <- raw$stores
distribution          <- raw$distribution
scan_data             <- raw$scan_data
promotions            <- raw$promotions
retailer_requirements <- raw$retailer_requirements

# ---- Remove UNFI (distributor, not a retailer) from all source tables ------
stores                <- stores |> filter(retailer != "UNFI")
chargebacks           <- chargebacks |> filter(retailer != "UNFI")
promotions            <- promotions |> filter(retailer != "UNFI")
retailer_requirements <- retailer_requirements |> filter(retailer != "UNFI")

# Map raw reason codes to presentable labels for charts and narrative.
chargebacks <- chargebacks |>
  mutate(reason = recode(reason,
    label_fine    = "Label / barcode fine",
    pricing_error = "Pricing error",
    damaged       = "Damaged goods",
    late_delivery = "Late delivery",
    short_ship    = "Short shipment"))

# Coerce date columns once.
chargebacks      <- chargebacks      |> mutate(month_date = ymd(paste0(month, "-01")))
distribution     <- distribution     |> mutate(authorized_date = ymd(authorized_date),
                                               deauthorized_date = ymd(deauthorized_date))
scan_data        <- scan_data        |> mutate(week_ending = ymd(week_ending))
promotions       <- promotions       |> mutate(start_week = ymd(start_week),
                                               end_week   = ymd(end_week))
product_master   <- product_master   |> mutate(last_updated = ymd(last_updated))

# ---- helpers --------------------------------------------------------------

source(file.path(ROOT, "R", "barcode_validators.R"))

# Map trade-spend wide cols to canonical retailer labels in `stores`.
trade_spend_long <- product_master |>
  select(sku, starts_with("trade_spend_pct_")) |>
  pivot_longer(-sku, names_to = "ts_col", values_to = "trade_spend_pct") |>
  mutate(retailer = recode(ts_col,
    trade_spend_pct_walmart      = "Walmart",
    trade_spend_pct_costco       = "Costco",
    trade_spend_pct_whole_foods  = "Whole Foods",
    trade_spend_pct_sprouts      = "Sprouts",
    trade_spend_pct_regional     = "Regional Group",

    trade_spend_pct_kehe         = "KeHE",
    trade_spend_pct_dtc          = "DTC")) |>
  select(sku, retailer, trade_spend_pct)

# ---- F1. sku_dim: one row per SKU with quality scoring --------------------

sku_dim <- product_master |>
  mutate(
    gtin_valid           = is_valid_gtin14(gtin14),
    upc_valid            = is_valid_upc(upc),
    missing_case_weight  = is.na(case_weight_lbs),
    missing_case_dims    = is.na(case_length_in) | is.na(case_width_in) | is.na(case_height_in),
    missing_country      = is.na(country_of_origin) | country_of_origin == "",
    missing_brand_owner  = is.na(brand_owner)      | brand_owner == "",
    ows_complete         = oneworldsync_status == "Registered - Complete",
    weight_plausible_simple = !is.na(unit_weight_lbs) & unit_weight_lbs > 0 & unit_weight_lbs < 100,
    weight_plausible = ifelse(
      is.na(case_weight_lbs) | is.na(unit_weight_lbs) | is.na(case_pack_qty), NA,
      abs(case_weight_lbs - unit_weight_lbs * case_pack_qty) /
        (unit_weight_lbs * case_pack_qty) <= 0.20),
    n_active_retailers   = ifelse(is.na(active_retailers), 0L,
                                  lengths(strsplit(active_retailers, ";\\s*"))),
    days_since_update    = as.integer(max(last_updated, na.rm = TRUE) - last_updated)
  ) |>
  mutate(
    issue_count =
      as.integer(is.na(gtin_valid) | !gtin_valid) +
      as.integer(is.na(upc_valid)  | !upc_valid) +
      as.integer(missing_case_weight) +
      as.integer(missing_case_dims) +
      as.integer(missing_country) +
      as.integer(missing_brand_owner) +
      as.integer(!is.na(weight_plausible) & !weight_plausible),
    chk_gtin_len = !is.na(gtin14) & nchar(as.character(gtin14)) == 14,
    chk_upc_len  = !is.na(upc) & nchar(as.character(upc)) %in% c(12L, 13L),
    checks_passed_6 =
      as.integer(chk_gtin_len) +
      as.integer(chk_upc_len) +
      as.integer(weight_plausible_simple) +
      as.integer(!missing_case_dims) +
      as.integer(!missing_country) +
      as.integer(!missing_brand_owner)
  ) |>
  mutate(
    data_quality_score = round(checks_passed_6 / 6 * 100, 1)
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

regional_trade_spend <- product_master |>
  select(sku, trade_spend_pct = trade_spend_pct_regional)

sku_retailer_revenue <- scan_with_retailer |>
  group_by(sku, retailer) |>
  summarise(
    ttm_units       = sum(units_sold),
    ttm_revenue     = sum(dollars_sold),
    store_count_ttm = n_distinct(store_id),
    weeks_with_sales= n_distinct(week_ending),
    .groups = "drop") |>
  left_join(trade_spend_long, by = c("sku", "retailer")) |>
  left_join(regional_trade_spend, by = "sku", suffix = c("", "_fallback")) |>
  mutate(trade_spend_pct = coalesce(trade_spend_pct, trade_spend_pct_fallback)) |>
  select(-trade_spend_pct_fallback)

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
required_fields <- retailer_requirements |>
  filter(required == 1) |>
  mutate(field = recode(field,
    case_dimensions = "case_dims",
    unit_weight     = "unit_weight_lbs"
  )) |>
  filter(!field %in% c("allergen_statement", "nutrition_facts",
                        "product_image", "sds_sheet", "serving_size"))

field_evals <- sku_dim |>
  transmute(
    sku,
    gtin14            = is_valid_gtin14(gtin14),
    upc               = is_valid_upc(upc),
    case_weight_lbs   = !is.na(case_weight_lbs),
    case_dims         = !is.na(case_length_in) & !is.na(case_width_in) & !is.na(case_height_in),
    case_pack_qty     = !is.na(case_pack_qty),
    unit_weight_lbs   = !is.na(unit_weight_lbs),
    msrp              = !is.na(msrp),
    country_of_origin = !(is.na(country_of_origin) | country_of_origin == ""),
    brand_owner       = !(is.na(brand_owner) | brand_owner == ""),
    oneworldsync_status = oneworldsync_status == "Registered - Complete"
  ) |>
  pivot_longer(-sku, names_to = "field", values_to = "passes") |>
  mutate(passes = !is.na(passes) & passes)

retailer_readiness_long <- crossing(
    sku_dim |> select(sku),
    required_fields
  ) |>
  left_join(field_evals, by = c("sku", "field")) |>
  mutate(passes = coalesce(passes, FALSE))

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
    trade_spend = trade_spend_total,
    total_chargebacks = chargeback_total,
    net_contribution = revenue_after_trade - chargeback_total,
    chargeback_pct_of_revenue       = chargeback_total / gross_revenue,
    trade_spend_pct_of_revenue      = trade_spend_total / gross_revenue,
    net_margin_pct_of_gross_revenue = net_contribution / gross_revenue
  )

# ---- F7. time_to_shelf: SKU × store gap from authorization to first scan --
# fct_distribution already has first_scan_week per sku × store (from the
# scan_data aggregation in the dbt model), so no R-side computation needed.

time_to_shelf <- distribution |>
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

deauth_summary <- distribution |>
  group_by(sku) |>
  summarise(
    auth_count       = n(),
    deauth_count     = sum(!is.na(deauthorized_date)),
    deauth_rate      = deauth_count / auth_count,
    deauth_rate_pct  = round(deauth_count / auth_count * 100, 1),
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
    revenue_rank      = percent_rank(desc(ttm_revenue)),
    quality_rank      = percent_rank(data_quality_score),
    chargeback_rank   = percent_rank(desc(chargeback_total)),
    fix_priority_score = round(
      (0.40 * revenue_rank +
       0.30 * quality_rank +
       0.30 * chargeback_rank) * 100, 1)
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

reason_defect_map <- tibble::tribble(
  ~reason,                  ~defect_field,          ~defect_label,
  "Label / barcode fine",   "gtin_valid",           "GTIN-14 check digit",
  "Label / barcode fine",   "upc_valid",            "UPC-12 check digit",
  "Damaged goods",          "missing_case_dims",    "Case dimensions blank",
  "Damaged goods",          "missing_case_weight",  "Case weight blank",
  "Damaged goods",          "weight_implausible",   "Implausible case weight",
  "Pricing error",          "missing_brand_owner",  "Brand owner blank",
  "Pricing error",          "missing_country",      "Country of origin blank"
)

sku_defect_flags <- sku_master_full |>
  transmute(sku,
    gtin_valid          = is.na(gtin_valid) | !gtin_valid,
    upc_valid           = is.na(upc_valid)  | !upc_valid,
    missing_case_dims   = missing_case_dims,
    missing_case_weight = missing_case_weight,
    weight_implausible  = !is.na(weight_plausible) & !weight_plausible,
    missing_brand_owner = missing_brand_owner,
    missing_country     = missing_country
  ) |>
  pivot_longer(-sku, names_to = "defect_field", values_to = "has_defect") |>
  filter(has_defect) |>
  select(-has_defect)

still_broken_df <- recent_cb_reasons |>
  inner_join(reason_defect_map, by = "reason") |>
  inner_join(sku_defect_flags, by = c("sku", "defect_field")) |>
  group_by(sku) |>
  summarise(still_broken = paste(unique(defect_label), collapse = "; "),
            .groups = "drop")

sku_master_full <- sku_master_full |>
  mutate(
    fix_minutes_est =
      as.integer(is.na(gtin_valid) | !gtin_valid)            * 10 +
      as.integer(is.na(upc_valid)  | !upc_valid)             * 10 +
      as.integer(missing_case_weight | missing_case_dims)     * 30 +
      as.integer(missing_brand_owner)                         * 10 +
      as.integer(missing_country)                             * 30 +
      as.integer(!is.na(weight_plausible) & !weight_plausible)* 15,
    est_fix_hours    = fix_minutes_est / 60,
    savings_per_hour = ifelse(
      est_fix_hours > 0,
      (chargeback_total * 12 / 36) / est_fix_hours,
      NA_real_),
    still_broken     = still_broken_df$still_broken[match(sku, still_broken_df$sku)]) |>
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

wsr_index <- split(weekly_sku_retailer,
                    interaction(weekly_sku_retailer$sku,
                                weekly_sku_retailer$retailer, drop = TRUE))

promo_lift_one <- function(sk, rt, sw, ew) {
  key <- paste(sk, rt, sep = ".")
  chunk <- wsr_index[[key]]
  if (is.null(chunk) || nrow(chunk) == 0) {
    return(tibble(baseline_weeks = 0L, promo_weeks = 0L,
                  baseline_units_per_wk = NA_real_,
                  promo_units_per_wk    = NA_real_,
                  lift_pct = NA_real_))
  }
  bl <- chunk[chunk$week_ending <  sw & chunk$week_ending >= sw - weeks(4), ]
  pw <- chunk[chunk$week_ending >= sw & chunk$week_ending <= ew, ]
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

scan_vel <- scan_with_retailer |> filter(!is.na(retailer))

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

vel_4w   <- vel_agg(filter(scan_vel, week_ending >= vel_cut_4w)) |>
  rename(units_4w = units, dollars_4w = dollars,
         stores_4w = stores, weeks_4w = weeks)
vel_12w  <- vel_agg(filter(scan_vel, week_ending >= vel_cut_12w)) |>
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
    ups_per_wk_4wk  = round(units_4w    / pmax(stores_4w    * weeks_4w,    1), 2),
    ups_per_wk_12wk = round(units_12w   / pmax(stores_12w   * weeks_12w,   1), 2),
    ups_per_w_prev4 = units_prev4 / pmax(stores_prev4 * weeks_prev4, 1),
    ups_pct_change_4w_vs_prev = ifelse(
      is.na(ups_per_w_prev4) | ups_per_w_prev4 == 0, NA_real_,
      ups_per_wk_4wk / ups_per_w_prev4 - 1)) |>
  select(sku, product_name, product_line, retailer,
         units_4w, dollars_4w, stores_4w, ups_per_wk_4wk,
         units_12w, dollars_12w, stores_12w, ups_per_wk_12wk,
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
