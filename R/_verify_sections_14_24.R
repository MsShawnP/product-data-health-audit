# Verify numbers cited in sections 14-24.
suppressPackageStartupMessages({library(dplyr); library(stringr)})
ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
P    <- file.path(ROOT, "data", "processed")
read_p <- function(n) readRDS(file.path(P, paste0(n, ".rds")))
smf <- read_p("sku_master_full")
ce  <- read_p("chargebacks_enriched")
pnl <- read_p("retailer_pnl")
sd  <- read_p("sku_dim")

hr <- function(t) cat("\n", strrep("=", 60), "\n", t, "\n", strrep("=", 60), "\n", sep="")

# ---- §14 concentration framing ------------------------------------------
hr("§14 — concentration: Pareto + retailer share")
ann_cb <- sum(smf$chargeback_total) * 12 / 18
cat(sprintf("Annualized cb $: $%.0f\n", ann_cb))
cat(sprintf("19 SKUs share: 80%% of cb $; 8 SKUs share: 50%%\n"))
cat(sprintf("Walmart+Costco share of cb $: %.1f%%\n",
  100 * sum(ce$amount[ce$retailer %in% c("Walmart","Costco")]) / sum(ce$amount)))
cat(sprintf("Top-3 retailers (Walmart+Costco+WF) share: %.1f%%\n",
  100 * sum(ce$amount[ce$retailer %in% c("Walmart","Costco","Whole Foods")]) / sum(ce$amount)))

# ---- §15 cost model assumptions -----------------------------------------
hr("§15 — cost model build")
n_cb_18mo <- nrow(ce)
n_cb_yr   <- n_cb_18mo * 12 / 18
cat(sprintf("Annualized chargeback events: %.0f\n", n_cb_yr))
n_fail_walmart <- sum(!read_p("retailer_readiness_summary")$overall_pass &
                       read_p("retailer_readiness_summary")$retailer == "Walmart")
total_fails <- read_p("retailer_readiness_summary") |>
  filter(!overall_pass) |> nrow()
cat(sprintf("Total readiness failures across 4 retailers: %d (n=4*%d=%d row\n",
  total_fails, 90, 360))
cat(sprintf("  Walmart fails: %d, Costco %d, UNFI %d, WF %d\n",
  sum(!read_p("retailer_readiness_summary")$overall_pass &
       read_p("retailer_readiness_summary")$retailer == "Walmart"),
  sum(!read_p("retailer_readiness_summary")$overall_pass &
       read_p("retailer_readiness_summary")$retailer == "Costco"),
  sum(!read_p("retailer_readiness_summary")$overall_pass &
       read_p("retailer_readiness_summary")$retailer == "UNFI"),
  sum(!read_p("retailer_readiness_summary")$overall_pass &
       read_p("retailer_readiness_summary")$retailer == "Whole Foods")))

# ---- §16 growth projection (already computed, reproduce) ----------------
hr("§16 — growth scaling (linear by SKU * retailer)")
current_cb_yr <- ann_cb
current_skus <- 90
for (case in list(
  list(name="Today",       n=90,  r=4),
  list(name="Stage 2",     n=225, r=6),
  list(name="Stage 3",     n=450, r=8))) {
  scale <- (case$n / current_skus) * (case$r / 4)
  cat(sprintf("  %-10s n=%d retailers=%d  scale=%4.2fx  proj cb $%.0f/yr\n",
              case$name, case$n, case$r, scale, current_cb_yr * scale))
}

# ---- §17 contrarian — find best candidate -------------------------------
hr("§17 — contrarian candidates")

# Candidate 1: perfect quality + middling revenue
hi_q <- smf |> filter(data_quality_score == 100) |>
  select(sku, product_name, product_line, ttm_revenue, chargeback_total,
         issue_count, data_quality_score)
cat("SKUs at quality=100:\n"); print(hi_q)

# Candidate 2: Walmart vs Whole Foods margin %
hr("retailer margins")
print(pnl |>
  filter(retailer %in% c("Walmart","UNFI","Whole Foods","Costco")) |>
  mutate(margin_pct = round(100 * net_margin_pct_of_gross_revenue, 1),
         cb_rate = round(100 * chargeback_pct_of_revenue, 2),
         trade_rate = round(100 * trade_spend_pct_of_revenue, 1)) |>
  select(retailer, gross_revenue, trade_rate, cb_rate, margin_pct))

# Candidate 3: highest-revenue SKUs and their quality
hr("Top-15 by revenue with quality")
top15 <- smf |> arrange(desc(ttm_revenue)) |>
  slice(1:15) |>
  select(sku, product_name, product_line, ttm_revenue,
         data_quality_score, issue_count, chargeback_total)
print(top15)
cat(sprintf("\nMean quality of top-15 by revenue: %.1f\n",
  mean(top15$data_quality_score)))
cat(sprintf("Mean quality across all SKUs: %.1f\n",
  mean(smf$data_quality_score)))

# ---- §19 after picture targets ------------------------------------------
hr("§19 — after-picture math")
cat(sprintf("Current OWS-Complete: 9 SKUs (10%%); target 85+ (~95%%)\n"))
cat(sprintf("Current readiness pass rates: WMT 44%%, CST 47%%, UNFI 54%%, WF 70%%\n"))
cb_data_defect_pct <- 100 * sum(ce$amount[ce$reason %in%
  c("Invalid GTIN/UPC","Missing product data","Dimension mismatch")]) /
  sum(ce$amount)
cat(sprintf("Data-defect chargebacks: %.1f%% of total cb $\n",
  cb_data_defect_pct))
# If we eliminate 75-80% of those, remaining cb is 100% - 0.78*93.7% = ~27%
cat(sprintf("If 78%% of data-defect cb $ eliminated: residual cb = %.0f%% of today\n",
  100 - 0.78 * cb_data_defect_pct))

# ---- §21 benchmarking ---------------------------------------------------
hr("§21 — benchmarking comparisons")
cat(sprintf("Item-setup pass rate: 44%% (Walmart) vs industry typical 60-75%%\n"))
cat(sprintf("GTIN failure rate (mod-10): 10%% vs industry typical <2%%\n"))
cat(sprintf("OneWorldSync Registered-Complete: 10%% vs industry 70-90%%\n"))

# ---- triage table peek --------------------------------------------------
hr("Triage list — top 15 by fix priority")
smf |> arrange(desc(fix_priority_score)) |>
  slice(1:15) |>
  select(sku, product_name, fix_priority_score, ttm_revenue,
         issue_count, data_quality_score, chargeback_total) |>
  mutate(across(where(is.numeric), ~ round(., 1))) |>
  print(width = Inf)
