-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Gold Layer: Star Schema - Date Dimension
-- Author: Ria Singh
-- ============================================================

USE olist_gold;

-- ============================================================
-- TABLE: dim_date
-- Grain: One row per calendar date
-- Purpose: Date attributes for time-based analysis and drill-down
--
-- DESIGN DECISIONS:
-- 1. Date range: 2016-01-01 to 2018-12-31 (3 full years)
--    - Actual order data: 2016-09-04 to 2018-10-17
--    - Extended to full years for complete year-over-year comparison
--    - Total: 1,096 days
--
-- 2. Generation method: Recursive CTE
--    - Generates all dates programmatically (no manual insert needed)
--    - Increases @@cte_max_recursion_depth to 2000 to handle 1,096 iterations
--
-- 3. Attributes included:
--    - date_key: Primary key (DATE type for direct joins)
--    - year, quarter, month, day: Numeric components for calculations
--    - month_name, day_of_week_name: Text labels for display
--    - is_weekend: Boolean flag for weekday/weekend segmentation
--    - month_year: YYYY-MM format for monthly grouping
--
-- 4. Day of week convention:
--    - 1 = Sunday, 7 = Saturday (MySQL DAYOFWEEK default)
--    - is_weekend = TRUE for Sunday (1) and Saturday (7)
--
-- USAGE IN ANALYSIS:
-- - Time series analysis (daily, monthly, quarterly trends)
-- - Year-over-year comparisons
-- - Seasonality analysis
-- - Weekday vs weekend performance
-- - Drill-down hierarchies: Year → Quarter → Month → Day
-- - Joins to fact_orders on order_purchase_timestamp or order_delivered_customer_date
--
-- POWER BI NOTE: Create date hierarchy in Power BI model:
-- Year → Quarter → Month → Date for interactive drill-down visuals
-- ============================================================

-- Increase recursion depth to generate 1,096 dates
SET SESSION cte_max_recursion_depth = 2000;

CREATE TABLE dim_date AS
WITH RECURSIVE date_range AS (
    -- Start date: January 1, 2016
    SELECT DATE('2016-01-01') AS date_key
    
    UNION ALL
    
    -- Recursively generate all dates by adding 1 day
    SELECT DATE_ADD(date_key, INTERVAL 1 DAY)
    FROM date_range
    WHERE date_key < DATE('2018-12-31')
)
SELECT 
    -- Primary key
    date_key,
    
    -- Date components for grouping and calculations
    YEAR(date_key) AS year,
    QUARTER(date_key) AS quarter,
    MONTH(date_key) AS month,
    DAY(date_key) AS day,
    
    -- Text labels for display
    MONTHNAME(date_key) AS month_name,
    DAYOFWEEK(date_key) AS day_of_week,          -- 1=Sunday, 7=Saturday
    DAYNAME(date_key) AS day_of_week_name,
    
    -- Flags for segmentation
    CASE 
        WHEN DAYOFWEEK(date_key) IN (1, 7) THEN TRUE 
        ELSE FALSE 
    END AS is_weekend,
    
    -- Composite labels for grouping
    DATE_FORMAT(date_key, '%Y-%m') AS month_year  -- Format: 2016-09
    
FROM date_range;


-- ============================================================
-- VALIDATION: Confirm row count and date range
-- ============================================================
SELECT 
    COUNT(*) AS total_days,
    MIN(date_key) AS start_date,
    MAX(date_key) AS end_date,
    DATEDIFF(MAX(date_key), MIN(date_key)) + 1 AS expected_days,
    CASE 
        WHEN COUNT(*) = DATEDIFF(MAX(date_key), MIN(date_key)) + 1 THEN 'PASS: No gaps'
        ELSE 'FAIL: Missing dates'
    END AS validation_status
FROM dim_date;

-- Expected: total_days = 1,096 (2016-01-01 to 2018-12-31)


-- ============================================================
-- SUMMARY STATISTICS
-- ============================================================
SELECT 
    COUNT(*) AS total_days,
    COUNT(DISTINCT year) AS unique_years,
    COUNT(CASE WHEN is_weekend = TRUE THEN 1 END) AS weekend_days,
    COUNT(CASE WHEN is_weekend = FALSE THEN 1 END) AS weekday_days,
    ROUND(COUNT(CASE WHEN is_weekend = TRUE THEN 1 END) * 100.0 / COUNT(*), 2) AS weekend_percentage
FROM dim_date;

-- Date distribution by year
SELECT 
    year,
    COUNT(*) AS days_in_year
FROM dim_date
GROUP BY year
ORDER BY year;

-- Date distribution by quarter
SELECT 
    year,
    quarter,
    COUNT(*) AS days_in_quarter
FROM dim_date
GROUP BY year, quarter
ORDER BY year, quarter;
