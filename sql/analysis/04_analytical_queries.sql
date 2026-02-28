-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Strategic Business Analysis Queries
-- Author: Ria Singh
-- ============================================================

-- BUSINESS PROBLEM:
-- Olist marketplace wants to improve profitability by:
-- 1. Increasing repeat purchases (currently only 3.5% buy twice)
-- 2. Reducing late deliveries (impacts customer satisfaction)
-- 3. Optimizing product mix (focus on high-performing categories)
-- 4. Expanding to underserved geographic regions

-- HYPOTHESES TO TEST:
-- H1: Late deliveries significantly damage review scores (target: reduce late rate 6.5% → 3%)
-- H2: Top 3 categories drive 25%+ of revenue (focus marketing here)
-- H3: Repeat customers have 3x higher lifetime value (invest in retention)
-- H4: Certain states are underserved (high population, low customer penetration)

USE olist_gold;


-- ============================================================
-- PERFORMANCE OPTIMIZATION: INDEXES
-- Create indexes on frequently filtered/joined columns
-- ============================================================

-- Index on fact_orders for date filtering (used in almost every query)
CREATE INDEX idx_fact_orders_purchase_date 
ON fact_orders(order_purchase_timestamp);

-- Index on fact_orders for status filtering
CREATE INDEX idx_fact_orders_status 
ON fact_orders(order_status);

-- Index on order_items for product analysis
CREATE INDEX idx_order_items_product 
ON olist_silver.order_items(product_id);


-- Index on fact_orders for customer analysis
CREATE INDEX idx_fact_orders_customer 
ON fact_orders(customer_unique_id);

-- ============================================================
-- QUERY 1: MONTHLY REVENUE TREND
-- Business Question: Are we growing or declining?
-- Hypothesis Check: Establish baseline growth rate
-- Expected Output: Month, revenue, growth % (positive = growing)
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
        COUNT(DISTINCT order_id) AS orders,
        SUM(order_revenue) AS revenue
    FROM fact_orders
    WHERE order_status = 'DELIVERED'
      AND order_purchase_timestamp >= '2017-01-01'
    GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
)

SELECT
    month,
    orders,
    ROUND(revenue, 2) AS revenue,

    ROUND(
        revenue - LAG(revenue) OVER (ORDER BY month),
        2
    ) AS revenue_change,

    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month))
        * 100.0 / LAG(revenue) OVER (ORDER BY month),
        2
    ) AS growth_pct

FROM monthly_revenue
ORDER BY month;


-- Expected Insight: 
-- "Revenue grew 15% MoM on average in 2017, but slowed to 5% in 2018"
-- Business Action: Investigate why growth slowed (market saturation? competition?)


-- ============================================================
-- QUERY 2: TOP 5 STATES BY CUSTOMER BASE
-- Business Question: Where are our customers concentrated?
-- Hypothesis Check: Identify underserved regions for expansion
-- Expected Output: State, customer count, revenue, orders per customer
-- ============================================================

SELECT 
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(f.order_revenue), 2) AS revenue,
    ROUND(COUNT(DISTINCT c.customer_unique_id) * 100.0 / 
          (SELECT COUNT(DISTINCT customer_unique_id) FROM dim_customers), 1) AS customer_pct,
    ROUND(SUM(f.order_revenue) * 100.0 / 
          (SELECT SUM(order_revenue) FROM fact_orders WHERE order_status = 'DELIVERED'), 1) AS revenue_pct,
    ROUND(COUNT(DISTINCT f.order_id) * 1.0 / COUNT(DISTINCT c.customer_unique_id), 2) AS orders_per_customer
FROM fact_orders f
JOIN dim_customers c ON f.customer_unique_id = c.customer_unique_id
WHERE f.order_status = 'DELIVERED'
GROUP BY c.customer_state
ORDER BY customers DESC
LIMIT 10;







-- Expected Insight:
-- "SP has 40k customers (42% of total), RJ has 12k (12%), MG has 11k (11%)"
-- Business Action: SP is saturated; focus marketing on RJ, MG for growth


-- ============================================================
-- QUERY 3: TOP 5 PRODUCT CATEGORIES BY REVENUE
-- Business Question: Which categories drive the business?
-- Hypothesis Check: H2 - Do top 3 categories = 25%+ of revenue?
-- Expected Output: Category, revenue, % of total
-- ============================================================


WITH total_revenue AS (
    SELECT SUM(oi.price) AS total
    FROM olist_silver.order_items oi
    JOIN fact_orders f ON oi.order_id = f.order_id
    WHERE f.order_status = 'DELIVERED'
)
SELECT 
    p.product_category_name,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(SUM(oi.price) * 100.0 / MAX(tr.total), 1) AS revenue_pct
FROM fact_orders f
JOIN olist_silver.order_items oi ON f.order_id = oi.order_id
JOIN dim_products p ON oi.product_id = p.product_id
CROSS JOIN total_revenue tr
WHERE f.order_status = 'DELIVERED'
GROUP BY p.product_category_name
ORDER BY revenue DESC
LIMIT 5;





-- Expected Insight:
-- "Top 3 categories (bed_bath, health_beauty, watches_gifts) = 24.3% of revenue"
-- Business Action: H2 VALIDATED. Focus ads/promotions on these 3 categories.


-- ============================================================
-- QUERY 4: LATE DELIVERY RATE AND IMPACT
-- Business Question: How bad is our delivery problem?
-- Hypothesis Check: H1 - Quantify late delivery impact on satisfaction
-- Expected Output: Delivery status, order count, avg review score
-- ============================================================


WITH classified_orders AS (
    SELECT
        CASE 
            WHEN delivery_delay_days <= 0 THEN 'On-time or Early'
            WHEN delivery_delay_days BETWEEN 1 AND 5 THEN 'Slightly Late (1-5 days)'
            ELSE 'Very Late (6+ days)'
        END AS delivery_status,
        review_score
    FROM fact_orders
    WHERE order_delivered_customer_date IS NOT NULL
)

SELECT
    delivery_status,
    COUNT(*) AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(CASE WHEN review_score <= 2 THEN 1 END) AS bad_reviews,
    ROUND(
        COUNT(CASE WHEN review_score <= 2 THEN 1 END) * 100.0 / COUNT(*),
        1
    ) AS bad_review_rate
FROM classified_orders
GROUP BY delivery_status
ORDER BY avg_review_score DESC;



-- Expected Insight:
-- "On-time delivery: 4.2 avg score. Very late: 2.8 avg score (1.4 point drop!)"
-- "Late deliveries = 6.5% of orders but 22% of bad reviews"
-- Business Action: H1 VALIDATED. Reduce late rate → improve satisfaction → more repeat buys


-- ============================================================
-- QUERY 5: ONE-TIME VS REPEAT CUSTOMERS
-- Business Question: How bad is our retention problem?
-- Hypothesis Check: H3 - Do repeat customers have higher LTV?
-- Expected Output: Customer type, count, avg lifetime value
-- ============================================================
    
    
    WITH customer_behavior AS (
    SELECT 
        customer_unique_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(order_revenue) AS lifetime_value,
        CASE 
            WHEN COUNT(DISTINCT order_id) = 1 THEN 'One-time Buyer'
            ELSE 'Repeat Buyer'
        END AS customer_type
    FROM fact_orders
    WHERE order_status = 'DELIVERED'
    GROUP BY customer_unique_id
)

SELECT 
    customer_type,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_customers,
    ROUND(AVG(lifetime_value), 2) AS avg_lifetime_value
FROM customer_behavior
GROUP BY customer_type
ORDER BY customer_count DESC;

-- Expected Insight:
-- "96.5% are one-time buyers with ₹136 LTV. Repeat buyers: ₹412 LTV (3x higher!)"
-- Business Action: H3 VALIDATED. Invest in email marketing, loyalty program to drive repeat


-- ============================================================
-- QUERY 6: WORST PERFORMING CATEGORIES (LOW SATISFACTION)
-- Business Question: Which products hurt our brand?
-- Hypothesis Check: Identify categories to phase out or fix
-- Expected Output: Category, avg review score, bad review %
-- ============================================================

SELECT 
    p.product_category_name,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(AVG(f.review_score), 2) AS avg_review_score,
    COUNT(CASE WHEN f.review_score <= 2 THEN 1 END) AS bad_reviews,
    ROUND(COUNT(CASE WHEN f.review_score <= 2 THEN 1 END) * 100.0 / COUNT(*), 1) AS bad_review_rate
FROM fact_orders f
JOIN olist_silver.order_items oi ON f.order_id = oi.order_id
JOIN dim_products p ON oi.product_id = p.product_id
WHERE f.review_score IS NOT NULL
GROUP BY p.product_category_name
HAVING orders >= 100  -- only categories with enough data
ORDER BY avg_review_score ASC
LIMIT 10;

-- Expected Insight:
-- "Security_services has 3.1 avg score (worst). Fashion_bags: 3.4 score"
-- Business Action: Audit these categories - seller quality issue? Product defects?


-- ============================================================
-- QUERY 7: STATES WITH WORST DELIVERY PERFORMANCE
-- Business Question: Where should we fix logistics first?
-- Hypothesis Check: Identify high-impact regions for ops improvement
-- Expected Output: State, late delivery %, avg delay
-- ============================================================

SELECT 
    c.customer_state,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN f.delivery_delay_days > 0 THEN 1 END) AS late_orders,
    ROUND(COUNT(CASE WHEN f.delivery_delay_days > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS late_rate,
    ROUND(AVG(f.delivery_time_days), 1) AS avg_delivery_days
FROM fact_orders f
JOIN dim_customers c ON f.customer_unique_id = c.customer_unique_id
WHERE f.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING total_orders >= 100
ORDER BY late_rate DESC
LIMIT 10;

-- Expected Insight:
-- "RR state: 18% late rate (worst). AC: 15%. PA: 12%"
-- "These are remote northern states - logistics challenge"
-- Business Action: Partner with regional carriers in RR, AC, PA to improve delivery


-- ============================================================
-- QUERY 8: WEEKEND VS WEEKDAY PURCHASE BEHAVIOR
-- Business Question: When do customers buy more?
-- Hypothesis Check: Optimize ad spend timing
-- Expected Output: Day type, orders, revenue, AOV
-- ============================================================

SELECT 
    CASE 
        WHEN d.is_weekend = TRUE THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND(SUM(f.order_revenue), 2) AS revenue,
    ROUND(AVG(f.order_revenue), 2) AS avg_order_value
FROM fact_orders f
JOIN dim_date d 
ON DATE(f.order_purchase_timestamp) = d.date_key
WHERE f.order_status = 'DELIVERED'
GROUP BY d.is_weekend;

-- Expected Insight:
-- "Weekday: 72% of orders, ₹134 AOV. Weekend: 28% orders, ₹145 AOV (8% higher!)"
-- Business Action: Run high-value product ads on Saturdays/Sundays (higher AOV)



-- ============================================================
-- SUMMARY OF FINDINGS FOR BUSINESS STAKEHOLDERS
-- ============================================================

-- ============================================================
-- SUMMARY OF FINDINGS FOR BUSINESS STAKEHOLDERS
-- Based on actual query results from Olist dataset (2016-2018)
-- ============================================================

-- EXECUTIVE SUMMARY:
-- Olist experienced explosive growth in 2017 (6.5x revenue increase) but hit a 
-- hard plateau in 2018 (0-3% MoM growth). The business has saturated its core 
-- markets (SP, RJ, MG = 64.5% of customers) and suffers from extremely low 
-- retention (97% one-time buyers). 

-- Three strategic levers exist for renewed growth:
-- 1) Geographic expansion to underserved states
-- 2) Delivery performance improvement (late deliveries destroy satisfaction)
-- 3) Customer retention programs (repeat buyers have 1.9x higher LTV)


-- ============================================================
-- KEY INSIGHTS BY QUERY
-- ============================================================

-- INSIGHT 1: GROWTH HAS STALLED (Query 1)
--    Finding: 2017 saw hyper-growth (6.5x revenue increase, Jan R$111k → Dec R$726k)
--             2018 growth collapsed to 0-3% MoM (some months negative)
--    Root Cause: Market saturation in core regions + low retention
--    → ACTION: Cannot rely on organic momentum; need new growth engines

-- INSIGHT 2: EXTREME GEOGRAPHIC CONCENTRATION (Query 2)
--    Finding: Top 3 states (SP, RJ, MG) = 64.5% of customers, 63.3% of revenue
--             Other 17 Brazilian states massively underserved
--             BA is Brazil's 4th largest state but only 3.3% of Olist customers
--    Opportunity: If BA, CE, PE, AM each reach 5% share → +8-10% total growth
--    → ACTION: Expand logistics and marketing to North/Northeast regions

-- INSIGHT 3: DIVERSIFIED PRODUCT MIX (Query 3)
--    Finding: Top 3 categories = 25.8% of revenue (health_beauty 9.3%, watches_gifts 8.8%, bed_bath_table 7.7%)
--             Revenue well-distributed across categories (no hero category)
--    Implication: Low category risk, but also no clear growth driver
--    → ACTION: Strategically promote top 3 categories to create revenue engines

-- INSIGHT 4: DELIVERY KILLS SATISFACTION (Query 4)
--    Finding: On-time delivery = 4.29 avg review score, 9.1% bad review rate
--             Slightly late (1-5 days) = 2.99 score, 40.3% bad reviews (4.4x increase!)
--             Very late (6+ days) = 1.74 score, 75.5% bad reviews (8.3x increase!)
--    Impact: Even 1-5 day delays cause massive satisfaction damage
--    → ACTION: Fix delivery operations urgently — highest ROI for CX improvement

-- INSIGHT 5: RETENTION CRISIS (Query 5)
--    Finding: 97.0% of customers buy only once (one-time buyers)
--             Only 3.0% are repeat customers
--             BUT repeat buyers have 1.9x higher LTV (R$260 vs R$138)
--    Opportunity: Even modest retention improvements drive outsized revenue
--    → ACTION: Launch email retention campaigns, loyalty rewards, post-purchase engagement

-- INSIGHT 6: PROBLEM CATEGORIES IDENTIFIED (Query 6)
--    Finding: office_furniture (26.2% bad reviews), fashion_male_clothing (28.5%)
--             fixed_telephony (25.7%), audio (21.7%)
--    Note: Originally suspected categories (security services) NOT the problem
--    → ACTION: Audit seller quality and product listings in furniture/fashion categories

-- INSIGHT 7: DELIVERY DELAYS NOT PURELY GEOGRAPHIC (Query 7)
--    Finding: AL (21.4% late rate), MA (17.4%) have higher delays BUT low volume
--             High-volume states (RJ 12.1%, BA 12.2%) maintain reasonable performance
--             No systemic regional failure detected
--    Implication: Delivery problems are seller/fulfillment-level, not geographic
--    → ACTION: Focus on seller dispatch speed and shipping partner performance

-- INSIGHT 8: WEEKDAY DOMINANCE (Query 8)
--    Finding: Weekdays = 74,288 orders (77%), R$137.46 AOV
--             Weekends = 22,190 orders (23%), R$135.63 AOV
--             SURPRISE: Weekday AOV slightly higher than weekends
--    Implication: Platform is routine purchase channel, not weekend shopping destination
--    → ACTION: Run weekend promotions/bundles to boost basket size


-- ============================================================
-- STRATEGIC PRIORITIES (Impact-weighted)
-- ============================================================

-- P0 (Critical): FIX DELIVERY PERFORMANCE
--    - Late deliveries cause 4-8x increase in bad reviews
--    - Focus on seller dispatch processes and logistics partners
--    - Target: Reduce late rate from 6.8% to <3%
--    - Expected impact: +0.5 to +1.0 point improvement in avg review score


-- P1 (High): LAUNCH RETENTION PROGRAM
--    - 97% one-time buyer rate is unsustainable
--    - Repeat buyers deliver 1.9x higher LTV (R$260 vs R$138)
--    - Tactics: Email campaigns, loyalty points, post-purchase engagement
--    - Expected impact: Move retention from 3% to 10% = +20% revenue


-- P2 (High): GEOGRAPHIC EXPANSION
--    - Top 3 states = 64.5% of customers (saturated)
--    - North/Northeast states (BA, CE, PE, AM) represent white space
--    - Requirements: Regional logistics partnerships, seller acquisition, targeted marketing
--    - Expected impact: +8-10% customer growth


-- P3 (Medium): CATEGORY OPTIMIZATION
--    - Top 3 categories (health_beauty, watches_gifts, bed_bath) = 25.8% revenue
--    - Concentrate marketing budget on these proven winners
--    - Expected impact: +3-5% AOV through better product mix


-- P4 (Medium): FIX PROBLEM CATEGORIES
--    - office_furniture (26.2%) and fashion_male_clothing (28.5%) have high bad reviews
--    - Audit seller quality, improve product listings, tighten QC
--    - Expected impact: +0.2 point improvement in platform avg rating


-- P5 (Low): WEEKEND MONETIZATION
--    - Weekend AOV (R$135.63) slightly lower than weekday (R$137.46)
--    - Run targeted weekend promotions to boost basket size
--    - Expected impact: +2-3% weekend revenue


-- ============================================================
-- RECOMMENDED NEXT ACTIONS (90-day roadmap)
-- ============================================================

-- KPIs TO TRACK:
--    - Late delivery rate (target: <3%)
--    - Repeat customer % (target: 10%)
--    - Customer acquisition by state (track BA, CE, PE, AM penetration)
--    - Category revenue concentration (ensure top 3 grow to 30%+)
--    - Platform average review score (target: 4.3+)

-- ============================================================
