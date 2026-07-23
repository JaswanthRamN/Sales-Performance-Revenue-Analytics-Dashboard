-- ============================================================================
-- CUSTOMER ANALYTICS QUERIES
-- Sales Performance & Revenue Analytics Dashboard
-- ============================================================================
-- Database   : sales_analytics
-- Author     : JaswanthRamN
-- Created    : 2026-07-23
-- Description: Customer-centric KPIs including acquisition, retention,
--              spending behavior, and lifetime value.
-- ============================================================================


-- ============================================================================
-- 1. TOTAL CUSTOMERS
-- ============================================================================
-- Counts every unique customer who has placed at least one order.
-- We use DISTINCT on customer_id from the orders table (not the customers
-- table) so we only count buyers, not just registered users.
-- NULL customer_ids (guest checkouts) are excluded.
-- ============================================================================

SELECT
    COUNT(DISTINCT customer_id) AS total_customers
FROM orders
WHERE customer_id IS NOT NULL;


-- ============================================================================
-- 2. NEW CUSTOMERS
-- ============================================================================
-- A "new" customer is one whose FIRST order falls within a chosen period.
-- We find each customer's earliest order_date with a subquery, then filter
-- to the target date range.
--
-- Adjust the date literals to match your reporting period.
-- ============================================================================

SELECT
    COUNT(*) AS new_customers
FROM (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date
    FROM orders
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
) first_orders
WHERE first_order_date >= '2025-01-01'
  AND first_order_date <  '2026-01-01';

-- Breakdown by month (useful for trend charts in Power BI):

SELECT
    DATE_TRUNC('month', first_order_date)  AS acquisition_month,
    COUNT(*)                               AS new_customers
FROM (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date
    FROM orders
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
) first_orders
GROUP BY DATE_TRUNC('month', first_order_date)
ORDER BY acquisition_month;


-- ============================================================================
-- 3. RETURNING CUSTOMERS
-- ============================================================================
-- A returning customer is one who has placed MORE THAN ONE order.
-- We count orders per customer and keep only those with order_count > 1.
--
-- "Total Customers = New + Returning" only holds when both queries share
-- the same date window. The query below is an all-time count.
-- ============================================================================

SELECT
    COUNT(*) AS returning_customers
FROM (
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM orders
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING COUNT(DISTINCT order_id) > 1
) repeat_buyers;


-- ============================================================================
-- 4. REPEAT PURCHASE RATE (%)
-- ============================================================================
-- Repeat Purchase Rate = (Returning Customers / Total Customers) × 100
--
-- Both numerator and denominator are computed in a single pass using
-- conditional aggregation. A rate above 30% is typically healthy for
-- retail; below 20% signals retention problems.
-- ============================================================================

SELECT
    COUNT(DISTINCT customer_id)
        AS total_customers,

    COUNT(DISTINCT CASE WHEN order_count > 1 THEN customer_id END)
        AS returning_customers,

    ROUND(
        COUNT(DISTINCT CASE WHEN order_count > 1 THEN customer_id END) * 100.0
        / NULLIF(COUNT(DISTINCT customer_id), 0),
        2
    ) AS repeat_purchase_rate_pct

FROM (
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM orders
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
) customer_orders;


-- ============================================================================
-- 5. AVERAGE CUSTOMER SPEND
-- ============================================================================
-- Total revenue attributed to each customer divided by the number of
-- customers. Revenue is the sum of line_total from order_items, joined
-- back to orders for the customer link.
--
-- Only completed / shipped orders are included (excludes Cancelled and
-- Returned to avoid inflating the metric).
-- ============================================================================

SELECT
    ROUND(
        SUM(oi.line_total) / NULLIF(COUNT(DISTINCT o.customer_id), 0),
        2
    ) AS avg_customer_spend
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.customer_id IS NOT NULL
  AND o.order_status IN ('Completed', 'Shipped', 'Processing');

-- Per-segment breakdown (feeds the Power BI slicer):

SELECT
    c.customer_segment,
    COUNT(DISTINCT o.customer_id)                                   AS customers,
    ROUND(SUM(oi.line_total), 2)                                    AS total_revenue,
    ROUND(SUM(oi.line_total) / NULLIF(COUNT(DISTINCT o.customer_id), 0), 2)
                                                                    AS avg_spend
FROM orders o
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN customers  c   ON c.customer_id = o.customer_id
WHERE o.order_status IN ('Completed', 'Shipped', 'Processing')
GROUP BY c.customer_segment
ORDER BY avg_spend DESC;


-- ============================================================================
-- 6. TOP CUSTOMERS (by Revenue)
-- ============================================================================
-- Ranks customers by their total spend across all valid orders.
-- DENSE_RANK handles ties (two customers with identical revenue both
-- get the same rank). The query returns the Top 20 but you can adjust
-- the LIMIT / TOP N as needed.
-- ============================================================================

SELECT
    o.customer_id,
    c.first_name || ' ' || c.last_name          AS customer_name,
    c.customer_segment,
    c.region,
    COUNT(DISTINCT o.order_id)                   AS total_orders,
    ROUND(SUM(oi.line_total), 2)                 AS total_revenue,
    ROUND(AVG(oi.line_total), 2)                 AS avg_order_value,
    MIN(o.order_date)                            AS first_order,
    MAX(o.order_date)                            AS last_order,
    DENSE_RANK() OVER (ORDER BY SUM(oi.line_total) DESC)
                                                 AS revenue_rank
FROM orders o
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN customers  c   ON c.customer_id = o.customer_id
WHERE o.order_status IN ('Completed', 'Shipped', 'Processing')
GROUP BY
    o.customer_id,
    c.first_name,
    c.last_name,
    c.customer_segment,
    c.region
ORDER BY total_revenue DESC
LIMIT 20;


-- ============================================================================
-- 7. CUSTOMER LIFETIME VALUE (CLV) — Basic Model
-- ============================================================================
-- A simplified, historical CLV calculated per customer:
--
--   CLV = Avg Order Value  ×  Purchase Frequency  ×  Customer Lifespan (years)
--
-- Where:
--   • Avg Order Value    = total_revenue / total_orders
--   • Purchase Frequency = total_orders  / active_years  (orders per year)
--   • Customer Lifespan  = years between first and last order (min 1 year
--                          for single-purchase customers to avoid zero)
--
-- This is a descriptive (backward-looking) CLV, not a predictive model.
-- For predictive CLV you would layer in churn probability (BG/NBD model).
-- ============================================================================

SELECT
    o.customer_id,
    c.first_name || ' ' || c.last_name                    AS customer_name,
    c.customer_segment,

    -- Component metrics
    COUNT(DISTINCT o.order_id)                             AS total_orders,
    ROUND(SUM(oi.line_total), 2)                           AS total_revenue,
    ROUND(SUM(oi.line_total)
          / NULLIF(COUNT(DISTINCT o.order_id), 0), 2)      AS avg_order_value,

    MIN(o.order_date)                                      AS first_order,
    MAX(o.order_date)                                      AS last_order,

    -- Lifespan in years (minimum 1 to handle single-order customers)
    GREATEST(
        ROUND(
            (MAX(o.order_date) - MIN(o.order_date)) / 365.25,
            2
        ),
        1
    )                                                      AS lifespan_years,

    -- Purchase frequency (orders per year)
    ROUND(
        COUNT(DISTINCT o.order_id)
        / GREATEST(
            (MAX(o.order_date) - MIN(o.order_date)) / 365.25,
            1
          ),
        2
    )                                                      AS purchase_frequency,

    -- CLV = Avg Order Value × Purchase Frequency × Lifespan
    ROUND(
        (SUM(oi.line_total) / NULLIF(COUNT(DISTINCT o.order_id), 0))
        * (COUNT(DISTINCT o.order_id)
           / GREATEST((MAX(o.order_date) - MIN(o.order_date)) / 365.25, 1))
        * GREATEST((MAX(o.order_date) - MIN(o.order_date)) / 365.25, 1),
        2
    )                                                      AS customer_lifetime_value

FROM orders o
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN customers  c   ON c.customer_id = o.customer_id
WHERE o.order_status IN ('Completed', 'Shipped', 'Processing')
GROUP BY
    o.customer_id,
    c.first_name,
    c.last_name,
    c.customer_segment
ORDER BY customer_lifetime_value DESC;


-- ============================================================================
-- 8. CLV SUMMARY BY SEGMENT
-- ============================================================================
-- Aggregates CLV at the segment level so you can compare the average
-- lifetime value of Regular vs Premium vs VIP vs New customers.
-- ============================================================================

WITH customer_clv AS (
    SELECT
        o.customer_id,
        c.customer_segment,
        COUNT(DISTINCT o.order_id)                         AS total_orders,
        SUM(oi.line_total)                                 AS total_revenue,
        GREATEST(
            (MAX(o.order_date) - MIN(o.order_date)) / 365.25,
            1
        )                                                  AS lifespan_years
    FROM orders o
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN customers  c   ON c.customer_id = o.customer_id
    WHERE o.order_status IN ('Completed', 'Shipped', 'Processing')
    GROUP BY o.customer_id, c.customer_segment
)
SELECT
    customer_segment,
    COUNT(*)                                               AS customers,
    ROUND(AVG(total_revenue), 2)                           AS avg_total_revenue,
    ROUND(AVG(total_orders), 1)                            AS avg_orders,
    ROUND(AVG(lifespan_years), 2)                          AS avg_lifespan_years,
    ROUND(AVG(total_revenue / NULLIF(total_orders, 0)), 2) AS avg_order_value,
    ROUND(AVG(
        (total_revenue / NULLIF(total_orders, 0))
        * (total_orders / lifespan_years)
        * lifespan_years
    ), 2)                                                  AS avg_clv
FROM customer_clv
GROUP BY customer_segment
ORDER BY avg_clv DESC;
