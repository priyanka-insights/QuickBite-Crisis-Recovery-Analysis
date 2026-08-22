-- ============================================================
-- QuickBite Express Crisis Recovery Analysis
-- 02_staging_import_check.sql
-- Purpose: Load all 8 raw CSVs into the staging tables using
-- LOAD DATA LOCAL INFILE (much faster than the Import Wizard for
-- bulk CSVs), then validate every import against the known row
-- counts from the data audit.
--
-- Setup required before this runs (one-time, per MySQL install):
--   1. In Workbench: Edit -> Preferences -> Others -> Advanced tab
--      of the connection -> add "OPT_LOCAL_INFILE=1" under "Others"
--   2. Run: SET GLOBAL local_infile = 1;
--
-- File paths below use forward slashes even on Windows, and point
-- at the data/ folder inside the project directory.
-- ============================================================

USE quickbite_express;

SET GLOBAL local_infile = 1;


-- ------------------------------------------------------------
-- Load dim_customer
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/prianka/OneDrive/Desktop/QuickBite-Express-Crisis-Recovery/data/dim_customer.csv'
INTO TABLE stg_dim_customer
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM stg_dim_customer;   -- expect 107776


-- ------------------------------------------------------------
-- Load dim_delivery_partner
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/prianka/OneDrive/Desktop/QuickBite-Express-Crisis-Recovery/data/dim_delivery_partner_.csv'
INTO TABLE stg_dim_delivery_partner
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM stg_dim_delivery_partner;   -- expect 15000


-- ------------------------------------------------------------
-- Load dim_menu_item
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/prianka/OneDrive/Desktop/QuickBite-Express-Crisis-Recovery/data/dim_menu_item.csv'
INTO TABLE stg_dim_menu_item
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM stg_dim_menu_item;   -- expect 342671


-- ------------------------------------------------------------
-- Load dim_restaurant
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/prianka/OneDrive/Desktop/QuickBite-Express-Crisis-Recovery/data/dim_restaurant.csv'
INTO TABLE stg_dim_restaurant
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM stg_dim_restaurant;   -- expect 19995


-- ------------------------------------------------------------
-- Load fact_delivery_performance
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/prianka/OneDrive/Desktop/QuickBite-Express-Crisis-Recovery/data/fact_delivery_performance.csv'
INTO TABLE stg_fact_delivery_performance
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM stg_fact_delivery_performance;   -- expect 149166


-- ------------------------------------------------------------
-- Load fact_order_items
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/prianka/OneDrive/Desktop/QuickBite-Express-Crisis-Recovery/data/fact_order_items.csv'
INTO TABLE stg_fact_order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM stg_fact_order_items;   -- expect 342994


-- ------------------------------------------------------------
-- Load fact_orders
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/prianka/OneDrive/Desktop/QuickBite-Express-Crisis-Recovery/data/fact_orders.csv'
INTO TABLE stg_fact_orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM stg_fact_orders;   -- expect 149166


-- ------------------------------------------------------------
-- Load fact_ratings
-- Note: 34 warnings are expected here (17 fully-blank rows in the
-- raw CSV cause "Incorrect decimal value" warnings for rating and
-- sentiment_score, 2 warnings per row = 34). This is not an error -
-- these 17 rows are the same blank rows identified in the audit,
-- and are filtered out later in 03_cleaning_and_views.sql using
-- WHERE order_id != '' (they load as empty strings, not NULL).
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/prianka/OneDrive/Desktop/QuickBite-Express-Crisis-Recovery/data/fact_ratings.csv'
INTO TABLE stg_fact_ratings
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM stg_fact_ratings;   -- expect 68842


-- ------------------------------------------------------------
-- Final check: all 8 staging tables loaded with expected row counts
-- ------------------------------------------------------------
SELECT 'stg_dim_customer' AS table_name, COUNT(*) AS row_count FROM stg_dim_customer
UNION ALL
SELECT 'stg_dim_delivery_partner', COUNT(*) FROM stg_dim_delivery_partner
UNION ALL
SELECT 'stg_dim_menu_item', COUNT(*) FROM stg_dim_menu_item
UNION ALL
SELECT 'stg_dim_restaurant', COUNT(*) FROM stg_dim_restaurant
UNION ALL
SELECT 'stg_fact_delivery_performance', COUNT(*) FROM stg_fact_delivery_performance
UNION ALL
SELECT 'stg_fact_order_items', COUNT(*) FROM stg_fact_order_items
UNION ALL
SELECT 'stg_fact_orders', COUNT(*) FROM stg_fact_orders
UNION ALL
SELECT 'stg_fact_ratings', COUNT(*) FROM stg_fact_ratings;
