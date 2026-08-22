# Pharmacy Operations & Demand Intelligence — Synthetic Demonstration
### Exploring sales, product availability, ordering patterns and customer demand using synthetic operational data.

**Author:** Brian Mtepe Kombo, KRCHN | Healthcare Data Analytics / Health Informatics
**Status:** Discovery & Demonstration project (NOT a live analysis of any real pharmacy)
**Repo type:** Portfolio project

---

## 0. Guiding Principles

1. This project **demonstrates a method**, not a conclusion. Nothing here describes any real pharmacy until validated by a pharmacist.
2. Every hypothesis is a *question*, never a *finding*, until real data confirms it: inventory problem, sales problem, supplier problem, "should stock more," stockout = poor ordering, low sales = low demand — **all unproven**.
3. **SALES ≠ DEMAND.** Sales = completed transactions. Demand = everything a customer wanted, including what never became a sale.
4. Analytics produces **evidence**. The pharmacist makes **decisions**.
5. No clinical or stocking recommendations. Product identities are fictionalized categories, not real brands.

---

## 1. Core Business Questions

| # | Question | Data area |
|---|---|---|
| Q1 | What products/categories are customers **actually purchasing**? | Sales |
| Q2 | What products/categories are customers **requesting**? | Customer_Requests |
| Q3 | How often are requested products **unavailable**? | Customer_Requests |
| Q4 | Which products are **repeatedly ordered because unavailable** at request time? | Requests → Orders |
| Q5 | Are there **stocked, low-movement products** while others are **repeatedly requested but not stocked**? | Sales + Stock + Requests |
| Q6 | How long to **fulfill** an order triggered by an unavailable/requested product? | Orders + Requests |
| Q7 | How well could **historical sales + request data** support ordering decisions? | All tables |

---

## 2. Data Architecture

### 2.1 Entity Relationship Overview

    Suppliers (1) ──< Product_Master (M)
    Product_Master (1) ──< Sales (M)
    Product_Master (1) ──< Stock_Daily (M)
    Product_Master (1) ──< Orders (M) >── Suppliers (1)
    Product_Master (1) ──< Customer_Requests (M) [Requested_Product_ID]
    Product_Master (1) ──< Customer_Requests (M) [Alternative_Product_ID]
    Orders (1) ──< Customer_Requests (M) [Order_ID, nullable]

### 2.2 Table: Suppliers

| Field | Type | Key | Nullable | Description |
|---|---|---|---|---|
| Supplier_ID | INT | PK | No | Unique supplier identifier |
| Supplier_Name | VARCHAR(100) | | No | Fictionalized supplier name |
| Supplier_Category | VARCHAR(50) | | Yes | Type of supplier |
| Typical_Lead_Time_Days | INT | | No | Baseline expected delivery days |
| Active | TINYINT | | No | Whether supplier is currently used |

### 2.3 Table: Product_Master

| Field | Type | Key | Nullable | Description |
|---|---|---|---|---|
| Product_ID | INT | PK | No | Unique product identifier |
| Product_Name | VARCHAR(100) | | No | Fictionalized product name |
| Category | VARCHAR(50) | | No | Broad category |
| Subcategory | VARCHAR(50) | | Yes | Finer grouping |
| Dosage_Form | VARCHAR(30) | | Yes | Tablet, syrup, cream, etc. |
| Strength | VARCHAR(30) | | Yes | Where applicable |
| Pack_Size | VARCHAR(30) | | Yes | Packaging unit |
| Supplier_ID | INT | FK | Yes | Primary supplier |
| Unit_Cost | DECIMAL(10,2) | | No | Purchase cost |
| Selling_Price | DECIMAL(10,2) | | No | Selling price |
| Routinely_Stocked | TINYINT | | No | 1 = normally stocked; 0 = order-on-request |
| Active | TINYINT | | No | 1 = currently in catalogue |

### 2.4 Table: Sales

| Field | Type | Key | Nullable | Description |
|---|---|---|---|---|
| Sale_ID | INT | PK | No | Transaction line identifier |
| Sale_Date | DATE | | No | Date of sale |
| Product_ID | INT | FK | No | Product sold |
| Quantity | INT | | No | Units sold |
| Unit_Selling_Price | DECIMAL(10,2) | | No | Actual price charged |
| Revenue | DECIMAL(10,2) | | No | Quantity × price |
| Unit_Cost | DECIMAL(10,2) | | Yes | Cost at time of sale |
| Margin | DECIMAL(10,2) | | Yes | Revenue − cost |

### 2.5 Table: Stock_Daily

| Field | Type | Key | Nullable | Description |
|---|---|---|---|---|
| Stock_ID | INT | PK | No | Surrogate key |
| Date | DATE | | No | Stock date |
| Product_ID | INT | FK | No | Product |
| Opening_Stock | INT | | No | Units at start of day |
| Received | INT | | No | Units received that day |
| Sold | INT | | No | Units sold that day |
| Adjustments | INT | | No | +/- write-offs, corrections |
| Closing_Stock | INT | | No | Opening + Received − Sold + Adjustments |

### 2.6 Table: Orders

| Field | Type | Key | Nullable | Description |
|---|---|---|---|---|
| Order_ID | INT | PK | No | Order identifier |
| Order_Date | DATE | | No | Date order placed |
| Product_ID | INT | FK | No | Product ordered |
| Quantity_Ordered | INT | | No | Units ordered |
| Supplier_ID | INT | FK | No | Supplier used |
| Reason | VARCHAR(30) | | No | Routine Replenishment / Customer Request / Stock Shortage / Other |
| Expected_Date | DATE | | Yes | Expected delivery |
| Received_Date | DATE | | Yes | Actual delivery (NULL if unresolved) |
| Quantity_Received | INT | | Yes | Units actually received |

### 2.7 Table: Customer_Requests (the critical table)

| Field | Type | Key | Nullable | Description |
|---|---|---|---|---|
| Request_ID | INT | PK | No | Request identifier |
| Request_Date | DATE | | No | Date of request |
| Requested_Product_ID | INT | FK | Yes | Specific product requested |
| Requested_Category | VARCHAR(50) | | Yes | Category-level request |
| Quantity_Requested | INT | | Yes | Units requested |
| Available | TINYINT | | No | 1 = in stock; 0 = not available |
| Alternative_Offered | TINYINT | | No | 1 = substitute offered |
| Alternative_Product_ID | INT | FK | Yes | Product offered as alternative |
| Ordered_For_Customer | TINYINT | | No | 1 = order placed due to this request |
| Order_ID | INT | FK | Yes | Linked order |
| Fulfilled_Date | DATE | | Yes | Date resolved |
| Outcome | VARCHAR(30) | | No | Sold / Alternative Accepted / Ordered and Fulfilled / Unavailable / Customer Declined / Other |

**Note:** SQL DDL uses `TINYINT` for all flag columns rather than `BIT`, since MySQL's `BIT` type does not load reliably through `LOAD DATA INFILE`.

---

## 3. Business Rules & Metric Definitions

**3.1 Total Sales** = `SUM(Revenue)` — completed transactions only; says nothing about unmet requests.

**3.2 Units Sold** = `SUM(Quantity)` — volume ≠ value.

**3.3 Product Demand** — two distinct definitions, never conflated:
- *Observed Sales Demand* = units sold (proxy only, undercounts true demand)
- *Total Recorded Demand* = count of logged Customer_Requests (closer to true demand, only as good as logging discipline)
- Never use "demand" alone in a chart or report — say "sales" or "recorded requests" explicitly.

**3.4 Request Volume** = `COUNT(Request_ID)` by product/category/period.

**3.5 Unavailable Request Rate** = `COUNT(Available=0) / COUNT(*)` within Customer_Requests.

**3.6 Availability Rate** = `1 − Unavailable Request Rate`.

**3.7 Alternative/Substitution Rate** = `COUNT(Alternative_Offered=1) / COUNT(Available=0)`.

**3.8 Customer-Request Order Rate** = `COUNT(Ordered_For_Customer=1) / COUNT(Available=0)`.

**3.9 Order Fulfillment Time** = `DATEDIFF(Received_Date, Order_Date)` per order, averaged; separately, customer-experienced wait = `DATEDIFF(Fulfilled_Date, Request_Date)`. Excludes unresolved orders — report those separately.

**3.10 Stockout Events** = `COUNT(*)` where `Closing_Stock = 0` **AND** `Routinely_Stocked = 1` — excluding never-stocked products avoids inflating this metric.

**3.11 Slow-Moving Products** = routinely-stocked products with `SUM(Quantity)` in the bottom quartile of sales.

**3.12 Product Movement** = Fast/Medium/Slow tertile classification by units or revenue.

**3.13 Potential Assortment Review Candidates** — flag a product if: `Routinely_Stocked=0` AND requested ≥5 times, OR `Routinely_Stocked=1` AND in the "Slow" movement band. Labeled **"Products for review"** — never "products to stock." This is a shortlist for human judgment, not a purchasing recommendation; cost, margin, expiry risk, storage, and supplier reliability are not in this dataset.

---

## 4. Analytical Logic (7 SQL Views)

- **vw_sales_trends** — daily/product-level sales rollup by category
- **vw_requests_summary** — request and unavailability counts by product/category
- **vw_availability** — daily unavailable-rate trend
- **vw_product_movement** — units sold and stockout days by product
- **vw_order_reasons** — order counts and units by Reason
- **vw_supplier_performance** — average fulfillment days and unresolved orders by supplier
- **vw_assortment_review** — the composite "products for review" flag, combining sales and request data

(Full SQL definitions live in `03_sql/03_analytic_views.sql`.)

---

## 5. Synthetic Data Generation (Python)

- 70 products across 10 categories, 6 suppliers, Jan–Sep 2025 daily data
- Deliberately mirrors the real pharmacist conversation: one category ("Antimalarial") has 1 routinely-stocked option and 2 order-on-request alternatives
- Fast/Medium/Slow movement tiers with seasonal boosts (e.g., malaria season, allergy season)
- Imperfect logging discipline modeled: only ~35% of real stockout events become a logged Customer_Request — mirrors the real-world question "do you actually record requests?"
- Noise deliberately preserved: supplier delays, partial receipts, unresolved orders, occasional stock write-offs — the analyst must investigate, not read a clean signal

Pipeline stages (in `04_python/`):
1. `01_data_generation.ipynb` — generates raw CSVs
2. `02_data_quality_check.ipynb` — validates and exports clean CSVs

---

## 6. Data Quality Checks

Validated: duplicates, missing foreign keys, invalid dates, negative quantities, stock balance reconciliation (`Opening + Received − Sold + Adjustments = Closing`), orders received before ordered, sales for inactive products, missing suppliers, inconsistent categories.

**Known resolved issues during build:**
- MySQL `BIT` columns silently corrupted via `LOAD DATA INFILE` — resolved by converting to `TINYINT`
- Windows `\r\n` line endings caused Customer_Requests to load 0 rows (CHECK constraint violation on the last column) — resolved with `LINES TERMINATED BY '\r\n'`
- Power BI date hierarchy auto-collapsed line charts to Year granularity — resolved by using plain date fields
- Stockout Days measure was inflated by non-stocked products — resolved with a `Routinely_Stocked=1` filter

---

## 7. Power BI Dashboard (5 pages)

1. **Executive Overview** — KPI summary, revenue/request trends, category breakdowns
2. **Demand & Availability** — requests vs. unavailability over time and by category, "Demand Not Fully Served" table
3. **Product, Assortment & Stock** — top requested/sold products, stockout exposure, assortment review table
4. **Ordering & Supplies** — orders by reason, supplier fulfillment performance
5. **Key Findings** — summary cards and synthetic-data disclaimer

**Color convention:** blue = normal activity, red = attention areas (unavailable requests, unresolved orders, stockouts).

---

## 8. Real-World Validation Questions

Before treating any of this as applicable to a real pharmacy: Does this reflect how your pharmacy operates? Do you already record customer requests? How do you know when a requested product was unavailable? How do you decide what to order? Does sales history influence ordering? How do you identify slow-moving stock? How do you track supplier delays? Which challenges do you consider most important?

Treat "we don't track that" as a legitimate finding, not a design gap — it defines what the first real deliverable should be.

---

## 9. Recommendation Framework

**Evidence → Interpretation → Possible Action → Owner Validation**

Example:
- **Evidence:** "Product X was requested 25 times and unavailable 8 times."
- **Interpretation:** "This suggests repeated unmet availability for this product."
- **Possible action:** "Consider reviewing whether routine availability is appropriate."
- **Owner validation:** "Check margin, expiry risk, supplier availability, storage requirements, and business considerations."

Never skip a step. Never phrase Possible Action as an instruction.

---

## 10. Final Reminders

- Remains a demonstration and discovery exercise until validated by a real pharmacist.
- Never present synthetic findings as real pharmacy findings.
- No stocking recommendations. No clinical recommendations. Evidence and questions only.
