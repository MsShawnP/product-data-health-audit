# _emit_canonical_numbers.R
# Reads the Phase 0C frames and writes output/canonical_numbers.md.
# Every figure cited anywhere in the project (Quarto report, dashboard,
# Excel workbook, executive tearsheet, Shiny calculator defaults) must
# match a number in this file. If a downstream artifact disagrees, that's
# a bug in the artifact, not in the data — re-derive from the frames.
#
# This script is the source of truth Phase 0D establishes. Re-run it any
# time the database is refreshed.

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(stringr); library(lubridate); library(scales)
})

ROOT     <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
FRM_DIR  <- file.path(ROOT, "output", "frames")
DB_PATH  <- file.path(ROOT, "data", "cinderhaven_product_master.db")
OUT_FILE <- file.path(ROOT, "output", "canonical_numbers.md")

read_p <- function(name) readRDS(file.path(FRM_DIR, paste0(name, ".rds")))
sku_master_full  <- read_p("sku_master_full")
sku_dim          <- read_p("sku_dim")
sku_revenue      <- read_p("sku_revenue")
chargebacks_e    <- read_p("chargebacks_enriched")
sku_chargebacks  <- read_p("sku_chargebacks")
retailer_pnl     <- read_p("retailer_pnl")
retailer_rs      <- read_p("retailer_readiness_summary")
deauth_summary   <- read_p("deauth_summary")
process_debt     <- read_p("process_debt")
time_to_shelf    <- read_p("time_to_shelf_sku")
promo_eff        <- read_p("promo_effectiveness")
raw              <- read_p("raw_tables")

# ---- snapshot metadata ---------------------------------------------------

db_info     <- file.info(DB_PATH)
db_mtime    <- format(db_info$mtime, "%Y-%m-%d %H:%M:%S")
db_size_mb  <- round(db_info$size / 1024^2, 1)

# ---- catalog shape -------------------------------------------------------

n_skus       <- nrow(sku_master_full)
n_lines      <- length(unique(sku_master_full$product_line))
line_counts  <- sku_master_full |> count(product_line) |>
  mutate(label = paste0(product_line, " (", n, ")")) |> pull(label) |>
  paste(collapse = ", ")
n_stores     <- nrow(raw$stores)
contracted   <- c("Walmart", "Costco", "UNFI", "Whole Foods")

scan_min     <- format(min(ymd(raw$scan_data$week_ending)), "%Y-%m-%d")
scan_max     <- format(max(ymd(raw$scan_data$week_ending)), "%Y-%m-%d")
scan_weeks   <- length(unique(raw$scan_data$week_ending))

# ---- revenue -------------------------------------------------------------

ttm_rev      <- sum(sku_master_full$ttm_revenue)
top_sku_rev  <- sku_master_full |> arrange(desc(ttm_revenue)) |> slice(1)
top10_share  <- sum(sort(sku_master_full$ttm_revenue, decreasing = TRUE)[1:9]) / ttm_rev
top20_share  <- sum(sort(sku_master_full$ttm_revenue, decreasing = TRUE)[1:18]) / ttm_rev

mean_q_full  <- mean(sku_master_full$data_quality_score)
mean_q_top15 <- sku_master_full |>
  arrange(desc(ttm_revenue)) |> slice(1:15) |>
  pull(data_quality_score) |> mean()

# ---- chargebacks ---------------------------------------------------------

cb_18mo      <- sum(sku_master_full$chargeback_total)
cb_annual    <- cb_18mo * 12 / 18

cb_p <- sku_master_full |> filter(chargeback_total > 0) |>
  arrange(desc(chargeback_total)) |>
  mutate(rank = row_number(),
         cum_pct = cumsum(chargeback_total) / sum(chargeback_total))
n50          <- min(which(cb_p$cum_pct >= 0.50))
n80          <- min(which(cb_p$cum_pct >= 0.80))
n_with_cb    <- nrow(cb_p)
n_without_cb <- n_skus - n_with_cb

cb_top1      <- cb_p |> slice(1)

# By reason
cb_by_reason <- chargebacks_e |>
  group_by(reason) |>
  summarise(amt = sum(amount), n = n(), .groups = "drop") |>
  arrange(desc(amt)) |>
  mutate(pct = 100 * amt / sum(amt))

cb_data_defect_pct <- sum(cb_by_reason$amt[cb_by_reason$reason %in%
  c("Invalid GTIN/UPC", "Missing product data", "Dimension mismatch")]) /
  sum(cb_by_reason$amt) * 100

# By retailer
cb_by_retailer <- chargebacks_e |>
  group_by(retailer) |>
  summarise(amt = sum(amount), n = n(), .groups = "drop") |>
  arrange(desc(amt)) |>
  left_join(retailer_pnl |> select(retailer, gross_revenue), by = "retailer") |>
  mutate(pct_total = 100 * amt / sum(amt),
         pct_of_rev = 100 * amt / gross_revenue)

# CHP-0082 highlight
cb_pct_gm <- sku_master_full |>
  filter(!is.na(chargeback_pct_of_gm), chargeback_pct_of_gm > 0,
         annual_gross_margin > 0) |>
  arrange(desc(chargeback_pct_of_gm)) |> slice(1:5)

# ---- retailer readiness --------------------------------------------------

rs_revenue <- retailer_rs |>
  left_join(sku_master_full |> select(sku, ttm_revenue), by = "sku") |>
  group_by(retailer) |>
  summarise(
    n_pass = sum(overall_pass),
    n_fail = sum(!overall_pass),
    pass_rate = mean(overall_pass),
    rev_at_risk = sum(ttm_revenue[!overall_pass], na.rm = TRUE),
    rev_total   = sum(ttm_revenue, na.rm = TRUE),
    rar_pct     = rev_at_risk / rev_total,
    mean_failed = mean(fields_failed),
    .groups = "drop") |>
  arrange(desc(rev_at_risk))

# ---- retailer P&L --------------------------------------------------------

pnl_contracted <- retailer_pnl |>
  filter(retailer %in% contracted) |>
  arrange(desc(gross_revenue))

# ---- defects -------------------------------------------------------------

n_gtin_invalid <- sum(!sku_dim$gtin_valid)
n_upc_invalid  <- sum(!sku_dim$upc_valid)
n_ows_incomp   <- sum(!sku_dim$ows_complete)

rev_share <- function(flag) {
  flag <- as.logical(flag); flag[is.na(flag)] <- FALSE
  sum(sku_master_full$ttm_revenue[flag]) / ttm_rev
}
gtin_rev_share <- rev_share(!sku_dim$gtin_valid)
dims_rev_share <- rev_share(sku_dim$missing_case_dims)

# ---- time-to-shelf -------------------------------------------------------

tts <- time_to_shelf |>
  left_join(sku_master_full |> select(sku, data_quality_score), by = "sku") |>
  filter(!is.na(mean_days_to_scan)) |>
  mutate(quartile = ntile(data_quality_score, 4))

tts_by_q <- tts |>
  group_by(quartile) |>
  summarise(n = n(), mean_d = mean(mean_days_to_scan), .groups = "drop")

q_worst_d  <- tts_by_q$mean_d[tts_by_q$quartile == 1]
q_best_d   <- tts_by_q$mean_d[tts_by_q$quartile == 4]

# ---- deauthorization -----------------------------------------------------

dq <- deauth_summary |>
  left_join(sku_master_full |> select(sku, data_quality_score), by = "sku") |>
  mutate(quartile = ntile(data_quality_score, 4))
deauth_overall <- sum(deauth_summary$deauth_count) /
  sum(deauth_summary$auth_count)

deauth_by_q <- dq |>
  group_by(quartile) |>
  summarise(rate = mean(deauth_rate), n_with_any = sum(deauth_rate > 0),
            n = n(), .groups = "drop")

# ---- product-line density ------------------------------------------------

pl_debt <- sku_master_full |>
  group_by(product_line) |>
  summarise(rev_M = sum(ttm_revenue) / 1e6,
            issues = sum(issue_count),
            issues_per_M = sum(issue_count) / (sum(ttm_revenue) / 1e6),
            cb = sum(chargeback_total),
            cb_per_M = sum(chargeback_total) / (sum(ttm_revenue) / 1e6),
            .groups = "drop") |>
  arrange(desc(issues_per_M))

# ---- process debt --------------------------------------------------------

broker_row <- process_debt |> filter(updated_by == "broker_upload")
prod_row   <- process_debt |> filter(updated_by == "production_admin")

# ---- promo lift ----------------------------------------------------------

pe2 <- promo_eff |> filter(!is.na(lift_pct))
n_promo_total      <- nrow(promo_eff)
n_promo_computable <- nrow(pe2)
promo_mean_lift    <- mean(pe2$lift_pct)
promo_median_lift  <- median(pe2$lift_pct)

# ---- emit ----------------------------------------------------------------

dol_one <- function(x, scale = "auto") {
  if (is.na(x)) return("—")
  if (scale == "M" || (scale == "auto" && abs(x) >= 1e6))
    return(sprintf("$%.2fM", x / 1e6))
  if (scale == "k" || (scale == "auto" && abs(x) >= 1e3))
    return(sprintf("$%.0fk", x / 1e3))
  paste0("$", formatC(round(x), big.mark = ",", format = "d"))
}
dol <- function(x, scale = "auto") vapply(x, dol_one, character(1), scale = scale)
pct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)

now <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

out <- c(
"# Cinderhaven canonical numbers",
"",
sprintf("_Generated %s by `R/_emit_canonical_numbers.R`._", now),
sprintf("_Source database: `data/cinderhaven_product_master.db` (%.1f MB, mtime %s)._",
        db_size_mb, db_mtime),
"",
"This document is the **single source of truth** for every numeric claim",
"made anywhere in the project. The Quarto report, the dashboard, the Excel",
"workbook, the executive tearsheet, and the Shiny calculator defaults all",
"derive their numbers from the same `output/frames/*.rds` files this script",
"reads. If two artifacts disagree on a number, the artifact is wrong — not",
"this file.",
"",
"All numbers re-derive automatically when `R/run_all.R` is rerun against a",
"new snapshot of the SQLite database. The R expressions in fenced blocks",
"below are exact; copy-paste any of them into the project to verify.",
"",
"---",
"",
"## Catalog shape",
"",
sprintf("- **%d SKUs** across %d product lines (%s).", n_skus, n_lines, line_counts),
sprintf("- **%d stores** in `stores` table; %d contracted retailers (%s).",
        n_stores, length(contracted), paste(contracted, collapse = ", ")),
sprintf("- Scan data window: **%s → %s** (%d weekly periods).",
        scan_min, scan_max, scan_weeks),
sprintf("- Database row counts: chargebacks %d, distribution_log %d, scan_data %s, promotions %d.",
        nrow(raw$chargebacks),
        nrow(raw$distribution_log),
        formatC(nrow(raw$scan_data), big.mark = ",", format = "d"),
        nrow(raw$promotions)),
"",
"## Headline numbers",
"",
sprintf("| Metric | Value | Re-derive |"),
"|---|---:|---|",
sprintf("| TTM revenue, all SKUs | **%s** | `sum(sku_master_full$ttm_revenue)` |",
        dol(ttm_rev)),
sprintf("| 18-month chargeback total | **%s** | `sum(sku_master_full$chargeback_total)` |",
        dol(cb_18mo)),
sprintf("| Annualized chargeback run-rate | **%s** | `cb_18mo * 12 / 18` |",
        dol(cb_annual)),
sprintf("| Walmart revenue at risk | **%s** | failing-readiness SKUs × ttm_revenue, Walmart |",
        dol(rs_revenue$rev_at_risk[rs_revenue$retailer == "Walmart"], "M")),
sprintf("| Catalog mean data-quality score | **%.1f** | `mean(sku_master_full$data_quality_score)` |",
        mean_q_full),
sprintf("| Top-15-by-revenue mean quality | **%.1f** | top 15 by ttm_revenue, mean of quality_score |",
        mean_q_top15),
"",
"## Chargeback Pareto",
"",
sprintf("- **%d of %d SKUs** carry any chargebacks; %d carry none.",
        n_with_cb, n_skus, n_without_cb),
sprintf("- **%d SKUs** account for 50%% of chargeback dollars.", n50),
sprintf("- **%d SKUs** account for 80%% of chargeback dollars.", n80),
sprintf("- Top SKU: **%s — %s** at %s (%.1f%% of total).",
        cb_top1$sku, cb_top1$product_name, dol(cb_top1$chargeback_total),
        100 * cb_top1$cum_pct[1]),
"",
"### Chargeback dollars by reason",
"",
"| Reason | $ (18mo) | % | Events |",
"|---|---:|---:|---:|",
paste(sprintf("| %s | %s | %s | %d |",
              cb_by_reason$reason,
              dol(cb_by_reason$amt),
              pct(cb_by_reason$pct / 100, 1),
              cb_by_reason$n),
      collapse = "\n"),
"",
sprintf("Three data-defect reasons (Invalid GTIN/UPC, Missing product data,"),
sprintf("Dimension mismatch) account for **%.1f%%** of chargeback dollars.",
        cb_data_defect_pct),
"",
"### Chargeback dollars by retailer",
"",
"| Retailer | $ (18mo) | % of cb total | % of retailer revenue |",
"|---|---:|---:|---:|",
paste(sprintf("| %s | %s | %s | %s |",
              cb_by_retailer$retailer,
              dol(cb_by_retailer$amt),
              pct(cb_by_retailer$pct_total / 100, 1),
              pct(cb_by_retailer$pct_of_rev / 100, 2)),
      collapse = "\n"),
"",
"## Chargebacks as % of gross margin (top 5)",
"",
"| SKU | Product | Chargebacks | Gross margin | Cb % of GM |",
"|---|---|---:|---:|---:|",
paste(sprintf("| %s | %s | %s | %s | **%.1f%%** |",
              cb_pct_gm$sku,
              cb_pct_gm$product_name,
              dol(cb_pct_gm$chargeback_total),
              dol(cb_pct_gm$annual_gross_margin),
              100 * cb_pct_gm$chargeback_pct_of_gm),
      collapse = "\n"),
"",
sprintf("**The headline:** %s (%s) carries %s in chargebacks against",
        cb_pct_gm$sku[1], cb_pct_gm$product_name[1],
        dol(cb_pct_gm$chargeback_total[1])),
sprintf("%s in TTM gross margin — **%.1f%% of gross margin to chargebacks**.",
        dol(cb_pct_gm$annual_gross_margin[1]),
        100 * cb_pct_gm$chargeback_pct_of_gm[1]),
"",
"## Retailer readiness — revenue at risk",
"",
"| Retailer | SKUs failing | Pass rate | Revenue at risk | % of catalog rev | Avg fields short |",
"|---|---:|---:|---:|---:|---:|",
paste(sprintf("| %s | %d / %d | %s | %s | %s | %.2f |",
              rs_revenue$retailer,
              rs_revenue$n_fail,
              rs_revenue$n_fail + rs_revenue$n_pass,
              pct(rs_revenue$pass_rate, 1),
              dol(rs_revenue$rev_at_risk, "M"),
              pct(rs_revenue$rar_pct, 1),
              rs_revenue$mean_failed),
      collapse = "\n"),
"",
"## Retailer P&L (TTM, contracted retailers only)",
"",
"| Retailer | Gross revenue | Trade spend | Chargebacks | Net contribution | Net margin % |",
"|---|---:|---:|---:|---:|---:|",
paste(sprintf("| %s | %s | %s (%s) | %s (%s) | **%s** | **%.1f%%** |",
              pnl_contracted$retailer,
              dol(pnl_contracted$gross_revenue, "M"),
              dol(pnl_contracted$trade_spend_total),
              pct(pnl_contracted$trade_spend_pct_of_revenue, 1),
              dol(pnl_contracted$chargeback_total),
              pct(pnl_contracted$chargeback_pct_of_revenue, 2),
              dol(pnl_contracted$net_contribution, "M"),
              100 * pnl_contracted$net_margin_pct_of_gross_revenue),
      collapse = "\n"),
"",
"## Defect counts and revenue concentration",
"",
sprintf("- **GTIN-14 invalid:** %d of %d SKUs (%.1f%% of catalog) carrying %s of TTM revenue (%.1f%%).",
        n_gtin_invalid, n_skus, 100 * n_gtin_invalid / n_skus,
        dol(gtin_rev_share * ttm_rev, "M"), 100 * gtin_rev_share),
sprintf("- **UPC-12 invalid:** %d of %d SKUs.", n_upc_invalid, n_skus),
sprintf("- **OneWorldSync incomplete:** %d of %d SKUs (%.1f%% — only %d in 'Registered – Complete').",
        n_ows_incomp, n_skus, 100 * n_ows_incomp / n_skus, n_skus - n_ows_incomp),
sprintf("- **Missing case dimensions:** %.1f%% of SKUs, %.1f%% of revenue.",
        100 * mean(sku_dim$missing_case_dims), 100 * dims_rev_share),
"",
"Validator note: this audit uses the dataset's own mod-10 algorithm for",
"GTIN/UPC check digits. Strict GS1 weights would flag a much larger share",
"of the catalog. See methodology appendix for the trade-off.",
"",
"## Time-to-shelf by data-quality tier",
"",
"| Tier (label used in report) | n SKUs | Mean days to first scan |",
"|---|---:|---:|",
sprintf("| Worst 25%% (lowest data-quality scores) | %d | %.1f |",
        tts_by_q$n[1], tts_by_q$mean_d[1]),
sprintf("| Below average | %d | %.1f |",
        tts_by_q$n[2], tts_by_q$mean_d[2]),
sprintf("| Above average | %d | %.1f |",
        tts_by_q$n[3], tts_by_q$mean_d[3]),
sprintf("| Best 25%% | %d | %.1f |",
        tts_by_q$n[4], tts_by_q$mean_d[4]),
"",
sprintf("**The 3× headline:** worst tier averages **%.1f days** vs. best tier",
        q_worst_d),
sprintf("**%.1f days** — a %.1f× spread in time-to-shelf.",
        q_best_d, q_worst_d / q_best_d),
"",
"## Deauthorization",
"",
sprintf("- Overall deauth rate: %.2f%% (%d deauths across %s authorizations).",
        100 * deauth_overall, sum(deauth_summary$deauth_count),
        formatC(sum(deauth_summary$auth_count), big.mark = ",", format = "d")),
sprintf("- Bottom-half quality SKUs (worst 25%% + below average): mean rate %.2f%%, **%d** SKUs with any deauth.",
        100 * mean(c(deauth_by_q$rate[1], deauth_by_q$rate[2])),
        deauth_by_q$n_with_any[1] + deauth_by_q$n_with_any[2]),
sprintf("- Top-half quality SKUs (above average + best 25%%): mean rate %.2f%%, **%d** SKUs with any deauth.",
        100 * mean(c(deauth_by_q$rate[3], deauth_by_q$rate[4])),
        deauth_by_q$n_with_any[3] + deauth_by_q$n_with_any[4]),
"",
"## Data debt by product line",
"",
"| Product line | TTM revenue | Total issues | Issues per $1M | Chargebacks | Cb per $1M |",
"|---|---:|---:|---:|---:|---:|",
paste(sprintf("| %s | $%.2fM | %d | **%.1f** | %s | $%s |",
              pl_debt$product_line,
              pl_debt$rev_M,
              pl_debt$issues,
              pl_debt$issues_per_M,
              dol(pl_debt$cb),
              formatC(round(pl_debt$cb_per_M), big.mark = ",", format = "d")),
      collapse = "\n"),
"",
"## Process debt by data-entry source",
"",
"| Source | n SKUs | Mean quality | Total chargebacks | $/SKU |",
"|---|---:|---:|---:|---:|",
paste(sprintf("| %s | %d | %.1f | %s | $%s |",
              ifelse(is.na(process_debt$updated_by),
                     "(unknown / NA)", process_debt$updated_by),
              process_debt$n_skus,
              process_debt$mean_quality_score,
              dol(process_debt$total_chargebacks),
              formatC(round(process_debt$chargeback_per_sku),
                      big.mark = ",", format = "d")),
      collapse = "\n"),
"",
sprintf("**The 3.3× ratio:** broker_upload averages $%s in chargebacks per SKU vs. production_admin's $%s — **%.1f×**.",
        formatC(round(broker_row$chargeback_per_sku), big.mark = ",", format = "d"),
        formatC(round(prod_row$chargeback_per_sku), big.mark = ",", format = "d"),
        broker_row$chargeback_per_sku / prod_row$chargeback_per_sku),
"",
"## Promo lift",
"",
sprintf("- %d of %d promotions have enough prior scan history to compute lift cleanly.",
        n_promo_computable, n_promo_total),
sprintf("- Across computable promos: median lift %.1f%%, mean lift %.1f%%.",
        100 * promo_median_lift, 100 * promo_mean_lift),
"",
"## Reconciliation against the Python HTML report",
"",
"The original HTML audit report (Python-generated, in the separate",
"`product-data-audit-queries` repo) was built against an earlier database",
"snapshot. Phase 8 of the rebuild plan calls for regenerating that report",
"against the current snapshot so all Cinderhaven artifacts agree on the",
"same numbers. Until that regeneration ships, **the Phase 0 frames in this",
"file are canonical** — any discrepancy is a stale-snapshot artifact in",
"the Python report, not a defect in the R pipeline.",
"",
"### How to verify a single number",
"",
"```r",
"# From the project root, in R:",
'source("R/00_theme.R")  # not strictly required for verification',
'frames <- "output/frames"',
'sku_master_full <- readRDS(file.path(frames, "sku_master_full.rds"))',
"",
"# Annual chargeback run-rate:",
"sum(sku_master_full$chargeback_total) * 12 / 18",
"",
"# Walmart revenue at risk:",
'rs <- readRDS(file.path(frames, "retailer_readiness_summary.rds"))',
'rs |> dplyr::filter(retailer == "Walmart", !overall_pass) |>',
"  dplyr::left_join(sku_master_full |> dplyr::select(sku, ttm_revenue),",
'                    by = "sku") |>',
"  dplyr::summarise(rar = sum(ttm_revenue))",
"```",
"",
"---",
"",
sprintf("_Last regenerated: %s._", now)
)

writeLines(out, OUT_FILE)
cat(sprintf("Wrote: %s (%.1f KB, %d lines)\n",
            OUT_FILE, file.info(OUT_FILE)$size / 1024,
            length(out)))
