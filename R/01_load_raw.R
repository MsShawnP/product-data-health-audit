# 01_load_raw.R
# Pull all 8 tables from cinderhaven_product_master.db into memory and
# persist as a single .rds for downstream scripts. This is the only
# script that talks to SQLite directly.

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(tibble)
})

ROOT    <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
DB_PATH <- file.path(ROOT, "data", "cinderhaven_product_master.db")
OUT_DIR <- file.path(ROOT, "output", "frames")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

stopifnot(file.exists(DB_PATH))

con <- dbConnect(SQLite(), DB_PATH)
tables <- dbListTables(con)
cat("Tables found:", length(tables), "\n")
# Schema as of 2026-05-02 22:58 includes price_history; older snapshots had 8.
stopifnot(length(tables) >= 8)
expected <- c("product_master","sku_costs","chargebacks","stores",
              "distribution_log","scan_data","promotions","retailer_requirements")
missing <- setdiff(expected, tables)
if (length(missing)) stop("Missing required tables: ", paste(missing, collapse = ", "))

raw <- setNames(lapply(tables, function(t) as_tibble(dbReadTable(con, t))), tables)
dbDisconnect(con)

# Quick row-count sanity print so the script is self-documenting in logs.
cat("\n--- Row counts ---\n")
for (t in tables) cat(sprintf("  %-22s %10d rows  %3d cols\n",
                              t, nrow(raw[[t]]), ncol(raw[[t]])))

saveRDS(raw, file.path(OUT_DIR, "raw_tables.rds"))
cat("\nWrote: ", file.path(OUT_DIR, "raw_tables.rds"), "\n", sep = "")
