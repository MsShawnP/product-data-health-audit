# Excel Workbook Content — Data Dictionary + Broker Intake Checklist

---

## Tab 7: Data Dictionary

This tab defines every column, score, and flag used in the workbook. One row per field.

### Tab 1: Velocity Summary

| Column | Definition |
|---|---|
| sku | Cinderhaven product identifier (CHP-XXXX). |
| product_name | Product display name. |
| retailer | Contracted retailer name (Walmart, Costco, UNFI, Whole Foods). |
| product_line | Product line (Artisan Sauces, Specialty Condiments, Pantry Staples). |
| store_count | Number of stores with active authorization for this SKU at this retailer. |
| velocity_4wk | Units sold per store per week, averaged over the most recent 4-week window. |
| velocity_12wk | Units sold per store per week, averaged over the most recent 12-week window. |
| pct_change | Percentage change from 12-week velocity to 4-week velocity. Positive = accelerating. Negative = decelerating. |
| dq_flag | Data quality flag. "REVIEW" = SKU has one or more active defects in the product master. "OK" = no active defects. |

### Tab 2: SKU Master + Data Quality Scores

| Column | Definition |
|---|---|
| sku | Cinderhaven product identifier (CHP-XXXX). |
| product_name | Product display name. |
| product_line | Product line (Artisan Sauces, Specialty Condiments, Pantry Staples). |
| brand_owner | Brand owner name as recorded in the product master. "NA" indicates a missing or placeholder value. |
| country_of_origin | Country of origin as recorded in the product master. |
| gtin_14 | 14-digit Global Trade Item Number for the case-level unit. |
| upc_12 | 12-digit Universal Product Code for the consumer-level unit. |
| gtin_14_valid | TRUE if the GTIN-14 check digit passes the mod-10 validation algorithm. FALSE if it fails. |
| upc_12_valid | TRUE if the UPC-12 check digit passes the mod-10 validation algorithm. FALSE if it fails. |
| case_weight_kg | Case weight in kilograms as recorded in the product master. |
| case_length_cm | Case length in centimeters. |
| case_width_cm | Case width in centimeters. |
| case_height_cm | Case height in centimeters. |
| case_dims_present | TRUE if all four case dimension fields (weight, length, width, height) are populated. FALSE if any are blank. |
| case_weight_plausible | TRUE if case weight falls within a plausible range for the product category. FALSE if the value is missing, zero, negative, or implausibly high. |
| ows_status | OneWorldSync registration status. Values: "Registered - Complete", "Registered - Incomplete", "Not Registered". |
| serving_size_raw | Serving size as originally entered in the product master. Not standardized. |
| serving_size_std | TRUE if the serving size string conforms to a standard format. FALSE if it uses a non-standard format. |
| data_quality_score | Composite score from 0 to 100. Calculated as (checks passed / 8) x 100. The 8 checks: GTIN-14 valid, UPC-12 valid, brand owner present, country of origin present, case weight plausible, case dimensions present, OneWorldSync complete, serving size standardized. |
| quality_tier | Plain-English label based on data_quality_score quartile. Values: "Worst 25%", "Below average", "Above average", "Best 25%". |
| issue_count | Total number of data quality checks failed (0 to 8). |
| ttm_revenue | Trailing twelve-month revenue in USD, calculated from scan_data over the most recent 365 days. |
| ttm_gross_margin | Trailing twelve-month gross margin in USD (revenue minus cost of goods sold). |
| chargeback_total | Total chargeback dollars over the 18-month observation window. |
| chargeback_events | Total number of chargeback events over the 18-month observation window. |
| fix_priority_score | Composite triage score from 0 to 100. Higher = fix sooner. Weighted: revenue rank (40%), quality rank (30%), chargeback rank (30%). Revenue rank 1 = highest revenue. Quality rank 1 = most issues. Chargeback rank 1 = most chargeback dollars. |
| data_entry_source | The role or process that originally entered this SKU into the product master. Values: broker_upload, production_admin, inventory_admin, import_script, quality_mgr, ops_coordinator, or NA (unknown). |
| days_to_first_scan | Days between first store authorization and first recorded scan. Measures time-to-shelf. |

### Tab 3: Retailer Readiness Matrix

| Column | Definition |
|---|---|
| sku | Cinderhaven product identifier (CHP-XXXX). |
| product_name | Product display name. |
| retailer | Contracted retailer name. |
| overall_pass | TRUE if the SKU passes all required-field checks for this retailer. FALSE if any check fails. |
| fields_short | Number of required fields that are missing, invalid, or incomplete for this retailer. |
| [field-specific columns] | One column per required field in the retailer's spec. TRUE = field passes. FALSE = field fails. Column names match the retailer's published requirement labels. |

### Tab 4: Chargeback Detail

| Column | Definition |
|---|---|
| chargeback_id | Unique identifier for the chargeback event. |
| sku | Cinderhaven product identifier (CHP-XXXX). |
| product_name | Product display name. |
| retailer | Retailer that issued the chargeback. |
| chargeback_date | Date the chargeback was recorded. |
| chargeback_amount | Dollar amount of the chargeback. |
| chargeback_reason | Reason category assigned by the retailer. Values: Invalid GTIN/UPC, Dimension mismatch, Missing product data, Late delivery, Short shipment. |
| data_defect_linked | TRUE if the chargeback reason maps to a correctable data defect in the product master. FALSE for logistics-related reasons (Late delivery, Short shipment). |

### Tab 5: Revenue by SKU x Retailer

| Column | Definition |
|---|---|
| sku | Cinderhaven product identifier (CHP-XXXX). |
| product_name | Product display name. |
| product_line | Product line. |
| retailer | Contracted retailer name. |
| ttm_revenue | Trailing twelve-month revenue in USD at this retailer. |
| store_count | Number of stores with active authorization at this retailer. |
| velocity_12wk | Units per store per week, 12-week average at this retailer. |

### Tab 6: Triage List

| Column | Definition |
|---|---|
| sku | Cinderhaven product identifier (CHP-XXXX). |
| product_name | Product display name. |
| product_line | Product line. |
| ttm_revenue | Trailing twelve-month revenue in USD. |
| data_quality_score | Composite data quality score (0 to 100). |
| chargeback_total | Total chargeback dollars, 18-month window. |
| fix_priority_score | Composite triage score (0 to 100). Higher = fix sooner. See Tab 2 definition for weighting. |
| est_fix_hours | Estimated hours to resolve all active defects for this SKU. Based on per-defect time estimates: GTIN/UPC check digit (10 min), case dimensions (30 min), brand owner (10 min), country of origin (30 min), OneWorldSync registration (30 min), implausible case weight (15 min). |
| savings_per_hour | Annualized chargeback savings divided by estimated fix hours. Higher = better return on time invested. |
| still_broken | Specific defect(s) currently present in the product master that are linked to active chargebacks. Blank if no active chargeback-linked defects. |

---

## Tab 8: Broker Intake Checklist

**Purpose:** This checklist gates every SKU submission from a broker into the product master. All eight fields must be populated and validated before the record goes live. The checklist applies to broker uploads but should be enforced on every entry path.

**Instructions:** Complete one row per SKU. Every field is required. Do not save the record to the product master until all eight fields pass validation. If a field cannot be completed, do not submit the SKU. Return the checklist to the broker with the incomplete fields marked.

| # | Field | What to enter | Validation rule | Common errors |
|---|---|---|---|---|
| 1 | GTIN-14 | 14-digit case-level barcode. | Must pass mod-10 check digit calculation. Enter all 14 digits including the check digit. | Transposed digits. Wrong check digit. Entering UPC-12 in the GTIN-14 field. |
| 2 | UPC-12 | 12-digit consumer-unit barcode. | Must pass mod-10 check digit calculation. Enter all 12 digits including the check digit. | Same as GTIN-14. Entering GTIN-14 in the UPC-12 field. |
| 3 | Brand owner | Legal brand name that owns the product. | Must be a non-empty string. Must not be "NA", "N/A", "TBD", or blank. | Entering "NA" or leaving blank. Entering distributor name instead of brand owner. |
| 4 | Country of origin | Country where the product is manufactured or primarily sourced. | Must be a recognized country name or ISO 3166 code. | Leaving blank for domestic products (enter "United States"). |
| 5 | Case weight (kg) | Gross weight of one shipping case in kilograms. | Must be a positive number. Must fall within a plausible range for the product category (typically 1-25 kg for specialty food). | Entering net weight instead of gross. Entering weight in pounds without converting. Leaving blank. |
| 6 | Case dimensions (L x W x H, cm) | Length, width, and height of one shipping case in centimeters. All three required. | Each dimension must be a positive number. All three must be populated. | Entering only one or two dimensions. Entering in inches without converting. Leaving blank. |
| 7 | OneWorldSync registration | Confirm the SKU is registered in OneWorldSync with status "Registered - Complete". | Must provide the OneWorldSync GTIN registration confirmation or status screenshot. | Submitting before registration is complete. Assuming registration happens automatically. |
| 8 | Serving size | Serving size as it appears on the product label. | Must follow the format: [number] [unit] ([metric equivalent]). Example: "2 tbsp (30 mL)". | Inconsistent formats across SKUs. Entering only metric or only imperial. |

**Validation summary row:** At the bottom of the checklist, a summary row counts the number of fields passing validation out of 8. A SKU with fewer than 8 passes does not enter the product master.

**Who fills this out:** The broker, for every SKU they submit. The ops team reviews the completed checklist before saving the record. If the broker cannot or will not complete all eight fields, that is information about the broker.
