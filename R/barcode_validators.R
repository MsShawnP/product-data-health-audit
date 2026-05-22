# barcode_validators.R — Mod-10 check digit and barcode validation helpers.
#
# Sourced by 02_build_frames.R and tests/test_mod10.R.

# GS1-standard mod-10 check digit. Weight pattern depends on body length:
#   GTIN-14 (13-digit body): (3,1,3,1,...) from left
#   EAN-13  (12-digit body): (1,3,1,3,...) from left
#   UPC-A   (11-digit body): (3,1,3,1,...) from left
mod10_check_digit <- function(body_digits) {
  d <- as.integer(strsplit(body_digits, "")[[1]])
  if (length(d) == 0 || any(is.na(d))) return(NA_integer_)
  if (length(d) == 12L) {
    weights <- rep(c(1L, 3L), length.out = length(d))
  } else {
    weights <- rep(c(3L, 1L), length.out = length(d))
  }
  s <- sum(d * weights)
  (10L - (s %% 10L)) %% 10L
}

is_valid_check_digit <- function(code, expected_len) {
  if (is.na(code) || nchar(code) != expected_len || !grepl("^[0-9]+$", code)) return(FALSE)
  body  <- substr(code, 1, expected_len - 1)
  check <- as.integer(substr(code, expected_len, expected_len))
  identical(check, mod10_check_digit(body))
}

is_valid_gtin14 <- function(x) vapply(x, is_valid_check_digit, logical(1), expected_len = 14L, USE.NAMES = FALSE)
is_valid_upc12  <- function(x) vapply(x, is_valid_check_digit, logical(1), expected_len = 12L, USE.NAMES = FALSE)
is_valid_ean13  <- function(x) vapply(x, is_valid_check_digit, logical(1), expected_len = 13L, USE.NAMES = FALSE)

is_valid_upc <- function(x) {
  vapply(x, function(code) {
    if (is.na(code)) return(FALSE)
    n <- nchar(code)
    if (n == 12L) return(is_valid_check_digit(code, 12L))
    if (n == 13L) return(is_valid_check_digit(code, 13L))
    FALSE
  }, logical(1), USE.NAMES = FALSE)
}
