-- ============================================================================
-- 02_data_cleaning.sql
-- Purpose: Identify and clean data quality issues
-- Author: Data Analyst Assessment
-- Date: 2026-01-29
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATA QUALITY ASSESSMENT
-- ============================================================================

-- Check for duplicate customers
SELECT 
    customer_id, 
    COUNT(*) as count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
-- Expected: 0 duplicates found

-- Check for missing values in customers
SELECT 
    COUNT(*) as total_records,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) as missing_customer_id,
    SUM(CASE WHEN signup_date IS NULL THEN 1 ELSE 0 END) as missing_signup_date,
    SUM(CASE WHEN segment IS NULL THEN 1 ELSE 0 END) as missing_segment,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) as missing_country
FROM customers;
-- Issues identified: 36 missing signup_date, 243 missing segment

-- Check for missing values in subscriptions
SELECT 
    COUNT(*) as total_records,
    SUM(CASE WHEN end_date IS NULL THEN 1 ELSE 0 END) as missing_end_date
FROM subscriptions;
-- Note: NULL end_date is expected for active subscriptions

-- Verify subscription status vs end_date consistency
SELECT 
    status,
    COUNT(*) as total,
    SUM(CASE WHEN end_date IS NULL THEN 1 ELSE 0 END) as null_end_date,
    SUM(CASE WHEN end_date IS NOT NULL THEN 1 ELSE 0 END) as has_end_date
FROM subscriptions
GROUP BY status;
-- Expected: active subscriptions should have NULL end_date

-- Check for duplicate events (same customer, event_type, date)
SELECT 
    customer_id,
    event_type,
    event_date,
    source,
    COUNT(*) as event_count
FROM events
GROUP BY customer_id, event_type, event_date, source
HAVING COUNT(*) > 1
ORDER BY event_count DESC;
-- Issue identified: ~94 duplicate events found

-- ============================================================================
-- SECTION 2: DATA CLEANING OPERATIONS
-- ============================================================================

-- ============================================================================
-- ASSUMPTION 1: Missing Segment Values
-- Decision: Label missing segments as 'Unknown' for analysis purposes
-- Justification: We need to track these customers but cannot assign them to
--                a specific segment without business context
-- ============================================================================
UPDATE customers
SET segment = 'Unknown'
WHERE segment IS NULL;

-- ============================================================================
-- ASSUMPTION 2: Missing Signup Dates
-- Decision: For customers with subscriptions, use subscription start_date - 3 days
--           as estimated signup date. For others, set to NULL and exclude from
--           time-based cohort analysis
-- Justification: Customers typically sign up before subscribing, 3 days is a
--                reasonable trial period assumption based on data
-- ============================================================================
UPDATE customers c
LEFT JOIN (
    SELECT 
        customer_id,
        MIN(start_date) as first_subscription_date
    FROM subscriptions
    GROUP BY customer_id
) s ON c.customer_id = s.customer_id
SET c.signup_date = DATE_SUB(s.first_subscription_date, INTERVAL 3 DAY)
WHERE c.signup_date IS NULL 
  AND s.first_subscription_date IS NOT NULL;

-- ============================================================================
-- ASSUMPTION 3: Duplicate Events
-- Decision: Keep only the first occurrence of duplicate events (lowest event_id)
-- Justification: Duplicate events are likely system errors or double-tracking.
--                We keep the first recorded instance as the source of truth.
-- ============================================================================
-- Create temporary table with event_ids to keep
CREATE TEMPORARY TABLE events_to_keep AS
SELECT MIN(event_id) as event_id
FROM events
GROUP BY customer_id, event_type, event_date, source;

-- Delete duplicate events
DELETE FROM events
WHERE event_id NOT IN (SELECT event_id FROM events_to_keep);

-- Drop temporary table
DROP TEMPORARY TABLE events_to_keep;

-- ============================================================================
-- ASSUMPTION 4: Subscription Status Validation
-- Decision: If a subscription has status='active' but has an end_date,
--           change status to 'canceled'
-- Justification: end_date indicates the subscription has ended
-- ============================================================================
UPDATE subscriptions
SET status = 'canceled'
WHERE status = 'active' AND end_date IS NOT NULL;

-- ============================================================================
-- ASSUMPTION 5: Multiple Subscriptions Per Customer
-- Decision: Allow multiple subscriptions per customer
-- Justification: Customers may upgrade/downgrade plans or have churned and
--                returned (winback scenarios)
-- Note: For MRR calculations, we'll use the most recent active subscription
-- ============================================================================
-- No action needed, just documenting the decision

-- ============================================================================
-- SECTION 3: CREATE CLEANED VIEWS FOR ANALYSIS
-- ============================================================================

-- Create a view with cleaned customer data
CREATE OR REPLACE VIEW vw_customers_clean AS
SELECT 
    customer_id,
    signup_date,
    segment,
    country,
    is_enterprise,
    CASE 
        WHEN signup_date IS NULL THEN 'No Signup Date'
        ELSE 'Has Signup Date'
    END as signup_date_status
FROM customers;

-- Create a view with active subscriptions only
CREATE OR REPLACE VIEW vw_active_subscriptions AS
SELECT *
FROM subscriptions
WHERE status = 'active';

-- Create a view with the latest subscription per customer
CREATE OR REPLACE VIEW vw_latest_subscription_per_customer AS
SELECT s.*
FROM subscriptions s
INNER JOIN (
    SELECT 
        customer_id,
        MAX(start_date) as latest_start_date
    FROM subscriptions
    GROUP BY customer_id
) latest ON s.customer_id = latest.customer_id 
        AND s.start_date = latest.latest_start_date;

-- ============================================================================
-- SECTION 4: VALIDATION QUERIES
-- ============================================================================

-- Verify cleaning results
SELECT 'Customers with NULL segment' as check_name, COUNT(*) as count
FROM customers WHERE segment IS NULL
UNION ALL
SELECT 'Customers with NULL signup_date', COUNT(*)
FROM customers WHERE signup_date IS NULL
UNION ALL
SELECT 'Duplicate events remaining', COUNT(*)
FROM (
    SELECT customer_id, event_type, event_date, source, COUNT(*) as cnt
    FROM events
    GROUP BY customer_id, event_type, event_date, source
    HAVING COUNT(*) > 1
) dups
UNION ALL
SELECT 'Active subscriptions with end_date', COUNT(*)
FROM subscriptions WHERE status = 'active' AND end_date IS NOT NULL;

-- Summary statistics after cleaning
SELECT 
    'Total Customers' as metric,
    COUNT(*) as value
FROM customers
UNION ALL
SELECT 'Total Subscriptions', COUNT(*)
FROM subscriptions
UNION ALL
SELECT 'Total Events', COUNT(*)
FROM events
UNION ALL
SELECT 'Active Subscriptions', COUNT(*)
FROM subscriptions WHERE status = 'active'
UNION ALL
SELECT 'Canceled Subscriptions', COUNT(*)
FROM subscriptions WHERE status = 'canceled';

-- ============================================================================
-- END OF DATA CLEANING SCRIPT
-- ============================================================================
