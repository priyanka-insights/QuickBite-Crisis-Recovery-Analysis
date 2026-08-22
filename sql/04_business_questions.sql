-- ============================================================
-- QuickBite Express Crisis Recovery Analysis
-- 04_business_questions.sql
-- Purpose: All 10 official business questions, answered against
-- the cleaned tables built in 03_cleaning_and_views.sql.
-- Every query below has been run and validated - results are
-- noted as comments next to each one.
-- ============================================================

USE quickbite_express;


-- ============================================================
-- Q1: Monthly orders, pre-crisis vs crisis - severity of decline
-- ============================================================
SELECT
    DATE_FORMAT(order_timestamp, '%Y-%m') AS order_month,
    COUNT(order_id) AS total_orders
FROM fact_orders
GROUP BY DATE_FORMAT(order_timestamp, '%Y-%m')
ORDER BY order_month;

-- Official binary framing (pre-crisis vs crisis Jun-Sep)
-- Result: pre_crisis = 113806, crisis_and_after = 35360 (~69% decline)
SELECT phase_binary, COUNT(order_id) AS total_orders
FROM fact_orders
GROUP BY phase_binary;


-- ============================================================
-- Q2: Top 5 cities with highest % order decline
-- Decision: using dim_restaurant.city (restaurant's operating city),
-- not dim_customer.city, since the crisis was restaurant/city-
-- operations driven (food-safety incident + delivery outage).
-- ============================================================
WITH city_phase AS (
    SELECT
        dr.city,
        SUM(CASE WHEN fo.phase_binary = 'pre_crisis' THEN 1 ELSE 0 END) AS pre_crisis_orders,
        SUM(CASE WHEN fo.phase_binary = 'crisis_and_after' THEN 1 ELSE 0 END) AS crisis_orders
    FROM fact_orders fo
    JOIN dim_restaurant dr ON fo.restaurant_id = dr.restaurant_id
    GROUP BY dr.city
)
SELECT
    city,
    pre_crisis_orders,
    crisis_orders,
    ROUND((crisis_orders - pre_crisis_orders) / pre_crisis_orders * 100, 2) AS pct_change
FROM city_phase
WHERE pre_crisis_orders > 0
ORDER BY pct_change ASC
LIMIT 5;
-- Result: Chennai -69.98%, Kolkata -69.19%, Bengaluru -69.17%,
-- Hyderabad -68.92%, Ahmedabad -68.83%


-- ============================================================
-- Q3: Top 10 restaurants with largest % decline, among those with
-- sufficient pre-crisis volume (>=10 orders, from vw_restaurant_pre_crisis_volume)
-- Secondary sort by pre_crisis_orders DESC breaks ties among
-- restaurants that dropped to 0 crisis orders (-100%), so the
-- ranking favors the restaurants that had the most to lose.
-- ============================================================
SELECT
    v.restaurant_id,
    v.pre_crisis_orders,
    COALESCE(c.crisis_orders, 0) AS crisis_orders,
    ROUND(v.pre_crisis_orders / 5, 2) AS pre_crisis_monthly_avg,
    ROUND(COALESCE(c.crisis_orders, 0) / 2, 2) AS crisis_monthly_avg,
    ROUND(
        (COALESCE(c.crisis_orders, 0) / 2 - v.pre_crisis_orders / 5)
        / (v.pre_crisis_orders / 5) * 100, 2
    ) AS pct_change_normalized
FROM vw_restaurant_pre_crisis_volume v
LEFT JOIN (
    SELECT restaurant_id, COUNT(*) AS crisis_orders
    FROM fact_orders
    WHERE phase = 'crisis'
    GROUP BY restaurant_id
) c ON v.restaurant_id = c.restaurant_id
ORDER BY pct_change_normalized ASC, v.pre_crisis_orders DESC
LIMIT 10;
-- Result: top restaurant REST13412 (17 pre-crisis orders -> 0 crisis orders, -100%)


-- ============================================================
-- Q4: Cancellation rate trend, pre-crisis vs crisis, by city
-- ============================================================
-- Overall trend
SELECT
    phase_binary,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN is_cancelled = 'Y' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(SUM(CASE WHEN is_cancelled = 'Y' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS cancellation_rate_pct
FROM fact_orders
GROUP BY phase_binary;
-- Result: pre_crisis ~6.06%, crisis ~11.93% (roughly doubled)

-- City-wise breakdown
SELECT
    dr.city,
    fo.phase_binary,
    COUNT(*) AS total_orders,
    ROUND(SUM(CASE WHEN fo.is_cancelled = 'Y' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS cancellation_rate_pct
FROM fact_orders fo
JOIN dim_restaurant dr ON fo.restaurant_id = dr.restaurant_id
GROUP BY dr.city, fo.phase_binary
ORDER BY dr.city, fo.phase_binary;


-- ============================================================
-- Q5: Delivery SLA - average delivery time and compliance change
-- ============================================================
SELECT
    fo.phase,
    ROUND(AVG(fdp.actual_delivery_time_mins), 2) AS avg_actual_delivery_mins,
    ROUND(AVG(fdp.expected_delivery_time_mins), 2) AS avg_expected_delivery_mins,
    ROUND(
        SUM(CASE WHEN fdp.actual_delivery_time_mins > fdp.expected_delivery_time_mins THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2
    ) AS sla_breach_rate_pct
FROM fact_orders fo
JOIN fact_delivery_performance fdp ON fo.order_id = fdp.order_id
GROUP BY fo.phase
ORDER BY FIELD(fo.phase, 'pre_crisis', 'crisis', 'recovery');
-- Result: pre_crisis 39.52min/56.40% breach, crisis 60.13min/87.84% breach,
-- recovery 60.10min/87.76% breach -- SLA performance has NOT improved in
-- the recovery phase, essentially unchanged from crisis levels.


-- ============================================================
-- Q6: Month-by-month rating trend, sharpest drop
-- ============================================================
WITH monthly_ratings AS (
    SELECT
        DATE_FORMAT(review_timestamp, '%Y-%m') AS review_month,
        ROUND(AVG(rating), 2) AS avg_rating
    FROM fact_ratings
    GROUP BY DATE_FORMAT(review_timestamp, '%Y-%m')
)
SELECT
    review_month,
    avg_rating,
    ROUND(avg_rating - LAG(avg_rating) OVER (ORDER BY review_month), 2) AS rating_change
FROM monthly_ratings
ORDER BY review_month;
-- Result: sharpest drop is June 2025 (4.49 -> 2.63, change -1.86), matching
-- the crisis month exactly. Ratings stay low through Aug-Sep (~2.3-2.4),
-- meaning trust has not recovered even though "recovery" phase has started.


-- ============================================================
-- Q7: Crisis-period negative review keywords (word cloud in Power BI)
-- This result set is fed directly into Power BI's Word Cloud visual -
-- no keyword counting is done in SQL.
-- ============================================================
SELECT fr.order_id, fr.rating, fr.review_text, fr.review_timestamp
FROM fact_ratings fr
JOIN fact_orders fo ON fr.order_id = fo.order_id
WHERE fo.phase = 'crisis' AND fr.rating <= 2;
-- Result: recurring themes - "Food safety issue", "Terrible hygiene",
-- "Stale food served", "Packaging issue", "Very late"


-- ============================================================
-- Q8: Revenue impact / loss estimate
-- ============================================================
SELECT
    phase,
    ROUND(SUM(subtotal_amount), 2) AS total_subtotal,
    ROUND(SUM(discount_amount), 2) AS total_discount,
    ROUND(SUM(delivery_fee), 2) AS total_delivery_fee,
    ROUND(SUM(total_amount), 2) AS total_revenue
FROM fact_orders
GROUP BY phase
ORDER BY FIELD(phase, 'pre_crisis', 'crisis', 'recovery');

-- Estimated revenue loss: (pre-crisis monthly avg x crisis months) - actual crisis revenue
SELECT
    ROUND(SUM(CASE WHEN phase = 'pre_crisis' THEN total_amount ELSE 0 END), 2) AS pre_crisis_revenue,
    ROUND(SUM(CASE WHEN phase = 'crisis' THEN total_amount ELSE 0 END), 2) AS crisis_revenue,
    ROUND(SUM(CASE WHEN phase = 'pre_crisis' THEN total_amount ELSE 0 END) / 5 * 2, 2) AS expected_crisis_revenue,
    ROUND(
        SUM(CASE WHEN phase = 'pre_crisis' THEN total_amount ELSE 0 END) / 5 * 2
        - SUM(CASE WHEN phase = 'crisis' THEN total_amount ELSE 0 END), 2
    ) AS estimated_revenue_loss
FROM fact_orders;
-- Result: pre_crisis revenue Rs.3,76,20,964.25, crisis revenue Rs.56,12,490.20,
-- expected crisis revenue (extrapolated) Rs.1,50,48,385.70,
-- estimated revenue loss = Rs.94,35,895.50


-- ============================================================
-- Q9: Loyalty impact - customers with 5+ pre-crisis orders,
-- how many churned, and how many of those had avg rating > 4.5
-- Broken into 3 simple steps instead of one large query, so each
-- part is independently testable.
-- ============================================================

-- Step 1: loyal customers (>=5 pre-crisis orders, valid customer only)
-- Result: 58
WITH loyal_customers AS (
    SELECT fo.customer_id
    FROM fact_orders fo
    INNER JOIN dim_customer dc ON fo.customer_id = dc.customer_id
    WHERE fo.phase = 'pre_crisis'
    GROUP BY fo.customer_id
    HAVING COUNT(*) >= 5
)
SELECT COUNT(*) AS total_loyal_customers FROM loyal_customers;

-- Step 2: of those, how many churned (zero crisis-phase orders)
-- Result: 51 (88% of loyal customers churned)
WITH loyal_customers AS (
    SELECT fo.customer_id
    FROM fact_orders fo
    INNER JOIN dim_customer dc ON fo.customer_id = dc.customer_id
    WHERE fo.phase = 'pre_crisis'
    GROUP BY fo.customer_id
    HAVING COUNT(*) >= 5
)
SELECT COUNT(*) AS churned_customers
FROM loyal_customers lc
WHERE lc.customer_id NOT IN (SELECT customer_id FROM fact_orders WHERE phase = 'crisis');

-- Step 3: of the churned, how many had avg pre-crisis rating > 4.5
-- Result: 26 (51% of churned customers were highly satisfied -
-- this is loyalty-driven churn, not dissatisfaction-driven churn)
WITH loyal_customers AS (
    SELECT fo.customer_id
    FROM fact_orders fo
    INNER JOIN dim_customer dc ON fo.customer_id = dc.customer_id
    WHERE fo.phase = 'pre_crisis'
    GROUP BY fo.customer_id
    HAVING COUNT(*) >= 5
),
churned_customers AS (
    SELECT customer_id FROM loyal_customers
    WHERE customer_id NOT IN (SELECT customer_id FROM fact_orders WHERE phase = 'crisis')
),
high_satisfaction_churned AS (
    SELECT cc.customer_id, AVG(fr.rating) AS avg_pre_crisis_rating
    FROM churned_customers cc
    JOIN fact_ratings fr ON cc.customer_id = fr.customer_id
    GROUP BY cc.customer_id
    HAVING AVG(fr.rating) > 4.5
)
SELECT COUNT(*) AS churned_high_satisfaction_count FROM high_satisfaction_churned;


-- ============================================================
-- Q10: Top 5% customers by pre-crisis spend - drop in frequency,
-- common patterns (city). A view handles the NTILE bucketing
-- (complex logic, similar to vw_restaurant_pre_crisis_volume),
-- then simple queries read from it.
-- ============================================================

-- View: top 5% customers by pre-crisis spend
CREATE VIEW vw_top5pct_customers AS
SELECT customer_id, pre_crisis_spend, pre_crisis_orders
FROM (
    SELECT
        fo.customer_id,
        SUM(fo.total_amount) AS pre_crisis_spend,
        COUNT(*) AS pre_crisis_orders,
        NTILE(20) OVER (ORDER BY SUM(fo.total_amount) DESC) AS spend_bucket
    FROM fact_orders fo
    INNER JOIN dim_customer dc ON fo.customer_id = dc.customer_id
    WHERE fo.phase = 'pre_crisis'
    GROUP BY fo.customer_id
) t
WHERE spend_bucket = 1;

-- Sanity check: how many customers in this top-5% group
-- Result: 4187
SELECT COUNT(*) FROM vw_top5pct_customers;

-- Crisis-phase behavior, summarized (not a row-by-row export, since
-- Workbench's default 1000-row display limit would truncate a
-- customer-by-customer list and undercount the real pattern)
-- Result: 3826 customers (91.38%) had ZERO crisis orders,
-- 361 customers (8.62%) had 1-2 crisis orders. No customer in this
-- top-5% group had 3+ crisis orders.
SELECT
    CASE
        WHEN crisis_orders = 0 THEN 'Zero crisis orders (fully churned)'
        WHEN crisis_orders BETWEEN 1 AND 2 THEN 'Very low crisis activity'
        ELSE '3+ crisis orders'
    END AS crisis_behavior_bucket,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) / 4187 * 100, 2) AS pct_of_top5pct
FROM (
    SELECT
        v.customer_id,
        COUNT(fo.order_id) AS crisis_orders
    FROM vw_top5pct_customers v
    LEFT JOIN fact_orders fo ON v.customer_id = fo.customer_id AND fo.phase = 'crisis'
    GROUP BY v.customer_id
) t
GROUP BY crisis_behavior_bucket;

-- Common pattern: city breakdown
-- Result: Bengaluru 1221 (29%), Mumbai 714, Delhi 578, Chennai 410,
-- Hyderabad 388, Pune 321, Kolkata 282, Ahmedabad 273
SELECT dc.city, COUNT(*) AS customer_count
FROM vw_top5pct_customers v
JOIN dim_customer dc ON v.customer_id = dc.customer_id
GROUP BY dc.city
ORDER BY customer_count DESC;
