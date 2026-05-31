-- ============================================================
-- PROJECT 1: Advanced Analytics Queries
-- Demonstrates: CTEs, Window Functions, Subqueries, Aggregations
-- ============================================================
USE insurance_fraud_db;

-- ─────────────────────────────────────────────────────────────────
-- QUERY 1: Fraud Risk Leaderboard — top customers by total risk score
-- Window: RANK() OVER, running total with SUM() OVER
-- ─────────────────────────────────────────────────────────────────
WITH customer_risk AS (
    SELECT
        c.customer_id,
        c.full_name,
        c.city,
        COUNT(DISTINCT cl.claim_id)       AS total_claims,
        SUM(cl.claim_amount)              AS total_claimed,
        SUM(ff.risk_score)                AS total_risk_score,
        MAX(ff.risk_score)                AS max_single_risk
    FROM customers c
    JOIN policies   p  ON p.customer_id  = c.customer_id
    JOIN claims     cl ON cl.policy_id   = p.policy_id
    LEFT JOIN fraud_flags ff ON ff.claim_id = cl.claim_id
    GROUP BY c.customer_id, c.full_name, c.city
),
ranked AS (
    SELECT *,
        RANK() OVER (ORDER BY total_risk_score DESC)     AS risk_rank,
        SUM(total_claimed) OVER ()                       AS grand_total_claimed,
        ROUND(total_claimed / SUM(total_claimed) OVER () * 100, 2) AS pct_of_total
    FROM customer_risk
)
SELECT
    risk_rank,
    full_name,
    city,
    total_claims,
    ROUND(total_claimed, 2)   AS total_claimed_eur,
    ROUND(total_risk_score,2) AS total_risk_score,
    max_single_risk,
    pct_of_total
FROM ranked
ORDER BY risk_rank;


-- ─────────────────────────────────────────────────────────────────
-- QUERY 2: Claim Velocity — days between consecutive claims per policy
-- Window: LAG() OVER (PARTITION BY policy_id ORDER BY claim_date)
-- ─────────────────────────────────────────────────────────────────
SELECT
    cl.policy_id,
    p.policy_type,
    c.full_name,
    cl.claim_id,
    cl.claim_date,
    cl.claim_amount,
    cl.status,
    LAG(cl.claim_date) OVER (
        PARTITION BY cl.policy_id ORDER BY cl.claim_date
    )                                                           AS prev_claim_date,
    DATEDIFF(cl.claim_date,
        LAG(cl.claim_date) OVER (
            PARTITION BY cl.policy_id ORDER BY cl.claim_date
        )
    )                                                           AS days_since_last_claim,
    COUNT(cl.claim_id) OVER (PARTITION BY cl.policy_id)        AS total_claims_on_policy
FROM claims cl
JOIN policies  p ON p.policy_id   = cl.policy_id
JOIN customers c ON c.customer_id = p.customer_id
ORDER BY cl.policy_id, cl.claim_date;


-- ─────────────────────────────────────────────────────────────────
-- QUERY 3: Monthly Claim Trend with Rolling 3-Month Average
-- Window: AVG() OVER with ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
-- ─────────────────────────────────────────────────────────────────
WITH monthly AS (
    SELECT
        DATE_FORMAT(claim_date, '%Y-%m')   AS month,
        COUNT(*)                           AS claim_count,
        ROUND(SUM(claim_amount), 2)        AS total_amount,
        ROUND(AVG(claim_amount), 2)        AS avg_amount
    FROM claims
    GROUP BY DATE_FORMAT(claim_date, '%Y-%m')
)
SELECT
    month,
    claim_count,
    total_amount,
    avg_amount,
    ROUND(AVG(claim_count) OVER (
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1)                                  AS rolling_3m_claim_count,
    ROUND(AVG(total_amount) OVER (
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                  AS rolling_3m_total_eur
FROM monthly
ORDER BY month;


-- ─────────────────────────────────────────────────────────────────
-- QUERY 4: Policy-Level Claim-to-Coverage Ratio + Quartile Bucketing
-- Window: NTILE(4) — flags top 25% as high risk
-- ─────────────────────────────────────────────────────────────────
WITH policy_summary AS (
    SELECT
        p.policy_id,
        p.policy_type,
        p.coverage_amount,
        p.premium_amount,
        COUNT(cl.claim_id)         AS num_claims,
        COALESCE(SUM(cl.claim_amount), 0)  AS total_claimed,
        COALESCE(SUM(cl.approved_amount),0) AS total_approved
    FROM policies p
    LEFT JOIN claims cl ON cl.policy_id = p.policy_id
    GROUP BY p.policy_id, p.policy_type, p.coverage_amount, p.premium_amount
)
SELECT
    policy_id,
    policy_type,
    coverage_amount,
    premium_amount,
    num_claims,
    total_claimed,
    total_approved,
    ROUND(total_claimed / coverage_amount * 100, 2)     AS claim_to_coverage_pct,
    NTILE(4) OVER (ORDER BY total_claimed / coverage_amount DESC) AS risk_quartile,
    CASE
        WHEN NTILE(4) OVER (ORDER BY total_claimed / coverage_amount DESC) = 1
        THEN 'HIGH RISK'
        WHEN NTILE(4) OVER (ORDER BY total_claimed / coverage_amount DESC) = 2
        THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS risk_label
FROM policy_summary
ORDER BY claim_to_coverage_pct DESC;


-- ─────────────────────────────────────────────────────────────────
-- QUERY 5: Adjuster Workload & Approval Rate Performance
-- Window: DENSE_RANK() for adjuster performance ranking
-- ─────────────────────────────────────────────────────────────────
WITH adjuster_stats AS (
    SELECT
        a.adjuster_id,
        a.full_name                                             AS adjuster_name,
        a.specialization,
        COUNT(cl.claim_id)                                      AS cases_handled,
        SUM(CASE WHEN cl.status = 'Approved'         THEN 1 ELSE 0 END)  AS approved,
        SUM(CASE WHEN cl.status = 'Rejected'         THEN 1 ELSE 0 END)  AS rejected,
        SUM(CASE WHEN cl.status = 'Fraud Suspected'  THEN 1 ELSE 0 END)  AS fraud_flagged,
        ROUND(AVG(DATEDIFF(cl.resolution_date, cl.claim_date)), 1)        AS avg_resolution_days,
        ROUND(SUM(cl.approved_amount), 2)                                 AS total_approved_eur
    FROM adjusters a
    LEFT JOIN claims cl ON cl.adjuster_id = a.adjuster_id
    GROUP BY a.adjuster_id, a.full_name, a.specialization
)
SELECT *,
    ROUND(approved / NULLIF(cases_handled,0) * 100, 1)         AS approval_rate_pct,
    DENSE_RANK() OVER (ORDER BY total_approved_eur DESC)        AS payout_rank
FROM adjuster_stats
ORDER BY payout_rank;


-- ─────────────────────────────────────────────────────────────────
-- QUERY 6: Recursive CTE — Policy Chain per Customer
-- Shows all policy-claim chains for fraud pattern mapping
-- ─────────────────────────────────────────────────────────────────
WITH RECURSIVE policy_chain AS (
    -- Base: all active policies
    SELECT
        p.customer_id,
        p.policy_id,
        p.policy_type,
        p.start_date,
        1 AS depth,
        CAST(p.policy_id AS CHAR(500)) AS chain_path
    FROM policies p
    WHERE p.status = 'Active'

    UNION ALL

    -- Recursive: link claims to each policy
    SELECT
        pc.customer_id,
        cl.claim_id,
        pc.policy_type,
        cl.claim_date,
        pc.depth + 1,
        CONCAT(pc.chain_path, ' -> ', cl.claim_id)
    FROM policy_chain pc
    JOIN claims cl ON cl.policy_id = pc.policy_id
    WHERE pc.depth < 3
)
SELECT
    customer_id,
    policy_type,
    depth,
    chain_path
FROM policy_chain
ORDER BY customer_id, chain_path;
