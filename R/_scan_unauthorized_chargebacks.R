suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })

ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
raw  <- readRDS(file.path(ROOT, "output/frames/raw_tables.rds"))
cb   <- read_csv(file.path(ROOT, "output/frames/chargebacks_enriched.csv"),
                 show_col_types = FALSE)
smf  <- readRDS(file.path(ROOT, "output/frames/sku_master_full.rds"))

stores  <- raw$stores
distlog <- raw$distribution_log

# Authorized SKU x retailer pairs (any time period, regardless of deauth)
auth_pairs <- distlog |>
  left_join(stores |> select(store_id, retailer), by = "store_id") |>
  distinct(sku, retailer) |>
  mutate(authorized = TRUE)

cb_flag <- cb |>
  left_join(auth_pairs, by = c("sku", "retailer")) |>
  mutate(authorized = coalesce(authorized, FALSE))

unauth_total <- sum(cb_flag$amount[!cb_flag$authorized])
auth_total   <- sum(cb_flag$amount[ cb_flag$authorized])
total        <- sum(cb_flag$amount)

cat(sprintf("Total chargebacks: $%s\n", format(round(total,2), big.mark=",")))
cat(sprintf("  ON authorized SKU x retailer pairs:   $%s (%.1f%%)\n",
            format(round(auth_total,2), big.mark=","), 100*auth_total/total))
cat(sprintf("  ON UNAUTHORIZED SKU x retailer pairs: $%s (%.1f%%)\n",
            format(round(unauth_total,2), big.mark=","), 100*unauth_total/total))

unauth_by_sku <- cb_flag |>
  filter(!authorized) |>
  group_by(sku, product_name) |>
  summarise(unauth_dollars = sum(amount),
            n_events       = n(),
            n_unauth_retailers = n_distinct(retailer),
            unauth_retailers = paste(sort(unique(retailer)), collapse="; "),
            .groups = "drop") |>
  arrange(desc(unauth_dollars))

cat(sprintf("\nSKUs affected: %d\n", nrow(unauth_by_sku)))
cat(sprintf("Total unauthorized chargeback events: %d of %d (%.1f%%)\n",
            sum(!cb_flag$authorized), nrow(cb_flag),
            100*mean(!cb_flag$authorized)))

cat("\nTop 10 SKUs by unauthorized chargeback dollars:\n")
print(unauth_by_sku |> head(10), n=10)

# --- New kill candidate after cleanup ---
# Compute per-SKU "clean" chargeback total = only chargebacks on authorized retailers
clean_cb <- cb_flag |> filter(authorized) |>
  group_by(sku) |> summarise(clean_cb_total = sum(amount), .groups="drop")

kill <- smf |>
  select(sku, product_name, chargeback_total, annual_gross_margin, active_retailers) |>
  left_join(clean_cb, by = "sku") |>
  mutate(clean_cb_total = coalesce(clean_cb_total, 0),
         clean_cb_pct_gm = ifelse(annual_gross_margin > 0,
                                  clean_cb_total / annual_gross_margin, NA_real_)) |>
  filter(annual_gross_margin > 0, clean_cb_total > 0) |>
  arrange(desc(clean_cb_pct_gm))

cat("\nNew top kill candidates (clean CB% of GM, after removing unauthorized rows):\n")
print(kill |> select(sku, product_name, old_cb=chargeback_total, clean_cb=clean_cb_total,
                     gm=annual_gross_margin, clean_pct_gm=clean_cb_pct_gm) |> head(10),
      n=10)

# --- For comparison: per-SKU split ---
cat("\nCHP-0039 detail check:\n")
print(cb_flag |> filter(sku == "CHP-0039") |>
        group_by(retailer, authorized) |>
        summarise(amt = sum(amount), n = n(), .groups="drop"))

# Pre-fix totals
cat(sprintf("\nIf we removed unauthorized rows, total chargebacks would drop from $%s to $%s (%.1f%% reduction)\n",
            format(round(total,2), big.mark=","),
            format(round(auth_total,2), big.mark=","),
            100*unauth_total/total))
