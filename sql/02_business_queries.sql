/*
    QuickBite Express - Crisis Recovery Analysis
    Business Analysis Queries
    Tool: MySQL Workbench
    Analyst: Priyanka Chaudhary

    Phase Definition used throughout this file:
    Pre-Crisis : Jan 2025 to May 2025 (5 months baseline)
    Crisis     : Jun 2025 to Jul 2025 (2 months of crisis)
    Recovery   : Aug 2025 to Sep 2025 (2 months recovery)

    Dataset: 149,166 orders across 8 cities
    Period: January 2025 to September 2025
*/


USE quickbite_db;


-- Q1. Monthly Order Trend
-- Goal: Measure how severely orders declined after the June 2025 crisis
-- This is the first thing leadership wants to see - the headline decline number

SELECT
    DATE_FORMAT(order_timestamp, '%Y-%m') AS order_month,

    CASE
        WHEN order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        WHEN order_timestamp < '2025-08-01' THEN 'Crisis'
        ELSE 'Recovery'
    END AS business_phase,

    COUNT(order_id) AS total_orders

FROM fact_orders

GROUP BY DATE_FORMAT(order_timestamp, '%Y-%m'), business_phase

ORDER BY order_month;


-- Q2. Revenue Impact by Business Phase
-- Goal: Quantify the actual revenue loss caused by the crisis
-- Using total_amount which is post-discount, post-fee final amount

SELECT
    CASE
        WHEN order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        WHEN order_timestamp < '2025-08-01' THEN 'Crisis'
        ELSE 'Recovery'
    END AS business_phase,

    COUNT(order_id) AS total_orders,

    ROUND(SUM(total_amount), 2) AS total_revenue,

    ROUND(SUM(total_amount) / 10000000, 2) AS revenue_in_crores,

    ROUND(AVG(total_amount), 2) AS avg_order_value

FROM fact_orders
WHERE is_cancelled = 'N'

GROUP BY business_phase

ORDER BY
    CASE business_phase
        WHEN 'Pre-Crisis' THEN 1
        WHEN 'Crisis' THEN 2
        ELSE 3
    END;


-- Q3. City-wise Cancellation Rate by Phase
-- Goal: Identify which cities had the worst cancellation problem
-- Helps prioritize where to focus operational recovery efforts

SELECT
    c.city,

    CASE
        WHEN o.order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        WHEN o.order_timestamp < '2025-08-01' THEN 'Crisis'
        ELSE 'Recovery'
    END AS business_phase,

    COUNT(o.order_id) AS total_orders,

    SUM(CASE WHEN o.is_cancelled = 'Y' THEN 1 ELSE 0 END) AS cancelled_orders,

    ROUND(
        SUM(CASE WHEN o.is_cancelled = 'Y' THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id),
        2
    ) AS cancellation_rate_pct

FROM fact_orders o
JOIN dim_customer c ON o.customer_id = c.customer_id

GROUP BY c.city, business_phase

ORDER BY cancellation_rate_pct DESC;


-- Q4. Restaurants with Highest Order Decline During Crisis
-- Goal: Identify which restaurant partners were most impacted
-- Using monthly average to make pre-crisis (5 months) and crisis (2 months) comparable
-- Threshold set to monthly avg >= 2 orders which equals 10+ total pre-crisis orders

WITH pre_crisis_orders AS (

    SELECT
        restaurant_id,
        COUNT(order_id) / 5.0 AS avg_monthly_pre_orders
    FROM fact_orders
    WHERE order_timestamp < '2025-06-01'
    GROUP BY restaurant_id

),

crisis_orders AS (

    SELECT
        restaurant_id,
        COUNT(order_id) / 2.0 AS avg_monthly_crisis_orders
    FROM fact_orders
    WHERE order_timestamp >= '2025-06-01'
      AND order_timestamp < '2025-08-01'
    GROUP BY restaurant_id

)

SELECT
    r.restaurant_name,
    r.city,
    r.cuisine_type,

    ROUND(p.avg_monthly_pre_orders, 1) AS pre_crisis_avg_monthly_orders,

    ROUND(COALESCE(c.avg_monthly_crisis_orders, 0), 1) AS crisis_avg_monthly_orders,

    ROUND(
        (p.avg_monthly_pre_orders - COALESCE(c.avg_monthly_crisis_orders, 0))
        / p.avg_monthly_pre_orders * 100,
        2
    ) AS decline_pct

FROM pre_crisis_orders p
LEFT JOIN crisis_orders c ON p.restaurant_id = c.restaurant_id
JOIN dim_restaurant r ON p.restaurant_id = r.restaurant_id

WHERE p.avg_monthly_pre_orders >= 2

ORDER BY decline_pct DESC

LIMIT 10;


-- Q5. Delivery SLA Performance by Phase
-- Goal: Measure how delivery performance deteriorated across phases
-- SLA breach = actual delivery time exceeded expected delivery time

SELECT
    CASE
        WHEN o.order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        WHEN o.order_timestamp < '2025-08-01' THEN 'Crisis'
        ELSE 'Recovery'
    END AS business_phase,

    ROUND(AVG(d.actual_delivery_time_mins), 2) AS avg_actual_delivery_mins,

    ROUND(AVG(d.expected_delivery_time_mins), 2) AS avg_expected_delivery_mins,

    ROUND(AVG(d.actual_delivery_time_mins - d.expected_delivery_time_mins), 2) AS avg_delay_mins,

    ROUND(
        SUM(CASE WHEN d.actual_delivery_time_mins > d.expected_delivery_time_mins THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS sla_breach_rate_pct

FROM fact_orders o
JOIN fact_delivery_performance d ON o.order_id = d.order_id

GROUP BY business_phase

ORDER BY
    CASE business_phase
        WHEN 'Pre-Crisis' THEN 1
        WHEN 'Crisis' THEN 2
        ELSE 3
    END;


-- Q6. Loyal Customer Churn Analysis
-- Goal: Find how many loyal customers stopped ordering during crisis
-- Loyal = customers who placed 2 or more orders before crisis
-- Only counting non-cancelled orders to measure genuine ordering behavior

WITH loyal_customers AS (

    SELECT
        customer_id,
        COUNT(order_id) AS pre_crisis_orders
    FROM fact_orders
    WHERE order_timestamp < '2025-06-01'
      
    GROUP BY customer_id
    HAVING COUNT(order_id) >= 2
),

crisis_active AS (

    SELECT DISTINCT customer_id
    FROM fact_orders
    WHERE order_timestamp >= '2025-06-01'
      AND order_timestamp < '2025-08-01'

)

SELECT
    COUNT(l.customer_id) AS total_loyal_customers,

    SUM(CASE WHEN ca.customer_id IS NULL THEN 1 ELSE 0 END) AS churned_loyal_customers,

    SUM(CASE WHEN ca.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS retained_loyal_customers,

    ROUND(
        SUM(CASE WHEN ca.customer_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(l.customer_id),
        2
    ) AS churn_rate_pct

FROM loyal_customers l
LEFT JOIN crisis_active ca ON l.customer_id = ca.customer_id;


-- Q7. High-Value Customers by City
-- Goal: Identify which cities have the most high-value customers
-- High-value = top 5% by total spend during pre-crisis period
-- Using NTILE(20) window function - group 1 represents top 5%

WITH customer_spending AS (

    SELECT
        o.customer_id,
        c.city,
        SUM(o.total_amount) AS total_spend
    FROM fact_orders o
    JOIN dim_customer c ON o.customer_id = c.customer_id
    WHERE o.order_timestamp < '2025-06-01'
      AND o.is_cancelled = 'N'
    GROUP BY o.customer_id, c.city

),

ranked_customers AS (

    SELECT
        customer_id,
        city,
        total_spend,
        NTILE(20) OVER (ORDER BY total_spend DESC) AS spending_group
    FROM customer_spending

)

SELECT
    city,
    COUNT(customer_id) AS high_value_customers,
    ROUND(AVG(total_spend), 2) AS avg_spend_per_customer,
    ROUND(MIN(total_spend), 2) AS min_spend_threshold

FROM ranked_customers

WHERE spending_group = 1

GROUP BY city

ORDER BY high_value_customers DESC;


-- Q8. Monthly Customer Rating and Sentiment Trend
-- Goal: Track when customer satisfaction dropped and by how much
-- Joining on order_id to get the phase context from fact_orders

SELECT
    DATE_FORMAT(o.order_timestamp, '%Y-%m') AS order_month,

    CASE
        WHEN o.order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        WHEN o.order_timestamp < '2025-08-01' THEN 'Crisis'
        ELSE 'Recovery'
    END AS business_phase,

    COUNT(r.order_id) AS total_reviews,

    ROUND(AVG(r.rating), 2) AS avg_rating,

    ROUND(AVG(r.sentiment_score), 2) AS avg_sentiment_score

FROM fact_orders o
JOIN fact_ratings r ON o.order_id = r.order_id

GROUP BY DATE_FORMAT(o.order_timestamp, '%Y-%m'), business_phase

ORDER BY order_month;


-- Q9. Delivery Delay Impact on Customer Ratings
-- Goal: Confirm whether late deliveries directly caused lower ratings
-- This validates that fixing delivery will improve satisfaction scores

SELECT
    CASE
        WHEN d.actual_delivery_time_mins > d.expected_delivery_time_mins
        THEN 'Delayed'
        ELSE 'On Time'
    END AS delivery_status,

    COUNT(o.order_id) AS total_orders,

    ROUND(AVG(r.rating), 2) AS avg_customer_rating,

    ROUND(AVG(r.sentiment_score), 2) AS avg_sentiment_score,

    ROUND(AVG(d.actual_delivery_time_mins), 2) AS avg_delivery_mins

FROM fact_orders o
JOIN fact_delivery_performance d ON o.order_id = d.order_id
JOIN fact_ratings r ON o.order_id = r.order_id

GROUP BY delivery_status;


-- Q10. Recovery Phase Effectiveness
-- Goal: Evaluate whether recovery efforts actually improved anything
-- This is a consolidated phase comparison across all key metrics
-- Critical finding: recovery phase metrics remain identical to crisis levels

SELECT
    CASE
        WHEN o.order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
        WHEN o.order_timestamp < '2025-08-01' THEN 'Crisis'
        ELSE 'Recovery'
    END AS business_phase,

    COUNT(o.order_id) AS total_orders,

    ROUND(AVG(r.rating), 2) AS avg_rating,

    ROUND(AVG(r.sentiment_score), 2) AS avg_sentiment,

    ROUND(AVG(d.actual_delivery_time_mins), 2) AS avg_delivery_mins,

    ROUND(
        SUM(CASE WHEN d.actual_delivery_time_mins > d.expected_delivery_time_mins THEN 1 ELSE 0 END)
        * 100.0 / COUNT(o.order_id),
        2
    ) AS sla_breach_pct,

    ROUND(
        SUM(CASE WHEN o.is_cancelled = 'Y' THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id),
        2
    ) AS cancellation_rate_pct

FROM fact_orders o
LEFT JOIN fact_ratings r ON o.order_id = r.order_id
LEFT JOIN fact_delivery_performance d ON o.order_id = d.order_id

GROUP BY business_phase

ORDER BY
    CASE business_phase
        WHEN 'Pre-Crisis' THEN 1
        WHEN 'Crisis' THEN 2
        ELSE 3
    END;
