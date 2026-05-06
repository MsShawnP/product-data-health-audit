# One-shot bootstrap script — run interactively the first time the project
# is cloned to capture exact package versions into renv.lock. Subsequent
# clones use renv::restore() instead.

ROOT <- "C:/Users/mssha/OneDrive/Desktop/product-data-health-audit"
setwd(ROOT)

# Bare init: do not install bioc, do not be interactive about edge cases.
renv::init(
  project   = ROOT,
  bare      = FALSE,            # discover deps from project R/Quarto files
  force     = TRUE,             # overwrite any half-initialized state
  restart   = FALSE,            # don't try to restart R
  bioconductor = FALSE
)

cat("\nrenv initialized. Lock file:\n")
print(file.info(file.path(ROOT, "renv.lock"))[, c("size", "mtime")])
