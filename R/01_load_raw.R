# 01_load_raw.R
# Pull tables from the Cinderhaven Data Platform's mart layer (Postgres)
# into memory and persist as a single .rds for downstream scripts.
# This is the only script that talks to the database directly.
#
# Reads from the dbt mart layer (dim_products, fct_chargebacks, etc.)
# instead of the raw schema. dim_products is the sole product-master
# definition — the R pipeline consumes it, not reconstructs it.

suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(dplyr)
  library(tibble)
})

ROOT    <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
OUT_DIR <- file.path(ROOT, "output", "frames")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

db_url <- Sys.getenv("DATABASE_URL")
if (nchar(db_url) == 0) stop("DATABASE_URL environment variable is not set.")

# Parse postgresql://user:pass@host:port/dbname
m <- regmatches(db_url, regexec("^postgres(?:ql)?://([^:]+):([^@]+)@([^:]+):(\\d+)/(.+)$", db_url))[[1]]
if (length(m) < 6) stop("Cannot parse DATABASE_URL. Expected: postgresql://user:pass@host:port/dbname")

con <- dbConnect(
  Postgres(),
  dbname   = m[6],
  host     = m[4],
  port     = as.integer(m[5]),
  user     = m[2],
  password = m[3]
)
dbExecute(con, "SET search_path TO public_marts, public")

# Map dbt mart table names to the R-internal names used by downstream scripts.
# dim_products replaces both raw.product_master AND raw.sku_costs (merged).
mart_to_local <- c(
  "dim_products"               = "product_master",
  "fct_chargebacks"            = "chargebacks",
  "dim_stores"                 = "stores",
  "fct_distribution"           = "distribution",
  "fct_scan_data"              = "scan_data",
  "fct_promotions"             = "promotions",
  "dim_retailer_requirements"  = "retailer_requirements"
)

cat("Loading", length(mart_to_local), "tables from Postgres (marts layer)...\n")
raw <- setNames(
  lapply(names(mart_to_local), function(t) as_tibble(dbReadTable(con, t))),
  unname(mart_to_local)
)
dbDisconnect(con)

cat("\n--- Row counts ---\n")
for (t in names(raw)) cat(sprintf("  %-22s %10d rows  %3d cols\n",
                                  t, nrow(raw[[t]]), ncol(raw[[t]])))

# Schema validation: every table must be non-empty and contain expected key columns.
expected <- list(
  product_master    = c("sku", "gtin14", "upc", "product_name",
                        "cogs_per_unit", "wholesale_price"),
  chargebacks       = c("sku", "retailer", "amount", "reason"),
  stores            = c("store_id", "retailer"),
  distribution      = c("sku", "store_id", "authorized_date"),
  scan_data         = c("sku", "store_id", "week_ending", "units_sold"),
  promotions        = c("sku", "retailer", "start_week", "end_week"),
  retailer_requirements = c("retailer", "field", "required")
)
for (tbl_name in names(expected)) {
  tbl <- raw[[tbl_name]]
  if (is.null(tbl)) stop(sprintf("Missing table: %s", tbl_name))
  if (nrow(tbl) == 0) stop(sprintf("Empty table: %s", tbl_name))
  missing_cols <- setdiff(expected[[tbl_name]], names(tbl))
  if (length(missing_cols) > 0)
    stop(sprintf("Table %s missing columns: %s", tbl_name,
                 paste(missing_cols, collapse = ", ")))
}
cat("  Schema validation passed.\n")

saveRDS(raw, file.path(OUT_DIR, "raw_tables.rds"))
cat("\nWrote: ", file.path(OUT_DIR, "raw_tables.rds"), "\n", sep = "")
