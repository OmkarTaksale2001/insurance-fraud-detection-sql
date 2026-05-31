-- ============================================================
-- PROJECT 1: Views (BI Reporting Layer) + Index Strategy
-- ============================================================
USE insurance_fraud_db;

-- ─────────────────────────────────────────────────────────────────
-- VIEW 1: Executive Dashboard — high-level KPIs
-- ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_executive_dashboard AS
SELECT
    p.policy_type,
    COUNT(DISTINCT p.policy_id)                                   AS active_policies,
    COUNT(DISTINCT cl.claim_id)                                   AS total_claims,
    ROUND(SUM(cl.claim_amount), 2)                                AS total_claimed_eur,
    ROUND(SUM(cl.approved_amount), 2)                             AS total_payout_eur,
    ROUND(SUM(cl.approved_amount) / NULLIF(SUM(cl.claim_amount),0) * 100, 2) AS payout_ratio_pct,
    SUM(CASE WHEN cl.status = 'Fraud Suspected' THEN 1 ELSE 0 END) AS fraud_cases,
    ROUND(
        SUM(CASE WHEN cl.status = 'Fraud Suspected' THEN 1 ELSE 0 END)
        / COUNT(DISTINCT cl.claim_id) * 100, 2
    )                                                             AS fraud_rate_pct,
    ROUND(SUM(p.premium_amount), 2)                               AS total_premiums_eur
FROM policies p
LEFT JOIN claims cl ON cl.policy_id = p.policy_id
WHERE p.status = 'Active'
GROUP BY p.policy_type;


-- ─────────────────────────────────────────────────────────────────
-- VIEW 2: Fraud Investigation Queue — all suspected claims with context
-- ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_fraud_investigation_queue AS
SELECT
    cl.claim_id,
    c.full_name                    AS customer_name,
    c.city,
    p.policy_type,
    p.coverage_amount,
    cl.claim_type,
    cl.claim_date,
    cl.claim_amount,
    ff.risk_score,
    ff.flag_reason,
    ff.review_outcome,
    a.full_name                    AS assigned_adjuster,
    DATEDIFF(CURDATE(), cl.claim_date) AS days_open
FROM claims cl
JOIN policies     p  ON p.policy_id    = cl.policy_id
JOIN customers    c  ON c.customer_id  = p.customer_id
LEFT JOIN fraud_flags ff ON ff.claim_id = cl.claim_id
LEFT JOIN adjusters   a  ON a.adjuster_id = cl.adjuster_id
WHERE cl.status = 'Fraud Suspected'
ORDER BY ff.risk_score DESC;


-- ─────────────────────────────────────────────────────────────────
-- VIEW 3: Customer 360 — full claim history per customer
-- ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_customer_360 AS
SELECT
    c.customer_id,
    c.full_name,
    c.city,
    c.state,
    COUNT(DISTINCT p.policy_id)        AS total_policies,
    COUNT(DISTINCT cl.claim_id)        AS total_claims,
    ROUND(SUM(cl.claim_amount), 2)     AS lifetime_claimed_eur,
    ROUND(SUM(cl.approved_amount), 2)  AS lifetime_approved_eur,
    ROUND(SUM(p.premium_amount), 2)    AS lifetime_premiums_eur,
    MAX(ff.risk_score)                 AS highest_risk_score,
    SUM(CASE WHEN cl.status='Fraud Suspected' THEN 1 ELSE 0 END) AS fraud_flags_count,
    CASE
        WHEN MAX(ff.risk_score) >= 85 THEN 'CRITICAL'
        WHEN MAX(ff.risk_score) >= 65 THEN 'HIGH'
        WHEN MAX(ff.risk_score) >= 40 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                AS customer_risk_tier
FROM customers c
LEFT JOIN policies   p  ON p.customer_id  = c.customer_id
LEFT JOIN claims     cl ON cl.policy_id   = p.policy_id
LEFT JOIN fraud_flags ff ON ff.claim_id   = cl.claim_id
GROUP BY c.customer_id, c.full_name, c.city, c.state;


-- ─────────────────────────────────────────────────────────────────
-- COVERING INDEXES — optimised for the most frequent query patterns
-- ─────────────────────────────────────────────────────────────────

-- Fast lookup: claims by status + date range (used in fraud queue)
CREATE INDEX idx_claims_status_date
    ON claims (status, claim_date, claim_amount);

-- Fast lookup: fraud flags sorted by risk score descending
CREATE INDEX idx_ff_risk_outcome
    ON fraud_flags (risk_score DESC, review_outcome);

-- Fast lookup: policies by customer + type + status
CREATE INDEX idx_policies_customer_type
    ON policies (customer_id, policy_type, status);

-- Fast lookup: audit log for a specific table+record
CREATE INDEX idx_audit_full
    ON audit_log (table_name, record_id, changed_at);
