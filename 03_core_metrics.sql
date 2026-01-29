-- ============================================================================
-- 03_core_metrics.sql
-- Purpose: Calculate core SaaS metrics (MRR, ARR, Churn, ARPC)
-- Author: Data Analyst Assessment
-- Date: 2026-01-29
-- ============================================================================

-- ============================================================================
-- METRIC 1: MONTHLY RECURRING REVENUE (MRR)
-- ============================================================================
-- Definition: Sum of all active subscription monthly prices in a given month
-- Business Context: Key metric for tracking revenue growth month-over-month

WITH date_spine AS (
    -- Generate a month spine from Jan 2023 to Dec 2023
    SELECT DATE_FORMAT(DATE('2023-01-01') + INTERVAL n MONTH, '%Y-%m-01') AS month_date
    FROM (
        SELECT 0 AS n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 
        UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 
        UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11
    ) numbers
),
monthly_mrr AS (
    SELECT 
        ds.month_date,
        SUM(s.monthly_price) as mrr,
        COUNT(DISTINCT s.customer_id) as active_customers
    FROM date_spine ds
    LEFT JOIN subscriptions s 
        ON s.start_date <= LAST_DAY(ds.month_date)
        AND (s.end_date IS NULL OR s.end_date > ds.month_date)
    GROUP BY ds.month_date
)
SELECT 
    month_date,
    mrr,
    active_customers,
    LAG(mrr) OVER (ORDER BY month_date) as previous_mrr,
    mrr - LAG(mrr) OVER (ORDER BY month_date) as mrr_growth,
    ROUND(
        ((mrr - LAG(mrr) OVER (ORDER BY month_date)) / 
        NULLIF(LAG(mrr) OVER (ORDER BY month_date), 0)) * 100, 
        2
    ) as mrr_growth_pct
FROM monthly_mrr
ORDER BY month_date;

-- ============================================================================
-- METRIC 2: ANNUAL RECURRING REVENUE (ARR)
-- ============================================================================
-- Definition: MRR * 12
-- Business Context: Annualized revenue run rate

SELECT 
    DATE_FORMAT(NOW(), '%Y-%m') as current_month,
    SUM(monthly_price) as current_mrr,
    SUM(monthly_price) * 12 as arr
FROM subscriptions
WHERE status = 'active';

-- ============================================================================
-- METRIC 3: CUSTOMER (LOGO) CHURN RATE
-- ============================================================================
-- Definition: (Customers lost in period / Customers at start of period) * 100
-- Business Context: Measures customer retention effectiveness
-- Calculation: Monthly churn rate

WITH monthly_customer_churn AS (
    SELECT 
        DATE_FORMAT(start_date, '%Y-%m') as cohort_month,
        COUNT(DISTINCT customer_id) as cohort_size,
        SUM(CASE WHEN status = 'canceled' THEN 1 ELSE 0 END) as churned_customers,
        ROUND(
            (SUM(CASE WHEN status = 'canceled' THEN 1 ELSE 0 END) * 100.0) / 
            COUNT(DISTINCT customer_id), 
            2
        ) as customer_churn_rate
    FROM subscriptions
    GROUP BY DATE_FORMAT(start_date, '%Y-%m')
)
SELECT * FROM monthly_customer_churn
ORDER BY cohort_month;

-- Overall customer churn rate
SELECT 
    COUNT(DISTINCT CASE WHEN status = 'active' THEN customer_id END) as active_customers,
    COUNT(DISTINCT CASE WHEN status = 'canceled' THEN customer_id END) as churned_customers,
    COUNT(DISTINCT customer_id) as total_customers,
    ROUND(
        (COUNT(DISTINCT CASE WHEN status = 'canceled' THEN customer_id END) * 100.0) / 
        COUNT(DISTINCT customer_id), 
        2
    ) as overall_churn_rate
FROM subscriptions;

-- ============================================================================
-- METRIC 4: REVENUE CHURN RATE
-- ============================================================================
-- Definition: (MRR lost from churned customers / Starting MRR) * 100
-- Business Context: Measures revenue retention (can be negative with expansion)

WITH monthly_revenue_churn AS (
    SELECT 
        DATE_FORMAT(end_date, '%Y-%m') as churn_month,
        SUM(monthly_price) as churned_mrr
    FROM subscriptions
    WHERE status = 'canceled' 
      AND end_date IS NOT NULL
    GROUP BY DATE_FORMAT(end_date, '%Y-%m')
),
monthly_starting_mrr AS (
    SELECT 
        DATE_FORMAT(DATE('2023-01-01') + INTERVAL n MONTH, '%Y-%m') as month,
        SUM(s.monthly_price) as starting_mrr
    FROM (
        SELECT 0 AS n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 
        UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 
        UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11
    ) months
    LEFT JOIN subscriptions s 
        ON s.start_date < DATE('2023-01-01') + INTERVAL n MONTH
        AND (s.end_date IS NULL OR s.end_date >= DATE('2023-01-01') + INTERVAL n MONTH)
    GROUP BY month
)
SELECT 
    m.month,
    COALESCE(m.starting_mrr, 0) as starting_mrr,
    COALESCE(c.churned_mrr, 0) as churned_mrr,
    ROUND(
        (COALESCE(c.churned_mrr, 0) * 100.0) / NULLIF(m.starting_mrr, 0),
        2
    ) as revenue_churn_rate
FROM monthly_starting_mrr m
LEFT JOIN monthly_revenue_churn c ON m.month = c.churn_month
ORDER BY m.month;

-- ============================================================================
-- METRIC 5: AVERAGE REVENUE PER CUSTOMER (ARPC)
-- ============================================================================
-- Definition: Total MRR / Total Active Customers
-- Business Context: Indicates customer value and pricing effectiveness

SELECT 
    DATE_FORMAT(NOW(), '%Y-%m') as metric_month,
    SUM(monthly_price) as total_mrr,
    COUNT(DISTINCT customer_id) as total_active_customers,
    ROUND(SUM(monthly_price) / COUNT(DISTINCT customer_id), 2) as arpc
FROM subscriptions
WHERE status = 'active';

-- ARPC by segment
SELECT 
    c.segment,
    SUM(s.monthly_price) as total_mrr,
    COUNT(DISTINCT s.customer_id) as active_customers,
    ROUND(SUM(s.monthly_price) / COUNT(DISTINCT s.customer_id), 2) as arpc
FROM subscriptions s
JOIN customers c ON s.customer_id = c.customer_id
WHERE s.status = 'active'
GROUP BY c.segment
ORDER BY arpc DESC;

-- ARPC by country
SELECT 
    c.country,
    SUM(s.monthly_price) as total_mrr,
    COUNT(DISTINCT s.customer_id) as active_customers,
    ROUND(SUM(s.monthly_price) / COUNT(DISTINCT s.customer_id), 2) as arpc
FROM subscriptions s
JOIN customers c ON s.customer_id = c.customer_id
WHERE s.status = 'active'
GROUP BY c.country
ORDER BY arpc DESC;

-- ============================================================================
-- ADDITIONAL METRIC: LIFETIME VALUE (LTV) ESTIMATE
-- ============================================================================
-- Simple LTV = ARPC / Churn Rate
-- Note: This is a simplified calculation

WITH arpc_calc AS (
    SELECT ROUND(SUM(monthly_price) / COUNT(DISTINCT customer_id), 2) as arpc
    FROM subscriptions
    WHERE status = 'active'
),
churn_calc AS (
    SELECT 
        ROUND(
            (COUNT(DISTINCT CASE WHEN status = 'canceled' THEN customer_id END) * 100.0) / 
            COUNT(DISTINCT customer_id), 
            2
        ) as churn_rate
    FROM subscriptions
)
SELECT 
    arpc,
    churn_rate,
    ROUND(arpc / (churn_rate / 100), 2) as estimated_ltv
FROM arpc_calc, churn_calc;

-- ============================================================================
-- SUMMARY DASHBOARD QUERY
-- ============================================================================
-- Single query to get all key metrics for dashboard

SELECT 
    'MRR' as metric,
    CONCAT('$', FORMAT(SUM(monthly_price), 0)) as value
FROM subscriptions
WHERE status = 'active'

UNION ALL

SELECT 
    'ARR',
    CONCAT('$', FORMAT(SUM(monthly_price) * 12, 0))
FROM subscriptions
WHERE status = 'active'

UNION ALL

SELECT 
    'Active Customers',
    FORMAT(COUNT(DISTINCT customer_id), 0)
FROM subscriptions
WHERE status = 'active'

UNION ALL

SELECT 
    'ARPC',
    CONCAT('$', FORMAT(SUM(monthly_price) / COUNT(DISTINCT customer_id), 2))
FROM subscriptions
WHERE status = 'active'

UNION ALL

SELECT 
    'Customer Churn Rate',
    CONCAT(
        FORMAT(
            (COUNT(DISTINCT CASE WHEN status = 'canceled' THEN customer_id END) * 100.0) / 
            COUNT(DISTINCT customer_id), 
            2
        ),
        '%'
    )
FROM subscriptions;

-- ============================================================================
-- END OF CORE METRICS SCRIPT
-- ============================================================================
