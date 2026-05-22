# 00_setup.R — Shared project root and frame-loading helper.
# Sourced by 03_verify.R, 04_hero_charts.R, 05_supporting_charts.R, 06_excel_workbook.R.

ROOT <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)

FRAMES_DIR <- file.path(ROOT, "output", "frames")

read_frame <- function(name) {
  readRDS(file.path(FRAMES_DIR, paste0(name, ".rds")))
}
