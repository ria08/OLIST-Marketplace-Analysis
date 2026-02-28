-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Silver Layer Validation Queries
-- Purpose: Validate data quality, referential integrity, and transformation accuracy
-- Author: Ria Singh
-- ============================================================

USE olist_silver;

-- ============================================================
-- SECTION 1: ROW COUNT VALIDATION
-- Confirms all tables loaded successfully from bronze to silver
-- ============================================================

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM product_category_translation;

-- Expected counts (approximate):
-- customers:                    ~99,441
-- sellers:                      ~3,095
-- products:                     ~32,951
-- orders:                       ~99,441
-- order_items:                  ~112,650
-- order_payments:               ~103,886
-- order_reviews:                ~98,400 (deduplicated from ~99,224)
-- geolocation:                  ~19,015 (deduplicated from ~1,000,163)
-- product_category_translation: ~71


-- ============================================================
-- SECTION 2: REFERENTIAL INTEGRITY CHECKS
-- Validates foreign key relationships between tables
-- All queries should return 0 rows if data is clean
-- ============================================================

-- Check 1: Orders without matching customers
-- Impact: Orders can't be analyzed without customer information
SELECT COUNT(*) AS orphan_orders
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
-- Expected: 0


-- Check 2: Order items without matching orders
-- Impact: Order items would be unattached to any order context
SELECT COUNT(*) AS orphan_order_items
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Expected: 0


-- Check 3: Order items without matching products
-- Impact: Can't analyze what was sold if product doesn't exist
SELECT COUNT(*) AS orphan_items_no_product
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
-- Expected: 0


-- Check 4: Order items without matching sellers
-- Impact: Can't attribute sales to sellers
SELECT COUNT(*) AS orphan_items_no_seller
FROM order_items oi
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;
-- Expected: 0


-- Check 5: Order payments without matching orders
-- Impact: Payments can't be reconciled to orders
SELECT COUNT(*) AS orphan_payments
FROM order_payments op
LEFT JOIN orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Expected: 0


-- Check 6: Order reviews without matching orders
-- Impact: Reviews can't be tied back to purchase context
SELECT COUNT(*) AS orphan_reviews
FROM order_reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Expected: 0


-- ============================================================
-- SECTION 3: DATA TYPE VALIDATION
-- Confirms transformations from VARCHAR to proper types succeeded
-- ============================================================

-- Check date columns are now DATETIME (not VARCHAR)
SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'olist_silver'
  AND TABLE_NAME = 'orders'
  AND (COLUMN_NAME LIKE '%date%' OR COLUMN_NAME LIKE '%timestamp%');
-- All should show 'datetime' as DATA_TYPE


-- Check zip codes are now numeric (INT/UNSIGNED)
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'olist_silver'
  AND COLUMN_NAME LIKE '%zip_code%';
-- Should show numeric type (bigint unsigned or int unsigned) as DATA_TYPE


-- ============================================================
-- SECTION 4: NULL CHECKS ON KEY COLUMNS
-- Ensures critical columns have no NULL values after filtering
-- ============================================================

-- Check orders table
SELECT 
    'orders' AS table_name,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id
FROM orders;
-- Both should be 0


-- Check order_items table
SELECT 
    'order_items' AS table_name,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS null_seller_id
FROM order_items;
-- All should be 0


-- ============================================================
-- SECTION 5: DEDUPLICATION VALIDATION
-- Confirms duplicates were removed properly
-- ============================================================

-- Check for duplicate review_ids (should be 0 after DISTINCT)
SELECT review_id, COUNT(*) as duplicate_count
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows returned
-- Note: Bronze had 789 review_ids with duplicates (814 total duplicate rows).
-- Duplicates had identical timestamps and content but different order_ids,
-- indicating a data quality issue in the source. Resolved in silver layer.


-- Check for duplicate zip codes in geolocation (should be 0 after ROW_NUMBER)
SELECT geolocation_zip_code_prefix, COUNT(*) as duplicate_count
FROM geolocation
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1;
-- Expected: 0 rows returned


-- ============================================================
-- SECTION 6: BUSINESS LOGIC VALIDATION
-- Sanity checks on data that should follow business rules
-- ============================================================

-- Check for negative prices or freight (should be 0)
SELECT COUNT(*) AS negative_price_count
FROM order_items
WHERE price < 0 OR freight_value < 0;
-- Expected: 0


-- Check for review scores outside 1-5 range (should be 0)
SELECT COUNT(*) AS invalid_review_score
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;
-- Expected: 0


-- Check for orders with purchase date after delivery date (data quality issue)
SELECT COUNT(*) AS invalid_order_dates
FROM orders
WHERE order_purchase_timestamp > order_delivered_customer_date
  AND order_delivered_customer_date IS NOT NULL;
-- Expected: close to 0 (may have a few edge cases)


-- ============================================================
-- END OF VALIDATION
-- If all checks pass, silver layer is ready for gold transformation
-- ============================================================

SELECT 
    order_id,
    COUNT(review_id) AS review_count,
    GROUP_CONCAT(review_id) AS review_ids,
    GROUP_CONCAT(review_score) AS review_scores
FROM olist_silver.order_reviews
GROUP BY order_id
HAVING COUNT(review_id) > 1
ORDER BY review_count DESC;

SELECT COUNT(*) FROM olist_gold.fact_orders;