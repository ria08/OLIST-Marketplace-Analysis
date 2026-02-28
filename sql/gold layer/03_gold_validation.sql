-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Gold Layer Validation Queries
-- Purpose: Validate star schema integrity, joins, and data quality
-- Author: Ria Singh
-- ============================================================

USE olist_gold;

-- ============================================================
-- SECTION 1: TABLE ROW COUNTS
-- Confirms all tables loaded correctly
-- ============================================================

SELECT 'fact_orders' AS table_name, COUNT(*) AS row_count FROM fact_orders
UNION ALL
SELECT 'dim_customers', COUNT(*) FROM dim_customers
UNION ALL
SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL
SELECT 'dim_sellers', COUNT(*) FROM dim_sellers
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date;

-- Expected counts:
-- fact_orders:    99,441
-- dim_customers:  96,096
-- dim_products:   32,951
-- dim_sellers:     3,095
-- dim_date:        1,096


-- ============================================================
-- SECTION 2: PRIMARY KEY UNIQUENESS
-- Confirms no duplicate primary keys in any table
-- ============================================================

-- Check fact_orders (order_id should be unique)
SELECT 
    'fact_orders' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_keys,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'PASS'
        ELSE 'FAIL: Duplicates exist'
    END AS validation_status
FROM fact_orders

UNION ALL

-- Check dim_customers (customer_unique_id should be unique)
SELECT 
    'dim_customers',
    COUNT(*),
    COUNT(DISTINCT customer_unique_id),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT customer_unique_id) THEN 'PASS'
        ELSE 'FAIL: Duplicates exist'
    END
FROM dim_customers

UNION ALL

-- Check dim_products (product_id should be unique)
SELECT 
    'dim_products',
    COUNT(*),
    COUNT(DISTINCT product_id),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT product_id) THEN 'PASS'
        ELSE 'FAIL: Duplicates exist'
    END
FROM dim_products

UNION ALL

-- Check dim_sellers (seller_id should be unique)
SELECT 
    'dim_sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT seller_id) THEN 'PASS'
        ELSE 'FAIL: Duplicates exist'
    END
FROM dim_sellers

UNION ALL

-- Check dim_date (date_key should be unique)
SELECT 
    'dim_date',
    COUNT(*),
    COUNT(DISTINCT date_key),
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT date_key) THEN 'PASS'
        ELSE 'FAIL: Duplicates exist'
    END
FROM dim_date;

-- Expected: All tables show PASS


-- ============================================================
-- SECTION 3: REFERENTIAL INTEGRITY (STAR SCHEMA JOINS)
-- Validates that fact table keys properly reference dimensions
-- ============================================================

-- Check 1: Orders with missing customers in dim_customers
-- Should return 0 (all orders should have a matching customer)
SELECT COUNT(*) AS orders_without_customer
FROM fact_orders f
LEFT JOIN dim_customers d ON f.customer_unique_id = d.customer_unique_id
WHERE d.customer_unique_id IS NULL;
-- Expected: 0


-- Check 2: Validate date references exist in dim_date
-- Orders should have valid purchase and delivery dates
SELECT 
    COUNT(*) AS orders_with_missing_purchase_date
FROM fact_orders f
LEFT JOIN dim_date d ON DATE(f.order_purchase_timestamp) = d.date_key
WHERE d.date_key IS NULL;
-- Expected: 0 (all purchase dates should be in dim_date range)



SELECT 
    COUNT(*) AS orders_with_missing_delivery_date
FROM fact_orders f
LEFT JOIN dim_date d ON DATE(f.order_delivered_customer_date) = d.date_key
WHERE d.date_key IS NULL 
  AND f.order_delivered_customer_date IS NOT NULL;
-- Expected: 0 or close to 0 (delivered orders should have valid dates)


-- ============================================================
-- SECTION 4: STAR SCHEMA JOIN TEST
-- Confirms all dimensions can be joined to fact table correctly
-- ============================================================

-- Sample query: Revenue by customer state and product category
-- This query tests if star schema joins work end-to-end
SELECT 
    c.customer_state,
    p.product_category_name,
    COUNT(DISTINCT f.order_id) AS order_count,
    ROUND(SUM(f.order_revenue), 2) AS total_revenue,
    ROUND(AVG(f.order_revenue), 2) AS avg_order_value
FROM fact_orders f
JOIN dim_customers c ON f.customer_unique_id = c.customer_unique_id
JOIN dim_date d ON DATE(f.order_purchase_timestamp) = d.date_key
LEFT JOIN olist_silver.order_items oi ON f.order_id = oi.order_id
LEFT JOIN dim_products p ON oi.product_id = p.product_id
WHERE d.year = 2017
GROUP BY c.customer_state, p.product_category_name
HAVING order_count > 10
ORDER BY total_revenue DESC
LIMIT 10;

-- If this query runs without errors and returns results, star schema is working


-- ============================================================
-- SECTION 5: DATA QUALITY CHECKS
-- Business logic validation on calculated metrics
-- ============================================================

-- Check 1: No negative revenue or freight values
SELECT COUNT(*) AS negative_revenue_orders
FROM fact_orders
WHERE order_revenue < 0 OR order_freight < 0;
-- Expected: 0


-- Check 2: Delivery time should be positive for delivered orders
SELECT COUNT(*) AS invalid_delivery_time
FROM fact_orders
WHERE delivery_time_days < 0
  AND order_delivered_customer_date IS NOT NULL;
-- Expected: 0 (can't deliver before purchase)


-- Check 3: Review scores should be between 1 and 5
SELECT COUNT(*) AS invalid_review_scores
FROM fact_orders
WHERE review_score NOT BETWEEN 1 AND 5
  AND review_score IS NOT NULL;
-- Expected: 0


-- Check 4: Payment value should match or be close to order revenue
-- Small differences expected due to vouchers/discounts
SELECT 
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN ABS(payment_value - order_revenue) > 100 THEN 1 END) AS large_discrepancies,
    ROUND(AVG(ABS(payment_value - order_revenue)), 2) AS avg_difference
FROM fact_orders
WHERE payment_value > 0 AND order_revenue > 0;
-- Large discrepancies should be minimal


-- ============================================================
-- SECTION 6: SUMMARY STATISTICS
-- High-level business metrics to understand the dataset
-- ============================================================

SELECT 
    -- Order metrics
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    ROUND(COUNT(DISTINCT order_id) * 1.0 / COUNT(DISTINCT customer_unique_id), 2) AS avg_orders_per_customer,
    
    -- Revenue metrics
    ROUND(SUM(order_revenue), 2) AS total_revenue,
    ROUND(AVG(order_revenue), 2) AS avg_order_value,
    ROUND(MIN(order_revenue), 2) AS min_order_value,
    ROUND(MAX(order_revenue), 2) AS max_order_value,
    
    -- Delivery metrics
    ROUND(AVG(delivery_time_days), 1) AS avg_delivery_days,
    COUNT(CASE WHEN delivery_delay_days > 0 THEN 1 END) AS late_deliveries,
    COUNT(CASE WHEN delivery_delay_days <= 0 THEN 1 END) AS ontime_early_deliveries,
    ROUND(COUNT(CASE WHEN delivery_delay_days > 0 THEN 1 END) * 100.0 / COUNT(*), 2) AS late_delivery_rate,
    
    -- Review metrics
    COUNT(CASE WHEN review_score IS NOT NULL THEN 1 END) AS orders_with_reviews,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM fact_orders;












-- ============================================================
-- SECTION 7: DIMENSION COVERAGE
-- Checks how many distinct dimension values are actually used
-- ============================================================

-- Customer dimension usage
SELECT 
    'dim_customers' AS dimension,
    COUNT(DISTINCT customer_unique_id) AS total_in_dimension,
    (SELECT COUNT(DISTINCT customer_unique_id) FROM fact_orders) AS used_in_fact,
    ROUND((SELECT COUNT(DISTINCT customer_unique_id) FROM fact_orders) * 100.0 / 
          COUNT(DISTINCT customer_unique_id), 2) AS coverage_percentage
FROM dim_customers

UNION ALL

-- Product dimension usage (via order_items)
SELECT 
    'dim_products',
    COUNT(DISTINCT product_id),
    (SELECT COUNT(DISTINCT product_id) FROM olist_silver.order_items),
    ROUND((SELECT COUNT(DISTINCT product_id) FROM olist_silver.order_items) * 100.0 / 
          COUNT(DISTINCT product_id), 2)
FROM dim_products

UNION ALL

-- Seller dimension usage (via order_items)
SELECT 
    'dim_sellers',
    COUNT(DISTINCT seller_id),
    (SELECT COUNT(DISTINCT seller_id) FROM olist_silver.order_items),
    ROUND((SELECT COUNT(DISTINCT seller_id) FROM olist_silver.order_items) * 100.0 / 
          COUNT(DISTINCT seller_id), 2)
FROM dim_sellers

UNION ALL

-- Date dimension usage
SELECT 
    'dim_date',
    COUNT(DISTINCT date_key),
    (SELECT COUNT(DISTINCT DATE(order_purchase_timestamp)) FROM fact_orders),
    ROUND((SELECT COUNT(DISTINCT DATE(order_purchase_timestamp)) FROM fact_orders) * 100.0 / 
          COUNT(DISTINCT date_key), 2)
FROM dim_date;


-- ============================================================
-- END OF VALIDATION
-- If all checks pass, gold layer is ready for analytics and BI
-- ============================================================
