-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Gold Layer: Star Schema - Seller Dimension
-- Author: Ria Singh
-- ============================================================

USE olist_gold;

-- ============================================================
-- TABLE: dim_sellers
-- Grain: One row per seller_id
-- Purpose: Seller demographic and location attributes for analysis
--
-- DESIGN DECISIONS:
-- 1. Simple dimension: Direct copy from silver.sellers
--    - No transformations needed (already cleaned in silver)
--    - No deduplication needed (seller_id is already unique)
--
-- 2. Attributes included:
--    - seller_id: Primary key
--    - seller_zip_code_prefix: Postal code for geographic analysis
--    - seller_city: City name
--    - seller_state: State abbreviation (e.g., SP, RJ)
--
-- 3. Row count validation:
--    - Silver sellers: 3,095
--    - Gold dim_sellers: 3,095 (one-to-one mapping)
--
-- USAGE IN ANALYSIS:
-- - Seller performance by location (state, city)
-- - Geographic distribution of sellers
-- - Supply vs demand analysis (seller locations vs customer locations)
-- - Joins to fact_order_items (future) for item-level seller analysis
--
-- NOTE: At order-level grain (fact_orders), seller data is not directly
-- joined because one order can have items from multiple sellers.
-- Seller analysis requires item-level fact table (future enhancement).
-- ============================================================

CREATE TABLE dim_sellers AS
SELECT 
    -- Primary key
    seller_id,
    
    -- Location attributes
    seller_zip_code_prefix,
    seller_city,
    seller_state
    
FROM olist_silver.sellers;


-- ============================================================
-- VALIDATION: Confirm uniqueness and row count
-- ============================================================
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS unique_sellers,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT seller_id) THEN 'PASS: All unique'
        ELSE 'FAIL: Duplicates exist'
    END AS validation_status
FROM dim_sellers;

-- Expected: total_rows = unique_sellers = 3,095


-- ============================================================
-- SUMMARY STATISTICS
-- ============================================================
SELECT 
    COUNT(*) AS total_sellers,
    COUNT(DISTINCT seller_state) AS unique_states,
    COUNT(DISTINCT seller_city) AS unique_cities,
    COUNT(DISTINCT seller_zip_code_prefix) AS unique_zip_codes
FROM dim_sellers;

-- Geographic distribution of sellers
SELECT 
    seller_state,
    COUNT(*) AS seller_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM dim_sellers
GROUP BY seller_state
ORDER BY seller_count DESC
LIMIT 10;
