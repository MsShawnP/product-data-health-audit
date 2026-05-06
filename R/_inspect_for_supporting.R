# Quick inspection ahead of supporting-chart build.
# Decide whether charts 10 (new vs old), 16 (seasonality), 22 (serving variants)
# have enough signal to be worth a chart.

suppressPackageStartupMessages({
  library(dplyr); library(stringr); library(lubridate)
})

ROOT     <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
PROC_DIR <- file.path(ROOT, "data", "processed")
raw      <- readRDS(file.path(PROC_DIR, "raw_tables.rds"))
sku_dim  <- readRDS(file.path(PROC_DIR, "sku_dim.rds"))
ce       <- readRDS(file.path(PROC_DIR, "chargebacks_enriched.rds"))

hr <- function(t) cat("\n", strrep("=", 60), "\n", t, "\n", strrep("=", 60), "\n", sep="")

hr("CHART 10 — last_updated variation")
lu <- raw$product_master$last_updated
cat("range:", as.character(min(lu, na.rm=TRUE)), "→",
    as.character(max(lu, na.rm=TRUE)), "\n")
cat("n distinct dates:", length(unique(lu)), "\n")
cat("days_since_update range:",
    range(sku_dim$days_since_update, na.rm=TRUE), "\n")
cat("Spearman(days_since_update, data_quality_score) =",
    round(cor(sku_dim$days_since_update, sku_dim$data_quality_score,
              method="spearman", use="complete.obs"), 3), "\n")

hr("CHART 16 — monthly chargebacks AND monthly scan dollars (overlap)")
ce_monthly <- ce |>
  mutate(month = floor_date(month_date, "month")) |>
  group_by(month) |>
  summarise(cb = sum(amount), n = n(), .groups="drop")
print(ce_monthly)
cat("\nMonthly scan dollars range:\n")
sd_monthly <- raw$scan_data |>
  mutate(month = floor_date(ymd(week_ending), "month")) |>
  group_by(month) |>
  summarise(dollars = sum(dollars_sold), .groups="drop") |>
  arrange(month)
print(head(sd_monthly, 5))
print(tail(sd_monthly, 5))

hr("CHART 22 — serving_size distinct values")
ss <- raw$product_master$serving_size
cat("distinct n:", length(unique(ss)), "\n")
print(head(sort(table(ss), decreasing=TRUE), 12))

hr("Also sanity: oneworldsync_status distinct values")
print(table(raw$product_master$oneworldsync_status, useNA="ifany"))
