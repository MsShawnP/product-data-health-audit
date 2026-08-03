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

subtitle <- eng$config_raw$report$subtitle
if (is.null(subtitle) || !nzchar(subtitle)) {
  # Fall back to "<client name>" so a config without report.subtitle still
  # produces a sensible, non-empty subtitle rather than a blank or a leak.
  subtitle <- eng$client_name
}

# Write with explicit UTF-8 so the middle-dot separator survives on any locale.
con <- file("_variables.yml", open = "w", encoding = "UTF-8")
on.exit(close(con))
writeLines(sprintf('report_subtitle: "%s"', subtitle), con)
