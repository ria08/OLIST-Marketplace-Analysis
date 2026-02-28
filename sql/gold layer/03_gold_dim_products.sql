-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Gold Layer: Star Schema - Product Dimension
-- Author: Ria Singh
-- ============================================================

USE olist_gold;

-- ============================================================
-- TABLE: dim_products
-- Grain: One row per product_id
-- Purpose: Product attributes for filtering and grouping in analysis
--
-- DESIGN DECISIONS:
-- 1. Category names: English only (translated in silver layer)
--    - Original Portuguese categories mapped via product_category_translation
--    - Unmapped categories labeled as 'unknown'
--
-- 2. Attributes included:
--    - product_category_name_english: Primary grouping dimension
--    - product_weight_g: Secondary attribute for freight analysis
--
-- 3. Attributes excluded:
--    - product_name_length, product_description_length, product_photos_qty
--      → Metadata about listings, not useful for business analysis
--    - product_length_cm, height_cm, width_cm
--      → Dimensional data rarely used; weight sufficient for size proxy
--
-- 4. Row count validation:
--    - Silver products: 32,951
--    - Gold dim_products: 32,951 (one-to-one, no deduplication needed)
--
-- USAGE IN ANALYSIS:
-- - Product category performance (revenue by category)
-- - Weight vs freight cost correlation
-- - Product mix analysis
-- - Joins to fact_order_items (future) for item-level analysis
-- ============================================================

CREATE TABLE dim_products AS
SELECT 
    -- Primary key
    product_id,
    
    -- Product attributes
    product_category_name_english,
    product_weight_g
    
FROM olist_silver.products;


-- ============================================================
-- VALIDATION: Confirm uniqueness and row count
-- ============================================================
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_products,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT product_id) THEN 'PASS: All unique'
        ELSE 'FAIL: Duplicates exist'
    END AS validation_status
FROM dim_products;

-- Expected: total_rows = unique_products = 32,951


-- ============================================================
-- SUMMARY STATISTICS
-- ============================================================
SELECT 
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_category_name_english) AS unique_categories,
    COUNT(CASE WHEN product_category_name_english = 'unknown' THEN 1 END) AS uncategorized_products,
    ROUND(AVG(product_weight_g), 2) AS avg_weight_g,
    MIN(product_weight_g) AS min_weight_g,
    MAX(product_weight_g) AS max_weight_g
FROM dim_products;

-- Top product categories by count
SELECT 
    product_category_name_english,
    COUNT(*) AS product_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM dim_products
GROUP BY product_category_name_english
ORDER BY product_count DESC
LIMIT 10;
