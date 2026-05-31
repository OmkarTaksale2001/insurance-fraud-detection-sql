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
