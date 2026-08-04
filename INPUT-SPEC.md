# INPUT-SPEC — Product Data Health Audit

What a client hands over to run this audit, written so an IT/data person can produce
the files without a call. The audit consumes **two extracts**: an **item master** and a
**chargeback (deduction) extract**. Both are validated by the preflight
(`python scripts/run_preflight.py`) *before* any analysis runs. A file that violates this
spec produces a **Data Readiness Report** naming exactly what is wrong — not a stack trace,
and never a silently-coerced number.

- **Formats:** CSV or XLSX. UTF-8, UTF-8-BOM, or latin-1. Comma, semicolon, or tab
  delimited. Leading blank rows, trailing junk rows, and whitespace in headers are
  tolerated. Excel or text dates both read.
- **Identifiers are text.** `sku`, `gtin14`, `upc`, `chargeback_id` are read as strings —
  leading zeros are preserved. Do **not** let Excel store a GTIN as a number.
- **Column names:** if your headers differ from the canonical names below, map them in
  `engagement.yml` under `columns:` (case/whitespace-insensitive exact matches are applied
  automatically and disclosed; anything else must be mapped explicitly — never guessed).
- **Blanks:** a blank in a *completeness* field (country of origin, case dimensions, brand
  owner) is a finding the audit **reports**, not a reason to reject the file. A blank in a
  *key* field (sku, gtin14, upc, amount) is a readiness problem.

---

## §1. Item master  (`--item-master`)

One row per SKU. Drives barcode validation, retailer-readiness, data-quality scoring, and
the fix-effort model.

| Canonical column | Type | Required | Blank allowed | Used for |
|---|---|---|---|---|
| `sku` | identifier | yes | no | Primary key; must be **unique** |
| `product_name` | string | yes | no | Labeling every finding |
| `product_line` | string | yes | no | Data-debt-by-line breakdown |
| `gtin14` | identifier | yes | no | GTIN-14 check-digit validation |
| `upc` | identifier | yes | no | UPC check-digit validation |
| `brand_owner` | string | yes | yes | Required-field completeness check |
| `country_of_origin` | string | yes | yes | Required-field completeness check |
| `case_pack_qty` | number | yes | yes | Case-pack completeness / weight plausibility |
| `unit_weight_lbs` | number | yes | yes | Weight plausibility |
| `case_weight_lbs` | number | yes | yes | Case-weight completeness |
| `case_length_in` | number | yes | yes | Case-dimension completeness |
| `case_width_in` | number | yes | yes | Case-dimension completeness |
| `case_height_in` | number | yes | yes | Case-dimension completeness |
| `cogs_per_unit` | number (≥0) | yes | no | Gross-margin math |
| `wholesale_price` | number (≥0) | yes | no | Revenue / margin math |
| `msrp` | number (≥0) | yes | yes | Reference pricing |
| `last_updated` | date | no | — | Audit-trail / new-vs-old-SKU analysis |
| `trade_spend_pct_<retailer>` | number | no | — | Retailer P&L; if absent, the rate comes from `engagement.yml` `rates:` |

`trade_spend_pct_<retailer>` columns are optional per retailer. Any retailer in the roster
(`engagement.yml` `retailers:`) without a rate column falls back to the configured proxy
rate — and that proxy is disclosed on the retailer-P&L output.

## §2. Chargeback / deduction extract  (`--chargebacks`)

One row per chargeback (deduction) line item from retailer settlement statements.

| Canonical column | Type | Required | Blank allowed | Used for |
|---|---|---|---|---|
| `chargeback_id` | identifier | yes | no | Primary key; must be **unique** |
| `sku` | identifier | yes | no | Joins to the item master `sku` |
| `retailer` | string | yes | no | Per-retailer P&L and roster |
| `amount` | number (≥0) | yes | no | All chargeback dollar figures |
| `reason` | string | yes | no | Reason-category breakdown |
| `month` | string (`YYYY-MM`) | yes | no | Monthly trend, annualization window |
| `triggered_by_field` | string | no | yes | Data-defect attribution. Blank = not attributed to a data field (fulfillment-driven) |

`triggered_by_field` is what separates data-attributable chargebacks from fulfillment ones.
When present it should name an item-master field (e.g. `missing_case_dims`, `gtin14`). When
your extract does not carry attribution, leave it blank — the audit reports the
data-attributable share as unknown rather than guessing.

---

## §3. Engagement config (`engagement.yml`)

Everything client-specific — client/brand name, `as_of_date`, retailer roster, rate table,
margin basis, column mapping, hard-fail thresholds — lives in `engagement.yml`. See
`engagement.demo.yml` for the shipped demo (Cinderhaven) values and the
[engagement-template](../engagement-template/engagement.example.yml) for the annotated
template. `as_of_date` is **required** and is never today's date.
