# tests/test_engagement_loader.R — Regression tests for load_engagement().
#
# Run: Rscript tests/test_engagement_loader.R
#
# Guards the P1 fix (PDHA-RENDER-VERIFICATION.md): the loader must FAIL CLOSED.
# A config that can't prove it is a demo (unparseable, no client$name, or a
# missing/non-logical `demo`) must stop() — never be treated as an active client
# and never silently flip the demo build into broken client mode.

ROOT <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
source(file.path(ROOT, "R", "engagement.R"))

pass <- 0L
fail <- 0L
assert <- function(desc, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) pass <<- pass + 1L
  else { fail <<- fail + 1L; cat(sprintf("  FAIL: %s\n", desc)) }
}

# Write `content` to a temp yaml, point ENGAGEMENT_CONFIG at it, run `fun`.
with_config <- function(content, fun) {
  f <- tempfile(fileext = ".yml")
  writeLines(content, f, useBytes = TRUE)
  old <- Sys.getenv("ENGAGEMENT_CONFIG", unset = NA)
  Sys.setenv(ENGAGEMENT_CONFIG = f)
  on.exit({
    if (is.na(old)) Sys.unsetenv("ENGAGEMENT_CONFIG")
    else Sys.setenv(ENGAGEMENT_CONFIG = old)
    unlink(f)
  })
  fun()
}

stops <- function(content) {
  with_config(content, function()
    inherits(try(load_engagement(ROOT), silent = TRUE), "try-error"))
}
loads <- function(content) {
  with_config(content, function()
    tryCatch(load_engagement(ROOT), error = function(e) NULL))
}

cat("--- load_engagement fail-closed tests ---\n")

# A mangled / unparseable YAML must stop, not degrade silently.
assert("unparseable yaml stops",
       stops("client: {name: 'Acme'\n  demo: [broken"))

# Missing client$name must stop.
assert("missing client name stops",
       stops("demo: true\nclient:\n  short_name: Acme"))

# Missing `demo` key must stop (can't prove it's a demo).
assert("missing demo key stops",
       stops("client:\n  name: Acme Foods"))

# Non-logical `demo` (a string) must stop.
assert("string demo value stops",
       stops("client:\n  name: Acme Foods\ndemo: \"true\""))

# Empty/whitespace client name must stop.
assert("blank client name stops",
       stops("client:\n  name: \"  \"\ndemo: true"))

cat("\n--- load_engagement happy-path tests ---\n")

demo <- loads(paste("client:", "  name: Cinderhaven Provisions",
                    "  short_name: Cinderhaven", "demo: true", sep = "\n"))
assert("valid demo config loads",            !is.null(demo))
assert("valid demo config is_demo TRUE",     isTRUE(demo$is_demo))
assert("valid demo config keeps client name",
       identical(demo$client_name, "Cinderhaven Provisions"))

active <- loads(paste("client:", "  name: Acme Foods",
                      "demo: false", sep = "\n"))
assert("valid active config loads",          !is.null(active))
assert("valid active config is_demo FALSE",  isFALSE(active$is_demo))

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0) stop("Tests failed.")
