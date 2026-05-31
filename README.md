# Insurance Claims Fraud Detection System
### MySQL 8.0 · Power BI · Advanced SQL

> **Author:** Omkar Taksale  
> **Stack:** MySQL 8.0, Power BI Desktop, MySQL ODBC Connector  
> **Domain:** Property & Casualty Insurance  
> **Status:** Complete — schema, data, analytics, automation, BI report

---

## The Problem

P&C insurers lose an estimated 5–10% of annual premium revenue to fraudulent claims. Manual review is slow, inconsistent, and reactive. This project builds a database-first fraud detection pipeline that automatically scores claims, flags high-risk cases, and surfaces findings through a 4-page Power BI dashboard.

---

## Architecture

\```
┌─────────────────────── MySQL 8.0 ─────────────────────────┐
│  DATA LAYER                                                │
│  customers → policies → claims (partitioned) → fraud_flags │
│                              ↓ trigger → audit_log (JSON) │
│  LOGIC LAYER                                               │
│  sp_auto_flag_fraud_claims  ← scheduled event (weekly)    │
│  sp_claims_summary_report   ← parameterized reporting     │
│  trg_claims_before_insert   ← reject expired policy       │
│  trg_claims_after_update    ← write JSON to audit_log     │
│  REPORTING LAYER (Views)                                   │
│  vw_executive_dashboard                                    │
│  vw_fraud_investigation_queue                              │
│  vw_customer_360                                           │
└────────────────────────────────────────────────────────────┘
              │ MySQL ODBC Connector
              ↓
┌───────────── Power BI Desktop ─────────────────────────────┐
│  Page 1: Executive KPIs (cards, bar, donut)                │
│  Page 2: Fraud Investigation Queue (table, gauge, slicer)  │
│  Page 3: Customer Risk Tiers (treemap, scatter)            │
│  Page 4: Claims Trend (line + rolling 3M avg, area chart)  │
└────────────────────────────────────────────────────────────┘
\```

---

## Database Schema

| Table | Rows | Key Features |
|-------|------|--------------|
| `customers` | 15 | Indexed by city + state |
| `policies` | 15 | Type + status composite index |
| `claims` | 20 | RANGE partitioned by year |
| `fraud_flags` | 7 | Risk score 0–100 · review outcome |
| `adjusters` | 5 | Region + specialization |
| `audit_log` | dynamic | JSON old/new values · immutable |

---

## SQL Concepts Demonstrated

| Query | Technique |
|-------|-----------|
| Fraud Risk Leaderboard | `RANK() OVER`, `SUM() OVER`, percentage of total |
| Claim Velocity Detection | `LAG() OVER PARTITION BY policy_id` |
| Monthly Trend + Rolling Avg | `AVG() OVER ROWS BETWEEN 2 PRECEDING AND CURRENT` |
| Policy Risk Quartiles | `NTILE(4) OVER`, claim-to-coverage ratio |
| Adjuster Performance | `DENSE_RANK()`, approval rate, avg resolution days |
| Policy Chain Mapping | Recursive CTE, depth-limited traversal |

### Automation
- `sp_auto_flag_fraud_claims` — cursor, 3 business rules, ROLLBACK on error
- `sp_claims_summary_report` — parameterized by date range + policy type
- `trg_claims_before_insert` — rejects claims on expired policies
- `trg_claims_after_update` — writes JSON_OBJECT to audit_log
- `evt_weekly_fraud_check` — runs every Sunday at 02:00

---

## Key Business Metrics

| Metric | Value |
|--------|-------|
| Total claims | 20 |
| Fraud suspected | 7 (35%) |
| Confirmed fraud | 3 |
| Highest risk score | 91.0 |
| Policy types | Auto, Home, Health, Life |
| Date range | 2022 – 2024 |

---

## How to Run

```sql
source 01_schema.sql
source 02_seed_data.sql
source 03_analytics_queries.sql
source 04_procedures_triggers.sql
source 05_views_indexes.sql

CALL sp_claims_summary_report('2023-01-01', '2024-12-31', 'Auto');
SELECT * FROM vw_fraud_investigation_queue;
```

For Power BI setup follow `06_powerbi_guide.md`.
