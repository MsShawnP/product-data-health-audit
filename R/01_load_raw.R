# 01_load_raw.R
# Pull all 8 tables from the Cinderhaven Data Platform (Postgres) into
# memory and persist as a single .rds for downstream scripts. This is
# the only script that talks to the database directly.

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
dbExecute(con, "SET search_path TO raw, public")

pg_to_local <- c(
  "product_master"        = "product_master",
  "sku_costs"             = "sku_costs",
  "retailer_chargebacks"  = "chargebacks",
  "stores"                = "stores",
  "distribution_log"      = "distribution_log",
  "scan_data"             = "scan_data",
  "promotions"            = "promotions",
  "retailer_requirements" = "retailer_requirements"
)

cat("Loading", length(pg_to_local), "tables from Postgres (raw schema)...\n")
raw <- setNames(
  lapply(names(pg_to_local), function(t) as_tibble(dbReadTable(con, t))),
  unname(pg_to_local)
)
retailer_map <- as_tibble(dbReadTable(con, "retailers")) |>
  select(retailer_id, retailer_name = name)
dbDisconnect(con)

raw$stores <- raw$stores |>
  rename(retailer = chain_name) |>
  select(-retailer_id)

raw$chargebacks <- raw$chargebacks |>
  left_join(retailer_map, by = "retailer_id") |>
  transmute(sku, retailer = retailer_name, amount,
            reason, month = format(month, "%Y-%m"))

raw$promotions <- raw$promotions |>
  left_join(retailer_map, by = "retailer_id") |>
  mutate(retailer = coalesce(retailer_name, retailer_id)) |>
  select(-retailer_id, -retailer_name)

raw$retailer_requirements <- raw$retailer_requirements |>
  left_join(retailer_map, by = "retailer_id") |>
  mutate(retailer = coalesce(retailer_name, retailer_id)) |>
  select(-retailer_id, -retailer_name)

cat("\n--- Row counts ---\n")
for (t in names(raw)) cat(sprintf("  %-22s %10d rows  %3d cols\n",
                                  t, nrow(raw[[t]]), ncol(raw[[t]])))

# Schema validation: every table must be non-empty and contain expected key columns.
expected <- list(
  product_master    = c("sku", "gtin14", "upc", "product_name"),
  sku_costs         = c("sku", "cogs_per_unit", "wholesale_price"),
  chargebacks       = c("sku", "retailer", "amount", "reason"),
  stores            = c("store_id", "retailer"),
  distribution_log  = c("sku", "store_id", "authorized_date"),
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
