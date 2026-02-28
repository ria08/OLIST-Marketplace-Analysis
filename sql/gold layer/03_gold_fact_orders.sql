-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Gold Layer: Star Schema - Fact Table
-- Author: Ria Singh
-- ============================================================

CREATE DATABASE IF NOT EXISTS olist_gold;
USE olist_gold;

-- ============================================================
-- TABLE: fact_orders
-- Grain: One row per order_id (order-level analysis)
-- Purpose: Central fact table for order analytics including revenue,
--          delivery performance, payment details, and customer satisfaction
--
-- DESIGN DECISIONS:
-- 1. Grain choice: Order-level (not item-level) because primary business
--    questions focus on "orders placed", "delivery performance", and
--    "customer behavior per transaction" rather than individual SKU analysis.
--
-- 2. CTE aggregation approach: Uses Common Table Expressions (CTEs) to 
--    pre-aggregate order_items, order_payments, and order_reviews BEFORE 
--    joining to orders. This prevents cartesian product issues where 
--    payment/review values get multiplied by the number of items per order.
--    Example: Order with 8 items and 1 payment would incorrectly sum payment 
--    8 times if joined directly. CTEs solve this by grouping first.
--
-- 3. Multiple reviews handling: Orders can have multiple reviews (264 orders
--    have 2+ reviews, with 91 having different scores). We use AVG(review_score)
--    in a separate CTE to aggregate to order-level. This represents overall 
--    order satisfaction when a customer reviewed multiple items.
--
-- 4. Multiple sellers: One order can contain items from multiple sellers.
--    Seller analysis requires item-level grain (future: fact_order_items).
--    At order-level we focus on aggregate order metrics.
--
-- 5. Payment installments: Using MAX() because one order can have multiple
--    payment types (e.g., credit card + voucher). MAX captures the primary
--    payment method's installment count. Known limitation for mixed payments.
--
-- 6. Delivery metrics: 
--    - delivery_time_days: Actual fulfillment time (purchase to delivery)
--    - delivery_delay_days: Performance vs promise (delivered vs estimated)
--      * Negative = early delivery (good)
--      * Positive = late delivery (bad)
--      * Zero = on-time delivery (perfect)
--
-- DATA QUALITY NOTES:
-- - Bronze: 99,441 orders
-- - Silver: 99,441 orders (cleaned, typed)
-- - Gold: 99,441 orders (1 row per order_id, validated unique)
-- - Orders without reviews: 1,306 (13% of total) - review_score = NULL
-- - Orders with multiple reviews: 264 total
--   * 91 with different scores (averaged)
--   * 173 with identical scores (no effect on average)
-- ============================================================


CREATE TABLE fact_orders AS
WITH order_aggregates AS (
    -- Pre-aggregate order_items metrics to avoid cartesian product
    -- One order can have multiple items, so we sum/count here first
    SELECT 
        order_id,
        SUM(price) AS total_price,
        SUM(freight_value) AS total_freight,
        COUNT(order_item_id) AS item_count
    FROM olist_silver.order_items
    GROUP BY order_id
),
payment_aggregates AS (
    -- Pre-aggregate payment metrics in separate CTE
    -- Critical: Aggregating payments separately prevents cartesian product
    -- when joining with multi-item orders (payment × items duplication)
    SELECT 
        order_id,
        SUM(payment_value) AS total_payment,
        MAX(payment_installments) AS max_installments
    FROM olist_silver.order_payments
    GROUP BY order_id
),
review_aggregates AS (
    -- Pre-aggregate reviews (handles orders with multiple reviews)
    SELECT 
        order_id,
        AVG(review_score) AS avg_review_score
    FROM olist_silver.order_reviews
    GROUP BY order_id
)
SELECT 
    -- Primary key
    o.order_id,
    
    -- Foreign keys to dimension tables
    o.customer_id,                          -- Order-level customer ID (transactional reference)
    c.customer_unique_id,                   -- Person-level customer ID (FK to dim_customers)
    o.order_purchase_timestamp,             
    o.order_delivered_customer_date,        
    o.order_estimated_delivery_date,        -- Reference for delay calculation
    
    -- Order attributes
    TRIM(UPPER(o.order_status)) AS order_status,  -- DELIVERED, SHIPPED, CANCELLED, etc.
    
    -- Revenue metrics (from pre-aggregated order_items CTE)
    COALESCE(oa.total_price, 0) AS order_revenue,           -- Total product value
    COALESCE(oa.total_freight, 0) AS order_freight,         -- Total shipping cost
    COALESCE(oa.item_count, 0) AS order_items_count,        -- Number of items in order
    
    -- Payment metrics (from pre-aggregated payments CTE)
    COALESCE(pa.total_payment, 0) AS payment_value,         -- Total amount paid
    COALESCE(pa.max_installments, 1) AS payment_installments,  -- Max installments used
    
    -- Customer satisfaction (from pre-aggregated reviews CTE)
    -- NULL if order has no review (13% of orders)
    -- If multiple reviews, averaged (e.g., scores 5,3 → 4.0)
    ra.avg_review_score AS review_score,
    
    -- Delivery performance metrics (calculated)
    -- Time from purchase to actual delivery
    DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_time_days,
    
    -- Delivery vs promise: negative = early, positive = late, zero = on-time
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delivery_delay_days
    
FROM olist_silver.orders o

-- JOIN to customers to get person-level customer_unique_id for dimension linking
JOIN olist_silver.customers c 
    ON o.customer_id = c.customer_id

-- LEFT JOIN to pre-aggregated CTEs (no cartesian product since already grouped by order_id)
LEFT JOIN order_aggregates oa ON o.order_id = oa.order_id
LEFT JOIN payment_aggregates pa ON o.order_id = pa.order_id
LEFT JOIN review_aggregates ra ON o.order_id = ra.order_id;


-- ============================================================
-- VALIDATION: Confirm one row per order_id (no duplicates)
-- ============================================================
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'PASS: No duplicates'
        ELSE 'FAIL: Duplicates exist'
    END AS validation_status
FROM fact_orders;

-- Expected result: total_rows = unique_order_ids = 99,441


-- Added column order_purchase_date for seamless data modelling in Power BI


ALTER TABLE fact_orders
ADD COLUMN order_purchase_date DATE;

UPDATE fact_orders
SET order_purchase_date = DATE(order_purchase_timestamp);


-- ============================================================
-- SUMMARY STATISTICS
-- ============================================================
SELECT 
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN review_score IS NOT NULL THEN 1 END) AS orders_with_reviews,
    COUNT(CASE WHEN review_score IS NULL THEN 1 END) AS orders_without_reviews,
    ROUND(AVG(order_revenue), 2) AS avg_order_value,
    ROUND(AVG(delivery_time_days), 1) AS avg_delivery_days,
    COUNT(CASE WHEN delivery_delay_days > 0 THEN 1 END) AS late_deliveries,
    COUNT(CASE WHEN delivery_delay_days < 0 THEN 1 END) AS early_deliveries,
    COUNT(CASE WHEN delivery_delay_days = 0 THEN 1 END) AS ontime_deliveries
FROM fact_orders;


