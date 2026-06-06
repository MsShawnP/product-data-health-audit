# 01_load_raw.R
# Pull tables into memory and persist as a single .rds for downstream scripts.
# This is the only script that talks to a database directly.
#
# Data sources (tried in order):
#   1. DATABASE_URL env var → Postgres marts layer (dim_products, etc.)
#   2. data/cinderhaven_product_master.db → local SQLite export from Postgres
# The SQLite export is produced by scripts/export_from_postgres.py and
# contains the same mart-level transformations (merged product_master,
# retailer names resolved, first_scan_week computed).

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(tibble)
})

ROOT    <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
OUT_DIR <- file.path(ROOT, "output", "frames")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

db_url      <- Sys.getenv("DATABASE_URL")
sqlite_path <- file.path(ROOT, "data", "cinderhaven_product_master.db")

if (nchar(db_url) > 0) {
  # ---- Path 1: Postgres marts ------------------------------------------------
  library(RPostgres)

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

} else if (file.exists(sqlite_path)) {
  # ---- Path 2: local SQLite export -------------------------------------------
  library(RSQLite)

  sqlite_tables <- c(
    "product_master", "chargebacks", "stores", "distribution",
    "scan_data", "promotions", "retailer_requirements"
  )

  cat("Loading", length(sqlite_tables), "tables from SQLite export...\n")
  cat("  Source:", sqlite_path, "\n")
  con <- dbConnect(SQLite(), sqlite_path)
  raw <- setNames(
    lapply(sqlite_tables, function(t) as_tibble(dbReadTable(con, t))),
    sqlite_tables
  )
  dbDisconnect(con)

  # SQLite stores all numerics as TEXT; coerce columns that downstream expects
  # as numeric. Only touch columns that exist.
  num_cols_pm <- c(
    "case_pack_qty", "unit_weight_lbs", "case_weight_lbs",
    "case_length_in", "case_width_in", "case_height_in", "msrp",
    "cogs_per_unit", "landed_cost_per_unit", "wholesale_price",
    "wholesale_walmart", "wholesale_costco", "wholesale_whole_foods",
    "wholesale_sprouts", "wholesale_regional", "wholesale_unfi",
    "wholesale_kehe", "wholesale_dtc",
    "trade_spend_pct_walmart", "trade_spend_pct_costco",
    "trade_spend_pct_whole_foods", "trade_spend_pct_sprouts",
    "trade_spend_pct_regional", "trade_spend_pct_unfi",
    "trade_spend_pct_kehe", "trade_spend_pct_dtc",
    "dtc_margin_per_unit", "dtc_margin_pct",
    "margin_per_unit", "margin_pct",
    "retailer_count", "distributor_count", "authorized_store_count"
  )
  for (col in intersect(num_cols_pm, names(raw$product_master)))
    raw$product_master[[col]] <- as.numeric(raw$product_master[[col]])

  raw$chargebacks$amount <- as.numeric(raw$chargebacks$amount)
  raw$chargebacks$chargeback_id <- as.integer(raw$chargebacks$chargeback_id)

  num_cols_dist <- c(
    "weeks_with_sales", "total_units", "total_dollars", "avg_weekly_units"
  )
  for (col in intersect(num_cols_dist, names(raw$distribution)))
    raw$distribution[[col]] <- as.numeric(raw$distribution[[col]])

  raw$scan_data$units_sold  <- as.integer(raw$scan_data$units_sold)
  raw$scan_data$dollars_sold <- as.numeric(raw$scan_data$dollars_sold)

  num_cols_promo <- c("discount_depth_pct", "promo_cost")
  for (col in intersect(num_cols_promo, names(raw$promotions)))
    raw$promotions[[col]] <- as.numeric(raw$promotions[[col]])

  raw$retailer_requirements$required <- as.integer(raw$retailer_requirements$required)

  # SQLite returns dates as character strings; coerce to Date.
  date_cols_dist <- c("authorized_date", "deauthorized_date",
                      "first_scan_week", "last_scan_week")
  for (col in intersect(date_cols_dist, names(raw$distribution)))
    raw$distribution[[col]] <- as.Date(raw$distribution[[col]])

  if ("week_ending" %in% names(raw$scan_data))
    raw$scan_data$week_ending <- as.Date(raw$scan_data$week_ending)

  date_cols_promo <- c("start_week", "end_week")
  for (col in intersect(date_cols_promo, names(raw$promotions)))
    raw$promotions[[col]] <- as.Date(raw$promotions[[col]])

  if ("last_updated" %in% names(raw$product_master))
    raw$product_master$last_updated <- as.Date(raw$product_master$last_updated)

} else {
  stop("No data source available. Set DATABASE_URL for Postgres, or run:\n",
       "  python scripts/export_from_postgres.py\n",
       "to create the SQLite export at data/cinderhaven_product_master.db")
}

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
