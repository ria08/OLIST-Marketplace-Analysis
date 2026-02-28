
-- ============================================================

-- Create the silver schema (database in MySQL)
CREATE DATABASE IF NOT EXISTS olist_silver;
USE olist_silver;

-- ============================================================
--   customers
-- Transformations: cast zip to INT, trim text
-- ============================================================

CREATE TABLE customers AS
SELECT
    customer_id,
    customer_unique_id,
    CAST(customer_zip_code_prefix AS UNSIGNED) AS customer_zip_code_prefix,  -- convert to integer
    TRIM(customer_city) AS customer_city,                                     -- remove spaces
    TRIM(customer_state) AS customer_state,
    CURRENT_TIMESTAMP AS _processed_at                                        -- audit column
FROM olist_bronze.customers
WHERE customer_id IS NOT NULL;  -- filter out any rows with no ID


-- ============================================================
--   orders
-- Transformations: trim text, cast date
-- ============================================================

CREATE TABLE orders AS
SELECT 
    order_id,
    customer_id,
    TRIM(UPPER(order_status)) AS order_status,
    STR_TO_DATE(NULLIF(order_purchase_timestamp, ''), '%Y-%m-%d %H:%i:%s') AS order_purchase_timestamp,
    STR_TO_DATE(NULLIF(order_approved_at, ''), '%Y-%m-%d %H:%i:%s') AS order_approved_at,
    STR_TO_DATE(NULLIF(order_delivered_carrier_date, ''), '%Y-%m-%d %H:%i:%s') AS order_delivered_carrier_date,
    STR_TO_DATE(NULLIF(order_delivered_customer_date, ''), '%Y-%m-%d %H:%i:%s') AS order_delivered_customer_date,
    STR_TO_DATE(NULLIF(order_estimated_delivery_date, ''), '%Y-%m-%d %H:%i:%s') AS order_estimated_delivery_date,
    CURRENT_TIMESTAMP AS _processed_at
FROM olist_bronze.orders
WHERE order_id IS NOT NULL
AND customer_id IS NOT NULL;


-- ============================================================
--  sellers
-- Transformations: cast zip to INT, trim text
-- ============================================================


CREATE TABLE sellers AS
SELECT 
    seller_id,
    CAST(seller_zip_code_prefix AS UNSIGNED) AS seller_zip_code_prefix,
    TRIM(seller_city) AS seller_city,
    TRIM(seller_state) AS seller_state,
    CURRENT_TIMESTAMP AS _processed_at
FROM olist_bronze.sellers
WHERE seller_id IS NOT NULL;


-- ============================================================
--   product_category_translation  
-- Transformations: trim category names
-- ============================================================


CREATE TABLE product_category_translation AS
SELECT 
    TRIM(product_category_name) AS product_category_name,
    TRIM(product_category_name_english) AS product_category_name_english,
    CURRENT_TIMESTAMP AS _processed_at
FROM olist_bronze.product_category_translation
WHERE product_category_name IS NOT NULL;


-- ============================================================
--   products
-- Transformations: translate category to English, cast dimensions to numeric, handle NULLs
-- ============================================================


CREATE TABLE products AS
SELECT 
    p.product_id,
    COALESCE(t.product_category_name_english, 'unknown') AS product_category_name_english,
    CASE 
        WHEN p.product_name_length = '' THEN NULL 
        ELSE CAST(p.product_name_length AS UNSIGNED) 
    END AS product_name_length,
    CASE 
        WHEN p.product_description_length = '' THEN NULL 
        ELSE CAST(p.product_description_length AS UNSIGNED) 
    END AS product_description_length,
    CASE 
        WHEN p.product_photos_qty = '' THEN NULL 
        ELSE CAST(p.product_photos_qty AS UNSIGNED) 
    END AS product_photos_qty,
    CASE 
        WHEN p.product_weight_g = '' THEN NULL 
        ELSE CAST(p.product_weight_g AS DECIMAL(10,2)) 
    END AS product_weight_g,
    CASE 
        WHEN p.product_length_cm = '' THEN NULL 
        ELSE CAST(p.product_length_cm AS DECIMAL(10,2)) 
    END AS product_length_cm,
    CASE 
        WHEN p.product_height_cm = '' THEN NULL 
        ELSE CAST(p.product_height_cm AS DECIMAL(10,2)) 
    END AS product_height_cm,
    CASE 
        WHEN p.product_width_cm = '' THEN NULL 
        ELSE CAST(p.product_width_cm AS DECIMAL(10,2)) 
    END AS product_width_cm,
    CURRENT_TIMESTAMP AS _processed_at
FROM olist_bronze.products p
LEFT JOIN olist_bronze.product_category_translation t
    ON TRIM(p.product_category_name) = TRIM(t.product_category_name)
WHERE p.product_id IS NOT NULL;


-- ============================================================
--   order_items
-- Transformations: cast date
-- ============================================================


CREATE TABLE order_items AS
SELECT 
    order_id,
    order_item_id,
    product_id,
    seller_id,
    STR_TO_DATE(NULLIF(shipping_limit_date, ''), '%Y-%m-%d %H:%i:%s') AS shipping_limit_date,
    price,
    freight_value,
    CURRENT_TIMESTAMP AS _processed_at
FROM olist_bronze.order_items
WHERE order_id IS NOT NULL 
  AND product_id IS NOT NULL;
  
  -- ============================================================
--     order_payments
-- Transformations: clean payment type
-- ============================================================
  
  
  CREATE TABLE order_payments AS
SELECT 
    order_id,
    payment_sequential,
    TRIM(LOWER(payment_type)) AS payment_type,
    payment_installments,
    payment_value,
    CURRENT_TIMESTAMP AS _processed_at
FROM olist_bronze.order_payments
WHERE order_id IS NOT NULL; -- we will circle back to payment type >0 in gold to address those.


-- ============================================================
--   order_reviews
-- Transformations: cast dates, cast score to INT, deduplicate on review_id
-- DATA QUALITY ISSUE IDENTIFIED IN SILVER LAYER:
-- Bronze contains 789 review_ids with duplicate entries (same review_id 
-- mapped to different order_ids with identical timestamps and content).
-- This is a data integrity issue in the source dataset - physically 
-- impossible for one customer to write multiple reviews at the exact 
-- same millisecond. Resolved by keeping the earliest review per review_id 
-- using ROW_NUMBER(), removing 814 duplicate rows as some rows were duplicated more than once.
-- Final count: 98,400 unique reviews (down from 99,214 in bronze)
-- ============================================================

CREATE TABLE order_reviews AS
SELECT 
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM (
    SELECT 
        review_id,
        order_id,
        CAST(review_score AS UNSIGNED) AS review_score,
        TRIM(review_comment_title) AS review_comment_title,
        TRIM(review_comment_message) AS review_comment_message,
        STR_TO_DATE(NULLIF(review_creation_date, ''), '%Y-%m-%d %H:%i:%s') AS review_creation_date,
        STR_TO_DATE(NULLIF(review_answer_timestamp, ''), '%Y-%m-%d %H:%i:%s') AS review_answer_timestamp,
        ROW_NUMBER() OVER (PARTITION BY review_id ORDER BY review_creation_date) AS rn,
        CURRENT_TIMESTAMP AS _processed_at
    FROM olist_bronze.order_reviews
    WHERE review_id IS NOT NULL
) ranked
WHERE rn = 1;


-- ============================================================
--   geolocation
-- Transformations: deduplicate zip codes, keep most common city/state per zip
-- ============================================================

CREATE TABLE geolocation AS
WITH geo_counts AS (
    SELECT 
        CAST(geolocation_zip_code_prefix AS UNSIGNED) AS zip_prefix,
        geolocation_lat,
        geolocation_lng,
        TRIM(geolocation_city) AS city,
        TRIM(geolocation_state) AS state,
        COUNT(*) AS occurrence_count
    FROM olist_bronze.geolocation
    WHERE geolocation_zip_code_prefix IS NOT NULL
    GROUP BY                                                     -- was getting group statement is ambigous warning so had to write whole func here.
        CAST(geolocation_zip_code_prefix AS UNSIGNED),
        geolocation_lat,
        geolocation_lng,
        TRIM(geolocation_city),
        TRIM(geolocation_state)
),
geo_ranked AS (
    SELECT 
        zip_prefix,
        geolocation_lat,
        geolocation_lng,
        city,
        state,
        ROW_NUMBER() OVER (
            PARTITION BY zip_prefix
            ORDER BY occurrence_count DESC
        ) AS rn
    FROM geo_counts
)
SELECT 
    zip_prefix AS geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    city AS geolocation_city,
    state AS geolocation_state,
    CURRENT_TIMESTAMP AS _processed_at
FROM geo_ranked
WHERE rn = 1;

 --  filtered out all the ids with null in these tables to ensure data integrity



