-- ============================================================
-- QuickBite Express Crisis Recovery Analysis
-- 01_create_database.sql
-- Purpose: Create the database and all 8 staging tables.
-- Staging tables use VARCHAR/TEXT for every column (including
-- dates and numbers) on purpose - this avoids MySQL silently
-- misreading dates like signup_date (DD-MM-YYYY format) during
-- import. Proper types are applied later in 03_cleaning_and_views.sql.
-- ============================================================

CREATE DATABASE IF NOT EXISTS quickbite_express;
USE quickbite_express;


-- ------------------------------------------------------------
-- Dimension tables
-- ------------------------------------------------------------
CREATE TABLE stg_dim_customer (
    customer_id VARCHAR(20),
    signup_date VARCHAR(20),
    city VARCHAR(50),
    acquisition_channel VARCHAR(30)
);

CREATE TABLE stg_dim_delivery_partner (
    delivery_partner_id VARCHAR(20),
    partner_name VARCHAR(50),
    city VARCHAR(50),
    vehicle_type VARCHAR(20),
    employment_type VARCHAR(20),
    avg_rating DECIMAL(3,2),
    is_active VARCHAR(5)
);

CREATE TABLE stg_dim_menu_item (
    menu_item_id VARCHAR(30),
    restaurant_id VARCHAR(20),
    item_name VARCHAR(100),
    category VARCHAR(50),
    is_veg VARCHAR(5),
    price DECIMAL(10,2)
);

CREATE TABLE stg_dim_restaurant (
    restaurant_id VARCHAR(20),
    restaurant_name VARCHAR(100),
    city VARCHAR(50),
    cuisine_type VARCHAR(50),
    partner_type VARCHAR(30),
    avg_prep_time_min VARCHAR(20),
    is_active VARCHAR(5)
);


-- ------------------------------------------------------------
-- Fact tables
-- ------------------------------------------------------------
CREATE TABLE stg_fact_delivery_performance (
    order_id VARCHAR(30),
    actual_delivery_time_mins INT,
    expected_delivery_time_mins INT,
    distance_km DECIMAL(6,2)
);

CREATE TABLE stg_fact_order_items (
    order_id VARCHAR(30),
    item_id VARCHAR(20),
    menu_item_id VARCHAR(30),
    restaurant_id VARCHAR(20),
    quantity INT,
    unit_price DECIMAL(10,2),
    item_discount DECIMAL(10,2),
    line_total DECIMAL(10,2)
);

CREATE TABLE stg_fact_orders (
    order_id VARCHAR(30),
    customer_id VARCHAR(20),
    restaurant_id VARCHAR(20),
    delivery_partner_id VARCHAR(20),
    order_timestamp VARCHAR(30),
    subtotal_amount DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    delivery_fee DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    is_cod VARCHAR(5),
    is_cancelled VARCHAR(5)
);

CREATE TABLE stg_fact_ratings (
    order_id VARCHAR(30),
    customer_id VARCHAR(20),
    restaurant_id VARCHAR(20),
    rating DECIMAL(3,1),
    review_text VARCHAR(500),
    review_timestamp VARCHAR(30),
    sentiment_score DECIMAL(4,2)
);


-- Confirm all 8 staging tables exist
SHOW TABLES;
