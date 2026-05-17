# tests/test_mod10.R — Unit tests for mod10_check_digit and barcode validators.
#
# Run: Rscript tests/test_mod10.R
#
# Uses the EAN-13-style weight pattern (1,3,1,3,...) that matches the
# Cinderhaven dataset generator. See the algorithm note in barcode_validators.R.

ROOT <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
source(file.path(ROOT, "R", "barcode_validators.R"))

pass <- 0L
fail <- 0L

assert <- function(desc, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) FALSE)
  if (ok) {
    pass <<- pass + 1L
  } else {
    fail <<- fail + 1L
    cat(sprintf("  FAIL: %s\n", desc))
  }
}

cat("--- mod10_check_digit tests ---\n")

# Edge cases
assert("empty string returns NA",
       is.na(mod10_check_digit("")))

assert("non-numeric returns NA",
       is.na(mod10_check_digit("abc")))

assert("check digit for 13 zeros is 0",
       mod10_check_digit("0000000000000") == 0L)

# Weight pattern verification: EAN-13-style (1,3,1,3,...)
assert("first digit gets weight 1",
       mod10_check_digit("1000000000000") == 9L)

assert("second digit gets weight 3",
       mod10_check_digit("0100000000000") == 7L)

# Arithmetic: body '123' → weights 1,3,1 → sum 1+6+3=10 → check 0
assert("body 123 → check 0",
       mod10_check_digit("123") == 0L)

# body '9' → 9*1=9 → (10-9)%%10=1
assert("single digit 9 → check 1",
       mod10_check_digit("9") == 1L)

# body '5' → 5*1=5 → (10-5)%%10=5
assert("single digit 5 → check 5",
       mod10_check_digit("5") == 5L)

cat("\n--- is_valid_gtin14 tests ---\n")

assert("valid 14-digit all-zeros passes",
       is_valid_gtin14("00000000000000"))

assert("wrong length fails",
       !is_valid_gtin14("0000000000000"))

assert("NA input fails",
       !is_valid_gtin14(NA_character_))

assert("alpha in code fails",
       !is_valid_gtin14("0000000000000a"))

assert("wrong check digit fails",
       !is_valid_gtin14("00000000000001"))

assert("vectorized input works",
       identical(is_valid_gtin14(c("00000000000000", "00000000000001")),
                 c(TRUE, FALSE)))

cat("\n--- is_valid_upc12 tests ---\n")

assert("valid 12-digit all-zeros passes",
       is_valid_upc12("000000000000"))

assert("wrong length fails",
       !is_valid_upc12("00000000000"))

assert("NA input fails",
       !is_valid_upc12(NA_character_))

assert("wrong check digit fails",
       !is_valid_upc12("000000000001"))

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0) stop("Tests failed.")
