-- =============================================================================
-- schema.sql
-- UPI Transaction Trends India 2024 — PostgreSQL Schema
-- =============================================================================
-- Run this file FIRST before loading any data.
-- Command: psql -U postgres -d upi_analysis -f sql/schema.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. Setup: drop existing tables if re-running (safe for dev)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS monthly_npci CASCADE;
DROP TABLE IF EXISTS monthly_summary CASCADE;


-- -----------------------------------------------------------------------------
-- 1. transactions
--    Main fact table. One row per UPI transaction.
--    Source: data/processed/transactions_clean.csv (~50,000 rows)
-- -----------------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id      VARCHAR(15)     PRIMARY KEY,
    timestamp           TIMESTAMP       NOT NULL,
    date                DATE            NOT NULL,
    month               SMALLINT        NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name          VARCHAR(10)     NOT NULL,
    day_of_week         VARCHAR(10)     NOT NULL,
    hour                SMALLINT        NOT NULL CHECK (hour BETWEEN 0 AND 23),
    sender_upi_id       VARCHAR(50)     NOT NULL,
    receiver_upi_id     VARCHAR(50)     NOT NULL,
    amount_inr          NUMERIC(12, 2)  NOT NULL CHECK (amount_inr > 0),
    transaction_type    VARCHAR(5)      NOT NULL CHECK (transaction_type IN ('P2P', 'P2M')),
    merchant_category   VARCHAR(50),
    upi_app             VARCHAR(20)     NOT NULL,
    city                VARCHAR(30)     NOT NULL,
    status              VARCHAR(10)     NOT NULL CHECK (status IN ('Success', 'Failed', 'Pending')),
    bank_handle         VARCHAR(20),
    is_outlier          BOOLEAN         NOT NULL DEFAULT FALSE,
    quarter             CHAR(2)         NOT NULL CHECK (quarter IN ('Q1', 'Q2', 'Q3', 'Q4')),
    day_type            VARCHAR(10)     NOT NULL CHECK (day_type IN ('Weekday', 'Weekend')),
    time_of_day         VARCHAR(25)     NOT NULL,
    amount_bracket      VARCHAR(25)     NOT NULL
);

-- Indexes for query performance on commonly filtered/grouped columns
CREATE INDEX idx_txn_date            ON transactions (date);
CREATE INDEX idx_txn_month           ON transactions (month);
CREATE INDEX idx_txn_app             ON transactions (upi_app);
CREATE INDEX idx_txn_city            ON transactions (city);
CREATE INDEX idx_txn_type            ON transactions (transaction_type);
CREATE INDEX idx_txn_status          ON transactions (status);
CREATE INDEX idx_txn_quarter         ON transactions (quarter);
CREATE INDEX idx_txn_is_outlier      ON transactions (is_outlier);

COMMENT ON TABLE transactions IS
    'Cleaned synthetic UPI transaction data for 2024. ~50,000 rows. '
    'Distributions calibrated to match real NPCI 2024 aggregate statistics.';


-- -----------------------------------------------------------------------------
-- 2. monthly_npci
--    Real NPCI aggregate data — official monthly statistics for 2024.
--    Source: data/raw/npci_monthly_2024.csv (12 rows)
--    Use this table to validate synthetic data patterns against ground truth.
-- -----------------------------------------------------------------------------
CREATE TABLE monthly_npci (
    month               SMALLINT        PRIMARY KEY CHECK (month BETWEEN 1 AND 12),
    year                SMALLINT        NOT NULL DEFAULT 2024,
    month_name          VARCHAR(10)     NOT NULL,
    volume_million      NUMERIC(8, 2)   NOT NULL,   -- Total UPI transactions (millions)
    value_crore_inr     NUMERIC(10, 2)  NOT NULL,   -- Total value (₹ lakh crore, displayed as crore)
    p2p_volume_million  NUMERIC(8, 2)   NOT NULL,   -- P2P transaction volume (millions)
    p2m_volume_million  NUMERIC(8, 2)   NOT NULL,   -- P2M transaction volume (millions)
    p2p_value_crore     NUMERIC(10, 2)  NOT NULL,   -- P2P value (₹ crore)
    p2m_value_crore     NUMERIC(10, 2)  NOT NULL,   -- P2M value (₹ crore)
    active_banks        SMALLINT        NOT NULL    -- Number of banks live on UPI
);

COMMENT ON TABLE monthly_npci IS
    'Real NPCI official UPI statistics for Jan–Dec 2024. '
    'Source: npci.org.in/product/upi/product-statistics';


-- -----------------------------------------------------------------------------
-- 3. monthly_summary
--    Aggregated monthly metrics derived from the cleaned transactions table.
--    Source: data/processed/monthly_summary.csv (12 rows)
--    Mirrors monthly_npci grain but built from synthetic transaction-level data.
-- -----------------------------------------------------------------------------
CREATE TABLE monthly_summary (
    month                   SMALLINT        PRIMARY KEY CHECK (month BETWEEN 1 AND 12),
    month_name              VARCHAR(10)     NOT NULL,
    total_transactions      INTEGER         NOT NULL,
    total_value_inr         NUMERIC(15, 2)  NOT NULL,
    avg_transaction_inr     NUMERIC(10, 2)  NOT NULL,
    median_txn_inr          NUMERIC(10, 2)  NOT NULL,
    p2p_transactions        INTEGER         NOT NULL,
    p2m_transactions        INTEGER         NOT NULL,
    success_count           INTEGER         NOT NULL,
    failed_count            INTEGER         NOT NULL,
    unique_cities           SMALLINT        NOT NULL,
    success_rate_pct        NUMERIC(5, 2)   NOT NULL,
    p2p_share_pct           NUMERIC(5, 2)   NOT NULL,
    p2m_share_pct           NUMERIC(5, 2)   NOT NULL,
    mom_txn_growth_pct      NUMERIC(6, 2),           -- NULL for January (no prior month)
    total_value_cr          NUMERIC(10, 2)  NOT NULL
);

COMMENT ON TABLE monthly_summary IS
    'Monthly aggregated metrics derived from the cleaned transactions table. '
    'Use this alongside monthly_npci to compare synthetic vs real patterns.';


-- -----------------------------------------------------------------------------
-- Verify
-- -----------------------------------------------------------------------------
SELECT
    table_name,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) AS size
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('transactions', 'monthly_npci', 'monthly_summary')
ORDER BY table_name;
