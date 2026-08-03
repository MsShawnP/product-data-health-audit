# 00_preflight_gate.R — Refuse to run the R analysis on unvalidated client data.
#
# The Python preflight (scripts/run_preflight.py) validates the client extracts and
# writes output/preflight/PREFLIGHT_STATUS.json. This gate is sourced at the top of
# run_all.R and stops the pipeline unless that token says the data passed.
#
# Policy:
#   * ACTIVE client engagement (engagement.yml present, not a demo):
#       a clean token is REQUIRED. No token, or passed=false -> hard stop.
#   * Demo / legacy dev (engagement.demo.yml or no engagement config):
#       honor a token if present (stop on passed=false); if absent, warn and
#       continue so the existing `Rscript R/run_all.R` demo flow is unbroken.
#
# This is the "R stage refuses unvalidated input" control in the engagement-ready
# checklist §2. It does not itself parse data — it trusts the preflight's verdict.

assert_preflight_ok <- function(root = ".") {
  token_path <- file.path(root, "output", "preflight", "PREFLIGHT_STATUS.json")
  active_cfg <- file.path(root, "engagement.yml")
  demo_cfg   <- file.path(root, "engagement.demo.yml")

  is_active_client <- file.exists(active_cfg)

  stop_unvalidated <- function(reason) {
    stop(paste0(
      "\n", strrep("=", 70), "\n",
      "PREFLIGHT GATE: ", reason, "\n",
      "This is an ACTIVE client engagement — the R stage will not run on\n",
      "unvalidated input. Run the preflight first:\n\n",
      "  python scripts/run_preflight.py --config engagement.yml \\\n",
      "      --item-master <item_master.csv> --chargebacks <chargebacks.csv>\n\n",
      "Then re-run the pipeline. If the preflight blocks, hand the client the\n",
      "Data Readiness Report it wrote to output/preflight/ — that is the finding.\n",
      strrep("=", 70), "\n"
    ), call. = FALSE)
  }

  if (!file.exists(token_path)) {
    if (is_active_client) stop_unvalidated("no preflight token found.")
    msg <- if (file.exists(demo_cfg))
      "  [preflight gate] demo config present but no token — running demo path unvalidated.\n"
    else
      "  [preflight gate] no engagement config or token — legacy/demo dev run.\n"
    cat(msg)
    return(invisible(FALSE))
  }

  if (!requireNamespace("jsonlite", quietly = TRUE))
    stop("jsonlite is required to read the preflight token.", call. = FALSE)
  tok <- jsonlite::fromJSON(token_path)

  if (!isTRUE(tok$passed)) {
    if (is_active_client)
      stop_unvalidated(sprintf("preflight status is '%s' (not passed).", tok$status))
    stop(paste0("\nPREFLIGHT GATE: token reports status '", tok$status,
                "' — fix the data and re-run the preflight before rendering.\n"),
         call. = FALSE)
  }

  cat(sprintf(
    "  [preflight gate] OK — %s (%s), status=%s, as_of=%s, config=%s\n",
    tok$client_name, tok$engagement_id, tok$status, tok$as_of_date,
    tok$config_hash_short))
  invisible(TRUE)
}
