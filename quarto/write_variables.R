# write_variables.R — Quarto pre-render hook (wired in _quarto.yml).
#
# Writes quarto/_variables.yml from the active engagement config so the report's
# YAML subtitle is driven by engagement.yml, not hardcoded into the .qmd title
# block (PDHA-RENDER-VERIFICATION.md P3: the hardcoded "Cinderhaven Provisions"
# subtitle leaked into a client render).
#
# Quarto runs this with cwd = the project dir (quarto/), before rendering any
# document, so `{{< var report_subtitle >}}` in report.qmd resolves at render time.
# _variables.yml is gitignored: it is regenerated every render and, on a real
# engagement, would carry the client's subtitle.

root <- ".."
source(file.path(root, "R", "engagement.R"))
eng <- load_engagement(root)

# Each front-matter string falls back to the client name so a config without the
# field still produces a sensible, non-empty value rather than a blank or a leak.
rpt <- eng$config_raw$report
pick <- function(x) if (is.null(x) || !nzchar(x)) eng$client_name else x
subtitle        <- pick(rpt$subtitle)
dashboard_title <- pick(rpt$dashboard_title)
tearsheet_title <- pick(rpt$tearsheet_title)

# Write with explicit UTF-8 so the middle-dot separator survives on any locale.
con <- file("_variables.yml", open = "w", encoding = "UTF-8")
on.exit(close(con))
writeLines(c(
  sprintf('report_subtitle: "%s"', subtitle),
  sprintf('dashboard_title: "%s"', dashboard_title),
  sprintf('tearsheet_title: "%s"', tearsheet_title)
), con)
