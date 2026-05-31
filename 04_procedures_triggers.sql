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
