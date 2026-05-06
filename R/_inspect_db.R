suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
con <- dbConnect(SQLite(), "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit/cinderhaven_product_master.db")
tables <- dbListTables(con)
cat("Tables (", length(tables), "):\n", sep = "")
for (t in tables) {
  n <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", t))$n
  cols <- dbListFields(con, t)
  cat(sprintf("  %-25s rows=%d  cols(%d): %s\n", t, n, length(cols), paste(cols, collapse=", ")))
}
dbDisconnect(con)
