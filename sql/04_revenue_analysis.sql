-- ============================================================================
-- REVENUE & SALES ANALYTICS QUERIES
-- Sales Performance & Revenue Analytics Dashboard
-- ============================================================================
-- Author     : JaswanthRamN
-- Created    : 2026-07-22
-- Description: Core KPI queries for revenue analysis. Each query includes
--              an explanation of business logic, calculation method, and
--              which tables/columns are used.
--
-- Revenue Logic:
--   Gross Revenue  = SUM(order_items.line_total)
--   Net Revenue    = Gross Revenue − Refunds − Order-level Discounts
--   Refunds        = SUM(returns.refund_amount) WHERE refund_status = 'Processed'
-- 
-- Filter Logic:
--   Only 'Completed' and 'Shipped' orders count toward revenue.
--   'Cancelled', 'Processing', and 'Returned' orders are excluded.
-- ============================================================================


-- ============================================================================
-- 1. TOTAL REVENUE (All-Time)
-- ============================================================================
-- Calculates overall gross revenue, total refunds, order-level discounts,
-- and net revenue across the entire dataset.
--
-- Gross Revenue  : Sum of all line totals from completed/shipped orders
-- Total Refunds  : Sum of processed refund amounts
-- Total Discounts: Sum of order-level discount amounts
-- Net Revenue    : Gross Revenue − Refunds − Discounts
-- ============================================================================

SELECT
    SUM(oi.line_total)                                          AS gross_revenue,
    COALESCE(ref.total_refunds, 0)                              AS total_refunds,
    SUM(DISTINCT o.order_id || ':' || o.discount_amount) * 0 
        + disc.total_discounts                                  AS total_discounts,
    SUM(oi.line_total) 
        - COALESCE(ref.total_refunds, 0) 
        - disc.total_discounts                                  AS net_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
-- Subquery: total processed refunds
CROSS JOIN (
    SELECT COALESCE(SUM(r.refund_amount), 0) AS total_refunds
    FROM returns r
    WHERE r.refund_status = 'Processed'
) ref
-- Subquery: total order-level discounts (only from revenue-qualifying orders)
CROSS JOIN (
    SELECT COALESCE(SUM(o2.discount_amount), 0) AS total_discounts
    FROM orders o2
    WHERE o2.order_status IN ('Completed', 'Shipped')
) disc
WHERE o.order_status IN ('Completed', 'Shipped');


-- ============================================================================
-- 2. MONTHLY REVENUE
-- ============================================================================
-- Breaks down gross and net revenue by calendar month.
-- Uses order_date to assign revenue to months.
--
-- Columns:
--   revenue_year/month : Calendar period
--   total_orders       : Count of distinct orders in that month
--   gross_revenue      : Sum of line totals before refunds
--   total_refunds      : Processed refunds for orders placed in that month
--   net_revenue        : Gross minus refunds
-- ============================================================================

SELECT
    CAST(strftime('%Y', o.order_date) AS INTEGER)   AS revenue_year,
    CAST(strftime('%m', o.order_date) AS INTEGER)    AS revenue_month,
    COUNT(DISTINCT o.order_id)                       AS total_orders,
    SUM(oi.line_total)                               AS gross_revenue,
    COALESCE(SUM(o.discount_amount) 
        / COUNT(oi.order_item_id) 
        * COUNT(DISTINCT o.order_id), 0)             AS order_discounts,
    SUM(oi.line_total) 
        - COALESCE(SUM(o.discount_amount) 
            / COUNT(oi.order_item_id) 
            * COUNT(DISTINCT o.order_id), 0)         AS net_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status IN ('Completed', 'Shipped')
GROUP BY
    strftime('%Y', o.order_date),
    strftime('%m', o.order_date)
ORDER BY revenue_year, revenue_month;


-- ============================================================================
-- 3. QUARTERLY REVENUE
-- ============================================================================
-- Aggregates revenue by fiscal quarter (Q1=Jan-Mar, Q2=Apr-Jun, etc.).
-- Quarter is derived from the order month using CASE expression.
--
-- Includes quarter-over-quarter (QoQ) growth calculated using a window
-- function (LAG) to compare each quarter against the previous one.
-- ============================================================================

WITH quarterly_data AS (
    SELECT
        CAST(strftime('%Y', o.order_date) AS INTEGER) AS revenue_year,
        CASE
            WHEN CAST(strftime('%m', o.order_date) AS INTEGER) BETWEEN 1 AND 3  THEN 1
            WHEN CAST(strftime('%m', o.order_date) AS INTEGER) BETWEEN 4 AND 6  THEN 2
            WHEN CAST(strftime('%m', o.order_date) AS INTEGER) BETWEEN 7 AND 9  THEN 3
            WHEN CAST(strftime('%m', o.order_date) AS INTEGER) BETWEEN 10 AND 12 THEN 4
        END AS revenue_quarter,
        COUNT(DISTINCT o.order_id)  AS total_orders,
        SUM(oi.line_total)          AS gross_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status IN ('Completed', 'Shipped')
    GROUP BY
        strftime('%Y', o.order_date),
        revenue_quarter
)
SELECT
    revenue_year,
    revenue_quarter,
    total_orders,
    ROUND(gross_revenue, 2)                             AS gross_revenue,
    LAG(gross_revenue) OVER (ORDER BY revenue_year, revenue_quarter)
                                                        AS prev_quarter_revenue,
    ROUND(
        (gross_revenue - LAG(gross_revenue) OVER (ORDER BY revenue_year, revenue_quarter))
        / LAG(gross_revenue) OVER (ORDER BY revenue_year, revenue_quarter) * 100,
        2
    )                                                   AS qoq_growth_pct
FROM quarterly_data
ORDER BY revenue_year, revenue_quarter;


-- ============================================================================
-- 4. YEARLY REVENUE
-- ============================================================================
-- Annual revenue summary with year-over-year (YoY) growth percentage.
--
-- YoY Growth % = (Current Year Revenue − Previous Year Revenue)
--                 / Previous Year Revenue × 100
--
-- Uses LAG window function to access the prior year's revenue for
-- comparison without a self-join.
-- ============================================================================

WITH yearly_data AS (
    SELECT
        CAST(strftime('%Y', o.order_date) AS INTEGER) AS revenue_year,
        COUNT(DISTINCT o.order_id)                     AS total_orders,
        COUNT(DISTINCT o.customer_id)                  AS unique_customers,
        SUM(oi.line_total)                             AS gross_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status IN ('Completed', 'Shipped')
    GROUP BY strftime('%Y', o.order_date)
)
SELECT
    revenue_year,
    total_orders,
    unique_customers,
    ROUND(gross_revenue, 2)                            AS gross_revenue,
    LAG(gross_revenue) OVER (ORDER BY revenue_year)    AS prev_year_revenue,
    ROUND(
        (gross_revenue - LAG(gross_revenue) OVER (ORDER BY revenue_year))
        / LAG(gross_revenue) OVER (ORDER BY revenue_year) * 100,
        2
    )                                                  AS yoy_growth_pct
FROM yearly_data
ORDER BY revenue_year;


-- ============================================================================
-- 5. AVERAGE ORDER VALUE (AOV)
-- ============================================================================
-- AOV = Total Revenue / Number of Orders
--
-- Calculated at multiple granularities:
--   5a. Overall AOV
--   5b. AOV by Channel (Online, In-Store, Marketplace)
--   5c. AOV by Month (trend analysis)
--
-- Revenue per order is the sum of all line_totals for that order,
-- minus the order-level discount.
-- ============================================================================

-- 5a. Overall AOV
SELECT
    COUNT(DISTINCT o.order_id)                                  AS total_orders,
    ROUND(SUM(oi.line_total), 2)                                AS total_revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2)  AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status IN ('Completed', 'Shipped');


-- 5b. AOV by Channel
SELECT
    o.channel,
    COUNT(DISTINCT o.order_id)                                  AS total_orders,
    ROUND(SUM(oi.line_total), 2)                                AS total_revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2)  AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status IN ('Completed', 'Shipped')
GROUP BY o.channel
ORDER BY avg_order_value DESC;


-- 5c. AOV by Month (for trend visualization)
SELECT
    strftime('%Y-%m', o.order_date)                             AS revenue_month,
    COUNT(DISTINCT o.order_id)                                  AS total_orders,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2)  AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status IN ('Completed', 'Shipped')
GROUP BY strftime('%Y-%m', o.order_date)
ORDER BY revenue_month;


-- ============================================================================
-- 6. TOTAL ORDERS (with breakdown)
-- ============================================================================
-- Counts orders across multiple dimensions. Includes ALL order statuses
-- to provide a complete operational picture.
--
-- 6a. Overall order count by status — shows fulfillment funnel
-- 6b. Orders by channel and status — channel health comparison
-- 6c. Monthly order volume — demand trend analysis
-- ============================================================================

-- 6a. Order count by status
SELECT
    order_status,
    COUNT(*)                                                    AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)        AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- 6b. Orders by channel and status
SELECT
    channel,
    order_status,
    COUNT(*)                                                    AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY channel), 2)
                                                                AS pct_within_channel
FROM orders
GROUP BY channel, order_status
ORDER BY channel, order_count DESC;


-- 6c. Monthly order volume trend
SELECT
    strftime('%Y-%m', order_date)   AS order_month,
    COUNT(*)                        AS total_orders,
    SUM(CASE WHEN order_status = 'Completed' THEN 1 ELSE 0 END)  AS completed,
    SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END)  AS cancelled,
    SUM(CASE WHEN order_status = 'Returned'  THEN 1 ELSE 0 END)  AS returned,
    ROUND(
        SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    )                               AS cancellation_rate_pct
FROM orders
GROUP BY strftime('%Y-%m', order_date)
ORDER BY order_month;


-- ============================================================================
-- 7. REVENUE GROWTH % (Month-over-Month)
-- ============================================================================
-- Calculates MoM revenue growth using a CTE + LAG window function.
--
-- Growth % = (Current Month Revenue − Previous Month Revenue)
--            / Previous Month Revenue × 100
--
-- Also classifies each month's trend as 'Growth', 'Decline', or 'Flat'
-- for quick visual identification in dashboards.
-- ============================================================================

WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_date)    AS revenue_month,
        SUM(oi.line_total)                 AS gross_revenue,
        COUNT(DISTINCT o.order_id)         AS total_orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status IN ('Completed', 'Shipped')
    GROUP BY strftime('%Y-%m', o.order_date)
)
SELECT
    revenue_month,
    total_orders,
    ROUND(gross_revenue, 2)                                     AS gross_revenue,
    ROUND(LAG(gross_revenue) OVER (ORDER BY revenue_month), 2) AS prev_month_revenue,
    ROUND(
        gross_revenue - LAG(gross_revenue) OVER (ORDER BY revenue_month), 2
    )                                                           AS revenue_change,
    ROUND(
        (gross_revenue - LAG(gross_revenue) OVER (ORDER BY revenue_month))
        / LAG(gross_revenue) OVER (ORDER BY revenue_month) * 100,
        2
    )                                                           AS mom_growth_pct,
    CASE
        WHEN LAG(gross_revenue) OVER (ORDER BY revenue_month) IS NULL THEN 'Baseline'
        WHEN gross_revenue > LAG(gross_revenue) OVER (ORDER BY revenue_month)  THEN 'Growth'
        WHEN gross_revenue < LAG(gross_revenue) OVER (ORDER BY revenue_month)  THEN 'Decline'
        ELSE 'Flat'
    END                                                         AS trend
FROM monthly_revenue
ORDER BY revenue_month;
