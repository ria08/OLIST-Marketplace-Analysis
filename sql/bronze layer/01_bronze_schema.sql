-- ============================================================
-- OLIST MARKETPLACE ANALYSIS
-- Medallion Architecture - Layer 1: BRONZE SCHEMA
-- Purpose: Land raw CSV data exactly as-is. No transformations.
-- Author: Ria Singh
-- ============================================================

-- Create the bronze schema (database in MySQL)
CREATE DATABASE IF NOT EXISTS olist_bronze;
USE olist_bronze;


-- ============================================================
-- TABLE 1: customers
-- Source: olist_customers_dataset.csv
-- Grain: One row per customer_id (unique per order)
-- Note: customer_unique_id identifies the real person across orders
-- ============================================================
CREATE TABLE IF NOT EXISTS customers (
    customer_id             VARCHAR(50),
    customer_unique_id      VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city           VARCHAR(100),
    customer_state          VARCHAR(5),
    _loaded_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP   -- audit column
);


-- ============================================================
-- TABLE 2: geolocation
-- Source: olist_geolocation_dataset.csv
-- Grain: Multiple rows per zip code prefix (known duplicates exist)
-- Note: Largest file (15MB). Duplicates handled in silver layer.
-- ============================================================
CREATE TABLE IF NOT EXISTS geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat             DECIMAL(18, 15),
    geolocation_lng             DECIMAL(18, 15),
    geolocation_city            VARCHAR(100),
    geolocation_state           VARCHAR(5),
    _loaded_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- TABLE 3: order_items
-- Source: olist_order_items_dataset.csv
-- Grain: One row per item within an order (order_id + order_item_id)
-- Note: One order can have multiple items from multiple sellers
-- ============================================================
CREATE TABLE IF NOT EXISTS order_items (
    order_id                VARCHAR(50),
    order_item_id           INT,              -- item sequence within order
    product_id              VARCHAR(50),
    seller_id               VARCHAR(50),
    shipping_limit_date     VARCHAR(30),      -- stored as string in bronze, cast in silver
    price                   DECIMAL(10, 2),
    freight_value           DECIMAL(10, 2),
    _loaded_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- TABLE 4: order_payments
-- Source: olist_order_payments_dataset.csv
-- Grain: One row per payment installment per order
-- Note: One order can have multiple payment types (e.g., voucher + credit card)
-- ============================================================
CREATE TABLE IF NOT EXISTS order_payments (
    order_id                VARCHAR(50),
    payment_sequential      INT,              -- installment sequence number
    payment_type            VARCHAR(30),      -- credit_card, boleto, voucher, debit_card
    payment_installments    INT,
    payment_value           DECIMAL(10, 2),
    _loaded_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- TABLE 5: order_reviews
-- Source: olist_order_reviews_dataset.csv
-- Grain: One row per review (review_id)
-- Note: Some orders have multiple reviews. review_comment fields can be NULL.
-- ============================================================
CREATE TABLE IF NOT EXISTS order_reviews (
    review_id               VARCHAR(50),
    order_id                VARCHAR(50),
    review_score            VARCHAR(5),       -- VARCHAR in bronze to handle any malformed values
    review_comment_title    TEXT,             -- TEXT to handle unexpectedly long values
    review_comment_message  TEXT,             -- often NULL, can be very long
    review_creation_date    VARCHAR(50),      -- increased size; some rows have extra characters
    review_answer_timestamp VARCHAR(50),
    _loaded_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- TABLE 6: orders
-- Source: olist_orders_dataset.csv
-- Grain: One row per order (order_id is primary key)
-- Note: This is your central fact. All other tables join back to here.
--       Multiple timestamp columns, many NULLs for cancelled orders.
-- ============================================================
CREATE TABLE IF NOT EXISTS orders (
    order_id                        VARCHAR(50),
    customer_id                     VARCHAR(50),
    order_status                    VARCHAR(30),  -- delivered, shipped, cancelled, etc.
    order_purchase_timestamp        VARCHAR(30),
    order_approved_at               VARCHAR(30),  -- can be NULL
    order_delivered_carrier_date    VARCHAR(30),  -- can be NULL
    order_delivered_customer_date   VARCHAR(30),  -- can be NULL
    order_estimated_delivery_date   VARCHAR(30),
    _loaded_at                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- TABLE 7: products
-- Source: olist_products_dataset.csv
-- Grain: One row per product_id
-- Note: category names are in Portuguese here.
--       English translation done in silver using translation table.
--       Several dimension columns have NULLs.
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
    product_id                  VARCHAR(50),
    product_category_name       VARCHAR(100),   -- in Portuguese, NULLs exist
    product_name_length         VARCHAR(10),    -- kept as VARCHAR in bronze; empty strings exist (cast to INT in silver)
    product_description_length  VARCHAR(10),
    product_photos_qty          VARCHAR(10),
    product_weight_g            VARCHAR(20),
    product_length_cm           VARCHAR(20),
    product_height_cm           VARCHAR(20),
    product_width_cm            VARCHAR(20),
    _loaded_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- TABLE 8: sellers
-- Source: olist_sellers_dataset.csv
-- Grain: One row per seller_id
-- ============================================================
CREATE TABLE IF NOT EXISTS sellers (
    seller_id               VARCHAR(50),
    seller_zip_code_prefix  VARCHAR(10),
    seller_city             VARCHAR(100),
    seller_state            VARCHAR(5),
    _loaded_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- TABLE 9: product_category_translation
-- Source: product_category_name_translation.csv
-- Grain: One row per Portuguese category name
-- Note: Bridge table. Used in silver to translate products.category_name
-- ============================================================
CREATE TABLE IF NOT EXISTS product_category_translation (
    product_category_name           VARCHAR(100),   -- Portuguese
    product_category_name_english   VARCHAR(100),   -- English
    _loaded_at                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- LOAD DATA: BULK INSERT COMMANDS
-- ============================================================

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/olist_geolocation_dataset.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, payment_sequential, payment_type, payment_installments, payment_value);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/olist_order_reviews_cleaned.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, review_comment_title, review_comment_message,
 review_creation_date, review_answer_timestamp);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at,
 order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, product_category_name, product_name_length, product_description_length,
 product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(seller_id, seller_zip_code_prefix, seller_city, seller_state);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OLIST marketplace data/product_category_name_translation.csv'
INTO TABLE product_category_translation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_category_name, product_category_name_english);






