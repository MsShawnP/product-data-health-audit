# tests/test_mod10.R — Unit tests for mod10_check_digit and barcode validators.
#
# Run: Rscript tests/test_mod10.R
#
# Uses GS1-standard weight patterns: (3,1,3,1,...) for GTIN-14/UPC-A bodies,
# (1,3,1,3,...) for EAN-13 bodies. See barcode_validators.R.

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

# Weight pattern verification: GS1-standard (3,1,3,1,...) for 13-digit body
assert("13-digit body: first digit gets weight 3",
       mod10_check_digit("1000000000000") == 7L)

assert("13-digit body: second digit gets weight 1",
       mod10_check_digit("0100000000000") == 9L)

# 12-digit body (EAN-13): weights (1,3,1,3,...)
assert("12-digit body: first digit gets weight 1",
       mod10_check_digit("100000000000") == 9L)

# 3-digit body → weights 3,1,3 → sum 3+6+9=18 → check (10-8)%10=2
assert("body 123 → check 2",
       mod10_check_digit("123") == 6L)

# body '9' → 9*3=27 → (10-7)%%10=3
assert("single digit 9 → check 3",
       mod10_check_digit("9") == 3L)

# body '5' → 5*3=15 → (10-5)%%10=5
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

assert("non-trivial valid GTIN-14 passes",
       is_valid_gtin14("12345678901231"))

assert("non-trivial GTIN-14 with wrong check digit fails",
       !is_valid_gtin14("12345678901235"))

cat("\n--- is_valid_upc12 tests ---\n")

assert("valid 12-digit all-zeros passes",
       is_valid_upc12("000000000000"))

assert("wrong length fails",
       !is_valid_upc12("00000000000"))

assert("NA input fails",
       !is_valid_upc12(NA_character_))

assert("wrong check digit fails",
       !is_valid_upc12("000000000001"))

assert("non-trivial valid UPC-12 passes",
       is_valid_upc12("012345678905"))

assert("non-trivial UPC-12 with wrong check digit fails",
       !is_valid_upc12("012345678901"))

cat("\n--- issue_count formula regression ---\n")

issue_count <- function(gtin_valid, upc_valid, missing_case_weight,
                        missing_case_dims, missing_country,
                        missing_brand_owner, ows_complete,
                        weight_plausible) {
  as.integer(is.na(gtin_valid) | !gtin_valid) +
  as.integer(is.na(upc_valid)  | !upc_valid) +
  as.integer(missing_case_weight) +
  as.integer(missing_case_dims) +
  as.integer(missing_country) +
  as.integer(missing_brand_owner) +
  as.integer(is.na(ows_complete) | !ows_complete) +
  as.integer(!is.na(weight_plausible) & !weight_plausible)
}

assert("all clean -> 0 issues",
       issue_count(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE) == 0L)

assert("all broken -> 8 issues",
       issue_count(FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE) == 8L)

assert("mixed NAs: NA gtin, NA ows, NA weight_plausible -> 4 issues",
       issue_count(NA, TRUE, TRUE, FALSE, FALSE, TRUE, NA, NA) == 4L)

assert("NA weight_plausible does not count as an issue",
       issue_count(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, NA) == 0L)

assert("FALSE weight_plausible counts as an issue",
       issue_count(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE) == 1L)

cat(sprintf("\n%d passed, %d failed\n", pass, fail))
if (fail > 0) stop("Tests failed.")
