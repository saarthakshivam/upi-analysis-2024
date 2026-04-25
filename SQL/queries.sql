-- =============================================================================
-- queries.sql
-- UPI Transaction Trends India 2024 — 15 Interview-Ready SQL Queries
-- =============================================================================
-- Each query includes:
--   QUESTION  : As an interviewer would ask it
--   CONCEPTS  : SQL skills being tested
--   QUERY     : The answer
--   WHY       : Business interpretation of the result
-- =============================================================================


-- =============================================================================
-- SECTION A: BASIC (Q1–Q5)
-- Tests: aggregations, GROUP BY, ORDER BY, WHERE, HAVING
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Q1. What is the total number of transactions and total value
--     processed by each UPI app in 2024?
--
-- CONCEPTS : GROUP BY, SUM, COUNT, ORDER BY, ROUND
-- WHY      : Market share analysis — which app dominates by volume vs value?
--            PhonePe leads by volume; Google Pay is close.
--            This is one of the most common business questions in fintech.
-- -----------------------------------------------------------------------------
SELECT
    upi_app,
    COUNT(*)                                                        AS total_transactions,
    ROUND(SUM(amount_inr) / 1e7, 2)                                AS total_value_cr,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)             AS volume_share_pct,
    ROUND(SUM(amount_inr) * 100.0 / SUM(SUM(amount_inr)) OVER (), 2) AS value_share_pct
FROM transactions
WHERE is_outlier = FALSE
GROUP BY upi_app
ORDER BY total_transactions DESC;


-- -----------------------------------------------------------------------------
-- Q2. Which cities recorded the highest average transaction value in 2024?
--     Show the top 10, excluding 'Unknown' and 'Others'.
--
-- CONCEPTS : WHERE with multiple conditions, AVG, ROUND, LIMIT
-- WHY      : Identifies high-value urban markets for targeted merchant strategy.
--            Cities with high avg ticket = more premium spending behaviour.
-- -----------------------------------------------------------------------------
SELECT
    city,
    COUNT(*)                            AS total_transactions,
    ROUND(AVG(amount_inr), 2)           AS avg_transaction_inr,
    ROUND(SUM(amount_inr) / 1e7, 2)    AS total_value_cr
FROM transactions
WHERE is_outlier = FALSE
  AND city NOT IN ('Unknown', 'Others')
GROUP BY city
ORDER BY avg_transaction_inr DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- Q3. What is the monthly transaction count and total value for 2024?
--     Show month-over-month growth in transaction count.
--
-- CONCEPTS : GROUP BY with ORDER BY on a numeric key, formatted output
-- WHY      : The foundational trend query every analyst runs first.
--            Reveals seasonality — festive months (Oct, Dec) show spikes.
-- -----------------------------------------------------------------------------
SELECT
    month,
    month_name,
    COUNT(*)                                AS total_transactions,
    ROUND(SUM(amount_inr) / 1e7, 2)        AS total_value_cr,
    ROUND(AVG(amount_inr), 2)              AS avg_txn_inr
FROM transactions
WHERE is_outlier = FALSE
GROUP BY month, month_name
ORDER BY month;


-- -----------------------------------------------------------------------------
-- Q4. What percentage of transactions failed for each UPI app?
--     Only show apps with more than 500 transactions.
--
-- CONCEPTS : CASE WHEN inside aggregation, HAVING, percentage calculation
-- WHY      : Reliability analysis. High failure rate = poor UX.
--            An interviewer may ask: "how would you flag an underperforming app?"
-- -----------------------------------------------------------------------------
SELECT
    upi_app,
    COUNT(*)                                                            AS total_transactions,
    SUM(CASE WHEN status = 'Failed'  THEN 1 ELSE 0 END)               AS failed_count,
    SUM(CASE WHEN status = 'Success' THEN 1 ELSE 0 END)               AS success_count,
    ROUND(
        SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    )                                                                   AS failure_rate_pct
FROM transactions
GROUP BY upi_app
HAVING COUNT(*) > 500
ORDER BY failure_rate_pct DESC;


-- -----------------------------------------------------------------------------
-- Q5. What is the breakdown of P2P vs P2M transactions by quarter?
--     Show both count and percentage split.
--
-- CONCEPTS : CASE WHEN, GROUP BY multiple columns, percentage of total
-- WHY      : Tracks the shift from personal transfers to merchant payments
--            over time — a key growth signal for NPCI and payment networks.
-- -----------------------------------------------------------------------------
SELECT
    quarter,
    transaction_type,
    COUNT(*)                                                        AS transactions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY quarter), 2) AS pct_of_quarter
FROM transactions
WHERE is_outlier = FALSE
GROUP BY quarter, transaction_type
ORDER BY quarter, transaction_type;


-- =============================================================================
-- SECTION B: INTERMEDIATE (Q6–Q10)
-- Tests: JOINs, subqueries, date functions, CASE WHEN logic, CROSS JOIN
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Q6. Compare synthetic transaction volumes with real NPCI data month by month.
--     Flag months where synthetic data diverges from NPCI by more than 10%.
--
-- CONCEPTS : JOIN between two tables of different grains, derived columns,
--            CASE WHEN for conditional flagging
-- WHY      : Data validation query — shows you understand the difference
--            between synthetic and real data, and can reconcile them.
--            This is a VERY strong portfolio talking point.
-- -----------------------------------------------------------------------------
SELECT
    n.month,
    n.month_name,
    n.volume_million                                        AS npci_volume_m,
    s.total_transactions                                    AS synthetic_txn_count,
    ROUND(s.total_transactions::NUMERIC / n.volume_million, 1) AS synthetic_per_m_npci,
    ROUND(s.p2m_share_pct, 1)                              AS synthetic_p2m_pct,
    ROUND(n.p2m_volume_million * 100.0
          / n.volume_million, 1)                           AS npci_p2m_pct,
    CASE
        WHEN ABS(s.p2m_share_pct -
                 ROUND(n.p2m_volume_million * 100.0 / n.volume_million, 1)) > 10
        THEN 'DIVERGED'
        ELSE 'OK'
    END                                                     AS p2m_alignment
FROM monthly_npci    n
JOIN monthly_summary s ON n.month = s.month
ORDER BY n.month;


-- -----------------------------------------------------------------------------
-- Q7. Find the top 3 merchant categories by total transaction value
--     separately for weekdays and weekends.
--
-- CONCEPTS : Subquery with RANK(), filtering on rank, multiple GROUP BY levels
-- WHY      : Consumer behaviour insight — weekend vs weekday spending patterns
--            differ significantly (entertainment/food spike on weekends).
-- -----------------------------------------------------------------------------
SELECT
    day_type,
    merchant_category,
    total_value_cr,
    txn_count,
    rnk
FROM (
    SELECT
        day_type,
        merchant_category,
        COUNT(*)                                    AS txn_count,
        ROUND(SUM(amount_inr) / 1e7, 3)           AS total_value_cr,
        RANK() OVER (
            PARTITION BY day_type
            ORDER BY SUM(amount_inr) DESC
        )                                           AS rnk
    FROM transactions
    WHERE is_outlier = FALSE
      AND transaction_type = 'P2M'
      AND merchant_category NOT IN ('N/A (P2P)', 'Uncategorised', 'Others')
    GROUP BY day_type, merchant_category
) ranked
WHERE rnk <= 3
ORDER BY day_type, rnk;


-- -----------------------------------------------------------------------------
-- Q8. Which hour of the day sees the highest transaction volume?
--     Show the top 5 peak hours and their average transaction value.
--
-- CONCEPTS : GROUP BY on derived time column, ORDER BY + LIMIT,
--            combining COUNT and AVG
-- WHY      : Operational insight — when to schedule server maintenance,
--            when to push marketing notifications, when to staff support teams.
-- -----------------------------------------------------------------------------
SELECT
    hour,
    time_of_day,
    COUNT(*)                            AS total_transactions,
    ROUND(AVG(amount_inr), 2)          AS avg_amount_inr,
    ROUND(SUM(amount_inr) / 1e7, 3)   AS total_value_cr
FROM transactions
WHERE is_outlier = FALSE
GROUP BY hour, time_of_day
ORDER BY total_transactions DESC
LIMIT 5;


-- -----------------------------------------------------------------------------
-- Q9. For each city, what is the most popular UPI app?
--     Exclude 'Unknown' and 'Others' cities.
--
-- CONCEPTS : Subquery + RANK() / ROW_NUMBER(), filtering on inner rank
-- WHY      : Regional preference analysis. In reality, PhonePe dominates
--            South India while Google Pay is stronger in metros.
--            Shows ability to find the mode within a group.
-- -----------------------------------------------------------------------------
SELECT
    city,
    upi_app             AS most_popular_app,
    txn_count,
    city_total,
    ROUND(txn_count * 100.0 / city_total, 1) AS app_share_in_city_pct
FROM (
    SELECT
        city,
        upi_app,
        COUNT(*)                                    AS txn_count,
        SUM(COUNT(*)) OVER (PARTITION BY city)     AS city_total,
        ROW_NUMBER() OVER (
            PARTITION BY city
            ORDER BY COUNT(*) DESC
        )                                           AS rn
    FROM transactions
    WHERE city NOT IN ('Unknown', 'Others')
    GROUP BY city, upi_app
) ranked
WHERE rn = 1
ORDER BY txn_count DESC;


-- -----------------------------------------------------------------------------
-- Q10. What is the distribution of transactions across amount brackets?
--      Show count, total value, and cumulative % of transaction volume.
--
-- CONCEPTS : CASE WHEN bucketing (already in column), ORDER BY custom sequence,
--            cumulative SUM window function
-- WHY      : NPCI's own data shows 86% of UPI transactions are under ₹500.
--            Verifying this in our dataset shows calibration quality.
-- -----------------------------------------------------------------------------
SELECT
    amount_bracket,
    COUNT(*)                                                            AS txn_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)                AS pct_of_total,
    ROUND(SUM(amount_inr) / 1e7, 3)                                   AS total_value_cr,
    ROUND(
        SUM(COUNT(*)) OVER (
            ORDER BY
                CASE amount_bracket
                    WHEN '₹0–100'          THEN 1
                    WHEN '₹101–500'        THEN 2
                    WHEN '₹501–2,000'      THEN 3
                    WHEN '₹2,001–10,000'   THEN 4
                    WHEN '₹10,001–1,00,000' THEN 5
                    ELSE 6
                END
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 / SUM(COUNT(*)) OVER ()
    , 2)                                                                AS cumulative_pct
FROM transactions
GROUP BY amount_bracket
ORDER BY
    CASE amount_bracket
        WHEN '₹0–100'           THEN 1
        WHEN '₹101–500'         THEN 2
        WHEN '₹501–2,000'       THEN 3
        WHEN '₹2,001–10,000'    THEN 4
        WHEN '₹10,001–1,00,000' THEN 5
        ELSE 6
    END;


-- =============================================================================
-- SECTION C: ADVANCED (Q11–Q15)
-- Tests: Window functions (LAG, RANK, DENSE_RANK, SUM OVER),
--        CTEs, running totals, multi-level aggregation
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Q11. Calculate month-over-month growth rate in transaction volume
--      and value using window functions. Flag months with negative growth.
--
-- CONCEPTS : LAG() window function, percentage change formula, CASE WHEN flag
-- WHY      : The classic time-series growth query. LAG() is one of the most
--            tested window functions in data analyst interviews.
-- -----------------------------------------------------------------------------
WITH monthly_metrics AS (
    SELECT
        month,
        month_name,
        COUNT(*)                        AS txn_count,
        ROUND(SUM(amount_inr) / 1e7, 2) AS value_cr
    FROM transactions
    WHERE is_outlier = FALSE
    GROUP BY month, month_name
)
SELECT
    month,
    month_name,
    txn_count,
    value_cr,
    LAG(txn_count)  OVER (ORDER BY month)  AS prev_month_txn,
    LAG(value_cr)   OVER (ORDER BY month)  AS prev_month_value,
    ROUND(
        (txn_count - LAG(txn_count) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(txn_count) OVER (ORDER BY month), 0)
    , 2)                                    AS mom_volume_growth_pct,
    ROUND(
        (value_cr - LAG(value_cr) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(value_cr) OVER (ORDER BY month), 0)
    , 2)                                    AS mom_value_growth_pct,
    CASE
        WHEN txn_count < LAG(txn_count) OVER (ORDER BY month)
        THEN 'DECLINE'
        ELSE 'GROWTH'
    END                                     AS trend_flag
FROM monthly_metrics
ORDER BY month;


-- -----------------------------------------------------------------------------
-- Q12. Rank UPI apps by transaction volume within each quarter.
--      Show how app rankings shift across quarters.
--
-- CONCEPTS : DENSE_RANK() with PARTITION BY quarter, multi-level window
-- WHY      : Competitive positioning over time. Did any app gain/lose rank
--            across quarters? Shows analytical storytelling ability.
-- -----------------------------------------------------------------------------
WITH app_quarterly AS (
    SELECT
        quarter,
        upi_app,
        COUNT(*)                            AS txn_count,
        ROUND(SUM(amount_inr) / 1e7, 2)   AS value_cr
    FROM transactions
    WHERE is_outlier = FALSE
    GROUP BY quarter, upi_app
)
SELECT
    quarter,
    upi_app,
    txn_count,
    value_cr,
    DENSE_RANK() OVER (
        PARTITION BY quarter
        ORDER BY txn_count DESC
    )                                       AS volume_rank,
    DENSE_RANK() OVER (
        PARTITION BY quarter
        ORDER BY value_cr DESC
    )                                       AS value_rank
FROM app_quarterly
ORDER BY quarter, volume_rank;


-- -----------------------------------------------------------------------------
-- Q13. Calculate the running (cumulative) total of UPI transaction value
--      month by month, alongside the running average.
--
-- CONCEPTS : SUM() OVER with ROWS BETWEEN frame, AVG() OVER, cumulative logic
-- WHY      : Running totals are used in every BI dashboard.
--            "Has UPI crossed ₹X lakh crore this year?" — this query answers it.
-- -----------------------------------------------------------------------------
WITH monthly AS (
    SELECT
        month,
        month_name,
        ROUND(SUM(amount_inr) / 1e7, 2)    AS monthly_value_cr,
        COUNT(*)                            AS monthly_txn_count
    FROM transactions
    WHERE is_outlier = FALSE
    GROUP BY month, month_name
)
SELECT
    month,
    month_name,
    monthly_value_cr,
    monthly_txn_count,
    SUM(monthly_value_cr) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                       AS cumulative_value_cr,
    SUM(monthly_txn_count) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                       AS cumulative_txn_count,
    ROUND(AVG(monthly_value_cr) OVER (
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                   AS rolling_3m_avg_value_cr
FROM monthly
ORDER BY month;


-- -----------------------------------------------------------------------------
-- Q14. Find the top 5% of transactions by amount for each UPI app.
--      Show what percentage of total value they contribute.
--
-- CONCEPTS : NTILE() window function, CTE with two levels of aggregation
-- WHY      : Pareto analysis — the top 5% of transactions often drive
--            30–40% of total value. Shows ability to identify power users
--            or high-value merchant segments.
-- -----------------------------------------------------------------------------
WITH percentile_tagged AS (
    SELECT
        transaction_id,
        upi_app,
        amount_inr,
        NTILE(20) OVER (
            PARTITION BY upi_app
            ORDER BY amount_inr DESC
        )                               AS ntile_20   -- ntile_20 = 1 means top 5%
    FROM transactions
    WHERE is_outlier = FALSE
),
top5_summary AS (
    SELECT
        upi_app,
        COUNT(*)                        AS top5_txn_count,
        ROUND(SUM(amount_inr), 2)      AS top5_value_inr
    FROM percentile_tagged
    WHERE ntile_20 = 1
    GROUP BY upi_app
),
total_summary AS (
    SELECT
        upi_app,
        COUNT(*)                        AS total_txn_count,
        ROUND(SUM(amount_inr), 2)      AS total_value_inr
    FROM transactions
    WHERE is_outlier = FALSE
    GROUP BY upi_app
)
SELECT
    t.upi_app,
    t.total_txn_count,
    t5.top5_txn_count,
    ROUND(t5.top5_value_inr / 1e7, 2)   AS top5_value_cr,
    ROUND(t.total_value_inr / 1e7, 2)   AS total_value_cr,
    ROUND(t5.top5_value_inr * 100.0
          / t.total_value_inr, 1)        AS top5_value_share_pct
FROM total_summary t
JOIN top5_summary t5 ON t.upi_app = t5.upi_app
ORDER BY top5_value_share_pct DESC;


-- -----------------------------------------------------------------------------
-- Q15. For each city, find months where transaction volume was above
--      that city's annual average, and show the deviation from average.
--
-- CONCEPTS : Multi-level CTE, AVG() OVER PARTITION BY, self-referencing,
--            above/below average flagging
-- WHY      : Anomaly detection pattern. A month that's 2x above average
--            could indicate a local festival, marketing campaign, or
--            a data quality issue — the analyst needs to spot it.
-- -----------------------------------------------------------------------------
WITH city_monthly AS (
    SELECT
        city,
        month,
        month_name,
        COUNT(*)    AS txn_count
    FROM transactions
    WHERE is_outlier = FALSE
      AND city NOT IN ('Unknown', 'Others')
    GROUP BY city, month, month_name
),
city_with_avg AS (
    SELECT
        *,
        ROUND(AVG(txn_count) OVER (PARTITION BY city), 1) AS city_annual_avg,
        ROUND(
            (txn_count - AVG(txn_count) OVER (PARTITION BY city))
            * 100.0
            / NULLIF(AVG(txn_count) OVER (PARTITION BY city), 0)
        , 1)                                               AS pct_deviation
    FROM city_monthly
)
SELECT
    city,
    month_name,
    txn_count,
    city_annual_avg,
    pct_deviation,
    CASE
        WHEN pct_deviation > 20  THEN 'ABOVE AVG'
        WHEN pct_deviation < -20 THEN 'BELOW AVG'
        ELSE 'NORMAL'
    END                                                    AS volume_status
FROM city_with_avg
WHERE ABS(pct_deviation) > 20      -- Only show months with significant deviation
ORDER BY city, ABS(pct_deviation) DESC;
