# Power BI Integration Guide
## Insurance Claims Fraud Detection System

---

## STEP 1: Install MySQL ODBC Connector

1. Go to: https://dev.mysql.com/downloads/connector/odbc/
2. Download **MySQL Connector/ODBC 8.0** (Windows x64)
3. Install it — keep all defaults
4. Open **ODBC Data Sources (64-bit)** from Windows Start menu
5. Click **Add** → select **MySQL ODBC 8.0 Unicode Driver** → Finish
6. Fill in:
   - Data Source Name: `InsuranceFraudDB`
   - Server: `localhost`
   - Port: `3306`
   - Database: `insurance_fraud_db`
   - User: `root` (or your MySQL user)
   - Password: your MySQL password
7. Click **Test** → should say "Connection Successful"
8. Click **OK**

---

## STEP 2: Connect Power BI Desktop to MySQL

1. Open **Power BI Desktop** (free download from Microsoft)
2. Click **Home → Get Data → More**
3. Search for **MySQL database** → Connect
4. Server: `localhost`
5. Database: `insurance_fraud_db`
6. Click **OK**
7. Authentication: select **Database** tab → enter your MySQL username + password
8. In the Navigator window, select these views (NOT the raw tables):
   - ✅ `vw_executive_dashboard`
   - ✅ `vw_fraud_investigation_queue`
   - ✅ `vw_customer_360`
9. Also select these raw tables for cross-filtering:
   - ✅ `claims`
   - ✅ `policies`
   - ✅ `customers`
10. Click **Load**

---

## STEP 3: Create Relationships in Power BI

Go to **Model view** (left sidebar icon).

Create these relationships:
| From table | Column | To table | Column | Cardinality |
|---|---|---|---|---|
| claims | policy_id | policies | policy_id | Many-to-One |
| policies | customer_id | customers | customer_id | Many-to-One |
| vw_fraud_investigation_queue | customer_name | vw_customer_360 | full_name | Many-to-One |

Set cross-filter direction to **Both** for all relationships.

---

## STEP 4: Create DAX Measures

Click **New Measure** in the Home tab. Create each measure below.

```dax
-- Total Claims
Total Claims = COUNTROWS(claims)

-- Total Claimed Amount
Total Claimed EUR = SUM(claims[claim_amount])

-- Total Approved Amount
Total Approved EUR = SUM(claims[approved_amount])

-- Fraud Count
Fraud Cases = CALCULATE(COUNTROWS(claims), claims[status] = "Fraud Suspected")

-- Fraud Rate %
Fraud Rate % = DIVIDE([Fraud Cases], [Total Claims], 0) * 100

-- Payout Ratio %
Payout Ratio % = DIVIDE([Total Approved EUR], [Total Claimed EUR], 0) * 100

-- Average Claim Amount
Avg Claim EUR = AVERAGE(claims[claim_amount])

-- Avg Risk Score (from fraud queue view)
Avg Risk Score = AVERAGE(vw_fraud_investigation_queue[risk_score])

-- High Risk Customers (risk score > 80)
High Risk Customers = 
    CALCULATE(
        COUNTROWS(vw_customer_360),
        vw_customer_360[highest_risk_score] >= 80
    )

-- Revenue at Risk (claimed amount on fraud suspected claims)
Revenue at Risk EUR = 
    CALCULATE(
        SUM(claims[claim_amount]),
        claims[status] = "Fraud Suspected"
    )
```

---

## STEP 5: Build the 4-Page Report

### PAGE 1 — Executive KPI Dashboard

**Title:** Insurance Fraud Detection — Executive Overview

**Visuals to add:**

1. **Card visual** — Total Claims
   - Field: `[Total Claims]`
   - Format: no decimal places

2. **Card visual** — Total Claimed EUR
   - Field: `[Total Claimed EUR]`
   - Format: currency, 0 decimal, € prefix

3. **Card visual** — Fraud Rate %
   - Field: `[Fraud Rate %]`
   - Format: 1 decimal, % suffix
   - Conditional formatting: RED if > 20%, AMBER if 10–20%, GREEN if < 10%

4. **Card visual** — Revenue at Risk EUR
   - Field: `[Revenue at Risk EUR]`

5. **Clustered bar chart** — Claims by Policy Type
   - X-axis: `vw_executive_dashboard[policy_type]`
   - Y-axis: `vw_executive_dashboard[total_claims]`
   - Legend: none

6. **Stacked bar chart** — Payout vs Fraud by Policy Type
   - X-axis: `vw_executive_dashboard[policy_type]`
   - Y-axis 1: `vw_executive_dashboard[total_payout_eur]`
   - Y-axis 2: `vw_executive_dashboard[fraud_cases]`

7. **Donut chart** — Fraud Rate by Policy Type
   - Legend: `policy_type`
   - Values: `[Fraud Rate %]`

**Layout:** 2 rows. Row 1: 4 KPI cards. Row 2: 3 charts side by side.

---

### PAGE 2 — Fraud Investigation Queue

**Title:** Active Fraud Cases — Investigation Queue

**Visuals to add:**

1. **Table visual** — Full fraud queue
   - Columns: `claim_id`, `customer_name`, `policy_type`, `claim_amount`, `risk_score`, `flag_reason`, `days_open`, `assigned_adjuster`
   - Sort by: `risk_score` descending
   - Conditional formatting on `risk_score`: 
     - ≥ 85 → RED background
     - 70–84 → AMBER background
     - < 70 → no fill

2. **Gauge visual** — Average Risk Score
   - Value: `[Avg Risk Score]`
   - Min: 0, Max: 100
   - Target: 70
   - Color: red above target

3. **Card visual** — High Risk Customers
   - Field: `[High Risk Customers]`

4. **Slicer** — Review Outcome
   - Field: `vw_fraud_investigation_queue[review_outcome]`
   - Style: dropdown

5. **Slicer** — Policy Type
   - Field: `vw_fraud_investigation_queue[policy_type]`
   - Style: buttons

**Layout:** Slicers on top. Gauge + card on left. Table fills right 75% of page.

---

### PAGE 3 — Customer Risk Analysis

**Title:** Customer Risk Tier Breakdown

**Visuals to add:**

1. **Treemap** — Customers by Risk Tier
   - Group: `vw_customer_360[customer_risk_tier]`
   - Values: `vw_customer_360[lifetime_claimed_eur]`
   - Colors: CRITICAL = red, HIGH = orange, MEDIUM = yellow, LOW = green

2. **Scatter chart** — Claims vs Risk Score per Customer
   - X-axis: `vw_customer_360[total_claims]`
   - Y-axis: `vw_customer_360[highest_risk_score]`
   - Size: `vw_customer_360[lifetime_claimed_eur]`
   - Details: `vw_customer_360[full_name]`
   - Add trend line: ON

3. **Bar chart** — Top 10 Customers by Claimed Amount
   - Y-axis: `vw_customer_360[full_name]`
   - X-axis: `vw_customer_360[lifetime_claimed_eur]`
   - Filter: Top N = 10 by `lifetime_claimed_eur`

4. **Table** — Customer 360 detail
   - Columns: `full_name`, `city`, `total_policies`, `total_claims`, `lifetime_claimed_eur`, `fraud_flags_count`, `customer_risk_tier`

**Layout:** Treemap top-left. Scatter top-right. Bar chart bottom-left. Table bottom-right.

---

### PAGE 4 — Claims Trend Analysis

**Title:** Monthly Claims Trend & Rolling Average

**Visuals to add:**

1. **Line chart** — Monthly claim count + rolling 3-month avg
   - X-axis: Month (from `claims[claim_date]`, format YYYY-MM)
   - Y-axis 1: Count of `claim_id`
   - Y-axis 2 (secondary): Rolling 3M avg — create this measure:
     ```dax
     Rolling 3M Claims = 
         AVERAGEX(
             DATESINPERIOD(claims[claim_date], LASTDATE(claims[claim_date]), -3, MONTH),
             [Total Claims]
         )
     ```

2. **Area chart** — Claimed vs Approved over time
   - X-axis: `claims[claim_date]` (month)
   - Y-axis: `[Total Claimed EUR]` + `[Total Approved EUR]`
   - Transparency: 30% for area fill

3. **Clustered column chart** — Claims by Type per Month
   - X-axis: month
   - Legend: `claims[claim_type]`
   - Y-axis: count of claims

4. **Card** — Last month fraud count
   ```dax
   Last Month Fraud = 
       CALCULATE(
           [Fraud Cases],
           DATESMTD(EOMONTH(MAX(claims[claim_date]), -1))
       )
   ```

**Layout:** Two large charts stacked vertically on left 60%. Cards + column chart on right 40%.

---

## STEP 6: Formatting & Design

Apply these to all pages:

1. **Theme**: File → Options → Report Settings → Theme
   - Use "Executive" or "Slate" theme from Power BI gallery
   - Or set manually: primary color #1E3A5F (dark navy), accent #E63946 (fraud red)

2. **Report title** on each page:
   - Insert → Text Box
   - Font: Segoe UI, 18pt, bold, white text
   - Background rectangle: dark navy (#1E3A5F)

3. **Page navigation** (makes it feel like a real app):
   - Insert → Buttons → Navigator → Page Navigator
   - Place at top of every page

4. **Bookmark for "High Risk Only" filter** on Page 2:
   - Filter the table to risk_score ≥ 80
   - View → Bookmarks → Add
   - Name it "High Risk Cases"
   - Add a button on the page: "Show High Risk Only" → action = bookmark

---

## STEP 7: Take Screenshots for GitHub

Once built, screenshot each page:
1. Press `Windows + Shift + S` to screenshot each page
2. Save as: `screenshot_page1_kpi.png`, `screenshot_page2_fraud.png`, etc.
3. Put them in a `/screenshots` folder in your GitHub repo
4. Reference them in the README (see README template)

---

## STEP 8: Export for Portfolio

1. File → Export → Export to PDF → saves all 4 pages as a PDF
2. Name it: `Insurance_Fraud_Detection_PowerBI_Report.pdf`
3. Upload this PDF to your GitHub repo under `/report/`
4. Link it from your README

---

## CV Bullet (Power BI version)

```
Insurance Claims Fraud Detection System | MySQL 8.0 · Power BI
Built an end-to-end fraud analytics platform: normalized MySQL database with
RANGE partitioning, cursor-based stored procedure auto-flagging high-risk claims
via 3 business rules, window functions (LAG, RANK, NTILE) across 6 analytical
queries, and a 4-page Power BI report (executive KPIs, fraud queue, customer
risk tiers, monthly trend) connected via MySQL ODBC with 10 custom DAX measures.
```
