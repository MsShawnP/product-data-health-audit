# 03_verify.R
# Distribution sanity checks on the synthetic dataset. The point isn't to
# render charts here — it's to confirm the data has the shapes the report
# is going to claim it has, before we spend time on hero charts:
#   * chargebacks: Pareto-skewed (top decile carries the bulk of dollars)
#   * missingness: realistic (some fields very sparse, some clean)
#   * revenue:    long-tailed (a few SKUs do most of the volume)
#   * quality:    correlated with chargebacks (worse data → more $$)
#   * time-to-shelf, deauth rate, retailer readiness: in plausible ranges

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
})

ROOT    <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
OUT_DIR <- file.path(ROOT, "output", "frames")

read_p <- function(name) readRDS(file.path(OUT_DIR, paste0(name, ".rds")))

raw                       <- read_p("raw_tables")
sku_dim                   <- read_p("sku_dim")
sku_master_full           <- read_p("sku_master_full")
sku_retailer_revenue      <- read_p("sku_retailer_revenue")
sku_chargebacks           <- read_p("sku_chargebacks")
chargebacks_enriched      <- read_p("chargebacks_enriched")
retailer_pnl              <- read_p("retailer_pnl")
retailer_readiness_summary<- read_p("retailer_readiness_summary")
time_to_shelf             <- read_p("time_to_shelf_sku_store")
time_to_shelf_sku         <- read_p("time_to_shelf_sku")
deauth_summary            <- read_p("deauth_summary")
process_debt              <- read_p("process_debt")
promo_effectiveness       <- read_p("promo_effectiveness")

hr <- function(t) cat("\n", strrep("=", 70), "\n", t, "\n", strrep("=", 70), "\n", sep = "")

# ---- 1. Chargeback Pareto -------------------------------------------------

hr("1. CHARGEBACK CONCENTRATION (Pareto check)")

cb_total   <- sum(sku_chargebacks$chargeback_total)
n_skus_cb  <- nrow(sku_chargebacks)
n_skus_all <- nrow(sku_dim)

sku_pareto <- sku_chargebacks |>
  arrange(desc(chargeback_total)) |>
  mutate(rank = row_number(),
         cum  = cumsum(chargeback_total),
         cum_pct = cum / cb_total,
         pct_of_skus = rank / n_skus_all)

cat(sprintf("Total chargeback dollars (18mo): $%s across %d SKUs (of %d in catalog)\n",
            format(round(cb_total), big.mark = ","), n_skus_cb, n_skus_all))

for (k in c(0.10, 0.20, 0.30, 0.50)) {
  n_at <- ceiling(k * n_skus_all)
  pct  <- sku_pareto$cum_pct[min(n_at, nrow(sku_pareto))]
  cat(sprintf("  Top %3d%% of SKUs (n=%2d) = %5.1f%% of chargeback dollars\n",
              round(k*100), n_at, 100*pct))
}

# Concentration by retailer.
ret_cb <- chargebacks_enriched |>
  group_by(retailer) |> summarise(amt = sum(amount), n = n(), .groups = "drop") |>
  arrange(desc(amt)) |>
  mutate(pct = amt / sum(amt))
cat("\nBy retailer:\n")
for (i in seq_len(nrow(ret_cb))) {
  cat(sprintf("  %-15s $%-10s  %4.1f%% of total  (%d records)\n",
              ret_cb$retailer[i], format(round(ret_cb$amt[i]), big.mark=","),
              100*ret_cb$pct[i], ret_cb$n[i]))
}

# By reason.
reason_cb <- chargebacks_enriched |>
  group_by(reason) |> summarise(amt = sum(amount), n = n(), .groups = "drop") |>
  arrange(desc(amt)) |> mutate(pct = amt / sum(amt))
cat("\nBy reason:\n")
for (i in seq_len(nrow(reason_cb))) {
  cat(sprintf("  %-30s $%-10s  %4.1f%%  (%d)\n",
              reason_cb$reason[i], format(round(reason_cb$amt[i]), big.mark=","),
              100*reason_cb$pct[i], reason_cb$n[i]))
}

# ---- 2. Missingness patterns ---------------------------------------------

hr(paste0("2. MISSINGNESS BY FIELD (product_master, n=", nrow(raw$product_master), ")"))

miss_tbl <- raw$product_master |>
  summarise(across(everything(), ~ mean(is.na(.) | (. == "" & is.character(.))))) |>
  pivot_longer(everything(), names_to = "field", values_to = "pct_missing") |>
  arrange(desc(pct_missing))

for (i in seq_len(nrow(miss_tbl))) {
  m <- miss_tbl$pct_missing[i]
  bar <- strrep("#", round(m * 30))
  cat(sprintf("  %-25s %5.1f%%  %s\n", miss_tbl$field[i], 100*m, bar))
}

# Quality score distribution.
cat("\nData quality score distribution (sku_dim):\n")
qs <- sku_dim$data_quality_score
cat(sprintf("  min=%.1f  q25=%.1f  median=%.1f  mean=%.1f  q75=%.1f  max=%.1f\n",
            min(qs), quantile(qs,.25), median(qs), mean(qs), quantile(qs,.75), max(qs)))
cat("Issue-count histogram:\n")
print(table(sku_dim$issue_count))

# GTIN/UPC failures.
cat(sprintf("\nGTIN-14 failures: %d / %d (%.1f%%)\n",
            sum(!sku_dim$gtin_valid), nrow(sku_dim),
            100*mean(!sku_dim$gtin_valid)))
cat(sprintf("UPC-12 failures:  %d / %d (%.1f%%)\n",
            sum(!sku_dim$upc_valid), nrow(sku_dim),
            100*mean(!sku_dim$upc_valid)))
cat(sprintf("OneWorldSync incomplete: %d / %d (%.1f%%)\n",
            sum(!sku_dim$ows_complete), nrow(sku_dim),
            100*mean(!sku_dim$ows_complete)))

# ---- 3. Revenue distribution --------------------------------------------

hr(paste0("3. REVENUE DISTRIBUTION (TTM, ", nrow(raw$product_master), " SKUs)"))

rev <- sku_master_full$ttm_revenue
cat(sprintf("Total TTM revenue: $%s\n", format(round(sum(rev)), big.mark=",")))
cat(sprintf("  min=$%s  q25=$%s  median=$%s  mean=$%s  q75=$%s  max=$%s\n",
            format(round(min(rev)), big.mark=","),
            format(round(quantile(rev,.25)), big.mark=","),
            format(round(median(rev)), big.mark=","),
            format(round(mean(rev)), big.mark=","),
            format(round(quantile(rev,.75)), big.mark=","),
            format(round(max(rev)), big.mark=",")))

rev_pareto <- sku_master_full |> arrange(desc(ttm_revenue)) |>
  mutate(cum_pct = cumsum(ttm_revenue)/sum(ttm_revenue),
         pct_of_skus = row_number()/n())
for (k in c(0.10, 0.20, 0.30, 0.50)) {
  n_at <- ceiling(k * nrow(rev_pareto))
  cat(sprintf("  Top %3d%% of SKUs = %4.1f%% of revenue\n",
              round(k*100), 100*rev_pareto$cum_pct[n_at]))
}

# By product line.
cat("\nRevenue by product line:\n")
pl_rev <- sku_master_full |>
  group_by(product_line) |>
  summarise(rev = sum(ttm_revenue), n = n(),
            mean_quality = mean(data_quality_score),
            cb = sum(chargeback_total), .groups = "drop") |>
  mutate(rev_pct = rev / sum(rev))
for (i in seq_len(nrow(pl_rev))) {
  cat(sprintf("  %-22s $%-12s  %4.1f%%  n=%d  mean_quality=%.1f  cb=$%s\n",
              pl_rev$product_line[i],
              format(round(pl_rev$rev[i]), big.mark=","),
              100*pl_rev$rev_pct[i], pl_rev$n[i], pl_rev$mean_quality[i],
              format(round(pl_rev$cb[i]), big.mark=",")))
}

# ---- 4. Quality vs chargeback correlation -------------------------------

hr("4. QUALITY vs. CHARGEBACK CORRELATION")

cor_q_cb <- cor(sku_master_full$data_quality_score,
                sku_master_full$chargeback_total, method = "spearman",
                use = "complete.obs")
cor_iss_cb <- cor(sku_master_full$issue_count,
                  sku_master_full$chargeback_total, method = "spearman",
                  use = "complete.obs")
cat(sprintf("  Spearman(quality_score, chargeback_$): %+.3f\n", cor_q_cb))
cat(sprintf("  Spearman(issue_count,  chargeback_$): %+.3f  (positive = issues -> $$)\n", cor_iss_cb))

# Quartile breakdown.
sku_master_full |>
  mutate(q_bin = ntile(data_quality_score, 4)) |>
  group_by(q_bin) |>
  summarise(n = n(),
            mean_cb       = mean(chargeback_total),
            median_cb     = median(chargeback_total),
            cb_share      = sum(chargeback_total)/sum(sku_master_full$chargeback_total),
            .groups = "drop") |>
  print()

# ---- 5. Retailer P&L ---------------------------------------------------

hr("5. RETAILER P&L SHAPE")
print(retailer_pnl |>
        mutate(across(c(gross_revenue, trade_spend_total, chargeback_total,
                        net_contribution),
                      ~ round(.))) |>
        arrange(desc(gross_revenue)))

# ---- 6. Retailer readiness ---------------------------------------------

hr("6. RETAILER READINESS — pass/fail by retailer")
print(retailer_readiness_summary |>
        group_by(retailer) |>
        summarise(n_skus = n(),
                  n_pass = sum(overall_pass),
                  pass_rate = mean(overall_pass),
                  mean_failed_fields = mean(fields_failed),
                  .groups = "drop") |>
        arrange(pass_rate))

# ---- 7. Time-to-shelf --------------------------------------------------

hr("7. TIME-TO-SHELF (days from authorized_date to first_scan_week)")
tts <- time_to_shelf$days_to_first_scan
tts <- tts[!is.na(tts) & tts >= 0]
cat(sprintf("  n=%d SKU×store auths with a matched scan\n", length(tts)))
if (length(tts) > 0) {
  cat(sprintf("  min=%d  q25=%d  median=%d  mean=%.1f  q75=%d  q95=%d  max=%d\n",
              min(tts), quantile(tts,.25), median(tts), mean(tts),
              quantile(tts,.75), quantile(tts,.95), max(tts)))
} else {
  cat("  (no matched scans — SKU format mismatch between tables)\n")
}

# ---- 8. Deauthorization ------------------------------------------------

hr("8. DEAUTHORIZATION")
cat(sprintf("Overall deauth rate: %.1f%% of SKU×store authorizations\n",
            100 * mean(!is.na(raw$distribution_log$deauthorized_date))))
cat("\nDeauth-rate distribution by SKU:\n")
print(summary(deauth_summary$deauth_rate))

# ---- 9. Process debt ---------------------------------------------------

hr("9. PROCESS DEBT — by updated_by source")
print(process_debt |> mutate(
  total_chargebacks = round(total_chargebacks),
  chargeback_per_sku = round(chargeback_per_sku, 1),
  chargeback_pct_of_rev = round(100*chargeback_pct_of_rev, 2)))

# ---- 10. Promo lift ----------------------------------------------------

hr("10. PROMO EFFECTIVENESS — lift_pct distribution")
lp <- promo_effectiveness$lift_pct
cat(sprintf("  promotions with computable lift: %d / %d\n",
            sum(!is.na(lp)), length(lp)))
cat(sprintf("  median lift=%.1f%%  mean=%.1f%%  q25=%.1f%%  q75=%.1f%%\n",
            100*median(lp, na.rm=TRUE), 100*mean(lp, na.rm=TRUE),
            100*quantile(lp,.25,na.rm=TRUE), 100*quantile(lp,.75,na.rm=TRUE)))

# Lift by quality tier.
cat("\nMean lift by SKU quality tier:\n")
promo_effectiveness |>
  filter(!is.na(lift_pct)) |>
  mutate(q_bin = ntile(data_quality_score, 3)) |>
  group_by(q_bin) |>
  summarise(n = n(), mean_lift = mean(lift_pct), .groups = "drop") |>
  print()

hr("VERIFICATION COMPLETE")
cat("If anything above looks degenerate (no Pareto, zero variance,\n",
    "all-NA fields, no correlation, impossible date gaps) — investigate\n",
    "before building hero charts.\n", sep = "")
