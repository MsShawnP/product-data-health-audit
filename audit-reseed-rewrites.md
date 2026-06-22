# Narrative Rewrites — Post-Reseed Data (Round 3)

All prose in Economist style, American English. CC: drop verbatim, do not edit.

---

## 1. Section title

The heading "15 hours against $228,845" should now render dynamically. If it already uses `r ds(annual_cb)`, it will show "15 hours against $146,961" — that's correct. If the heading doesn't support inline R, hardcode it to:

**15 hours against $146,961**

---

## 2. "The $56-a-month problem nobody sees" (replaces "The $111-a-month" section — full replacement)

Update the section heading in the TOC/anchor too.

> ## The $56-a-month problem nobody sees
>
> The 12 invalid GTIN check digits, 12 invalid UPC check digits, and 19 missing case dimension records in Cinderhaven's product master have been wrong since the day each SKU was entered. In that time, nobody corrected a single one. Not because anyone decided the chargebacks were acceptable. Because nobody knew the chargebacks and the digits were connected.
>
> The chain of visibility works like this. A retailer's automated system validates the barcode on an inbound shipment or a data feed submission. The check digit fails. The system generates a compliance penalty. The penalty appears as a line item on the next settlement statement, categorized under a heading like "vendor compliance deductions" or "label/barcode fine." The settlement statement is 40 pages long. It contains hundreds of line items. The compliance penalties are scattered across pages, interleaved with promotional deductions, logistics credits, and payment adjustments. An individual penalty is small. It does not trigger an investigation. It does not cross an approval threshold. It does not generate an alert.
>
> On the other side, the product master sits in whatever system Cinderhaven uses to manage product data. The GTIN-14 and UPC fields contain numbers that were typed once, by whoever set up each SKU, and have not been opened since. Nobody reviews barcode fields. Nobody runs check digit validations. Nobody has a process for connecting a chargeback on a settlement statement to a digit in the product master.
>
> The ops team is not negligent. They are fully occupied. Six retailer portals. Broker coordination. Velocity reports rebuilt by hand every Monday. Trade spend reconciliation. New SKU launches. Promotional planning. Data cleanup is on the list. It is always on the list. It sits between "update the trade spend template" and "fix the label printer" and it never reaches the top because the chargebacks arrive in amounts too small to demand attention and too steady to ever stop on their own.
>
> CHP-AS-005, Classic Tomato Basil, carries $4,029 in annualized chargebacks spread across all six retailers. That works out to roughly $56 per retailer per month. Each month, at each retailer, $56 appears on the settlement statement as a compliance deduction. Not large enough to flag. Not unusual enough to investigate. Not connected to the other five retailers generating the same charge for the same reason.
>
> Fifty-six dollars. Six retailers. Thirty-six months. One wrong digit.
>
> This is the structural problem. The chargebacks persist because the defects persist. The defects persist because nobody has time to find them. Nobody has time to find them because the cost of each individual defect is too small to surface through normal business processes. The total is `r ds(annual_cb)` a year. The individual units are invisible. The system that would make them visible does not exist yet. Part 3 of this report describes what that system looks like.

---

## 3. "The SKU you can't afford to ignore" (full replacement)

> ## The SKU you can't afford to ignore
>
> CHP-DG-007, Trail Mix Premium, is the sixth-best-selling product in the Cinderhaven catalog. $2.2 million in trailing twelve-month revenue. 315 stores across every channel. It represents $1.6 million in annual gross margin.
>
> It fails every retailer's readiness check. Zero of six.
>
> The product carries three defects: an invalid GTIN-14 check digit, an invalid UPC check digit, and missing case dimensions. It has generated 73 chargeback events over 36 months — $23,760 in penalties. Twenty-eight of its 315 store authorizations have been revoked. Those slots are gone.
>
> The chargebacks are not the point. At $7,920 a year, they barely register against $2.2 million in revenue. What registers is the deauthorization risk. A retailer's automated readiness check does not distinguish between a $7,920-a-year chargeback product and a $70-a-year one. It checks the barcode. The digit fails. The product is flagged.
>
> Fixing CHP-DG-007 takes 50 minutes. Correct the GTIN check digit. Correct the UPC check digit. Measure and enter the case dimensions. When that is done, 28 lost store authorizations stop compounding, and a $2.2 million product moves from zero of six retailers passing to a candidate for all six.
>
> The same pattern repeats across the top of the catalog:

CC: replace the hardcoded top 10 table with a dynamic inline R expression that renders the table from the current data. If that's not feasible in Quarto, hardcode the following table from the current pipeline output. But CHECK THESE NUMBERS AGAINST THE ACTUAL DATA — do not trust my table, verify against the pipeline:

> | Rank | Product | Revenue | DQ score | Chargebacks (36mo) | Retailers passing |
> |------|---------|---------|----------|-------------------|-------------------|
>
> (CC fills this from current data — sort by TTM revenue descending, top 10)

Then continue with:

> The difference is not commercial attention. Everyone at Cinderhaven knows what Trail Mix Premium sells. Nobody knows that its GTIN-14 check digit is wrong. Those are two different kinds of knowing, and only the first one happens naturally.
>
> The risk of leaving CHP-DG-007 unfixed is not the $7,920. The risk is that a retailer runs the check. Walmart does not send a chargeback for a readiness failure. Walmart sends a deauthorization. And when a $2.2 million product — one that already fails every retailer it ships to — loses shelf space at its largest account, the conversation is not with the data team. It is with the board.

---

## 4. "15 hours against $X" section — data-defect percentages

Find and replace the paragraph about data-defect share:

OLD: "\"Label / barcode fine\" chargebacks totaled $137,041 over 36 months, annualized to $45,680 a year. Combined with pricing errors ($5,466 annualized), data-related chargebacks account for 22% of the total bill."

NEW (make these dynamic if possible, otherwise hardcode from current data):

"Label and barcode fine chargebacks, combined with pricing errors, account for 35% of the total bill — $51,147 a year traced directly to data defects. The remaining 65% traces to fulfillment operations and is outside the scope of this data audit."

CC: verify the exact percentage from the pipeline. If 34.8%, round to 35% in prose.

---

## 5. Fix action table — annual savings line

The "$51,147 data-defect" figure in the fix action table is still correct. No change needed.

---

## 6. Fulfillment reference in "The sequence" section

OLD (approximately): "$177,698 traces to fulfillment operations"

NEW: Use dynamic expression: `r ds(annual_cb - data_defect_annual)` — or if that variable doesn't exist, hardcode "$95,814 traces to fulfillment operations: short shipments, late deliveries, and receiving discrepancies."

---

## 7. Monthly chargeback references

Three references to "$19,000 per month" — replace all with ~$12,200 per month (or make dynamic).

OLD: "held roughly flat at about $19,000 per month"
NEW: "held roughly flat at about $12,200 per month"

OLD: (any other $19,000 references)
NEW: ~$12,200

---

## 8. "The concentrated defect" — line references

OLD (approximately): "$897,000 a year" and "$1.2 million SKU" and "$319,000 SKU"
These need updating to current revenue figures. CC: pull current revenue for these SKUs and replace. Or better, make them dynamic.

---

## 9. Tearsheet — CHP-DG-007 paragraph (full replacement)

> **The crown jewel**
>
> CHP-DG-007, Trail Mix Premium, is the sixth-highest-revenue SKU in the catalog ($2.2 million TTM) and fails every retailer's readiness check — zero of six. 73 chargeback events across 36 months, $23,760 in penalties, 28 store authorizations revoked. It carries three defects: an invalid GTIN-14 check digit, an invalid UPC check digit, and missing case dimensions. Fixing all three takes 50 minutes. A $2.2 million product that fails every retailer it sells to is less than an hour of clerical work from full compliance.

---

## 10. Landing page — updated paragraph

OLD: "...demonstrating how dirty product data costs a growing brand $51,000 a year in retailer chargebacks traced directly to data defects — with another $177,000 in fulfillment penalties concentrated in the same SKUs — and how 15 hours of data entry fixes the data side entirely."

NEW: "...demonstrating how dirty product data costs a growing brand $51,000 a year in retailer chargebacks traced directly to data defects — with another $96,000 in fulfillment penalties concentrated in the same SKUs — and how 15 hours of data entry fixes the data side entirely."

---

## 11. Dashboard — quick-win claim

OLD: "over $20,000 per fix-hour"
NEW: "over $15,000 per fix-hour"

(Or make dynamic — pull the threshold from the data.)

---

## 12. "What a wrong barcode costs" — CHP-SC-006 detail

This section references CHP-SC-006 with old figures. CC: update with current data:
- 36mo chargebacks: $45,196 (was $80,490)
- TTM revenue: $51,332 (was $607,924)
- Store count: check current
- Monthly rate: ~$1,255/mo (was $3,004)
- Annual savings from fix: check current

NOTE: CHP-SC-006 now has only $51K in revenue but $45K in 36mo chargebacks — that's an 88% chargeback-to-revenue ratio, which is extreme. The story shifts from "high-revenue SKU bleeding quietly" to "this SKU's chargebacks nearly equal its revenue." That's a different and arguably more shocking argument. I'll leave the framing for CC to update the numbers and I can adjust the prose if the framing needs to shift.

Actually — CC, confirm: is CHP-SC-006 TTM revenue really $51,332? That seems implausibly low for a product authorized at stores. If correct, this SKU is essentially unprofitable after chargebacks and the narrative needs to reflect that.
