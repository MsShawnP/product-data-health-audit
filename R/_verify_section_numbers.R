# Verify exact numbers cited in quarto/report.qmd sections 4 and 5.
suppressPackageStartupMessages({library(dplyr)})
ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
sd  <- readRDS(file.path(ROOT, "data/processed/sku_dim.rds"))
smf <- readRDS(file.path(ROOT, "data/processed/sku_master_full.rds"))

j <- left_join(
  sd  |> select(sku, gtin_valid, upc_valid, missing_case_dims,
                missing_case_weight, missing_brand_owner, missing_country,
                weight_plausible, ows_complete),
  smf |> select(sku, ttm_revenue, chargeback_total, issue_count, product_line),
  by = "sku")

total_rev <- sum(j$ttm_revenue)
cat("Total TTM rev: $", format(total_rev, big.mark = ","), "\n\n", sep = "")

cat("Revenue share of SKUs failing each defect:\n")
chk <- function(name, flag) {
  flag <- as.logical(flag); flag[is.na(flag)] <- FALSE
  cat(sprintf("  %-25s n=%2d  rev=$%5.2fM  share=%5.1f%%\n",
    name, sum(flag), sum(j$ttm_revenue[flag]) / 1e6,
    100 * sum(j$ttm_revenue[flag]) / total_rev))
}
chk("Invalid GTIN",        !j$gtin_valid)
chk("Invalid UPC",         !j$upc_valid)
chk("Missing case dims",    j$missing_case_dims)
chk("Missing case weight",  j$missing_case_weight)
chk("Missing brand owner",  j$missing_brand_owner)
chk("Missing country",      j$missing_country)
chk("OWS incomplete",      !j$ows_complete)
chk("Implausible case wt", !is.na(j$weight_plausible) & !j$weight_plausible)

cat("\nBy product line:\n")
j |> group_by(product_line) |>
  summarise(n_skus       = n(),
            rev_M        = sum(ttm_revenue) / 1e6,
            total_issues = sum(issue_count),
            mean_issues  = mean(issue_count),
            issues_per_M = sum(issue_count) / (sum(ttm_revenue) / 1e6),
            cb           = sum(chargeback_total),
            cb_per_M     = sum(chargeback_total) / (sum(ttm_revenue) / 1e6),
            .groups = "drop") |>
  arrange(desc(issues_per_M)) |> print()
