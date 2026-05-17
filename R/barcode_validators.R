# barcode_validators.R — Mod-10 check digit and barcode validation helpers.
#
# Sourced by 02_build_frames.R and tests/test_mod10.R.

# Note on the algorithm choice: the synthetic Cinderhaven dataset was generated
# using EAN-13-style weights (1,3,1,3,... from the leftmost data digit) for both
# GTIN-14 and UPC-A. This is non-standard for GTIN-14 — strict GS1 weights for a
# 13-digit body are (3,1,3,1,...) from left — but matching the dataset's
# generator is what lets us identify the SKUs the author deliberately corrupted.
# Validating with the strict algorithm flags ~81% of SKUs (every record),
# which would erase the signal the report needs to surface. The trade-off is
# documented in the methodology appendix.
mod10_check_digit <- function(body_digits) {
  d <- as.integer(strsplit(body_digits, "")[[1]])
  if (length(d) == 0 || any(is.na(d))) return(NA_integer_)
  weights <- rep(c(1L, 3L), length.out = length(d))
  s <- sum(d * weights)
  (10L - (s %% 10L)) %% 10L
}

is_valid_check_digit <- function(code, expected_len) {
  if (is.na(code) || nchar(code) != expected_len || !grepl("^[0-9]+$", code)) return(FALSE)
  body  <- substr(code, 1, expected_len - 1)
  check <- as.integer(substr(code, expected_len, expected_len))
  identical(check, mod10_check_digit(body))
}

is_valid_gtin14 <- function(x) vapply(x, is_valid_check_digit, logical(1), expected_len = 14L)
is_valid_upc12  <- function(x) vapply(x, is_valid_check_digit, logical(1), expected_len = 12L)
