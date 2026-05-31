-- ============================================================
-- PROJECT 1: Insurance Claims Fraud Detection System
-- Database: MySQL 8.0+
-- Author: Omkar Taksale
-- Description: End-to-end fraud analytics pipeline for P&C insurance
-- ============================================================

CREATE DATABASE IF NOT EXISTS insurance_fraud_db;
USE insurance_fraud_db;

-- ─────────────────────────────────────────────
-- TABLE 1: customers
-- ─────────────────────────────────────────────
CREATE TABLE customers (
    customer_id     INT AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(100)        NOT NULL,
    dob             DATE                NOT NULL,
    gender          ENUM('M','F','Other'),
    city            VARCHAR(80),
    state           VARCHAR(50),
    email           VARCHAR(120)        UNIQUE,
    phone           VARCHAR(20),
    created_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_city_state (city, state)
);

-- ─────────────────────────────────────────────
-- TABLE 2: policies
-- ─────────────────────────────────────────────
CREATE TABLE policies (
    policy_id       INT AUTO_INCREMENT PRIMARY KEY,
    customer_id     INT                 NOT NULL,
    policy_type     ENUM('Auto','Home','Health','Life') NOT NULL,
    start_date      DATE                NOT NULL,
    end_date        DATE                NOT NULL,
    premium_amount  DECIMAL(10,2)       NOT NULL,
    coverage_amount DECIMAL(12,2)       NOT NULL,
    status          ENUM('Active','Expired','Cancelled') DEFAULT 'Active',
    created_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_policy_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id) ON DELETE RESTRICT,
    INDEX idx_policy_customer (customer_id),
    INDEX idx_policy_type_status (policy_type, status)
);

-- ─────────────────────────────────────────────
-- TABLE 3: adjusters
-- ─────────────────────────────────────────────
CREATE TABLE adjusters (
    adjuster_id     INT AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(100)        NOT NULL,
    region          VARCHAR(50),
    specialization  ENUM('Auto','Home','Health','Life','General'),
    hire_date       DATE,
    is_active       TINYINT(1)          DEFAULT 1
);

-- ─────────────────────────────────────────────
-- TABLE 4: claims  (PARTITIONED by year)
-- ─────────────────────────────────────────────
CREATE TABLE claims (
    claim_id        INT                 NOT NULL,
    policy_id       INT                 NOT NULL,
    adjuster_id     INT,
    incident_date   DATE                NOT NULL,
    claim_date      DATE                NOT NULL,
    claim_amount    DECIMAL(12,2)       NOT NULL,
    approved_amount DECIMAL(12,2)       DEFAULT 0,
    claim_type      ENUM('Theft','Accident','Medical','Natural Disaster','Fire','Other') NOT NULL,
    description     TEXT,
    status          ENUM('Pending','Under Review','Approved','Rejected','Fraud Suspected') DEFAULT 'Pending',
    resolution_date DATE,
    PRIMARY KEY (claim_id, claim_date),
    CONSTRAINT fk_claim_policy   FOREIGN KEY (policy_id)   REFERENCES policies(policy_id),
    CONSTRAINT fk_claim_adjuster FOREIGN KEY (adjuster_id) REFERENCES adjusters(adjuster_id),
    INDEX idx_claim_policy   (policy_id),
    INDEX idx_claim_adjuster (adjuster_id),
    INDEX idx_claim_status   (status),
    INDEX idx_incident_date  (incident_date)
)
PARTITION BY RANGE (YEAR(claim_date)) (
    PARTITION p2021 VALUES LESS THAN (2022),
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION pFuture VALUES LESS THAN MAXVALUE
);

-- ─────────────────────────────────────────────
-- TABLE 5: fraud_flags
-- ─────────────────────────────────────────────
CREATE TABLE fraud_flags (
    flag_id         INT AUTO_INCREMENT PRIMARY KEY,
    claim_id        INT                 NOT NULL,
    flag_reason     VARCHAR(255),
    risk_score      DECIMAL(5,2),           -- 0 to 100
    flagged_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    reviewed_by     INT,                    -- adjuster_id
    review_outcome  ENUM('Confirmed Fraud','False Positive','Under Review') DEFAULT 'Under Review',
    INDEX idx_fraud_claim (claim_id),
    INDEX idx_risk_score  (risk_score)
);

-- ─────────────────────────────────────────────
-- TABLE 6: audit_log  (immutable change tracking)
-- ─────────────────────────────────────────────
CREATE TABLE audit_log (
    log_id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name      VARCHAR(50),
    record_id       INT,
    action          ENUM('INSERT','UPDATE','DELETE'),
    old_value       JSON,
    new_value       JSON,
    changed_by      VARCHAR(100)        DEFAULT 'SYSTEM',
    changed_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_table_record (table_name, record_id),
    INDEX idx_audit_time (changed_at)
);
-- ============================================================
-- PROJECT 1: Seed Data — Realistic Insurance Dataset
-- ============================================================
USE insurance_fraud_db;

-- ─── Customers ───────────────────────────────
INSERT INTO customers (full_name, dob, gender, city, state, email, phone) VALUES
('Anna Müller',       '1985-03-12', 'F', 'Munich',    'Bavaria',          'anna.mueller@email.de',     '+49-89-1001'),
('Thomas Braun',      '1979-07-04', 'M', 'Hamburg',   'Hamburg',          'thomas.braun@email.de',     '+49-40-1002'),
('Lena Fischer',      '1992-11-21', 'F', 'Berlin',    'Berlin',           'lena.fischer@email.de',     '+49-30-1003'),
('Klaus Weber',       '1968-05-30', 'M', 'Frankfurt', 'Hesse',            'k.weber@email.de',          '+49-69-1004'),
('Maria Schmidt',     '1995-08-14', 'F', 'Stuttgart', 'Baden-Württemberg','m.schmidt@email.de',        '+49-711-1005'),
('Peter Schulz',      '1983-01-09', 'M', 'Cologne',   'NRW',              'p.schulz@email.de',         '+49-221-1006'),
('Sandra Hoffmann',   '1990-06-17', 'F', 'Düsseldorf','NRW',              's.hoffmann@email.de',       '+49-211-1007'),
('Markus König',      '1975-12-03', 'M', 'Leipzig',   'Saxony',           'm.koenig@email.de',         '+49-341-1008'),
('Julia Bauer',       '1998-04-22', 'F', 'Nuremberg', 'Bavaria',          'j.bauer@email.de',          '+49-911-1009'),
('Stefan Lange',      '1987-09-11', 'M', 'Dresden',   'Saxony',           's.lange@email.de',          '+49-351-1010'),
('Franziska Richter', '1993-02-28', 'F', 'Hannover',  'Lower Saxony',     'f.richter@email.de',        '+49-511-1011'),
('Bernd Wolf',        '1965-10-05', 'M', 'Dortmund',  'NRW',              'b.wolf@email.de',           '+49-231-1012'),
('Katja Neumann',     '1980-07-19', 'F', 'Essen',     'NRW',              'k.neumann@email.de',        '+49-201-1013'),
('Dieter Schwarz',    '1970-03-25', 'M', 'Bremen',    'Bremen',           'd.schwarz@email.de',        '+49-421-1014'),
('Sabine Zimmermann', '1988-12-31', 'F', 'Bochum',    'NRW',              's.zimmermann@email.de',     '+49-234-1015');

-- ─── Adjusters ───────────────────────────────
INSERT INTO adjusters (full_name, region, specialization, hire_date) VALUES
('Heinrich Vogel',  'Bavaria',          'Auto',    '2018-03-01'),
('Greta Winkler',   'Hamburg',          'Home',    '2020-06-15'),
('Rolf Krause',     'Berlin',           'Health',  '2017-01-10'),
('Ute Hartmann',    'Hesse',            'Life',    '2019-09-20'),
('Frank Meyer',     'Baden-Württemberg','General', '2021-04-05');

-- ─── Policies ────────────────────────────────
INSERT INTO policies (customer_id, policy_type, start_date, end_date, premium_amount, coverage_amount, status) VALUES
(1,  'Auto',   '2022-01-01','2024-12-31', 850.00,  25000.00, 'Active'),
(2,  'Home',   '2021-06-01','2023-05-31', 1200.00, 150000.00,'Expired'),
(3,  'Health', '2023-01-01','2025-12-31', 620.00,  50000.00, 'Active'),
(4,  'Auto',   '2022-03-15','2024-03-14', 950.00,  30000.00, 'Active'),
(5,  'Life',   '2020-07-01','2030-06-30', 1500.00, 200000.00,'Active'),
(6,  'Home',   '2023-02-01','2026-01-31', 980.00,  120000.00,'Active'),
(7,  'Auto',   '2022-09-01','2024-08-31', 780.00,  22000.00, 'Active'),
(8,  'Health', '2021-11-01','2024-10-31', 540.00,  45000.00, 'Active'),
(9,  'Auto',   '2023-05-01','2025-04-30', 870.00,  28000.00, 'Active'),
(10, 'Home',   '2022-08-01','2025-07-31', 1100.00, 135000.00,'Active'),
(3,  'Auto',   '2021-01-01','2022-12-31', 800.00,  20000.00, 'Expired'), -- customer 3 has 2 policies
(4,  'Home',   '2023-06-01','2026-05-31', 1300.00, 160000.00,'Active'),
(1,  'Health', '2023-03-01','2026-02-28', 590.00,  40000.00, 'Active'),  -- customer 1 has 2 policies
(11, 'Auto',   '2022-10-01','2024-09-30', 810.00,  24000.00, 'Active'),
(12, 'Life',   '2019-04-01','2029-03-31', 1800.00, 250000.00,'Active');

-- ─── Claims ──────────────────────────────────
INSERT INTO claims (claim_id, policy_id, adjuster_id, incident_date, claim_date, claim_amount, approved_amount, claim_type, status, resolution_date) VALUES
-- 2022 partition
(1,  1,  1, '2022-03-10','2022-03-12', 4500.00, 4200.00, 'Accident',          'Approved',         '2022-04-01'),
(2,  2,  2, '2022-07-05','2022-07-08', 15000.00,13000.00,'Fire',              'Approved',         '2022-08-15'),
(3,  4,  1, '2022-11-20','2022-11-22', 3200.00, 3200.00, 'Theft',             'Approved',         '2022-12-10'),
(4,  7,  1, '2022-06-14','2022-06-16', 8900.00, 0.00,    'Accident',          'Fraud Suspected',  NULL),
(5,  8,  3, '2022-09-01','2022-09-03', 6000.00, 5500.00, 'Medical',           'Approved',         '2022-10-01'),

-- 2023 partition
(6,  1,  1, '2023-01-15','2023-01-18', 5200.00, 0.00,    'Theft',             'Fraud Suspected',  NULL),  -- same policy 2nd claim fast
(7,  3,  3, '2023-04-11','2023-04-13', 3100.00, 3100.00, 'Medical',           'Approved',         '2023-05-01'),
(8,  6,  2, '2023-06-22','2023-06-25', 22000.00,18000.00,'Natural Disaster',  'Approved',         '2023-08-01'),
(9,  9,  1, '2023-08-03','2023-08-05', 11000.00,0.00,    'Accident',          'Fraud Suspected',  NULL),
(10, 10, 2, '2023-09-17','2023-09-20', 7500.00, 7000.00, 'Fire',              'Approved',         '2023-10-30'),
(11, 11, 1, '2023-02-28','2023-03-02', 4800.00, 4800.00, 'Accident',          'Approved',         '2023-03-25'),
(12, 4,  1, '2023-05-10','2023-05-12', 9500.00, 0.00,    'Theft',             'Fraud Suspected',  NULL),  -- policy 4 second claim
(13, 5,  4, '2023-07-07','2023-07-09', 45000.00,0.00,    'Other',             'Rejected',         '2023-09-01'),
(14, 12, 2, '2023-11-01','2023-11-04', 18000.00,15000.00,'Natural Disaster',  'Approved',         '2024-01-05'),

-- 2024 partition
(15, 1,  1, '2024-02-14','2024-02-16', 6100.00, 0.00,    'Accident',          'Fraud Suspected',  NULL),  -- policy 1 third claim
(16, 13, 3, '2024-01-20','2024-01-22', 2800.00, 2800.00, 'Medical',           'Approved',         '2024-02-10'),
(17, 14, 1, '2024-03-05','2024-03-07', 5600.00, 5600.00, 'Accident',          'Approved',         '2024-04-01'),
(18, 9,  1, '2024-04-19','2024-04-22', 13000.00,0.00,    'Theft',             'Fraud Suspected',  NULL),  -- policy 9 second claim
(19, 15, 4, '2024-06-01','2024-06-03', 9000.00, 8500.00, 'Medical',           'Approved',         '2024-07-01'),
(20, 6,  2, '2024-07-12','2024-07-15', 25000.00,0.00,    'Fire',              'Fraud Suspected',  NULL);  -- policy 6 second large claim

-- ─── Fraud Flags ─────────────────────────────
INSERT INTO fraud_flags (claim_id, flag_reason, risk_score, reviewed_by, review_outcome) VALUES
(4,  'Claim amount 30% above coverage average; no police report attached',  72.5, 1, 'Confirmed Fraud'),
(6,  'Second claim on same policy within 60 days; inconsistent dates',      85.0, 1, 'Confirmed Fraud'),
(9,  'Claim filed 2 days after policy near-expiry; high amount',            78.0, 1, 'Under Review'),
(12, 'Third claim on policy in 18 months; amount spike 200%',               91.0, 1, 'Confirmed Fraud'),
(15, 'Policy 1: fourth incident flagged; short resolution gap',             88.5, 1, 'Under Review'),
(18, 'Repeat claimant pattern; same claim_type as previous',                76.0, 1, 'Under Review'),
(20, 'Claim amount exceeds 20% of coverage; second large claim in 12 months',82.0,2,'Under Review');
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
-- ============================================================
-- PROJECT 1: Stored Procedures, Triggers & Scheduled Events
-- ============================================================
USE insurance_fraud_db;

DELIMITER $$

-- ─────────────────────────────────────────────────────────────────
-- STORED PROCEDURE 1: Auto-flag high-risk claims
-- Logic: flags any claim > 70% of coverage OR 3rd+ claim on same policy
-- ─────────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_auto_flag_fraud_claims()
BEGIN
    DECLARE v_claim_id      INT;
    DECLARE v_policy_id     INT;
    DECLARE v_claim_amount  DECIMAL(12,2);
    DECLARE v_coverage      DECIMAL(12,2);
    DECLARE v_claim_count   INT;
    DECLARE v_risk_score    DECIMAL(5,2);
    DECLARE v_reason        VARCHAR(255);
    DECLARE done            INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT
            cl.claim_id,
            cl.policy_id,
            cl.claim_amount,
            p.coverage_amount,
            COUNT(cl2.claim_id) AS claim_count
        FROM claims cl
        JOIN policies p ON p.policy_id = cl.policy_id
        JOIN claims cl2 ON cl2.policy_id = cl.policy_id
        WHERE cl.status NOT IN ('Approved','Rejected','Fraud Suspected')
        GROUP BY cl.claim_id, cl.policy_id, cl.claim_amount, p.coverage_amount;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_claim_id, v_policy_id, v_claim_amount, v_coverage, v_claim_count;
        IF done THEN LEAVE read_loop; END IF;

        SET v_risk_score = 0;
        SET v_reason     = '';

        -- Rule 1: Claim > 70% of total coverage
        IF v_claim_amount > (v_coverage * 0.70) THEN
            SET v_risk_score = v_risk_score + 40;
            SET v_reason     = CONCAT(v_reason, 'Claim >70% of coverage; ');
        END IF;

        -- Rule 2: 3rd+ claim on same policy
        IF v_claim_count >= 3 THEN
            SET v_risk_score = v_risk_score + 35;
            SET v_reason     = CONCAT(v_reason, 'Policy has 3+ claims; ');
        END IF;

        -- Rule 3: Claim filed within 30 days of policy start
        IF (SELECT DATEDIFF(claim_date, (SELECT start_date FROM policies WHERE policy_id = v_policy_id))
            FROM claims WHERE claim_id = v_claim_id) < 30 THEN
            SET v_risk_score = v_risk_score + 25;
            SET v_reason     = CONCAT(v_reason, 'Claim <30 days after policy start; ');
        END IF;

        -- Insert fraud flag if score > 50
        IF v_risk_score > 50 THEN
            INSERT IGNORE INTO fraud_flags (claim_id, flag_reason, risk_score)
            VALUES (v_claim_id, TRIM(TRAILING '; ' FROM v_reason), v_risk_score);

            UPDATE claims
            SET status = 'Fraud Suspected'
            WHERE claim_id = v_claim_id;
        END IF;

    END LOOP;

    CLOSE cur;
    COMMIT;

    SELECT CONCAT('Fraud flagging complete. Timestamp: ', NOW()) AS result;
END$$


-- ─────────────────────────────────────────────────────────────────
-- STORED PROCEDURE 2: Claims Summary Report by Policy Type & Period
-- ─────────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_claims_summary_report(
    IN p_start_date DATE,
    IN p_end_date   DATE,
    IN p_policy_type VARCHAR(20)  -- pass NULL for all types
)
BEGIN
    IF p_policy_type IS NOT NULL AND p_policy_type NOT IN ('Auto','Home','Health','Life') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid policy_type. Use: Auto, Home, Health, Life, or NULL';
    END IF;

    SELECT
        p.policy_type,
        cl.claim_type,
        COUNT(cl.claim_id)                                AS total_claims,
        ROUND(SUM(cl.claim_amount), 2)                    AS total_claimed_eur,
        ROUND(SUM(cl.approved_amount), 2)                 AS total_approved_eur,
        ROUND(AVG(cl.claim_amount), 2)                    AS avg_claim_eur,
        SUM(CASE WHEN cl.status='Fraud Suspected' THEN 1 ELSE 0 END) AS fraud_count,
        ROUND(
            SUM(CASE WHEN cl.status='Fraud Suspected' THEN 1 ELSE 0 END)
            / COUNT(cl.claim_id) * 100, 2
        )                                                 AS fraud_rate_pct
    FROM claims cl
    JOIN policies p ON p.policy_id = cl.policy_id
    WHERE cl.claim_date BETWEEN p_start_date AND p_end_date
      AND (p_policy_type IS NULL OR p.policy_type = p_policy_type)
    GROUP BY p.policy_type, cl.claim_type
    ORDER BY p.policy_type, total_claimed_eur DESC;
END$$


-- ─────────────────────────────────────────────────────────────────
-- TRIGGER 1: After claims status changes — write to audit_log
-- ─────────────────────────────────────────────────────────────────
CREATE TRIGGER trg_claims_after_update
AFTER UPDATE ON claims
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO audit_log (table_name, record_id, action, old_value, new_value)
        VALUES (
            'claims',
            NEW.claim_id,
            'UPDATE',
            JSON_OBJECT(
                'status',          OLD.status,
                'approved_amount', OLD.approved_amount
            ),
            JSON_OBJECT(
                'status',          NEW.status,
                'approved_amount', NEW.approved_amount,
                'resolution_date', NEW.resolution_date
            )
        );
    END IF;
END$$


-- ─────────────────────────────────────────────────────────────────
-- TRIGGER 2: Before new claim insert — reject if policy is expired
-- ─────────────────────────────────────────────────────────────────
CREATE TRIGGER trg_claims_before_insert
BEFORE INSERT ON claims
FOR EACH ROW
BEGIN
    DECLARE v_policy_status VARCHAR(20);
    SELECT status INTO v_policy_status
    FROM policies
    WHERE policy_id = NEW.policy_id;

    IF v_policy_status = 'Expired' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot file claim on an expired policy.';
    END IF;

    IF v_policy_status = 'Cancelled' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot file claim on a cancelled policy.';
    END IF;
END$$


-- ─────────────────────────────────────────────────────────────────
-- SCHEDULED EVENT: Run fraud flagging procedure every Sunday at 2AM
-- (requires event_scheduler=ON in MySQL config)
-- ─────────────────────────────────────────────────────────────────
CREATE EVENT IF NOT EXISTS evt_weekly_fraud_check
ON SCHEDULE EVERY 1 WEEK
STARTS '2024-01-07 02:00:00'
DO
    CALL sp_auto_flag_fraud_claims();$$

DELIMITER ;

-- ─────────────────────────────────────────────────────────────────
-- Test stored procedures:
-- ─────────────────────────────────────────────────────────────────
-- CALL sp_auto_flag_fraud_claims();
-- CALL sp_claims_summary_report('2023-01-01', '2024-12-31', 'Auto');
-- CALL sp_claims_summary_report('2022-01-01', '2024-12-31', NULL);
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
