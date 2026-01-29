-- ============================================================================
-- 04_funnel_analysis.sql
-- Purpose: Analyze user funnel (Signup → Trial → Activated → Paid → Churned)
-- Author: Data Analyst Assessment
-- Date: 2026-01-29
-- ============================================================================

-- ============================================================================
-- FUNNEL OVERVIEW
-- ============================================================================
-- Stages: Signup → Trial Start → Activated → Paid → Churned
-- Goal: Identify conversion rates and drop-off points

-- ============================================================================
-- SECTION 1: BUILD CUSTOMER FUNNEL STAGE TABLE
-- ============================================================================

CREATE OR REPLACE VIEW vw_customer_funnel AS
WITH customer_events AS (
    SELECT 
        customer_id,
        MAX(CASE WHEN event_type = 'signup' THEN event_date END) as signup_date,
        MAX(CASE WHEN event_type = 'trial_start' THEN event_date END) as trial_start_date,
        MAX(CASE WHEN event_type = 'activated' THEN event_date END) as activated_date,
        MAX(CASE WHEN event_type = 'churned' THEN event_date END) as churned_date,
        MAX(CASE WHEN event_type = 'signup' THEN source END) as acquisition_source
    FROM events
    GROUP BY customer_id
),
customer_subscription AS (
    SELECT 
        customer_id,
        MIN(start_date) as first_subscription_date,
        MAX(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as has_active_subscription
    FROM subscriptions
    GROUP BY customer_id
)
SELECT 
    ce.customer_id,
    c.segment,
    c.country,
    ce.acquisition_source,
    ce.signup_date,
    ce.trial_start_date,
    ce.activated_date,
    cs.first_subscription_date as paid_date,
    ce.churned_date,
    -- Funnel stage flags
    CASE WHEN ce.signup_date IS NOT NULL THEN 1 ELSE 0 END as reached_signup,
    CASE WHEN ce.trial_start_date IS NOT NULL THEN 1 ELSE 0 END as reached_trial,
    CASE WHEN ce.activated_date IS NOT NULL THEN 1 ELSE 0 END as reached_activated,
    CASE WHEN cs.first_subscription_date IS NOT NULL THEN 1 ELSE 0 END as reached_paid,
    CASE WHEN ce.churned_date IS NOT NULL THEN 1 ELSE 0 END as reached_churned,
    -- Current stage (most advanced stage reached)
    CASE 
        WHEN ce.churned_date IS NOT NULL THEN 'Churned'
        WHEN cs.first_subscription_date IS NOT NULL THEN 'Paid'
        WHEN ce.activated_date IS NOT NULL THEN 'Activated'
        WHEN ce.trial_start_date IS NOT NULL THEN 'Trial'
        WHEN ce.signup_date IS NOT NULL THEN 'Signup'
        ELSE 'Unknown'
    END as current_stage
FROM customer_events ce
LEFT JOIN customers c ON ce.customer_id = c.customer_id
LEFT JOIN customer_subscription cs ON ce.customer_id = cs.customer_id;

-- ============================================================================
-- SECTION 2: OVERALL FUNNEL METRICS
-- ============================================================================

SELECT 
    SUM(reached_signup) as total_signups,
    SUM(reached_trial) as total_trial_starts,
    SUM(reached_activated) as total_activated,
    SUM(reached_paid) as total_paid,
    SUM(reached_churned) as total_churned,
    
    -- Conversion rates
    ROUND(SUM(reached_trial) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as signup_to_trial_rate,
    ROUND(SUM(reached_activated) * 100.0 / NULLIF(SUM(reached_trial), 0), 2) as trial_to_activated_rate,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_activated), 0), 2) as activated_to_paid_rate,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as signup_to_paid_rate,
    
    -- Drop-off rates
    ROUND((SUM(reached_signup) - SUM(reached_trial)) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as dropoff_signup_to_trial,
    ROUND((SUM(reached_trial) - SUM(reached_activated)) * 100.0 / NULLIF(SUM(reached_trial), 0), 2) as dropoff_trial_to_activated,
    ROUND((SUM(reached_activated) - SUM(reached_paid)) * 100.0 / NULLIF(SUM(reached_activated), 0), 2) as dropoff_activated_to_paid
FROM vw_customer_funnel;

-- ============================================================================
-- SECTION 3: FUNNEL BY ACQUISITION SOURCE
-- ============================================================================

SELECT 
    acquisition_source,
    SUM(reached_signup) as signups,
    SUM(reached_trial) as trial_starts,
    SUM(reached_activated) as activated,
    SUM(reached_paid) as paid,
    SUM(reached_churned) as churned,
    
    -- Conversion rates
    ROUND(SUM(reached_trial) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as signup_to_trial_rate,
    ROUND(SUM(reached_activated) * 100.0 / NULLIF(SUM(reached_trial), 0), 2) as trial_to_activated_rate,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_activated), 0), 2) as activated_to_paid_rate,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as signup_to_paid_rate,
    
    -- Churn rate
    ROUND(SUM(reached_churned) * 100.0 / NULLIF(SUM(reached_paid), 0), 2) as churn_rate
FROM vw_customer_funnel
GROUP BY acquisition_source
ORDER BY signups DESC;

-- ============================================================================
-- SECTION 4: FUNNEL BY CUSTOMER SEGMENT
-- ============================================================================

SELECT 
    segment,
    SUM(reached_signup) as signups,
    SUM(reached_trial) as trial_starts,
    SUM(reached_activated) as activated,
    SUM(reached_paid) as paid,
    SUM(reached_churned) as churned,
    
    -- Conversion rates
    ROUND(SUM(reached_trial) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as signup_to_trial_rate,
    ROUND(SUM(reached_activated) * 100.0 / NULLIF(SUM(reached_trial), 0), 2) as trial_to_activated_rate,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_activated), 0), 2) as activated_to_paid_rate,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as signup_to_paid_rate
FROM vw_customer_funnel
GROUP BY segment
ORDER BY signups DESC;

-- ============================================================================
-- SECTION 5: FUNNEL BY COUNTRY
-- ============================================================================

SELECT 
    country,
    SUM(reached_signup) as signups,
    SUM(reached_trial) as trial_starts,
    SUM(reached_activated) as activated,
    SUM(reached_paid) as paid,
    
    -- Conversion rates
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as signup_to_paid_rate
FROM vw_customer_funnel
GROUP BY country
ORDER BY signups DESC;

-- ============================================================================
-- SECTION 6: TIME TO CONVERSION ANALYSIS
-- ============================================================================

SELECT 
    acquisition_source,
    COUNT(*) as customers,
    
    -- Average days between stages
    ROUND(AVG(DATEDIFF(trial_start_date, signup_date)), 1) as avg_days_signup_to_trial,
    ROUND(AVG(DATEDIFF(activated_date, trial_start_date)), 1) as avg_days_trial_to_activated,
    ROUND(AVG(DATEDIFF(paid_date, activated_date)), 1) as avg_days_activated_to_paid,
    ROUND(AVG(DATEDIFF(paid_date, signup_date)), 1) as avg_days_signup_to_paid
FROM vw_customer_funnel
WHERE paid_date IS NOT NULL
GROUP BY acquisition_source
ORDER BY customers DESC;

-- ============================================================================
-- SECTION 7: CURRENT STAGE DISTRIBUTION
-- ============================================================================

SELECT 
    current_stage,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM vw_customer_funnel), 2) as percentage
FROM vw_customer_funnel
GROUP BY current_stage
ORDER BY 
    CASE current_stage
        WHEN 'Signup' THEN 1
        WHEN 'Trial' THEN 2
        WHEN 'Activated' THEN 3
        WHEN 'Paid' THEN 4
        WHEN 'Churned' THEN 5
        ELSE 6
    END;

-- ============================================================================
-- SECTION 8: COHORT ANALYSIS BY SIGNUP MONTH
-- ============================================================================

SELECT 
    DATE_FORMAT(signup_date, '%Y-%m') as signup_month,
    COUNT(*) as total_signups,
    SUM(reached_trial) as converted_to_trial,
    SUM(reached_paid) as converted_to_paid,
    ROUND(SUM(reached_trial) * 100.0 / COUNT(*), 2) as trial_conversion_rate,
    ROUND(SUM(reached_paid) * 100.0 / COUNT(*), 2) as paid_conversion_rate
FROM vw_customer_funnel
WHERE signup_date IS NOT NULL
GROUP BY DATE_FORMAT(signup_date, '%Y-%m')
ORDER BY signup_month;

-- ============================================================================
-- SECTION 9: BEST AND WORST PERFORMING SOURCES
-- ============================================================================

-- Top 3 sources by paid conversion rate
SELECT 
    'Top Sources by Conversion' as category,
    acquisition_source,
    SUM(reached_signup) as signups,
    SUM(reached_paid) as paid_customers,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as conversion_rate
FROM vw_customer_funnel
GROUP BY acquisition_source
HAVING SUM(reached_signup) >= 10  -- Minimum sample size
ORDER BY conversion_rate DESC
LIMIT 3;

-- Bottom 3 sources by paid conversion rate
SELECT 
    'Bottom Sources by Conversion' as category,
    acquisition_source,
    SUM(reached_signup) as signups,
    SUM(reached_paid) as paid_customers,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as conversion_rate
FROM vw_customer_funnel
GROUP BY acquisition_source
HAVING SUM(reached_signup) >= 10  -- Minimum sample size
ORDER BY conversion_rate ASC
LIMIT 3;

-- ============================================================================
-- SECTION 10: FUNNEL VISUALIZATION DATA
-- ============================================================================
-- Data formatted for easy visualization in BI tools

SELECT 
    'Signup' as stage,
    1 as stage_order,
    SUM(reached_signup) as customers,
    100.00 as conversion_rate
FROM vw_customer_funnel

UNION ALL

SELECT 
    'Trial Start' as stage,
    2 as stage_order,
    SUM(reached_trial) as customers,
    ROUND(SUM(reached_trial) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as conversion_rate
FROM vw_customer_funnel

UNION ALL

SELECT 
    'Activated' as stage,
    3 as stage_order,
    SUM(reached_activated) as customers,
    ROUND(SUM(reached_activated) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as conversion_rate
FROM vw_customer_funnel

UNION ALL

SELECT 
    'Paid' as stage,
    4 as stage_order,
    SUM(reached_paid) as customers,
    ROUND(SUM(reached_paid) * 100.0 / NULLIF(SUM(reached_signup), 0), 2) as conversion_rate
FROM vw_customer_funnel

ORDER BY stage_order;

-- ============================================================================
-- END OF FUNNEL ANALYSIS SCRIPT
-- ============================================================================
