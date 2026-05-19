-- QuickBite Express - Crisis Recovery Analysis
-- Table Setup Script
-- Tool: MySQL
-- Analyst: Priyanka Chaudhary

CREATE DATABASE IF NOT EXISTS quickbite_db;
USE quickbite_db;

CREATE TABLE dim_customer (
    customer_id         VARCHAR(20),
    signup_date         VARCHAR(20),
    city                VARCHAR(50),
    acquisition_channel VARCHAR(50)
);

CREATE TABLE dim_restaurant (
    restaurant_id     VARCHAR(20),
    restaurant_name   VARCHAR(100),
    city              VARCHAR(50),
    cuisine_type      VARCHAR(50),
    partner_type      VARCHAR(50),
    avg_prep_time_min VARCHAR(20),
    is_active         VARCHAR(5)
);

CREATE TABLE dim_delivery_partner (
    delivery_partner_id VARCHAR(20),
    partner_name        VARCHAR(100),
    city                VARCHAR(50),
    vehicle_type        VARCHAR(20),
    employment    VARCHAR(20),
    avg_rating          FLOAT,
    is_active           VARCHAR(5)
);

CREATE TABLE dim_menu_item (
    menu_item_id  VARCHAR(20),
    restaurant_id VARCHAR(20),
    item_name     VARCHAR(100),
    category      VARCHAR(50),
    is_veg        VARCHAR(5),
    price         FLOAT
);

CREATE TABLE fact_orders (
    order_id            VARCHAR(20),
    customer_id         VARCHAR(20),
    restaurant_id       VARCHAR(20),
    delivery_partner_id VARCHAR(20),
    order_timestamp     DATETIME,
    subtotal_amount     FLOAT,
    discount_amount     FLOAT,
    delivery_fee        FLOAT,
    total_amount        FLOAT,
    is_cod              VARCHAR(5),
    is_cancelled        VARCHAR(5)
);

CREATE TABLE fact_order_items (
    order_id      VARCHAR(20),
    item_id       VARCHAR(20),
    menu_item_id  VARCHAR(20),
    restaurant_id VARCHAR(20),
    quantity      INT,
    unit_price    FLOAT,
    item_discount FLOAT,
    line_total    FLOAT
);

CREATE TABLE fact_ratings (
    order_id         VARCHAR(20),
    customer_id      VARCHAR(20),
    restaurant_id    VARCHAR(20),
    rating           FLOAT,
    review_text      TEXT,
    review_timestamp VARCHAR(30),
    sentiment_score  FLOAT
);

CREATE TABLE fact_delivery_performance (
    order_id                    VARCHAR(20),
    actual_delivery_time_mins   INT,
    expected_delivery_time_mins INT,
    distance_km                 FLOAT
);