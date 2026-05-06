# Verify exact numbers cited in quarto/report.qmd sections 7-13.
suppressPackageStartupMessages({library(dplyr); library(stringr)})
ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
P    <- file.path(ROOT, "data", "processed")

read_p <- function(n) readRDS(file.path(P, paste0(n, ".rds")))
smf <- read_p("sku_master_full")
rs  <- read_p("retailer_readiness_summary")
pnl <- read_p("retailer_pnl")
ce  <- read_p("chargebacks_enriched")
deh <- read_p("deauth_summary")
pd  <- read_p("process_debt")
tts <- read_p("time_to_shelf_sku")
pe  <- read_p("promo_effectiveness")

hr <- function(t) cat("\n", strrep("=", 60), "\n", t, "\n", strrep("=", 60), "\n", sep="")

# ---- §7 Retailer readiness with revenue at risk --------------------------
hr("§7 retailer_readiness × revenue at risk")
rs |>
  left_join(smf |> select(sku, ttm_revenue), by = "sku") |>
  group_by(retailer) |>
  summarise(
    n_pass = sum(overall_pass), n_fail = sum(!overall_pass),
    pass_rate = mean(overall_pass),
    rev_at_risk = sum(ttm_revenue[!overall_pass], na.rm=TRUE),
    rev_total   = sum(ttm_revenue, na.rm=TRUE),
    rev_at_risk_pct = rev_at_risk / rev_total,
    mean_failed_fields = mean(fields_failed),
    .groups = "drop") |>
  arrange(pass_rate) |>
  print(width = Inf)

# ---- §8 net-margin by retailer -------------------------------------------
hr("§8 net-margin by retailer")
pnl |>
  filter(retailer %in% c("Walmart", "UNFI", "Whole Foods", "Costco")) |>
  mutate(across(c(gross_revenue, trade_spend_total, chargeback_total,
                  net_contribution), ~ round(.))) |>
  arrange(desc(gross_revenue)) |>
  print(width = Inf)

# ---- §9 time-to-shelf and promo lift -------------------------------------
hr("§9 time-to-shelf summary")
tts_q <- tts |>
  left_join(smf |> select(sku, data_quality_score), by = "sku") |>
  filter(!is.na(mean_days_to_scan)) |>
  mutate(qb = ntile(data_quality_score, 4))
print(tts_q |> group_by(qb) |>
  summarise(n=n(), mean_d=mean(mean_days_to_scan),
            sd_d=sd(mean_days_to_scan), .groups="drop"))
cat("Spearman(quality, mean_days):",
    round(cor(tts_q$data_quality_score, tts_q$mean_days_to_scan,
              method="spearman"), 3), "\n")

hr("§9 promo lift")
pe2 <- pe |> filter(!is.na(lift_pct))
cat("Computable promos:", nrow(pe2), "of", nrow(pe), "\n")
cat("Median lift:", round(100*median(pe2$lift_pct), 1), "%\n")
cat("Mean lift:",   round(100*mean(pe2$lift_pct), 1), "%\n")
cat("Spearman(quality, lift):",
    round(cor(pe2$data_quality_score, pe2$lift_pct, method="spearman"), 3), "\n")
print(pe2 |> mutate(qb = ntile(data_quality_score, 3)) |>
  group_by(qb) |>
  summarise(n=n(), mean_lift=round(mean(lift_pct), 3),
            mean_q=round(mean(data_quality_score), 1), .groups="drop"))

# ---- §10 process_debt ----------------------------------------------------
hr("§10 process_debt")
pd |> mutate(across(where(is.numeric), ~ round(., 1))) |>
  arrange(desc(chargeback_per_sku)) |> print(width = Inf)

# ---- §11 new vs old ------------------------------------------------------
hr("§11 days_since_update vs quality")
pm <- read_p("raw_tables")$product_master
sd2 <- read_p("sku_dim")
cat("last_updated range:",
    as.character(min(pm$last_updated, na.rm=TRUE)), "→",
    as.character(max(pm$last_updated, na.rm=TRUE)), "\n")
cat("days_since_update: min=", min(sd2$days_since_update, na.rm=TRUE),
    " max=", max(sd2$days_since_update, na.rm=TRUE),
    " median=", median(sd2$days_since_update, na.rm=TRUE), "\n")
cat("Spearman(days_since_update, quality_score):",
    round(cor(sd2$days_since_update, sd2$data_quality_score,
              method="spearman", use="complete.obs"), 3), "\n")

# split by half — recent vs old SKUs
sd_split <- sd2 |>
  mutate(age_half = ifelse(days_since_update < median(days_since_update),
                           "recent half", "older half"))
print(sd_split |> group_by(age_half) |>
  summarise(n=n(), mean_q=round(mean(data_quality_score), 1),
            mean_iss=round(mean(issue_count), 2), .groups="drop"))

# ---- §12 deauth ----------------------------------------------------------
hr("§12 deauth rate by quality tier")
dq <- deh |>
  left_join(smf |> select(sku, data_quality_score, issue_count), by="sku") |>
  mutate(qb = ntile(data_quality_score, 4))
print(dq |> group_by(qb) |>
  summarise(n=n(),
            mean_deauth = round(mean(deauth_rate), 4),
            n_with_any = sum(deauth_rate > 0),
            total_deauths = sum(deauth_count),
            total_auths   = sum(auth_count),
            .groups="drop"))
cat("Total deauths/auths:", sum(deh$deauth_count), "/",
    sum(deh$auth_count), "=",
    round(100 * sum(deh$deauth_count) / sum(deh$auth_count), 2), "%\n")
cat("Spearman(quality, deauth_rate):",
    round(cor(dq$data_quality_score, dq$deauth_rate, method="spearman"), 3), "\n")

# ---- §13 chargeback details ----------------------------------------------
hr("§13 chargeback Pareto / by reason / monthly / by retailer")
sku_cb <- smf |> filter(chargeback_total > 0) |>
  arrange(desc(chargeback_total)) |>
  mutate(rank=row_number(), cum=cumsum(chargeback_total),
         cum_pct = cum / sum(chargeback_total))
n50 <- min(which(sku_cb$cum_pct >= 0.5))
n80 <- min(which(sku_cb$cum_pct >= 0.8))
cat("SKUs with any cb:", nrow(sku_cb), "/ total:", nrow(smf), "\n")
cat("Top", n50, "SKUs = 50% of cb $\n")
cat("Top", n80, "SKUs = 80% of cb $\n")
cat("Top SKU:", sku_cb$sku[1], "—", sku_cb$product_name[1], "$",
    round(sku_cb$chargeback_total[1]), "\n")

cat("\nBy reason:\n")
ce |> group_by(reason) |>
  summarise(amt=sum(amount), n=n(), .groups="drop") |>
  arrange(desc(amt)) |>
  mutate(pct = round(100*amt/sum(amt), 1)) |>
  print()

cat("\nBy retailer:\n")
ce |> group_by(retailer) |>
  summarise(amt=sum(amount), n=n(), .groups="drop") |>
  arrange(desc(amt)) |>
  mutate(pct = round(100*amt/sum(amt), 1)) |>
  print()

cat("\nTop 5 cb%-of-GM:\n")
smf |> filter(!is.na(chargeback_pct_of_gm), chargeback_pct_of_gm > 0,
              annual_gross_margin > 0) |>
  arrange(desc(chargeback_pct_of_gm)) |>
  select(sku, product_name, chargeback_total, annual_gross_margin,
         chargeback_pct_of_gm, issue_count) |>
  slice(1:5) |>
  mutate(annual_gross_margin = round(annual_gross_margin),
         chargeback_pct_of_gm = round(100*chargeback_pct_of_gm, 1)) |>
  print(width = Inf)
