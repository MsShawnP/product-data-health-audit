# tests/test_canonical_regression.R -- Canonical regression tests for Cinderhaven
# baked output frames.
#
# Validates that pre-computed output/frames/ files contain expected baseline
# counts and structure.
#
# Run:  Rscript tests/test_canonical_regression.R

ROOT <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)

FRAMES <- file.path(ROOT, "output", "frames")

pass <- 0L
fail <- 0L

assert <- function(desc, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) {
    pass <<- pass + 1L
  } else {
    fail <<- fail + 1L
    cat(sprintf("  FAIL: %s\n", desc))
  }
}

# ---------------------------------------------------------------------------
# Smoke test: key output files exist
# ---------------------------------------------------------------------------

cat("--- smoke test: key output files exist ---\n")

assert("raw_tables.rds exists",
       file.exists(file.path(FRAMES, "raw_tables.rds")))

assert("sku_master_full.csv exists",
       file.exists(file.path(FRAMES, "sku_master_full.csv")))

assert("sku_dim.csv exists",
       file.exists(file.path(FRAMES, "sku_dim.csv")))

assert("chargebacks_enriched.csv exists",
       file.exists(file.path(FRAMES, "chargebacks_enriched.csv")))

assert("sku_master_full.rds exists",
       file.exists(file.path(FRAMES, "sku_master_full.rds")))

assert("chargebacks_enriched.rds exists",
       file.exists(file.path(FRAMES, "chargebacks_enriched.rds")))

# ---------------------------------------------------------------------------
# 1. sku_master_full: row count and product line count
# ---------------------------------------------------------------------------

cat("\n--- sku_master_full regression ---\n")

sku_master <- read.csv(file.path(FRAMES, "sku_master_full.csv"),
                       stringsAsFactors = FALSE)

assert("sku_master_full has 50 rows (50 SKUs)",
       nrow(sku_master) == 50L)

assert("sku_master_full has product_line column",
       "product_line" %in% names(sku_master))

n_product_lines <- length(unique(sku_master$product_line))

assert("sku_master_full has 5 distinct product lines",
       n_product_lines == 5L)

known_lines <- c("Artisan Sauces", "Pantry Staples", "Specialty Condiments",
                 "Dried Goods", "Snack Bites")
assert("known product lines present in sku_master_full",
       all(known_lines %in% unique(sku_master$product_line)))

# ---------------------------------------------------------------------------
# 2. sku_dim: SKU count
# ---------------------------------------------------------------------------

cat("\n--- sku_dim regression ---\n")

sku_dim <- read.csv(file.path(FRAMES, "sku_dim.csv"),
                    stringsAsFactors = FALSE)

assert("sku_dim has 50 rows (50 SKUs)",
       nrow(sku_dim) == 50L)

assert("sku_dim has sku column",
       "sku" %in% names(sku_dim))

assert("sku_dim SKUs are all unique",
       length(unique(sku_dim$sku)) == nrow(sku_dim))

# ---------------------------------------------------------------------------
# 3. chargebacks_enriched: canonical retailers
# ---------------------------------------------------------------------------

cat("\n--- chargebacks_enriched regression ---\n")

cb <- read.csv(file.path(FRAMES, "chargebacks_enriched.csv"),
               stringsAsFactors = FALSE)

assert("chargebacks_enriched has retailer column",
       "retailer" %in% names(cb))

assert("chargebacks_enriched is not empty",
       nrow(cb) > 0L)

cb_retailers <- unique(cb$retailer)

canonical_retailers <- c("Walmart", "Costco", "Whole Foods",
                         "Kroger", "Sprouts", "Regional Group")

for (r in canonical_retailers) {
  assert(sprintf("chargebacks contain data for %s", r),
         r %in% cb_retailers)
}

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0) stop("Tests failed.")
