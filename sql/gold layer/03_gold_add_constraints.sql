-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Gold Layer: Add Primary Key Constraints
-- Purpose: Enforce uniqueness on primary keys for all star schema tables
-- Author: Ria Singh
-- ============================================================

USE olist_gold;

-- ============================================================
-- SECTION 1: ADD PRIMARY KEYS TO ALL TABLES
-- Primary keys enforce uniqueness and create automatic indexes
-- for faster joins and lookups
-- ============================================================

-- Fact table: fact_orders
-- Primary key: order_id (one row per order)
ALTER TABLE fact_orders
ADD PRIMARY KEY (order_id);

-- Dimension table: dim_customers
-- Primary key: customer_unique_id (one row per actual person)
ALTER TABLE dim_customers
ADD PRIMARY KEY (customer_unique_id);

-- Dimension table: dim_products
-- Primary key: product_id (one row per product)
ALTER TABLE dim_products
ADD PRIMARY KEY (product_id);

-- Dimension table: dim_sellers
-- Primary key: seller_id (one row per seller)
ALTER TABLE dim_sellers
ADD PRIMARY KEY (seller_id);

-- Dimension table: dim_date
-- Primary key: date_key (one row per calendar date)
ALTER TABLE dim_date
ADD PRIMARY KEY (date_key);


-- ============================================================
-- SECTION 2: VALIDATION - CONFIRM CONSTRAINTS APPLIED
-- ============================================================

-- Check all primary keys are in place
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'olist_gold'
  AND CONSTRAINT_NAME = 'PRIMARY'
ORDER BY TABLE_NAME;

-- Expected result: 5 rows (one for each table's primary key)


-- ============================================================
-- NOTES ON FOREIGN KEYS
-- ============================================================
-- We do NOT add foreign key constraints because:
-- 1. Data warehouses prioritize query performance over referential integrity
-- 2. Foreign keys add overhead on INSERT/UPDATE operations
-- 3. Referential integrity already validated in silver layer
-- 4. Star schema design assumes clean dimension references
--
-- In a transactional OLTP database, foreign keys would be critical.
-- In an analytical OLAP warehouse, they're optional.
-- ============================================================
