# Phase 7: Shareable Artifacts — Content

---

## Artifact A: GS1 Sunrise 2027 / FSMA 204 Compliance Timeline

**Format:** One-page visual timeline. Print-friendly. Any specialty food brand can use it.

**Title:** Product Data Compliance Timeline: What's Coming and What It Requires

**Subtitle:** Two industry transitions are already underway. Both depend on clean product data. This timeline shows the key dates, what each transition requires, and what needs to be true about your product master before each deadline arrives.

---

### Timeline entries (chronological)

**NOW (2026)**

Label: You are here.

What's happening: GS1 Sunrise transition period is active. Retailers are upgrading point-of-sale systems to accept 2D barcodes alongside traditional UPCs. Some retailers, including Walmart, have communicated supplier requirements ahead of the 2027 target. Dual-marking (1D + 2D barcodes on the same package) is the current best practice during transition.

What your product master needs today:
- Every GTIN-14 and UPC-12 must pass mod-10 check digit validation
- Brand owner field must contain the legal brand name (not "NA", not blank)
- OneWorldSync registration must be complete for every active SKU

---

**DECEMBER 31, 2027 — GS1 Sunrise**

Label: Retail POS systems must accept 2D barcodes.

What happens: Retailers' point-of-sale systems must be capable of scanning and processing 2D barcodes, including GS1 Digital Link QR codes, at checkout. UPC barcodes will continue to work. But the 2D barcode becomes the primary carrier of product data at point of sale.

What this requires from you:
- Valid GTINs. A GS1 Digital Link QR code is built on a GTIN. If the GTIN is wrong, the QR code is wrong. There is no workaround.
- Product data registered in GS1-certified data pools (OneWorldSync, 1WorldSync, or equivalent). The QR code points to a resolver that looks up product data. If the product data isn't registered, the resolver returns nothing.
- Packaging updated to include 2D barcodes. This requires artwork changes with lead times of 3 to 12 months depending on your packaging supply chain.

What happens if you're not ready: Your products can still scan via UPC. But retailers that have moved to 2D-first workflows may flag non-compliant products. Retailer-specific mandates may be more stringent than the GS1 baseline. Products without 2D barcodes lose access to the enhanced data capabilities (batch tracking, expiration dates, promotional linking) that retailers are building into their systems.

---

**JULY 20, 2028 — FSMA Rule 204 (Food Traceability Rule)**

Label: FDA food traceability compliance deadline.

What happens: All covered entities in the food supply chain must maintain and share Key Data Elements (KDEs) at Critical Tracking Events (CTEs) for foods on the FDA's Food Traceability List. Records must be producible in electronic, sortable format within 24 hours of an FDA request. This deadline was originally January 20, 2026. FDA extended it by 30 months in March 2025 to allow industry-wide coordination.

What this requires from you:
- Accurate GTINs as the product identifier backbone. The traceability system tracks products by GTIN. If the GTIN is wrong, the traceability chain breaks.
- Lot-level tracking capability tied to accurate product identifiers
- Systems that can capture and share traceability data with supply chain partners and FDA on request
- The ability to trace any covered product from source to point of sale within 24 hours

Who is covered: Any entity that manufactures, processes, packs, or holds foods on the FDA's Food Traceability List. This includes many specialty food categories: fresh and fresh-cut produce, soft cheeses, shell eggs, fresh herbs, certain seafood, nut butters, and foods containing these as ingredients in their listed form.

What happens if you're not ready: Non-compliance with a federal regulation. FDA enforcement actions. Beyond enforcement, retailers are already adding "FSMA 204 ready" as a qualification criterion in supplier evaluations. Non-compliance is not just a regulatory risk. It is a market access risk.

---

**2028-2029 — Post-compliance**

Label: The new baseline.

What's true after both transitions: Product data quality is no longer optional infrastructure. It is the foundation for barcode scanning, food traceability, and retailer compliance. Companies that fixed their product master for GS1 Sunrise simultaneously built the infrastructure for FSMA 204 compliance, because both transitions depend on the same thing: valid, complete, registered product identifiers.

---

### Prerequisites checklist (bottom of the page)

Before either deadline, your product master must have:

| # | Requirement | GS1 Sunrise | FSMA 204 | Status |
|---|---|:---:|:---:|---|
| 1 | Valid GTIN-14 check digits on all SKUs | Required | Required | ☐ |
| 2 | Valid UPC-12 check digits on all SKUs | Required | Required | ☐ |
| 3 | Brand owner field populated (legal name) | Required | — | ☐ |
| 4 | Case dimensions populated (L x W x H) | Required | — | ☐ |
| 5 | Case weight populated | Required | — | ☐ |
| 6 | Country of origin populated | Required | Required | ☐ |
| 7 | OneWorldSync registration complete | Required | — | ☐ |
| 8 | Lot-level tracking operational | — | Required | ☐ |
| 9 | 2D barcode on packaging | Required | — | ☐ |
| 10 | 24-hour traceability response capability | — | Required | ☐ |

**Source note:** GS1 Sunrise dates from GS1 US (gs1us.org). FSMA 204 dates from FDA (fda.gov). The FSMA 204 compliance date was extended from January 20, 2026 to July 20, 2028 by FDA notice dated March 20, 2025. Requirements are summarized for specialty food manufacturers. Consult the full regulations and your legal counsel for applicability to your specific products and operations.

---
---

## Artifact B: Product Data Health Scorecard Template

**Format:** One-page self-assessment. Fillable. An ops manager can complete it in 15 minutes without any tools.

**Title:** Product Data Health Scorecard

**Subtitle:** Score your product master against eight dimensions. If you score below 50, your data will break before you hit $50 million.

---

### Instructions

Answer each question using the data in your product master or ERP system. For each dimension, circle the score that matches your current state. Add the scores. The total tells you where you stand and what to prioritize.

---

### The eight dimensions

**1. GTIN validity**

What it measures: Do your barcodes pass algorithmic validation?

| Score | Criteria |
|---:|---|
| 0 | Don't know, or have never checked |
| 5 | Checked, and more than 10% of GTINs fail |
| 10 | Checked, and fewer than 10% fail |
| 15 | All GTINs pass mod-10 check digit validation |

Why it matters: An invalid GTIN triggers automated chargebacks at every retailer, every month, until it's fixed. It also blocks GS1 Sunrise 2027 compliance and FSMA 204 traceability. This is the single highest-leverage data quality dimension.

---

**2. Required field completeness**

What it measures: Are the fields retailers require actually populated?

| Score | Criteria |
|---:|---|
| 0 | Don't know which fields each retailer requires |
| 5 | Know the requirements, fewer than 50% of SKUs pass |
| 10 | 50-80% of SKUs pass all required fields |
| 15 | More than 80% of SKUs pass all retailer required-field checks |

Why it matters: A SKU that fails a required-field check cannot be onboarded, reauthorized, or expanded at that retailer. The fields are usually simple: brand owner, country of origin, case dimensions, case weight. The gap between failing and passing is typically one to three fields per SKU.

---

**3. Case dimensions and weights**

What it measures: Are physical product specifications populated and plausible?

| Score | Criteria |
|---:|---|
| 0 | More than 30% of SKUs have blank or implausible case dimensions |
| 5 | 10-30% have gaps |
| 10 | Fewer than 10% have gaps |
| 15 | All SKUs have populated, verified case dimensions and weights |

Why it matters: Blank or wrong case dimensions cause warehouse receiving errors, chargeback penalties for dimension mismatches, and delays in distribution center slot assignment. These are physical measurements that require someone to measure the actual product. They cannot be guessed or defaulted.

---

**4. Data pool registration (OneWorldSync / 1WorldSync)**

What it measures: Are your products registered and complete in a GS1-certified data pool?

| Score | Criteria |
|---:|---|
| 0 | No data pool registration, or don't know |
| 3 | Some SKUs registered, most incomplete |
| 7 | Most SKUs registered, some incomplete |
| 10 | All active SKUs registered with status "Complete" |

Why it matters: Data pool registration is the mechanism that synchronizes your product data with retailers. Without it, retailers maintain their own copy of your product data, which drifts from yours over time. Registration is a prerequisite for GS1 Sunrise 2027.

---

**5. Data entry governance**

What it measures: Is there a gate between data entry and the live product master?

| Score | Criteria |
|---:|---|
| 0 | Anyone can enter or edit product records with no validation |
| 3 | Some entry paths have validation, others do not |
| 7 | All entry paths require validation, but it's not consistently enforced |
| 10 | All entry paths require validation before a record goes live, with an audit trail |

Why it matters: Every product data problem starts at the moment of entry. If there is no check between "someone typed this" and "retailers are ordering against it," every defect becomes a chargeback, a stalled launch, or a deauthorization. The cost of an intake checklist is five minutes per SKU. The cost of skipping it is months of accumulated penalties that nobody traces back to the entry.

---

**6. Chargeback traceability**

What it measures: Can you trace a chargeback to the specific field in the product master that caused it?

| Score | Criteria |
|---:|---|
| 0 | Chargebacks are not tracked, or are tracked only as a total dollar amount |
| 3 | Chargebacks are tracked by SKU but not linked to specific data fields |
| 7 | Chargebacks are linked to reason codes and can be matched to data defects manually |
| 10 | Automated reconciliation links each chargeback to the specific field that caused it |

Why it matters: If you cannot trace a chargeback to its cause, you cannot fix the cause. Chargebacks arrive on settlement statements as line items categorized under generic headings. Without a reconciliation process, the charges look like dozens of separate problems. They are usually a handful of fields, repeated.

---

**7. Velocity and performance monitoring**

What it measures: Do you have a reliable, consistent view of product performance across retailers?

| Score | Criteria |
|---:|---|
| 0 | No velocity reporting, or reports are built manually from retailer exports |
| 3 | Manual reports exist but definitions vary across retailers |
| 7 | Consistent reporting across retailers, updated weekly |
| 10 | Automated reporting with data quality flags and trend alerts |

Why it matters: A velocity report built from four different retailer CSVs with four different column headers and four different store count definitions is not a report. It is a reconciliation exercise. The time spent reconciling is time not spent acting on what the data says.

---

**8. Regulatory readiness**

What it measures: Are you prepared for GS1 Sunrise 2027 and FSMA Rule 204?

| Score | Criteria |
|---:|---|
| 0 | Have not assessed readiness for either transition |
| 5 | Aware of the deadlines, no action plan |
| 10 | Action plan in place, partially implemented |
| 15 | Fully prepared: valid GTINs, registered data pool, 2D barcodes on packaging, lot-level traceability operational |

Why it matters: These are not future concerns. GS1 Sunrise transition is active now. FSMA 204 compliance is required by July 2028. Both depend on accurate product identifiers. Preparing for one prepares you for both.

---

### Scoring interpretation

| Total score | What it means |
|---:|---|
| 80-100 | Strong. Your product master supports current operations and upcoming transitions. Focus on maintaining governance and monitoring for drift. |
| 60-79 | Adequate with gaps. You likely have specific dimensions pulling the score down. Identify them and prioritize. The fixes are usually bounded and specific. |
| 40-59 | At risk. Your product data will generate increasing costs as you grow and as compliance deadlines arrive. A focused cleanup, typically 2 to 4 weeks of effort, can move you into the adequate range. |
| Below 40 | Your data will break before you hit $50 million. The cost of inaction compounds with every new SKU, every new retailer, and every month closer to the 2027 and 2028 deadlines. Start with GTIN validation and required field completeness. Those two dimensions unlock the most value fastest. |

---

### What to do with your score

This scorecard is a starting point, not a diagnosis. A score tells you where to look. A product data audit tells you what to fix, in what order, and what it's worth.

If your score is below 60, the next step is to run the GTIN validation check across your catalog. It takes less than an hour and immediately surfaces the highest-cost defects.

**Source note:** Scoring dimensions are based on observed patterns across specialty food companies at $10 million to $100 million in revenue. Thresholds are directional. Your specific situation may warrant different weights depending on your retailer mix, growth trajectory, and regulatory exposure.
