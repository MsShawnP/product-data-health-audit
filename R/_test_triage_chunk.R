# Standalone test of the §18 triage reactable chunk.
suppressPackageStartupMessages({
  library(dplyr); library(reactable); library(htmltools)
})
proc_dir <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit/data/processed"
smf <- readRDS(file.path(proc_dir, "sku_master_full.rds"))

triage <- smf |>
  arrange(desc(fix_priority_score)) |>
  transmute(
    SKU = sku,
    Product = product_name,
    Line    = product_line,
    Priority = round(fix_priority_score, 0),
    `TTM revenue ($)` = round(ttm_revenue),
    `Issues (of 8)`   = issue_count,
    `Quality score`   = round(data_quality_score, 1),
    `Chargebacks 18mo ($)` = round(chargeback_total),
    `Days to shelf`   = round(mean_days_to_scan, 1),
    `Cb % of GM`      = ifelse(is.na(chargeback_pct_of_gm), NA,
                                round(100 * chargeback_pct_of_gm, 1)))

cat("triage dim: ", dim(triage), "\n")
cat("top 5:\n"); print(head(triage, 5))

rt <- reactable(
  triage,
  defaultSorted = list(Priority = "desc"),
  searchable    = TRUE,
  filterable    = TRUE,
  highlight     = TRUE,
  bordered      = FALSE,
  striped       = TRUE,
  defaultPageSize = 15)
cat("reactable widget class:", class(rt)[1], "\n")
cat("OK\n")
