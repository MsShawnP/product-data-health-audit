suppressPackageStartupMessages({library(dplyr); library(lubridate)})
ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
ce <- readRDS(file.path(ROOT, "output/frames/chargebacks_enriched.rds"))
c15 <- ce |> mutate(month = floor_date(month_date, "month")) |>
  group_by(month) |> summarise(amt = sum(amount), .groups = "drop") |> arrange(month)
cat("first 3 months:\n"); print(head(c15, 3))
cat("\nlast 3 months:\n"); print(tail(c15, 3))
fit <- lm(amt ~ as.numeric(month), data = c15)
slope_per_month <- coef(fit)[2] * 30
cat(sprintf("\nslope: %.0f $/month\n", slope_per_month))
cat(sprintf("predicted first  month: %.0f\n", predict(fit)[1]))
cat(sprintf("predicted last   month: %.0f\n", tail(predict(fit), 1)))
cat(sprintf("observed   mean: %.0f\n", mean(c15$amt)))
cat(sprintf("observed median: %.0f\n", median(c15$amt)))
cat(sprintf("min: %.0f, max: %.0f\n", min(c15$amt), max(c15$amt)))
