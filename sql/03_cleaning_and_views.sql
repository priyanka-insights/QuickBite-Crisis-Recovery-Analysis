-- ============================================================
-- QuickBite Express Crisis Recovery Analysis
-- 03_cleaning_and_views.sql
-- Purpose: Convert staging tables (raw, VARCHAR-only) into clean,
--          typed tables that all later SQL queries and Power BI
--          will read from. This is the single source of truth.
-- ============================================================

USE quickbite_express;


-- ------------------------------------------------------------
-- 3.1 Cleaned fact_orders: proper DATETIME and DECIMAL types
-- ------------------------------------------------------------
CREATE TABLE fact_orders AS
SELECT
    order_id,
    customer_id,
    restaurant_id,
    delivery_partner_id,
    STR_TO_DATE(order_timestamp, '%Y-%m-%d %H:%i:%s') AS order_timestamp,
    CAST(subtotal_amount AS DECIMAL(10,2)) AS subtotal_amount,
    CAST(discount_amount AS DECIMAL(10,2)) AS discount_amount,
    CAST(delivery_fee AS DECIMAL(10,2)) AS delivery_fee,
    CAST(total_amount AS DECIMAL(10,2)) AS total_amount,
    is_cod,
    is_cancelled
FROM stg_fact_orders;

-- Validation: expect 149166 rows, date range 2025-01-01 to 2025-09-30
SELECT COUNT(*) FROM fact_orders;
SELECT MIN(order_timestamp), MAX(order_timestamp) FROM fact_orders;


-- ------------------------------------------------------------
-- 3.2 Phase tagging (pre_crisis / crisis / recovery)
-- Boundaries: pre_crisis = Jan-May 2025 (5mo), crisis = Jun-Jul 2025 (2mo),
-- recovery = Aug-Sep 2025 (2mo). phase_binary matches the official
-- Q1 framing (pre-crisis vs crisis Jun-Sep combined).
-- ------------------------------------------------------------
ALTER TABLE fact_orders ADD COLUMN phase VARCHAR(20);
ALTER TABLE fact_orders ADD COLUMN phase_binary VARCHAR(20);

SET SQL_SAFE_UPDATES = 0;  -- needed since these UPDATEs have no WHERE clause (update all rows)

UPDATE fact_orders
SET phase = CASE
    WHEN order_timestamp < '2025-06-01' THEN 'pre_crisis'
    WHEN order_timestamp >= '2025-06-01' AND order_timestamp < '2025-08-01' THEN 'crisis'
    ELSE 'recovery'
END;

UPDATE fact_orders
SET phase_binary = CASE
    WHEN order_timestamp < '2025-06-01' THEN 'pre_crisis'
    ELSE 'crisis_and_after'
END;

-- Validation: expect pre_crisis=113806, crisis=18111, recovery=17249
SELECT phase, COUNT(*) FROM fact_orders GROUP BY phase;
-- Validation: expect pre_crisis=113806, crisis_and_after=35360
SELECT phase_binary, COUNT(*) FROM fact_orders GROUP BY phase_binary;


-- ------------------------------------------------------------
-- 3.3 customer_in_dim flag
-- 3.39% of fact_orders (5,053 rows) reference a customer_id NOT
-- present in dim_customer. Rather than silently dropping these
-- rows, flag them explicitly so customer-level queries (RFM, Q9,
-- Q10) can filter them out on purpose, while order-level/volume/
-- revenue queries (Q1, Q2, Q4, Q5, Q8) can keep them.
--
-- Indexes added first: a plain correlated EXISTS subquery timed
-- out on this data size; a JOIN without an index on customer_id
-- was also too slow. Indexing customer_id on both tables made the
-- JOIN-based UPDATE finish in ~10 seconds instead of timing out.
-- ------------------------------------------------------------
ALTER TABLE stg_dim_customer ADD INDEX idx_customer_id (customer_id);
ALTER TABLE fact_orders ADD INDEX idx_fo_customer_id (customer_id);

ALTER TABLE fact_orders ADD COLUMN customer_in_dim TINYINT(1);

UPDATE fact_orders fo
LEFT JOIN stg_dim_customer dc ON fo.customer_id = dc.customer_id
SET fo.customer_in_dim = IF(dc.customer_id IS NOT NULL, 1, 0);

-- Validation: expect 1 -> 144113, 0 -> 5053
SELECT customer_in_dim, COUNT(*) FROM fact_orders GROUP BY customer_in_dim;


-- ------------------------------------------------------------
-- 3.4 Cleaned dim_customer and fact_ratings
-- signup_date is DD-MM-YYYY, needs explicit dayfirst-style parsing.
-- fact_ratings has 17 rows that came in as empty strings ('') for
-- order_id (not NULL) - filtered out with != '' rather than
-- IS NOT NULL, since MySQL's LOAD DATA turns blank CSV fields into
-- empty strings for VARCHAR columns, not NULL.
-- ------------------------------------------------------------
CREATE TABLE dim_customer AS
SELECT
    customer_id,
    STR_TO_DATE(signup_date, '%d-%m-%Y') AS signup_date,
    city,
    acquisition_channel
FROM stg_dim_customer;

-- Validation: expect 107776 rows
SELECT COUNT(*) FROM dim_customer;
SELECT MIN(signup_date), MAX(signup_date) FROM dim_customer;

CREATE TABLE fact_ratings AS
SELECT
    order_id,
    customer_id,
    restaurant_id,
    CAST(rating AS DECIMAL(3,1)) AS rating,
    review_text,
    STR_TO_DATE(review_timestamp, '%d-%m-%Y %H:%i') AS review_timestamp,
    CAST(sentiment_score AS DECIMAL(4,2)) AS sentiment_score
FROM stg_fact_ratings
WHERE order_id != '';

-- Validation: expect 68825 rows (68842 - 17 blank rows)
SELECT COUNT(*) FROM fact_ratings;


-- ------------------------------------------------------------
-- 3.5 Remaining tables - copied as-is (no date/phase changes needed)
-- ------------------------------------------------------------
CREATE TABLE dim_restaurant AS SELECT * FROM stg_dim_restaurant;
CREATE TABLE dim_delivery_partner AS SELECT * FROM stg_dim_delivery_partner;
CREATE TABLE dim_menu_item AS SELECT * FROM stg_dim_menu_item;
CREATE TABLE fact_order_items AS SELECT * FROM stg_fact_order_items;
CREATE TABLE fact_delivery_performance AS SELECT * FROM stg_fact_delivery_performance;

-- Validation: match against audit numbers
SELECT COUNT(*) FROM dim_restaurant;              -- expect 19995
SELECT COUNT(*) FROM dim_delivery_partner;         -- expect 15000
SELECT COUNT(*) FROM dim_menu_item;                -- expect 342671
SELECT COUNT(*) FROM fact_order_items;             -- expect 342994
SELECT COUNT(*) FROM fact_delivery_performance;    -- expect 149166


-- ------------------------------------------------------------
-- 3.6 View for Q3's "sufficient volume" threshold
-- Only 1,292 restaurants have >=10 pre-crisis orders (avg was
-- 5.71, max 21 - a threshold of 50 or even 20 is not usable with
-- this data). This view is reused directly in Q3 instead of
-- recalculating the threshold logic in every query.
-- ------------------------------------------------------------
CREATE VIEW vw_restaurant_pre_crisis_volume AS
SELECT restaurant_id, COUNT(*) AS pre_crisis_orders
FROM fact_orders
WHERE phase = 'pre_crisis'
GROUP BY restaurant_id
HAVING COUNT(*) >= 10;

-- Validation: expect 1292 restaurants
SELECT COUNT(*) FROM vw_restaurant_pre_crisis_volume;
