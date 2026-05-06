# _verify_targeted.R — ad-hoc cross-tabs the standard 03 script doesn't expose.
# Used to verify the four claims after the supposed DB refresh.

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(DBI); library(RSQLite)
})

ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
OUT  <- file.path(ROOT, "data", "processed")

sku_master_full     <- readRDS(file.path(OUT, "sku_master_full.rds"))
time_to_shelf_sku   <- readRDS(file.path(OUT, "time_to_shelf_sku.rds"))
time_to_shelf_store <- readRDS(file.path(OUT, "time_to_shelf_sku_store.rds"))
promo_eff           <- readRDS(file.path(OUT, "promo_effectiveness.rds"))
deauth_summary      <- readRDS(file.path(OUT, "deauth_summary.rds"))

hr <- function(t) cat("\n", strrep("=", 70), "\n", t, "\n", strrep("=", 70), "\n", sep = "")

# --- DB freshness sanity ---------------------------------------------------
con <- dbConnect(SQLite(), file.path(ROOT, "cinderhaven_product_master.db"))
hr("DB ROW COUNTS (live)")
for (t in dbListTables(con)) {
  n <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", t))$n
  cat(sprintf("  %-25s %10d\n", t, n))
}
hr("DISTRIBUTION_LOG.deauthorized_date — null vs non-null")
print(dbGetQuery(con,
  "SELECT (deauthorized_date IS NULL) AS is_null, COUNT(*) AS n
     FROM distribution_log GROUP BY 1"))
hr("SCAN_DATA week range (live)")
print(dbGetQuery(con, "SELECT MIN(week_ending) AS minw, MAX(week_ending) AS maxw FROM scan_data"))
hr("DISTRIBUTION_LOG.authorized_date — distinct gap to first scan (sample)")
print(dbGetQuery(con,
  "SELECT d.sku, d.store_id, d.authorized_date, MIN(s.week_ending) AS first_scan,
          (julianday(MIN(s.week_ending)) - julianday(d.authorized_date)) AS gap_days
     FROM distribution_log d JOIN scan_data s
       ON d.sku = s.sku AND d.store_id = s.store_id
    GROUP BY d.sku, d.store_id
    ORDER BY RANDOM() LIMIT 8"))
dbDisconnect(con)

# --- (1) Chargebacks vs product master defects ----------------------------
hr("(1) CHARGEBACKS vs PRODUCT-MASTER DEFECTS")

cor_q  <- cor(sku_master_full$data_quality_score, sku_master_full$chargeback_total,
              method = "spearman")
cor_iss<- cor(sku_master_full$issue_count,        sku_master_full$chargeback_total,
              method = "spearman")
cat(sprintf("Spearman(quality_score, chargeback_$) = %+.3f\n", cor_q))
cat(sprintf("Spearman(issue_count,   chargeback_$) = %+.3f\n", cor_iss))

cat("\nMean chargeback $ by issue_count bin:\n")
sku_master_full |>
  group_by(issue_count) |>
  summarise(n = n(), mean_cb = round(mean(chargeback_total)),
            median_cb = round(median(chargeback_total)),
            mean_q = round(mean(data_quality_score),1)) |>
  arrange(issue_count) |>
  print()

cat("\nPer-defect chargeback exposure (mean cb among SKUs WITH vs WITHOUT each defect):\n")
defect_cols <- c("gtin_valid","upc_valid","missing_case_weight","missing_case_dims",
                 "missing_country","missing_brand_owner","ows_complete","weight_plausible")
sku_dim_local <- readRDS(file.path(OUT, "sku_dim.rds"))
joined <- sku_dim_local |> select(sku, all_of(defect_cols)) |>
  left_join(sku_master_full |> select(sku, chargeback_total), by = "sku")

for (d in defect_cols) {
  has_defect <- if (d %in% c("gtin_valid","upc_valid","ows_complete","weight_plausible"))
                  !isTRUE(joined[[d]]) | is.na(joined[[d]]) else
                  isTRUE(joined[[d]])
  # vectorize
  flag <- switch(d,
    gtin_valid       = !joined$gtin_valid,
    upc_valid        = !joined$upc_valid,
    ows_complete     = !joined$ows_complete,
    weight_plausible = !joined$weight_plausible | is.na(joined$weight_plausible),
    joined[[d]])
  flag <- as.logical(flag); flag[is.na(flag)] <- FALSE
  with_def    <- joined$chargeback_total[flag]
  without_def <- joined$chargeback_total[!flag]
  cat(sprintf("  %-22s n_with=%2d mean_cb_with=$%6.0f | n_without=%2d mean_cb_without=$%6.0f | ratio=%.2fx\n",
              d, length(with_def),
              if (length(with_def))    mean(with_def)    else NA,
              length(without_def),
              if (length(without_def)) mean(without_def) else NA,
              if (length(without_def) && mean(without_def) > 0)
                mean(with_def)/mean(without_def) else NA))
}

# --- (2) Time-to-shelf variance vs data completeness ----------------------
hr("(2) TIME-TO-SHELF variance by data completeness")

tts_join <- time_to_shelf_sku |>
  left_join(sku_master_full |> select(sku, data_quality_score, issue_count),
            by = "sku")

cat("\nMean & SD of mean_days_to_scan by quality quartile:\n")
tts_join |>
  filter(!is.na(mean_days_to_scan)) |>
  mutate(q_bin = ntile(data_quality_score, 4)) |>
  group_by(q_bin) |>
  summarise(n = n(),
            mean_d = round(mean(mean_days_to_scan), 2),
            sd_d   = round(sd(mean_days_to_scan), 2),
            min_d  = min(mean_days_to_scan),
            max_d  = max(mean_days_to_scan)) |>
  print()

cat("\nUnique values of days_to_first_scan in raw store-level table:\n")
print(table(time_to_shelf_store$days_to_first_scan, useNA = "ifany"))

cat(sprintf("\nVariance of days_to_first_scan: %.4f  (SD = %.4f)\n",
            var(time_to_shelf_store$days_to_first_scan, na.rm = TRUE),
            sd(time_to_shelf_store$days_to_first_scan,  na.rm = TRUE)))

# --- (3) Deauthorization vs data quality ----------------------------------
hr("(3) DEAUTH RATE vs DATA QUALITY")

deauth_join <- deauth_summary |>
  left_join(sku_master_full |> select(sku, data_quality_score, issue_count),
            by = "sku")

cat(sprintf("Spearman(quality_score, deauth_rate) = %+.3f\n",
            cor(deauth_join$data_quality_score, deauth_join$deauth_rate, method = "spearman")))
cat(sprintf("Spearman(issue_count,   deauth_rate) = %+.3f\n",
            cor(deauth_join$issue_count,        deauth_join$deauth_rate, method = "spearman")))

cat("\nMean deauth_rate by quality quartile:\n")
deauth_join |>
  mutate(q_bin = ntile(data_quality_score, 4)) |>
  group_by(q_bin) |>
  summarise(n = n(),
            mean_deauth = round(mean(deauth_rate), 4),
            median_deauth = round(median(deauth_rate), 4),
            n_with_any = sum(deauth_rate > 0)) |>
  print()

cat("\nMean deauth_rate by issue_count bin:\n")
deauth_join |>
  group_by(issue_count) |>
  summarise(n = n(),
            mean_deauth = round(mean(deauth_rate), 4),
            n_with_any = sum(deauth_rate > 0)) |>
  arrange(issue_count) |>
  print()

# --- (4) Promo lift vs data issues ----------------------------------------
hr("(4) PROMO LIFT vs DATA ISSUES")

pe <- promo_eff |> filter(!is.na(lift_pct))
cat(sprintf("Spearman(quality_score, lift_pct) = %+.3f  (n=%d)\n",
            cor(pe$data_quality_score, pe$lift_pct, method = "spearman"), nrow(pe)))
cat(sprintf("Spearman(issue_count,   lift_pct) = %+.3f\n",
            cor(pe$issue_count,        pe$lift_pct, method = "spearman")))

cat("\nMean / median lift by quality tier (3-bin):\n")
pe |>
  mutate(q_bin = ntile(data_quality_score, 3)) |>
  group_by(q_bin) |>
  summarise(n = n(),
            mean_lift   = round(mean(lift_pct), 3),
            median_lift = round(median(lift_pct), 3),
            mean_q      = round(mean(data_quality_score), 1)) |>
  print()

cat("\nLift split by 'has any data issue' (issue_count >= 1):\n")
pe |>
  mutate(has_issue = issue_count >= 1) |>
  group_by(has_issue) |>
  summarise(n = n(),
            mean_lift   = round(mean(lift_pct), 3),
            median_lift = round(median(lift_pct), 3)) |>
  print()
