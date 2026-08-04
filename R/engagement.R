# engagement.R — Single source of engagement parameters for the R/Quarto stage.
#
# Loads engagement.yml (or engagement.demo.yml) so no client-specific value is
# hardcoded on the client path: client/brand name, as_of_date, retailer roster,
# trade-spend rate proxy, and margin basis all come from here. The three .qmd
# deliverables source this in their setup chunk.
#
# Demo builds (demo: true) are byte-identical to the pre-conversion golden: the
# client-mode chrome (provenance footer, draft watermark, auto-limitations) is
# gated OFF when is_demo is TRUE, and every demo value equals the former hardcode.
#
# Env overrides (set by a render wrapper for a real engagement):
#   ENGAGEMENT_CONFIG  path to the engagement.yml to use   (default: auto-detect)
#   ENGAGEMENT_FINAL   "true" to drop the DRAFT watermark   (default: draft)

suppressPackageStartupMessages(library(yaml))

load_engagement <- function(root = "..") {
  explicit <- Sys.getenv("ENGAGEMENT_CONFIG", unset = "")
  path <- if (nzchar(explicit)) explicit else {
    active <- file.path(root, "engagement.yml")
    demo   <- file.path(root, "engagement.demo.yml")
    if (file.exists(active)) active else demo
  }
  if (!file.exists(path))
    stop("engagement config not found: ", path,
         " (add engagement.demo.yml or set ENGAGEMENT_CONFIG)", call. = FALSE)

  # Read with EXPLICIT UTF-8 so box-drawing comments etc. never trip a locale-
  # dependent "invalid input on connection" that silently degrades the parse.
  y <- tryCatch(
    yaml::read_yaml(text = readLines(path, encoding = "UTF-8", warn = FALSE)),
    error = function(e)
      stop("engagement config could not be parsed as UTF-8 YAML: ", path,
           " (", conditionMessage(e), ")", call. = FALSE))

  # Fail CLOSED. A config that can't prove it is a demo must never be treated as
  # an active client engagement (that flipped the demo build into broken client
  # mode with empty client names — see PDHA-RENDER-VERIFICATION.md P1).
  if (is.null(y) || !is.list(y))
    stop("engagement config did not parse as a mapping: ", path, call. = FALSE)
  client_name <- y$client$name
  if (is.null(client_name) || !is.character(client_name) ||
      length(client_name) != 1 || !nzchar(trimws(client_name)))
    stop("engagement config has no non-empty client$name: ", path, call. = FALSE)
  if (!("demo" %in% names(y)) || !is.logical(y$demo) ||
      length(y$demo) != 1 || is.na(y$demo))
    stop("engagement config must set 'demo:' to true or false (a bare logical): ",
         path, call. = FALSE)

  final_env <- tolower(Sys.getenv("ENGAGEMENT_FINAL", unset = "false"))
  list(
    source_path   = path,
    client_name   = y$client$name,
    client_short  = y$client$short_name %||% y$client$name,
    revenue_desc  = y$client$revenue_description %||% "",
    engagement_id = y$engagement$id %||% "",
    as_of_date    = as.character(y$as_of_date),
    prepared_by   = y$prepared_by %||% "Lailara LLC",
    is_demo       = isTRUE(y$demo),
    is_final      = final_env %in% c("true", "1", "yes"),
    retailers     = unlist(y$retailers) %||% character(0),
    trade_spend_proxy = y$rates$trade_spend_proxy %||% list(),
    margin_basis  = y$basis$margin %||% "contribution",
    scan_basis    = y$basis$scan_basis %||% "retail",
    window_months = y$basis$window_months %||% NA_integer_,
    window_label  = y$basis$window_label %||% "",
    config_raw    = y
  )
}

# ---- Deliverable title strings ----------------------------------------------
# Compose the three front-matter strings from the client identity + a fixed
# suffix, so a title can never carry the wrong client name. A present-but-stale
# literal is the failure mode a plain `report.subtitle: "..."` invites (round-3
# verification: a config with client.name updated but dashboard_title left alone
# rendered a client deliverable titled with the demo client's name). An explicit
# report.* value is honored as an OVERRIDE for custom wording; otherwise the
# composed default wins. The composed demo strings are byte-identical to golden.
compose_titles <- function(eng) {
  dot <- "\u00b7"  # middle dot via \u escape so byte output is encoding-independent
  months <- c("January", "February", "March", "April", "May", "June", "July",
              "August", "September", "October", "November", "December")
  d <- tryCatch(as.Date(eng$as_of_date), error = function(e) as.Date(NA))
  month_year <- if (!is.na(d))
    paste(months[as.integer(format(d, "%m"))], format(d, "%Y")) else ""

  defaults <- list(
    report_subtitle = paste0(eng$client_name, "  ", dot, "  ", month_year),
    dashboard_title = paste0(eng$client_short, " ", dot, " Monday Morning Dashboard"),
    tearsheet_title = paste0(eng$client_name, " ", dot, " Product Data Readiness")
  )

  rpt <- eng$config_raw$report
  override <- function(val, default)
    if (is.null(val) || !is.character(val) || !nzchar(val)) default else val

  list(
    report_subtitle = override(rpt$subtitle,        defaults$report_subtitle),
    dashboard_title = override(rpt$dashboard_title, defaults$dashboard_title),
    tearsheet_title = override(rpt$tearsheet_title, defaults$tearsheet_title)
  )
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# ---- Provenance footer ------------------------------------------------------
# Markdown block for a `results: asis` chunk. Inputs come from the preflight
# token when a client run produced one; otherwise the pipeline source is named.

eng_provenance_md <- function(eng, tool, version, root = "..") {
  tok_path <- file.path(root, "output", "preflight", "PREFLIGHT_STATUS.json")
  inputs_line <- "Source: cached pipeline frames (output/frames/)."
  config_hash <- "n/a"
  status <- "n/a"
  if (file.exists(tok_path) && requireNamespace("jsonlite", quietly = TRUE)) {
    tok <- jsonlite::fromJSON(tok_path)
    config_hash <- tok$config_hash_short %||% "n/a"
    status <- tok$status %||% "n/a"
    if (!is.null(tok$inputs) && nrow(as.data.frame(tok$inputs))) {
      im <- as.data.frame(tok$inputs)
      inputs_line <- paste(
        sprintf("%s (sha256 %s…, %s rows)",
                im$filename, substr(im$sha256, 1, 12), im$n_rows),
        collapse = "; ")
    }
  }
  paste0(
    "::: {.provenance-footer}\n",
    "**Provenance.** ", tool, " v", version, " · ",
    eng$client_name, " (", eng$engagement_id, ") · ",
    "as-of ", eng$as_of_date, " · ",
    "config ", config_hash, " · ",
    "margin basis: ", eng$margin_basis, " · ",
    "window: ", eng$window_label, " · ",
    "validation: ", status, ".  \n",
    "Inputs: ", inputs_line, "\n",
    ":::\n")
}

# ---- Auto data-limitations from preflight -----------------------------------
# Returns a markdown block enumerating every disclosed assumption / excluded row
# from the readiness report, or NULL when there is no preflight output (demo).

eng_limitations_md <- function(root = "..") {
  rep_path <- file.path(root, "output", "preflight", "readiness-findings.json")
  if (!file.exists(rep_path) || !requireNamespace("jsonlite", quietly = TRUE))
    return(NULL)
  f <- jsonlite::fromJSON(rep_path)
  if (length(f) == 0) return(NULL)
  lines <- vapply(seq_len(nrow(f)), function(i)
    sprintf("- **%s** (%s): %s%s", f$column[i], f$severity[i], f$message[i],
            if (!is.na(f$assumption[i]) && nzchar(f$assumption[i]))
              paste0(" — *assumption:* ", f$assumption[i]) else ""),
    character(1))
  paste0("Preflight surfaced the following data limitations, each carried into ",
         "this deliverable:\n\n", paste(lines, collapse = "\n"), "\n")
}

# ---- Draft watermark --------------------------------------------------------
# A visible banner for a `results: asis` chunk. Shown only for non-final client
# builds; empty for demo or --final. A diagonal page watermark can be layered in
# on the R host via draftwatermark (PDF) — this banner is the format-portable core.

eng_watermark_md <- function(eng) {
  if (eng$is_demo || eng$is_final) return("")
  paste0(
    "::: {.draft-banner}\n",
    "**DRAFT — not for distribution.** Prepared for ", eng$client_name,
    " (", eng$engagement_id, "), as-of ", eng$as_of_date,
    ". Rebuild with `ENGAGEMENT_FINAL=true` for the final deliverable.\n",
    ":::\n")
}
