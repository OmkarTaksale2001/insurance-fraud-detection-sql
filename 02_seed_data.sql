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
