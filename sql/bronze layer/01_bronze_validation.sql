-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Bronze Layer Validation Queries
-- Purpose: Validate raw CSV data loaded correctly into bronze tables
-- Author: Ria Singh
-- ============================================================

USE olist_bronze;

-- ============================================================
-- SECTION 1: ROW COUNT VALIDATION
-- Confirms CSV files loaded with expected row counts
-- ============================================================

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM product_category_translation;

-- Expected approximate counts for reference:
-- customers:                    ~99,441
-- geolocation:                  ~1,000,163 (large, has duplicates - expected)
-- order_items:                  ~112,650
-- order_payments:               ~103,886
-- order_reviews:                ~99,224 (Note: order_reviews raw count was 99,234 vs expected 99,224. 10 extra rows identified during bronze ingestion due to embedded newlines in review_comment_message. It will be deduplicated in silver on review_id.)
-- orders:                       ~99,441
-- products:                     ~32,951
-- sellers:                      ~3,095
-- product_category_translation: ~71


-- ============================================================
-- SECTION 2: SAMPLE DATA INSPECTION
-- Quick look at first few rows to confirm data loaded properly
-- ============================================================

-- Sample customers
SELECT * FROM customers LIMIT 5;

-- Sample orders
SELECT * FROM orders LIMIT 5;

-- Sample products (check for Portuguese category names)
SELECT * FROM products LIMIT 5;


-- ============================================================
-- SECTION 3: DATA QUALITY ISSUES IN BRONZE
-- Bronze is raw - these queries document known issues to fix in silver
-- ============================================================

-- Issue 1: Date columns are VARCHAR (need casting in silver)
SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'olist_bronze'
  AND TABLE_NAME = 'orders'
  AND (COLUMN_NAME LIKE '%date%' OR COLUMN_NAME LIKE '%timestamp%');
-- Expected: All show 'varchar' - this is correct for bronze


-- Issue 2: Product dimensions are VARCHAR (contain empty strings)
SELECT COUNT(*) AS empty_product_dimensions
FROM products
WHERE product_name_length = '' 
   OR product_weight_g = ''
   OR product_length_cm = '';
-- Expected: Some rows - these need NULLIF handling in silver


-- Issue 3: Geolocation has many duplicate zip codes
SELECT 
    geolocation_zip_code_prefix,
    COUNT(*) as occurrence_count
FROM geolocation
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC
LIMIT 10;
-- Expected: Many duplicates - will deduplicate in silver


-- Issue 4: Some review comments had embedded newlines (fixed via Python preprocessing)
SELECT COUNT(*) AS rows_with_newlines
FROM order_reviews
WHERE review_comment_message LIKE '%\n%'
   OR review_comment_message LIKE '%\r%';
-- Expected: 0 after using cleaned CSV

-- multiple review ids with same review creation time for different order ids( not possible, will fix it in silver)
SELECT 
    review_id,
    COUNT(*) AS review_count,
    GROUP_CONCAT(order_id) AS order_ids,
    GROUP_CONCAT(review_score) AS review_scores
FROM olist_bronze.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC;

-- ============================================================
-- SECTION 4: NULL VALUE ANALYSIS
-- Document NULL patterns in bronze for transparency
-- ============================================================

-- NULL analysis in orders
SELECT 
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_approved_at IS NULL OR order_approved_at = '' THEN 1 ELSE 0 END) AS null_approved,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL OR order_delivered_carrier_date = '' THEN 1 ELSE 0 END) AS null_carrier,
    SUM(CASE WHEN order_delivered_customer_date IS NULL OR order_delivered_customer_date = '' THEN 1 ELSE 0 END) AS null_delivered
FROM orders;
-- Expected: Many NULLs for cancelled/processing orders - this is normal


-- NULL analysis in products
SELECT 
    COUNT(*) AS total_products,
    SUM(CASE WHEN product_category_name IS NULL OR product_category_name = '' THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN product_weight_g IS NULL OR product_weight_g = '' THEN 1 ELSE 0 END) AS null_weight
FROM products;
-- Expected: Some NULLs - products may have incomplete metadata


-- ============================================================
-- END OF VALIDATION
-- Bronze layer is intentionally messy - all issues documented above
-- will be addressed in silver layer transformations
-- ============================================================
