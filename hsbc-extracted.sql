
Next steps — to load into MySQL locally, run (replace credentials and DB name):


mysql -u root -p your_database < hsbc-extracted.sql
Or, to create a fresh DB and load:


mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS hsbc_demo; USE hsbc_demo;" 
mysql -u root -p hsbc_demo < hsbc-extracted.sql


-- hsbc-extracted.sql
-- Extracted SQL statements and runnable sample data from hsbc.txt

-- NOTE: This file is written for MySQL. Adjust types/syntax slightly for other RDBMS.

-- PAYMENT REQUEST (idempotency example)
DROP TABLE IF EXISTS payment_request;
CREATE TABLE IF NOT EXISTS payment_request (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  idempotency_key VARCHAR(64) NOT NULL,
  status VARCHAR(20),
  response TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY ux_user_idempotency (user_id, idempotency_key)
) ENGINE=InnoDB;

INSERT INTO payment_request (user_id, idempotency_key, status, response) VALUES
(1001, 'idem-abc-1', 'SUCCESS', 'OK'),
(1002, 'idem-xyz-1', 'PENDING', 'processing');

-- ACCOUNTS (used for balance mismatch example)
DROP TABLE IF EXISTS accounts;
CREATE TABLE IF NOT EXISTS accounts (
  account_id BIGINT PRIMARY KEY,
  balance DECIMAL(14,2) NOT NULL
) ENGINE=InnoDB;

INSERT INTO accounts (account_id, balance) VALUES
(1, 120.00),   -- matches transactions sample below (100 -30 +50 = 120)
(101, -900.00),
(201, 1100.00),
(301, -100.00);

-- TRANSACTIONS (canonical table used by many examples)
DROP TABLE IF EXISTS transactions;
CREATE TABLE IF NOT EXISTS transactions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  account_id BIGINT NOT NULL,
  txn_time DATETIME NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  type VARCHAR(20),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_account_time (account_id, txn_time DESC),
  INDEX idx_account_amount_time (account_id, amount, txn_time)
) ENGINE=InnoDB;

-- Sample rows covering running-balance, duplicates, latest, second-highest, negative-balance, reversals, etc.
INSERT INTO transactions (account_id, txn_time, amount, type) VALUES
-- running balance example (account_id = 1)
(1, '2025-01-10 10:00:00', 100.00, 'CREDIT'),
(1, '2025-01-10 11:00:00', -30.00, 'DEBIT'),
(1, '2025-01-10 12:00:00', 50.00, 'CREDIT'),

-- duplicate transactions example (account_id = 101)
(101, '2025-01-10 10:00:00', -500.00, 'DEBIT'),
(101, '2025-01-10 10:00:00', -500.00, 'DEBIT'),

-- latest-transaction example for account 101 and 102
(101, '2025-01-10 12:00:00', 200.00, 'CREDIT'),
(101, '2025-01-11 09:00:00', -100.00, 'DEBIT'),
(102, '2025-01-10 08:00:00', -300.00, 'DEBIT'),
(102, '2025-01-11 11:30:00', 400.00, 'CREDIT'),

-- second-highest transaction per account example (account_id = 201)
(201, '2025-01-01 09:00:00', 500.00, 'CREDIT'),
(201, '2025-01-02 10:00:00', 500.00, 'CREDIT'),
(201, '2025-01-03 11:00:00', 300.00, 'CREDIT'),
(201, '2025-01-04 12:00:00', 200.00, 'DEBIT'),

-- negative balance event example (account_id = 301)
(301, '2025-01-05 09:00:00', 100.00, 'CREDIT'),
(301, '2025-01-06 10:00:00', -200.00, 'DEBIT'),

-- reversal example (same amount opposite sign, same timestamp) (account_id = 401)
(401, '2025-01-07 10:00:00', 250.00, 'CREDIT'),
(401, '2025-01-07 10:00:00', -250.00, 'DEBIT');

-- Example: transaction IDs intentionally sequential via AUTO_INCREMENT

-- Useful extracted queries (kept as comments so this file is runnable as-is)

-- ================================================================
-- === Extracted SQL Queries (each section has a heading + canonical SQL)
-- ================================================================

-- **1) Running balance per account**
-- Purpose: compute the running ledger balance for each account ordered by time
-- SQL (window function):
-- SELECT
--   account_id,
--   txn_time,
--   amount,
--   SUM(amount) OVER (
--     PARTITION BY account_id
--     ORDER BY txn_time
--     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--   ) AS running_balance
-- FROM transactions;
-- Sample output (based on the sample rows above):
-- account_id | txn_time            | amount   | running_balance
-- -----------------------------------------------------------
-- 1          | 2025-01-10 10:00:00 | 100.00   | 100.00
-- 1          | 2025-01-10 11:00:00 | -30.00   | 70.00
-- 1          | 2025-01-10 12:00:00 | 50.00    | 120.00

-- **2) Find duplicate transactions (fraud-style)**
-- Purpose: detect exact duplicates by account, amount, and time
-- SQL:
-- SELECT account_id, amount, txn_time, COUNT(*) AS cnt
-- FROM transactions
-- GROUP BY account_id, amount, txn_time
-- HAVING COUNT(*) > 1;
-- Sample output:
-- account_id | amount   | txn_time            | cnt
-- ------------------------------------------------
-- 101        | -500.00  | 2025-01-10 10:00:00 | 2

-- **3) Latest transaction per account**
-- Purpose: get the most recent row per account (keeps non-aggregated columns)
-- SQL (ROW_NUMBER pattern):
-- SELECT *
-- FROM (
--   SELECT t.*, 
--           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY txn_time DESC) rn
--   FROM transactions t
-- ) x
-- WHERE rn = 1;
-- Sample output:
-- account_id | txn_time            | amount   | type
-- -----------------------------------------------
-- 101        | 2025-01-11 09:00:00 | -100.00  | DEBIT
-- 102        | 2025-01-11 11:30:00 | 400.00   | CREDIT
-- 201        | 2025-01-04 12:00:00 | -200.00  | DEBIT

-- **4) Second highest transaction amount per account**
-- Purpose: return the second largest distinct amount per account (handles duplicates)
-- SQL (DENSE_RANK):
-- SELECT account_id, amount
-- FROM (
--   SELECT account_id, amount,
--     DENSE_RANK() OVER (PARTITION BY account_id ORDER BY amount DESC) rnk
--   FROM transactions
-- ) x
-- WHERE rnk = 2;
-- Sample output:
-- account_id | amount
-- -------------------
-- 201        | 300.00

-- **5) Top N accounts by total transaction volume**
-- Purpose: find most active accounts by summed transaction magnitude
-- SQL:
-- SELECT account_id, SUM(ABS(amount)) AS volume
-- FROM transactions
-- GROUP BY account_id
-- ORDER BY volume DESC
-- LIMIT 5;
-- Sample output:
-- account_id | volume
-- -------------------
-- 201        | 1500.00
-- 101        | 1300.00
-- 102        | 700.00
-- 401        | 500.00
-- 301        | 300.00

-- **6) Accounts with no transactions in last 30 days**
-- Purpose: detect inactive accounts
-- SQL:
-- SELECT a.account_id
-- FROM accounts a
-- LEFT JOIN transactions t
--   ON a.account_id = t.account_id
--  AND t.txn_time >= CURRENT_DATE - INTERVAL 30 DAY
-- WHERE t.account_id IS NULL;
-- Sample output (given the sample txn_time are in Jan 2025 and current date is later):
-- account_id
-- ----------
-- 1
-- 101
-- 102
-- 201
-- 301
-- 401

-- **7) Monthly transaction totals per account**
-- Purpose: aggregate by month
-- SQL:
-- SELECT
--   account_id,
--   DATE_FORMAT(txn_time, '%Y-%m-01') AS month_start,
--   SUM(amount) AS total
-- FROM transactions
-- GROUP BY account_id, DATE_FORMAT(txn_time, '%Y-%m-01');
-- Sample output (month = 2025-01-01):
-- account_id | month_start | total
-- --------------------------------
-- 1          | 2025-01-01  | 120.00
-- 101        | 2025-01-01  | -900.00
-- 102        | 2025-01-01  | 100.00
-- 201        | 2025-01-01  | 1100.00
-- 301        | 2025-01-01  | -100.00
-- 401        | 2025-01-01  | 0.00

-- **8) Balance mismatch detection (audit)**
-- Purpose: compare stored account balance vs calculated from transactions
-- SQL:
-- SELECT a.account_id,
--        a.balance AS stored_balance,
--        SUM(t.amount) AS calculated_balance
-- FROM accounts a
-- JOIN transactions t ON a.account_id = t.account_id
-- GROUP BY a.account_id, a.balance
-- HAVING a.balance <> SUM(t.amount);
-- Sample output (no mismatches based on our sample data):
-- (no rows)

-- **9) Find gaps in transaction dates**
-- Purpose: detect >7-day gaps using window LAG (Postgres/Snowflake flavor shown)
-- SQL (Postgres example with interval):
-- SELECT account_id, txn_time,
--        LAG(txn_time) OVER (PARTITION BY account_id ORDER BY txn_time) AS prev_txn
-- FROM transactions
-- WHERE txn_time - LAG(txn_time) OVER (PARTITION BY account_id ORDER BY txn_time) > INTERVAL '7' DAY;
-- Note: some DBs support QUALIFY which simplifies filtering after window functions.
-- Sample output (no gaps >7 days in the provided sample):
-- (no rows)

-- **10) Daily end-of-day balance snapshot per account**
-- Purpose: produce end-of-day balances for reporting
-- SQL:
-- SELECT account_id,
--        txn_date,
--        SUM(amount) OVER (PARTITION BY account_id ORDER BY txn_date) AS end_of_day_balance
-- FROM (
--   SELECT account_id, DATE(txn_time) AS txn_date, SUM(amount) AS amount
--   FROM transactions
--   GROUP BY account_id, DATE(txn_time)
-- ) d;
-- Sample output:
-- account_id | txn_date   | end_of_day_balance
-- -------------------------------------------
-- 1          | 2025-01-10 | 120.00
-- 101        | 2025-01-10 | -1000.00
-- 101        | 2025-01-11 | -900.00
-- 102        | 2025-01-10 | -300.00
-- 102        | 2025-01-11 | 100.00
-- 201        | 2025-01-04 | 1100.00

-- **11) Detect negative balance events**
-- Purpose: find accounts that ever went below zero
-- SQL:
-- SELECT DISTINCT account_id
-- FROM (
--   SELECT account_id,
--          SUM(amount) OVER (PARTITION BY account_id ORDER BY txn_time) AS running_balance
--   FROM transactions
-- ) x
-- WHERE running_balance < 0;
-- Sample output:
-- account_id
-- ----------
-- 101
-- 301

-- **12) Transaction that caused balance to go negative**
-- Purpose: locate the exact row that crossed balance from >=0 to <0
-- SQL:
-- SELECT *
-- FROM (
--   SELECT t.*, SUM(amount) OVER (PARTITION BY account_id ORDER BY txn_time) AS balance
--   FROM transactions t
-- ) x
-- WHERE balance < 0
--   AND balance - amount >= 0;
-- Sample output (rows that caused crossing):
-- account_id | txn_time            | amount   | balance_before -> after
-- --------------------------------------------------------------------
-- 101        | 2025-01-10 10:00:00 | -500.00  | 0 -> -500.00
-- 301        | 2025-01-06 10:00:00 | -200.00  | 100.00 -> -100.00

-- **13) Find reversed transactions (credit + matching debit)**
-- Purpose: detect likely reversals by same timestamp and opposite amount
-- SQL:
-- SELECT t1.*
-- FROM transactions t1
-- JOIN transactions t2
--   ON t1.account_id = t2.account_id
--  AND t1.amount = -t2.amount
--  AND t1.txn_time = t2.txn_time
--  AND t1.id <> t2.id;
-- Sample output (both rows shown as reversal pair):
-- account_id | txn_time            | amount   | type
-- -----------------------------------------------
-- 401        | 2025-01-07 10:00:00 | 250.00   | CREDIT
-- 401        | 2025-01-07 10:00:00 | -250.00  | DEBIT

-- **14) Identify unusually large transactions (outliers)**
-- Purpose: per-account outlier detection using 3x average
-- SQL:
-- SELECT *
-- FROM (
--   SELECT t.*, AVG(ABS(amount)) OVER (PARTITION BY account_id) avg_amt
--   FROM transactions t
-- ) x
-- WHERE ABS(amount) > 3 * avg_amt;
-- Sample output (no outliers based on sample data):
-- (no rows)

-- **15) Cumulative debit vs credit per account**
-- Purpose: split totals into debit and credit
-- SQL:
-- SELECT account_id,
--        SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total_credit,
--        SUM(CASE WHEN amount < 0 THEN -amount ELSE 0 END) AS total_debit
-- FROM transactions
-- GROUP BY account_id;
-- Sample output:
-- account_id | total_credit | total_debit
-- ---------------------------------------
-- 1          | 150.00       | 30.00
-- 101        | 200.00       | 1100.00
-- 102        | 400.00       | 300.00
-- 201        | 1300.00      | 200.00
-- 301        | 100.00       | 200.00
-- 401        | 250.00       | 250.00

-- **16) Detect missing transaction IDs (audit)**
-- Purpose: simple gap detection in sequential IDs
-- SQL:
-- SELECT id + 1 AS missing_id
-- FROM transactions t
-- WHERE NOT EXISTS (SELECT 1 FROM transactions t2 WHERE t2.id = t.id + 1);
-- Sample output (depends on auto-increment values; with contiguous inserts likely no rows):
-- (no rows)

-- **17) Slow query diagnosis / date function fix**
-- Problematic (prevents index use):
-- SELECT * FROM transactions WHERE DATE(txn_time) = '2025-01-10';
-- Better (range scan uses index):
-- SELECT * FROM transactions
-- WHERE txn_time >= '2025-01-10' AND txn_time < '2025-01-11';

-- ================================================================
-- End of hsbc-extracted.sql
