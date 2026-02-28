-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Gold Layer: Star Schema - Customer Dimension
-- Author: Ria Singh
-- ============================================================

USE olist_gold;

-- ============================================================
-- TABLE: dim_customers
-- Grain: One row per customer_unique_id (actual person)
-- Purpose: Customer demographic and location attributes for analysis
--
-- DESIGN DECISIONS:
-- 1. Primary key: customer_unique_id (not customer_id)
--    - customer_id changes with each order (99,441 total)
--    - customer_unique_id identifies the person (96,096 unique)
--    - This allows proper customer lifetime value and retention analysis
--
-- 2. Address handling: Customers who ordered from multiple cities (moved?)
--    - Solution: Keep most recent address based on last order_purchase_timestamp
--    - Rationale: Business questions focus on "where is customer NOW"
--    - Historical addresses preserved in silver.customers if needed
--
-- 3. Row count validation:
--    - Silver customers: 99,441 (order-level)
--    - Gold dim_customers: 96,096 (person-level)
--    - Difference: 3,345 repeat customers
--    - Average orders per customer: 1.03 (low repeat rate)
--
-- USAGE IN ANALYSIS:
-- - Customer segmentation by location (state, city)
-- - Geographic performance analysis
-- - Customer acquisition tracking
-- - Joins to fact_orders on customer_id
-- ============================================================

CREATE TABLE dim_customers AS
SELECT 
    -- Primary key
    customer_unique_id,
    
    -- Location attributes (most recent address)
    customer_zip_code_prefix,
    customer_city,
    customer_state
    
FROM (
    SELECT 
        c.customer_unique_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state,
        -- Rank addresses by recency, keep most recent
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp DESC
        ) AS rn
    FROM olist_silver.customers c
    JOIN olist_silver.orders o 
        ON c.customer_id = o.customer_id
) ranked
WHERE rn = 1;


-- ============================================================
-- VALIDATION: Confirm uniqueness and row count
-- ============================================================
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT customer_unique_id) THEN 'PASS: All unique'
        ELSE 'FAIL: Duplicates exist'
    END AS validation_status
FROM dim_customers;

-- Expected: total_rows = unique_customers = 96,096


-- ============================================================
-- SUMMARY STATISTICS
-- ============================================================
SELECT 
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_state) AS unique_states,
    COUNT(DISTINCT customer_city) AS unique_cities,
    COUNT(DISTINCT customer_zip_code_prefix) AS unique_zip_codes
FROM dim_customers;

-- Geographic distribution
SELECT 
    customer_state,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM dim_customers
GROUP BY customer_state
ORDER BY customer_count DESC
LIMIT 10;
