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
dbExecute(con, "SET search_path TO public_marts, public_staging, public_intermediate, raw, public")

# Staging views (stg_*) live in public_staging; retailer_requirements
# has no staging model and is read from the raw schema. The database
# search_path includes both, so unqualified names resolve correctly.
pg_to_local <- c(
  "stg_product_master"    = "product_master",
  "stg_sku_costs"         = "sku_costs",
  "stg_chargebacks"       = "chargebacks",
  "stg_stores"            = "stores",
  "stg_distribution_log"  = "distribution_log",
  "stg_scan_data"         = "scan_data",
  "stg_promotions"        = "promotions",
  "retailer_requirements" = "retailer_requirements"
)

cat("Loading", length(pg_to_local), "tables from Postgres...\n")
raw <- setNames(
  lapply(names(pg_to_local), function(t) as_tibble(dbReadTable(con, t))),
  unname(pg_to_local)
)
dbDisconnect(con)

cat("\n--- Row counts ---\n")
for (t in names(raw)) cat(sprintf("  %-22s %10d rows  %3d cols\n",
                                  t, nrow(raw[[t]]), ncol(raw[[t]])))

saveRDS(raw, file.path(OUT_DIR, "raw_tables.rds"))
cat("\nWrote: ", file.path(OUT_DIR, "raw_tables.rds"), "\n", sep = "")
