# run_all.R — Full pipeline orchestrator.
#
# One command rebuilds everything from the Postgres database:
#   0. Load shared theme + helpers          (R/00_theme.R, sourced by chart scripts)
#   1. Load raw tables                      (R/01_load_raw.R)
#   2. Build canonical analytical frames    (R/02_build_frames.R)
#   3. Verify distributions / sanity check  (R/03_verify.R)
#   4. Build hero charts        (PNG+HTML)  (R/04_hero_charts.R)
#   5. Build supporting charts  (PNG+HTML)  (R/05_supporting_charts.R)
#   6. Build Excel workbook                 (R/06_excel_workbook.R)
#   7. Render Quarto report     (HTML+PDF)  — calls quarto CLI if installed
#   8. Render interactive dashboard (HTML)  — calls quarto CLI if installed
#   9. Render executive tearsheet (PDF)     — calls quarto CLI if installed
#  10. Render shareable artifacts (PDF)     — compliance timeline + scorecard
#
# Steps 1–6 are pure R. Steps 7–10 shell out to `quarto`. If quarto isn't
# on PATH the script logs a skip and continues — the analytical outputs
# are still valid.

ROOT <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
cfg <- yaml::read_yaml(file.path(ROOT, "config.yml"))

R_SCRIPTS <- c(
  "R/01_load_raw.R",
  "R/02_build_frames.R",
  "R/03_verify.R",
  "R/04_hero_charts.R",
  "R/05_supporting_charts.R",
  "R/06_excel_workbook.R"
)

step_banner <- function(msg) {
  cat("\n", strrep("=", 70), "\n>>> ", msg, "\n", strrep("=", 70), "\n",
      sep = "")
}

t0 <- Sys.time()

# ---- R steps -------------------------------------------------------------

for (s in R_SCRIPTS) {
  if (s == "R/01_load_raw.R" && !nzchar(Sys.getenv("DATABASE_URL"))) {
    rds_path <- file.path(ROOT, "output", "frames", "raw_tables.rds")
    if (file.exists(rds_path)) {
      step_banner(paste(s, "(SKIPPED — no DATABASE_URL, using cached RDS)"))
      next
    }
  }
  step_banner(s)
  tryCatch(
    source(file.path(ROOT, s), echo = FALSE),
    error = function(e) {
      cat("\n!!! PIPELINE FAILED at ", s, " !!!\n", conditionMessage(e), "\n",
          sep = "")
      stop("Pipeline halted — fix the error above before continuing.",
           call. = FALSE)
    })
}

# ---- Quarto render -------------------------------------------------------

step_banner("Quarto render — quarto/report.qmd")

# Locate quarto. On Windows it's commonly at
# "C:/Program Files/Quarto/bin/quarto.exe". Fall back to PATH.
quarto_exe <- {
  candidates <- c(
    Sys.which("quarto"),
    "C:/Program Files/Quarto/bin/quarto.exe",
    "C:/Program Files/Quarto/bin/quarto"
  )
  hit <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (length(hit)) hit[[1]] else ""
}

# Render a .qmd. `fmt` is passed via --to; for the dashboard, use NA to
# omit --to so Quarto picks up `format: dashboard` from the YAML. (Passing
# `--to html` overrides the YAML format and silently degrades the dashboard
# to a plain HTML doc — value boxes print as raw R lists and the row/column
# layout directives leak through as visible <h2>/<h3> headings.)
render_qmd <- function(qmd_rel, fmt, out_name, out_dir_rel = NULL) {
  qmd <- file.path(ROOT, qmd_rel)
  args <- c("render", shQuote(qmd))
  if (!is.na(fmt))           args <- c(args, "--to", fmt)
  if (!is.null(out_dir_rel)) args <- c(args, "--output-dir", out_dir_rel)
  cat(sprintf("\n  rendering %s%s ...\n", basename(qmd),
              if (is.na(fmt)) "" else paste0(" -> ", fmt)))
  rc <- system2(quarto_exe, args = args, stdout = TRUE, stderr = TRUE)
  rc_status <- attr(rc, "status")
  if (is.null(rc_status) || rc_status == 0) {
    base_dir <- if (is.null(out_dir_rel)) dirname(qmd)
                else normalizePath(file.path(dirname(qmd), out_dir_rel),
                                    mustWork = FALSE)
    out_file <- file.path(base_dir, out_name)
    sz <- if (file.exists(out_file))
            sprintf(" (%.0f KB)", file.info(out_file)$size / 1024) else ""
    cat(sprintf("  %s OK%s\n",
                if (is.na(fmt)) "render" else paste0(fmt, " render"), sz))
  } else {
    cat(sprintf("  render FAILED (exit %s) — see output above\n", rc_status))
  }
}

if (!nzchar(quarto_exe)) {
  cat("Quarto not found on PATH — skipping render step.\n",
      "Install from https://quarto.org and re-run, or render manually with:\n",
      "  quarto render quarto/report.qmd\n",
      "  quarto render quarto/dashboard.qmd\n",
      "  quarto render quarto/tearsheet.qmd\n",
      "  quarto render quarto/compliance_timeline.qmd\n",
      "  quarto render quarto/scorecard.qmd\n", sep = "")
} else {
  # report.qmd declares both html and pdf formats — omit --to so Quarto
  # evaluates R chunks once and produces both outputs in a single pass.
  render_qmd("quarto/report.qmd",    NA, "report.html")

  step_banner("Quarto render — quarto/dashboard.qmd")
  render_qmd("quarto/dashboard.qmd", NA, "dashboard.html")

  # Three independent PDFs — render in parallel when possible.
  step_banner("Quarto render — tearsheet + compliance timeline + scorecard")
  pdf_jobs <- list(
    list(qmd = "quarto/tearsheet.qmd",
         fmt = "pdf", out = "tearsheet.pdf", out_dir = NULL),
    list(qmd = "quarto/compliance_timeline.qmd",
         fmt = "pdf", out = "compliance_timeline.pdf", out_dir = "../output"),
    list(qmd = "quarto/scorecard.qmd",
         fmt = "pdf", out = "scorecard.pdf", out_dir = "../output")
  )

  if (requireNamespace("processx", quietly = TRUE)) {
    cat("  (rendering 3 PDFs in parallel via processx)\n")
    procs <- lapply(pdf_jobs, function(j) {
      qmd <- file.path(ROOT, j$qmd)
      args <- c("render", qmd, "--to", j$fmt)
      if (!is.null(j$out_dir)) args <- c(args, "--output-dir", j$out_dir)
      processx::process$new(quarto_exe, args, stdout = "|", stderr = "|")
    })
    for (i in seq_along(procs)) {
      procs[[i]]$wait()
      rc <- procs[[i]]$get_exit_status()
      j <- pdf_jobs[[i]]
      base_dir <- if (is.null(j$out_dir)) file.path(ROOT, dirname(j$qmd))
                  else normalizePath(file.path(ROOT, dirname(j$qmd), j$out_dir),
                                      mustWork = FALSE)
      out_file <- file.path(base_dir, j$out)
      if ((is.null(rc) || rc == 0) && file.exists(out_file)) {
        cat(sprintf("  %s OK (%.0f KB)\n", j$out,
                    file.info(out_file)$size / 1024))
      } else {
        err <- procs[[i]]$read_error_lines()
        cat(sprintf("  %s FAILED (exit %s)\n", j$out,
                    if (is.null(rc)) "?" else rc))
        if (length(err)) cat(paste("    ", err, collapse = "\n"), "\n")
      }
    }
  } else {
    for (j in pdf_jobs) render_qmd(j$qmd, j$fmt, j$out, j$out_dir)
  }
}

# ---- Wrap up -------------------------------------------------------------

elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
cat(sprintf("\n%s\nFull pipeline completed in %s seconds.\n%s\n",
            strrep("=", 70), elapsed, strrep("=", 70)))

cat("\nKey outputs:\n")
key_outputs <- c(
  "output/frames/sku_master_full.rds",
  "output/canonical_numbers.md",
  paste0("output/", cfg$data$output_prefix, "_audit.xlsx"),
  "output/charts/01_chargeback_pareto.png",
  "output/compliance_timeline.pdf",
  "output/scorecard.pdf",
  "quarto/report.html",
  "quarto/report.pdf",
  "quarto/dashboard.html",
  "quarto/tearsheet.pdf"
)
for (f in key_outputs) {
  full <- file.path(ROOT, f)
  if (file.exists(full)) {
    cat(sprintf("  %-50s %6.0f KB\n", f, file.info(full)$size / 1024))
  } else {
    cat(sprintf("  %-50s (missing)\n", f))
  }
}
