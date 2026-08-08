# write_variables.R — Quarto pre-render hook (wired in _quarto.yml).
#
# Writes quarto/_variables.yml from the active engagement config so the report,
# dashboard, and tearsheet title/subtitle are driven by engagement.yml, not
# hardcoded into the .qmd title blocks (PDHA-RENDER-VERIFICATION P3 + round-3:
# hardcoded "Cinderhaven" strings leaked into client renders).
#
# The strings are COMPOSED from the client identity by compose_titles() (see
# R/engagement.R), so a present-but-stale report.* literal can't leak the wrong
# client name; an explicit report.* value still wins as an override.
#
# Quarto runs this with cwd = the project dir (quarto/), before rendering any
# document, so `{{< var ... >}}` resolves at render time. _variables.yml is
# gitignored: regenerated every render, and on a real engagement it carries the
# client's own strings.

root <- ".."
source(file.path(root, "R", "engagement.R"))
eng    <- load_engagement(root)
titles <- compose_titles(eng)

# report_date (+ its month-year display) drive the report/tearsheet date fields so those
# front-matter dates come from engagement.yml, not hardcodes. report_date is the AUTHORING
# date (document identity), NOT data_as_of. (0.d split.)
report_date <- eng$report_date %||% eng$as_of_date
.months <- c("January", "February", "March", "April", "May", "June", "July",
             "August", "September", "October", "November", "December")
.rd <- tryCatch(as.Date(report_date), error = function(e) as.Date(NA))
report_month_year <- if (!is.na(.rd))
  paste(.months[as.integer(format(.rd, "%m"))], format(.rd, "%Y")) else ""

# Write with explicit UTF-8 so the middle-dot separator survives on any locale.
con <- file("_variables.yml", open = "w", encoding = "UTF-8")
on.exit(close(con))
writeLines(c(
  sprintf('report_subtitle: "%s"', titles$report_subtitle),
  sprintf('dashboard_title: "%s"', titles$dashboard_title),
  sprintf('tearsheet_title: "%s"', titles$tearsheet_title),
  sprintf('report_date: "%s"', report_date),
  sprintf('report_month_year: "%s"', report_month_year)
), con)
