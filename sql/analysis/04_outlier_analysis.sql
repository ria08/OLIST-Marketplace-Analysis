-- ============================================
-- OUTLIER ANALYSIS & BUSINESS JUSTIFICATION
-- OLIST E-Commerce Data (2016-2018)
-- ============================================

-- 1. PAYMENT VALUE OUTLIERS
-- ============================================
-- FINDINGS:
-- - Range: R$10 - R$13,440
-- - Orders over R$1,000: ~1% of total orders
-- - Maximum order: R$13,440 (legitimate high-value purchase)

-- BUSINESS DECISION: RETAIN ALL VALUES
-- Justification:
-- - High-value orders (R$5,000+) represent legitimate expensive purchases
-- - Only ~1% exceed R$1,000 - minimal impact on averages
-- - Average customer LTV remains stable at R$142 despite extreme values
-- - RFM uses quintile-based scoring (robust to outliers)
-- - Removing would misrepresent revenue and high-value customer segment

SELECT 
    COUNT(*) as total_orders,
    ROUND(AVG(order_revenue), 2) as mean_payment,
    ROUND(MIN(order_revenue), 2) as min_payment,
    ROUND(MAX(order_revenue), 2) as max_payment,
    (SELECT COUNT(*) FROM fact_orders 
     WHERE order_status = 'delivered' AND order_revenue > 1000) as orders_over_1000,
    ROUND((SELECT COUNT(*) FROM fact_orders 
           WHERE order_status = 'delivered' AND order_revenue > 1000) * 100.0 / 
          COUNT(*), 2) as pct_over_1000
FROM fact_orders
WHERE order_status = 'delivered';

-- Expected result:
-- max_payment: 13440
-- orders_over_1000: ~900 (1.15% of ~96K orders)
-- mean_payment: ~130-150


-- 2. DELIVERY TIME OUTLIERS
-- ============================================
-- FINDINGS:
-- - ~4,000 orders took over 30 days (4% of deliveries)
-- - 298 orders took over 60 days (0.3% of deliveries)
-- - Extreme delays up to 100+ days occurred

-- BUSINESS DECISION: RETAIN ALL VALUES
-- Justification:
-- - Extreme delays are REAL operational bottlenecks, not data errors
-- - Critical evidence for "delivery kills satisfaction" hypothesis
-- - Over 4% of customers experienced severe delays (30+ days)
-- - These delays explain retention crisis
-- - Essential for identifying logistics improvement areas

SELECT 
    COUNT(*) as total_delivered,
    (SELECT COUNT(*) FROM fact_orders 
     WHERE order_status = 'delivered' AND delivery_time_days > 30) as over_30_days,
    ROUND((SELECT COUNT(*) FROM fact_orders 
           WHERE order_status = 'delivered' AND delivery_time_days > 30) * 100.0 / 
          COUNT(*), 2) as pct_over_30_days,
    (SELECT COUNT(*) FROM fact_orders 
     WHERE order_status = 'delivered' AND delivery_time_days > 60) as over_60_days,
    ROUND((SELECT COUNT(*) FROM fact_orders 
           WHERE order_status = 'delivered' AND delivery_time_days > 60) * 100.0 / 
          COUNT(*), 2) as pct_over_60_days,
    ROUND(MAX(delivery_time_days), 2) as max_delivery_days
FROM fact_orders
WHERE order_status = 'delivered';

-- Expected result:
-- over_30_days: ~4,000 (~4% of orders)
-- over_60_days: 298 (0.3% of orders)
-- max_delivery_days: 100+


-- 3. IMPACT VALIDATION
-- ============================================
-- Verify that outliers don't skew key metrics

-- Customer LTV (should be ~R$141 despite R$13,665 max order)
SELECT 
    ROUND(SUM(order_revenue) / COUNT(DISTINCT customer_unique_id), 2) as avg_customer_ltv
FROM fact_orders
WHERE order_status = 'delivered';
-- Result: ~R$140-150 (stable despite extreme values)

-- Delivery impact on reviews (validates retention crisis root cause)
SELECT 
    CASE 
        WHEN delivery_time_days <= 7 THEN 'On-Time'
        WHEN delivery_time_days BETWEEN 8 AND 12 THEN 'Slightly Late'
        ELSE 'Very Late'
    END as delivery_category,
    COUNT(*) as order_count,
    ROUND(AVG(f.review_score), 2) as avg_review_score
FROM fact_orders f
JOIN olist_silver.order_reviews r ON f.order_id = r.order_id
WHERE f.order_status = 'delivered'
GROUP BY delivery_category;
-- Shows clear correlation: late deliveries = lower reviews


-- ============================================
-- CONCLUSION
-- ============================================
-- Payment outliers (~1% over R$1,000):
--   - Legitimate business data
--   - LTV remains stable at R$142
--   - RFM methodology robust to extremes
--
-- Delivery outliers (4% over 30 days):
--   - Real operational failures
--   - Critical for understanding retention crisis
--   - Cannot be removed without hiding business problems
--
-- DECISION: NO OUTLIER REMOVAL OR CAPPING
-- All extreme values retained for accurate business analysis
-- ============================================
