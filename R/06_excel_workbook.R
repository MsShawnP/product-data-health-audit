# 06_excel_workbook.R
# Phase 5 — Generate the CEO's working Excel workbook from the same analytical
# frames that drive the Quarto report. Seven tabs, programmatically built so
# the workbook stays in sync with the underlying data on every pipeline run.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(lubridate)
  library(openxlsx2)
})

ROOT     <- normalizePath(
  Sys.getenv("PROJECT_ROOT", unset = "."),
  winslash = "/", mustWork = FALSE)
cfg      <- yaml::read_yaml(file.path(ROOT, "config.yml"))
PROC_DIR <- file.path(ROOT, "output", "frames")
OUT_DIR  <- file.path(ROOT, "output")
OUT_FILE <- file.path(OUT_DIR, paste0(cfg$data$output_prefix, "_audit.xlsx"))
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

read_p <- function(name) readRDS(file.path(PROC_DIR, paste0(name, ".rds")))
sku_dim          <- read_p("sku_dim")
sku_master_full  <- read_p("sku_master_full")
sku_retailer_rev <- read_p("sku_retailer_revenue")
chargebacks_e    <- read_p("chargebacks_enriched")
retailer_rs_long <- read_p("retailer_readiness_long")
velocity         <- read_p("velocity")

# ---- helpers --------------------------------------------------------------

# Apply a header style + freeze top row + reasonable column widths.
finish_sheet <- function(wb, sheet, df, header_fill = "#1f4e79") {
  n_col <- ncol(df)
  n_row <- nrow(df)
  if (n_row == 0 || n_col == 0) return(invisible(wb))

  # Header row formatting.
  wb$add_fill(sheet = sheet, dims = wb_dims(rows = 1, cols = 1:n_col),
              color = wb_color(hex = header_fill))
  wb$add_font(sheet = sheet, dims = wb_dims(rows = 1, cols = 1:n_col),
              color = wb_color(hex = "FFFFFF"), bold = TRUE,
              name  = "Calibri")

  # Freeze top row, autofilter, autofit columns.
  wb$freeze_pane(sheet = sheet, first_active_row = 2)
  wb$add_filter(sheet = sheet, rows = 1, cols = 1:n_col)
  wb$set_col_widths(sheet = sheet, cols = 1:n_col, widths = "auto")
  invisible(wb)
}

# Date when this workbook was generated (for tab footers / dictionary).
gen_date <- format(Sys.Date(), "%Y-%m-%d")

# ---- TAB 1: Velocity Summary ---------------------------------------------
# SKU × retailer, last 4-week and last 12-week roll-ups, % change, ACV
# distribution proxy (store count), and a data-quality flag.

cat("[1/8] Velocity Summary\n")

# ---- TAB 2: SKU Master + Data Quality Scores -----------------------------

cat("[2/8] SKU Master + Data Quality Scores\n")

sku_master_xlsx <- sku_master_full |>
  transmute(
    sku, product_name, product_line, subcategory,
    gtin14, upc,
    case_pack_qty, unit_weight_lbs, case_weight_lbs,
    case_length_in, case_width_in, case_height_in,
    msrp, wholesale_price, cogs_per_unit,
    country_of_origin, brand_owner, oneworldsync_status,
    updated_by, last_updated,
    # Quality flags
    gtin_valid, upc_valid,
    missing_case_weight, missing_case_dims,
    missing_country, missing_brand_owner,
    ows_complete, weight_plausible,
    issue_count, data_quality_score,
    # Outcomes
    ttm_units, ttm_revenue, store_count_ttm,
    chargeback_total, chargeback_count, n_retailers_charged,
    annual_gross_margin, chargeback_pct_of_gm,
    median_days_to_scan, mean_days_to_scan,
    auth_count, deauth_count, deauth_rate,
    fix_priority_score)

# ---- TAB 3: Retailer Readiness Matrix ------------------------------------
# Long format (sku × retailer × field × pass), filterable to "show me all
# rows that fail Walmart" or "everything missing case_weight_lbs."

cat("[3/8] Retailer Readiness Matrix\n")

readiness_matrix <- retailer_rs_long |>
  left_join(sku_dim |> select(sku, product_name, product_line,
                              data_quality_score, issue_count),
            by = "sku") |>
  left_join(sku_master_full |> select(sku, ttm_revenue),
            by = "sku") |>
  transmute(
    sku, product_name, product_line,
    retailer, field,
    passes = ifelse(passes, "PASS", "FAIL"),
    ttm_revenue, data_quality_score, issue_count) |>
  arrange(retailer, sku, field)

# ---- TAB 4: Chargeback Detail --------------------------------------------

cat("[4/8] Chargeback Detail\n")

chargeback_detail <- chargebacks_e |>
  transmute(
    month, sku, product_name, product_line,
    retailer, reason, amount,
    data_quality_score, issue_count,
    wholesale_price, cogs_per_unit) |>
  arrange(desc(amount))

# ---- TAB 5: Revenue by SKU × Retailer ------------------------------------

cat("[5/8] Revenue by SKU × Retailer\n")

rev_by_sku_ret <- sku_retailer_rev |>
  left_join(sku_dim |> select(sku, product_name, product_line,
                              data_quality_score, issue_count),
            by = "sku") |>
  transmute(
    sku, product_name, product_line, retailer,
    ttm_units, ttm_revenue, store_count_ttm, weeks_with_sales,
    trade_spend_pct,
    trade_spend_dollars = ttm_revenue * trade_spend_pct,
    revenue_after_trade = ttm_revenue * (1 - coalesce(trade_spend_pct, 0)),
    data_quality_score, issue_count) |>
  arrange(desc(ttm_revenue))

# ---- TAB 6: Triage List --------------------------------------------------
# est_fix_hours, savings_per_hour, and still_broken are computed once in
# R/02_build_frames.R and read here from sku_master_full. Rounding is done
# at the consumer for display purposes only.

cat("[6/8] Triage List\n")

triage <- sku_master_full |>
  arrange(desc(fix_priority_score)) |>
  transmute(
    rank = row_number(),
    sku, product_name, product_line,
    fix_priority_score,
    revenue_rank, quality_rank, chargeback_rank,
    ttm_revenue, issue_count, data_quality_score,
    chargeback_total, chargeback_pct_of_gm,
    mean_days_to_scan, deauth_rate,
    est_fix_hours    = round(est_fix_hours, 2),
    savings_per_hour = round(savings_per_hour, 0),
    still_broken)

# ---- TAB 7: Data Dictionary ----------------------------------------------
# Definitions are the approved text from excel_workbook_content.md. Where a
# content field name doesn't match the actual workbook column (e.g. content
# uses "gtin_14", workbook outputs "gtin14"), the row carries the actual
# column name and keeps the approved definition verbatim.

cat("[7/8] Data Dictionary\n")

dict_sections <- list(
  list(name = "Tab 1: Velocity Summary",
       rows = tribble(
~column,                       ~definition,
"sku",                         "Cinderhaven product identifier (CHP-XXXX).",
"product_name",                "Product display name.",
"retailer",                    "Contracted retailer name (Walmart, Costco, UNFI, Whole Foods).",
"product_line",                "Product line (Artisan Sauces, Specialty Condiments, Pantry Staples).",
"stores_4w",                   "Number of stores with active authorization for this SKU at this retailer.",
"ups_per_w_4w",                "Units sold per store per week, averaged over the most recent 4-week window.",
"ups_per_w_12w",               "Units sold per store per week, averaged over the most recent 12-week window.",
"ups_pct_change_4w_vs_prev",   "Percentage change from 12-week velocity to 4-week velocity. Positive = accelerating. Negative = decelerating.",
"data_quality_flag",           "Data quality flag. \"REVIEW\" = SKU has one or more active defects in the product master. \"OK\" = no active defects.")),

  list(name = "Tab 2: SKU Master + Data Quality Scores",
       rows = tribble(
~column,                       ~definition,
"sku",                         "Cinderhaven product identifier (CHP-XXXX).",
"product_name",                "Product display name.",
"product_line",                "Product line (Artisan Sauces, Specialty Condiments, Pantry Staples).",
"brand_owner",                 "Brand owner name as recorded in the product master. \"NA\" indicates a missing or placeholder value.",
"country_of_origin",           "Country of origin as recorded in the product master.",
"gtin14",                      "14-digit Global Trade Item Number for the case-level unit.",
"upc",                         "12-digit Universal Product Code for the consumer-level unit.",
"gtin_valid",                  "TRUE if the GTIN-14 check digit passes the mod-10 validation algorithm. FALSE if it fails.",
"upc_valid",                   "TRUE if the UPC-12 check digit passes the mod-10 validation algorithm. FALSE if it fails.",
"case_weight_lbs",             "Case weight in pounds as recorded in the product master.",
"case_length_in",              "Case length in inches.",
"case_width_in",               "Case width in inches.",
"case_height_in",              "Case height in inches.",
"missing_case_dims",           "TRUE if all four case dimension fields (weight, length, width, height) are populated. FALSE if any are blank.",
"weight_plausible",            "TRUE if case weight falls within a plausible range for the product category. FALSE if the value is missing, zero, negative, or implausibly high.",
"oneworldsync_status",         "OneWorldSync registration status. Values: \"Registered - Complete\", \"Registered - Incomplete\", \"Not Registered\".",
"data_quality_score",          "Composite score from 0 to 100. Calculated as (checks passed / 8) x 100. The 8 checks: GTIN-14 valid, UPC-12 valid, brand owner present, country of origin present, case weight plausible, case dimensions present, OneWorldSync complete, serving size standardized.",
"issue_count",                 "Total number of data quality checks failed (0 to 8).",
"ttm_revenue",                 "Trailing twelve-month revenue in USD, calculated from scan_data over the most recent 365 days.",
"annual_gross_margin",         "Trailing twelve-month gross margin in USD (revenue minus cost of goods sold).",
"chargeback_total",            "Total chargeback dollars over the 18-month observation window.",
"chargeback_count",            "Total number of chargeback events over the 18-month observation window.",
"fix_priority_score",          "Composite triage score from 0 to 100. Higher = fix sooner. Weighted: revenue rank (40%), quality rank (30%), chargeback rank (30%). Revenue rank 1 = highest revenue. Quality rank 1 = most issues. Chargeback rank 1 = most chargeback dollars.",
"updated_by",                  "The role or process that originally entered this SKU into the product master. Values: broker_upload, production_admin, inventory_admin, import_script, quality_mgr, ops_coordinator, or NA (unknown).",
"mean_days_to_scan",           "Days between first store authorization and first recorded scan. Measures time-to-shelf.")),

  list(name = "Tab 3: Retailer Readiness Matrix",
       rows = tribble(
~column,                       ~definition,
"sku",                         "Cinderhaven product identifier (CHP-XXXX).",
"product_name",                "Product display name.",
"retailer",                    "Contracted retailer name.",
"passes",                      "One column per required field in the retailer's spec. TRUE = field passes. FALSE = field fails. Column names match the retailer's published requirement labels.")),

  list(name = "Tab 4: Chargeback Detail",
       rows = tribble(
~column,                       ~definition,
"sku",                         "Cinderhaven product identifier (CHP-XXXX).",
"product_name",                "Product display name.",
"retailer",                    "Retailer that issued the chargeback.",
"month",                       "Date the chargeback was recorded.",
"amount",                      "Dollar amount of the chargeback.",
"reason",                      "Reason category assigned by the retailer. Values: Invalid GTIN/UPC, Dimension mismatch, Missing product data, Late delivery, Short shipment.")),

  list(name = "Tab 5: Revenue by SKU x Retailer",
       rows = tribble(
~column,                       ~definition,
"sku",                         "Cinderhaven product identifier (CHP-XXXX).",
"product_name",                "Product display name.",
"product_line",                "Product line.",
"retailer",                    "Contracted retailer name.",
"ttm_revenue",                 "Trailing twelve-month revenue in USD at this retailer.",
"store_count_ttm",             "Number of stores with active authorization at this retailer.")),

  list(name = "Tab 6: Triage List",
       rows = tribble(
~column,                       ~definition,
"sku",                         "Cinderhaven product identifier (CHP-XXXX).",
"product_name",                "Product display name.",
"product_line",                "Product line.",
"ttm_revenue",                 "Trailing twelve-month revenue in USD.",
"data_quality_score",          "Composite data quality score (0 to 100).",
"chargeback_total",            "Total chargeback dollars, 18-month window.",
"fix_priority_score",          "Composite triage score (0 to 100). Higher = fix sooner. See Tab 2 definition for weighting.",
"est_fix_hours",               "Estimated hours to resolve all active defects for this SKU. Based on per-defect time estimates: GTIN/UPC check digit (10 min), case dimensions (30 min), brand owner (10 min), country of origin (30 min), OneWorldSync registration (30 min), implausible case weight (15 min).",
"savings_per_hour",            "Annualized chargeback savings divided by estimated fix hours. Higher = better return on time invested.",
"still_broken",                "Specific defect(s) currently present in the product master that are linked to active chargebacks. Blank if no active chargeback-linked defects.")))

# ---- TAB 8: Broker Intake Checklist --------------------------------------
# Approved text + 8 required fields from excel_workbook_content.md.

cat("[8/8] Broker Intake Checklist\n")

intake_purpose <-
  paste("Purpose: This checklist gates every SKU submission from a broker",
        "into the product master. All eight fields must be populated and",
        "validated before the record goes live. The checklist applies to",
        "broker uploads but should be enforced on every entry path.")

intake_instructions <-
  paste("Instructions: Complete one row per SKU. Every field is required.",
        "Do not save the record to the product master until all eight fields",
        "pass validation. If a field cannot be completed, do not submit the",
        "SKU. Return the checklist to the broker with the incomplete fields",
        "marked.")

intake_summary_note <-
  paste("Validation summary row: At the bottom of the checklist, a summary",
        "row counts the number of fields passing validation out of 8. A SKU",
        "with fewer than 8 passes does not enter the product master.")

intake_who <-
  paste("Who fills this out: The broker, for every SKU they submit.",
        "The ops team reviews the completed checklist before saving the",
        "record. If the broker cannot or will not complete all eight fields,",
        "that is information about the broker.")

intake_rows <- tribble(
~`#`, ~Field,                          ~`What to enter`,                                                                                  ~`Validation rule`,                                                                                                                          ~`Common errors`,
1,    "GTIN-14",                       "14-digit case-level barcode.",                                                                    "Must pass mod-10 check digit calculation. Enter all 14 digits including the check digit.",                                "Transposed digits. Wrong check digit. Entering UPC-12 in the GTIN-14 field.",
2,    "UPC-12",                        "12-digit consumer-unit barcode.",                                                                 "Must pass mod-10 check digit calculation. Enter all 12 digits including the check digit.",                                "Same as GTIN-14. Entering GTIN-14 in the UPC-12 field.",
3,    "Brand owner",                   "Legal brand name that owns the product.",                                                         "Must be a non-empty string. Must not be \"NA\", \"N/A\", \"TBD\", or blank.",                                              "Entering \"NA\" or leaving blank. Entering distributor name instead of brand owner.",
4,    "Country of origin",             "Country where the product is manufactured or primarily sourced.",                                 "Must be a recognized country name or ISO 3166 code.",                                                                       "Leaving blank for domestic products (enter \"United States\").",
5,    "Case weight (kg)",              "Gross weight of one shipping case in kilograms.",                                                 "Must be a positive number. Must fall within a plausible range for the product category (typically 1-25 kg for specialty food).", "Entering net weight instead of gross. Entering weight in pounds without converting. Leaving blank.",
6,    "Case dimensions (L x W x H, cm)", "Length, width, and height of one shipping case in centimeters. All three required.",           "Each dimension must be a positive number. All three must be populated.",                                                    "Entering only one or two dimensions. Entering in inches without converting. Leaving blank.",
7,    "OneWorldSync registration",     "Confirm the SKU is registered in OneWorldSync with status \"Registered - Complete\".",            "Must provide the OneWorldSync GTIN registration confirmation or status screenshot.",                                        "Submitting before registration is complete. Assuming registration happens automatically.",
8,    "Serving size",                  "Serving size as it appears on the product label.",                                                "Must follow the format: [number] [unit] ([metric equivalent]). Example: \"2 tbsp (30 mL)\".",                              "Inconsistent formats across SKUs. Entering only metric or only imperial.")

# ---- write the workbook --------------------------------------------------

cat("\nWriting: ", OUT_FILE, "\n", sep = "")

wb <- wb_workbook(creator = paste(cfg$company$short_name, "Audit Pipeline"))

# Cinderhaven palette (must match R/00_theme.R).
PAL_NAVY     <- "1B2A4A"
PAL_BG_PALE  <- "E8ECF0"
PAL_BG_PALER <- "F4F6F8"
PAL_TEXT     <- "2D3436"

# Tabs 1–6 use the standard `finish_sheet` formatting.
data_sheets <- list(
  list(name = "Velocity Summary",          df = velocity),
  list(name = "SKU Master + DQ",           df = sku_master_xlsx),
  list(name = "Retailer Readiness Matrix", df = readiness_matrix),
  list(name = "Chargeback Detail",         df = chargeback_detail),
  list(name = "Revenue SKU x Retailer",    df = rev_by_sku_ret),
  list(name = "Triage List",               df = triage))

for (s in data_sheets) {
  wb$add_worksheet(s$name)
  wb$add_data(sheet = s$name, x = s$df, start_row = 1, start_col = 1)
  finish_sheet(wb, s$name, s$df, header_fill = paste0("#", PAL_NAVY))
}

# ---- Tab 7: Data Dictionary (sectioned) ----------------------------------
dict_sheet <- "Data Dictionary"
wb$add_worksheet(dict_sheet)

# Row 1: column header
wb$add_data(sheet = dict_sheet,
            x = data.frame(Column = "Column", Definition = "Definition"),
            start_row = 1, col_names = FALSE)
wb$add_fill(sheet = dict_sheet, dims = wb_dims(rows = 1, cols = 1:2),
            color = wb_color(hex = PAL_NAVY))
wb$add_font(sheet = dict_sheet, dims = wb_dims(rows = 1, cols = 1:2),
            color = wb_color(hex = "FFFFFF"), bold = TRUE, name = "Calibri")

cur_row <- 2
for (sec in dict_sections) {
  # Section header row (merged across both columns)
  wb$add_data(sheet = dict_sheet, x = sec$name,
              start_row = cur_row, start_col = 1)
  wb$merge_cells(sheet = dict_sheet,
                 dims = wb_dims(rows = cur_row, cols = 1:2))
  wb$add_fill(sheet = dict_sheet,
              dims = wb_dims(rows = cur_row, cols = 1:2),
              color = wb_color(hex = PAL_BG_PALE))
  wb$add_font(sheet = dict_sheet,
              dims = wb_dims(rows = cur_row, cols = 1:2),
              color = wb_color(hex = PAL_TEXT), bold = TRUE,
              name = "Calibri", size = 12)
  cur_row <- cur_row + 1

  # Data rows for this section, with alternating row shading
  n_data <- nrow(sec$rows)
  wb$add_data(sheet = dict_sheet, x = sec$rows,
              start_row = cur_row, col_names = FALSE)
  for (i in seq_len(n_data)) {
    if (i %% 2 == 0) {
      wb$add_fill(sheet = dict_sheet,
                  dims = wb_dims(rows = cur_row + i - 1, cols = 1:2),
                  color = wb_color(hex = PAL_BG_PALER))
    }
  }
  # Wrap the definition column so long text remains visible
  wb$add_cell_style(sheet = dict_sheet,
                    dims = wb_dims(rows = cur_row:(cur_row + n_data - 1),
                                   cols = 2),
                    wrap_text = "1", vertical = "top")
  wb$add_cell_style(sheet = dict_sheet,
                    dims = wb_dims(rows = cur_row:(cur_row + n_data - 1),
                                   cols = 1),
                    vertical = "top")
  cur_row <- cur_row + n_data
}

wb$freeze_pane(sheet = dict_sheet, first_active_row = 2)
wb$set_col_widths(sheet = dict_sheet, cols = 1, widths = 32)
wb$set_col_widths(sheet = dict_sheet, cols = 2, widths = 95)

# ---- Tab 8: Broker Intake Checklist --------------------------------------
intake_sheet <- "Broker Intake Checklist"
wb$add_worksheet(intake_sheet)

# Row 1: title
wb$add_data(sheet = intake_sheet, x = "Broker Intake Checklist",
            start_row = 1, start_col = 1)
wb$merge_cells(sheet = intake_sheet, dims = wb_dims(rows = 1, cols = 1:5))
wb$add_fill(sheet = intake_sheet, dims = wb_dims(rows = 1, cols = 1:5),
            color = wb_color(hex = PAL_NAVY))
wb$add_font(sheet = intake_sheet, dims = wb_dims(rows = 1, cols = 1:5),
            color = wb_color(hex = "FFFFFF"), bold = TRUE,
            name = "Calibri", size = 16)
wb$set_row_heights(sheet = intake_sheet, rows = 1, heights = 28)

# Row 2: Purpose (merged, wrapped)
wb$add_data(sheet = intake_sheet, x = intake_purpose,
            start_row = 2, start_col = 1)
wb$merge_cells(sheet = intake_sheet, dims = wb_dims(rows = 2, cols = 1:5))
wb$add_fill(sheet = intake_sheet, dims = wb_dims(rows = 2, cols = 1:5),
            color = wb_color(hex = PAL_BG_PALE))
wb$add_cell_style(sheet = intake_sheet,
                  dims = wb_dims(rows = 2, cols = 1:5),
                  wrap_text = "1", vertical = "top")
wb$set_row_heights(sheet = intake_sheet, rows = 2, heights = 50)

# Row 3: Instructions (merged, wrapped)
wb$add_data(sheet = intake_sheet, x = intake_instructions,
            start_row = 3, start_col = 1)
wb$merge_cells(sheet = intake_sheet, dims = wb_dims(rows = 3, cols = 1:5))
wb$add_fill(sheet = intake_sheet, dims = wb_dims(rows = 3, cols = 1:5),
            color = wb_color(hex = PAL_BG_PALER))
wb$add_cell_style(sheet = intake_sheet,
                  dims = wb_dims(rows = 3, cols = 1:5),
                  wrap_text = "1", vertical = "top")
wb$set_row_heights(sheet = intake_sheet, rows = 3, heights = 60)

# Row 5: header row for the table
table_header_row <- 5
wb$add_data(sheet = intake_sheet,
            x = data.frame(`#` = "#", Field = "Field",
                           `What to enter` = "What to enter",
                           `Validation rule` = "Validation rule",
                           `Common errors` = "Common errors",
                           check.names = FALSE),
            start_row = table_header_row, col_names = FALSE)
wb$add_fill(sheet = intake_sheet,
            dims = wb_dims(rows = table_header_row, cols = 1:5),
            color = wb_color(hex = PAL_NAVY))
wb$add_font(sheet = intake_sheet,
            dims = wb_dims(rows = table_header_row, cols = 1:5),
            color = wb_color(hex = "FFFFFF"), bold = TRUE,
            name = "Calibri", size = 11)

# Rows 6-13: 8 required-field rows
data_start_row <- table_header_row + 1
wb$add_data(sheet = intake_sheet, x = intake_rows,
            start_row = data_start_row, col_names = FALSE)

# Wrap text in all 8 data rows; alternate row shading
for (i in seq_len(nrow(intake_rows))) {
  r <- data_start_row + i - 1
  wb$add_cell_style(sheet = intake_sheet,
                    dims = wb_dims(rows = r, cols = 1:5),
                    wrap_text = "1", vertical = "top")
  if (i %% 2 == 0) {
    wb$add_fill(sheet = intake_sheet,
                dims = wb_dims(rows = r, cols = 1:5),
                color = wb_color(hex = PAL_BG_PALER))
  }
  wb$set_row_heights(sheet = intake_sheet, rows = r, heights = 42)
}

# Row 14: validation summary row (counts passing fields)
summary_row_n <- data_start_row + nrow(intake_rows)
wb$add_data(sheet = intake_sheet,
            x = data.frame(`#` = "Σ",
                           Field = "Validation summary",
                           `What to enter` = "Pass / 8",
                           `Validation rule` = "All 8 must pass before SKU enters product master.",
                           `Common errors` = "Submitting with any field unvalidated.",
                           check.names = FALSE),
            start_row = summary_row_n, col_names = FALSE)
wb$add_fill(sheet = intake_sheet,
            dims = wb_dims(rows = summary_row_n, cols = 1:5),
            color = wb_color(hex = PAL_BG_PALE))
wb$add_font(sheet = intake_sheet,
            dims = wb_dims(rows = summary_row_n, cols = 1:5),
            bold = TRUE, color = wb_color(hex = PAL_TEXT),
            name = "Calibri")
wb$add_cell_style(sheet = intake_sheet,
                  dims = wb_dims(rows = summary_row_n, cols = 1:5),
                  wrap_text = "1", vertical = "top")
wb$set_row_heights(sheet = intake_sheet, rows = summary_row_n, heights = 28)

# Validation summary description note
note1_row <- summary_row_n + 2
wb$add_data(sheet = intake_sheet, x = intake_summary_note,
            start_row = note1_row, start_col = 1)
wb$merge_cells(sheet = intake_sheet,
               dims = wb_dims(rows = note1_row, cols = 1:5))
wb$add_cell_style(sheet = intake_sheet,
                  dims = wb_dims(rows = note1_row, cols = 1:5),
                  wrap_text = "1", vertical = "top")
wb$set_row_heights(sheet = intake_sheet, rows = note1_row, heights = 36)

# Who-fills-this-out note
note2_row <- note1_row + 1
wb$add_data(sheet = intake_sheet, x = intake_who,
            start_row = note2_row, start_col = 1)
wb$merge_cells(sheet = intake_sheet,
               dims = wb_dims(rows = note2_row, cols = 1:5))
wb$add_cell_style(sheet = intake_sheet,
                  dims = wb_dims(rows = note2_row, cols = 1:5),
                  wrap_text = "1", vertical = "top")
wb$set_row_heights(sheet = intake_sheet, rows = note2_row, heights = 48)

# Column widths tuned so the 5-column table fits one US-letter landscape page
wb$set_col_widths(sheet = intake_sheet, cols = 1, widths = 5)   # #
wb$set_col_widths(sheet = intake_sheet, cols = 2, widths = 22)  # Field
wb$set_col_widths(sheet = intake_sheet, cols = 3, widths = 38)  # What to enter
wb$set_col_widths(sheet = intake_sheet, cols = 4, widths = 42)  # Validation rule
wb$set_col_widths(sheet = intake_sheet, cols = 5, widths = 38)  # Common errors

# Print on one page (landscape, US-letter, fit-to-page)
wb$page_setup(sheet         = intake_sheet,
              orientation   = "landscape",
              paper_size    = 1,            # 1 = US Letter
              fit_to_width  = 1,
              fit_to_height = 1,
              left = 0.4, right = 0.4, top = 0.5, bottom = 0.5)

wb$save(OUT_FILE)

# Footer log.
cat(sprintf("\nWrote %s (%.0f KB)\n", basename(OUT_FILE),
            file.info(OUT_FILE)$size / 1024))
cat("\nTab row counts:\n")
for (s in data_sheets) cat(sprintf("  %-30s %6d rows × %3d cols\n",
                                    s$name, nrow(s$df), ncol(s$df)))
n_dict_rows <- sum(sapply(dict_sections, function(x) nrow(x$rows))) +
               length(dict_sections) + 1
cat(sprintf("  %-30s %6d rows × %3d cols\n",
            "Data Dictionary", n_dict_rows, 2))
cat(sprintf("  %-30s %6d rows × %3d cols\n",
            "Broker Intake Checklist", note2_row, 5))
