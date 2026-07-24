-- ============================================================================
-- PRODUCT PERFORMANCE ANALYTICS
-- Sales Performance & Revenue Analytics Dashboard
-- ============================================================================
-- Author     : JaswanthRamN
-- Created    : 2026-07-24
-- Description: Product-level analytics covering best/worst sellers,
--              revenue contribution, category performance, and profitability.
--
-- Revenue Filter: Only 'Completed' and 'Shipped' orders count.
-- Profitability : Profit = Revenue - COGS (unit_cost × quantity sold)
-- ============================================================================


-- ============================================================================
-- 1. BEST-SELLING PRODUCTS (Top 15 by Units Sold)
-- ============================================================================
-- Ranks products by total quantity sold across all completed/shipped orders.
-- Includes revenue and avg selling price to show if volume leaders are also
-- revenue leaders, or if they rely on high volume at low price points.
--
-- JOIN: order_items → orders (for status filter) → products (for name/category)
-- ============================================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    SUM(oi.quantity)                                            AS total_units_sold,
    COUNT(DISTINCT oi.order_id)                                AS order_count,
    ROUND(SUM(oi.line_total), 2)                               AS total_revenue,
    ROUND(AVG(oi.unit_price), 2)                               AS avg_selling_price,
    RANK() OVER (ORDER BY SUM(oi.quantity) DESC)               AS sales_rank
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status IN ('Completed', 'Shipped')
GROUP BY p.product_id, p.product_name, p.category, p.subcategory
ORDER BY total_units_sold DESC
LIMIT 15;


-- ============================================================================
-- 2. WORST-SELLING PRODUCTS (Bottom 15 by Units Sold)
-- ============================================================================
-- Identifies underperforming products that may need promotion, repricing,
-- or discontinuation. Only considers active products to avoid flagging
-- already-retired SKUs.
--
-- Filters: is_active = 1 ensures we only flag live products that are
-- genuinely underperforming, not ones that were intentionally removed.
-- ============================================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.unit_price,
    COALESCE(SUM(oi.quantity), 0)                              AS total_units_sold,
    COALESCE(COUNT(DISTINCT oi.order_id), 0)                   AS order_count,
    COALESCE(ROUND(SUM(oi.line_total), 2), 0)                  AS total_revenue,
    p.stock_quantity                                            AS current_stock,
    RANK() OVER (ORDER BY COALESCE(SUM(oi.quantity), 0) ASC)   AS worst_rank
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
LEFT JOIN orders o       ON o.order_id = oi.order_id
                         AND o.order_status IN ('Completed', 'Shipped')
WHERE p.is_active = 1
GROUP BY p.product_id, p.product_name, p.category, p.subcategory,
         p.unit_price, p.stock_quantity
ORDER BY total_units_sold ASC
LIMIT 15;


-- ============================================================================
-- 3. PRODUCT REVENUE (Full Product Revenue Report)
-- ============================================================================
-- Comprehensive product-level revenue report showing each product's
-- contribution to total revenue. Uses a window function to calculate
-- revenue share (%) without a subquery.
--
-- Revenue Share % = Product Revenue / Total Revenue × 100
-- Cumulative %    = Running sum of revenue share (Pareto analysis)
--
-- This enables 80/20 (Pareto) analysis: which products drive 80% of revenue.
-- ============================================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    SUM(oi.quantity)                                            AS units_sold,
    ROUND(SUM(oi.line_total), 2)                               AS product_revenue,
    ROUND(
        SUM(oi.line_total) * 100.0 
        / SUM(SUM(oi.line_total)) OVER (), 2
    )                                                          AS revenue_share_pct,
    ROUND(
        SUM(SUM(oi.line_total)) OVER (
            ORDER BY SUM(oi.line_total) DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 / SUM(SUM(oi.line_total)) OVER (), 2
    )                                                          AS cumulative_pct,
    RANK() OVER (ORDER BY SUM(oi.line_total) DESC)             AS revenue_rank
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status IN ('Completed', 'Shipped')
GROUP BY p.product_id, p.product_name, p.category, p.brand
ORDER BY product_revenue DESC;


-- ============================================================================
-- 4. CATEGORY REVENUE
-- ============================================================================
-- Aggregates revenue, units, and order metrics at the category level.
-- Shows which product categories contribute most to the business.
--
-- Includes:
--   - Total revenue and revenue share per category
--   - Average order value within each category
--   - Number of active products (inventory breadth)
--   - Avg unit price and units per order (buying behavior)
-- ============================================================================

SELECT
    p.category,
    COUNT(DISTINCT p.product_id)                               AS product_count,
    SUM(oi.quantity)                                           AS total_units_sold,
    COUNT(DISTINCT o.order_id)                                 AS order_count,
    ROUND(SUM(oi.line_total), 2)                               AS category_revenue,
    ROUND(
        SUM(oi.line_total) * 100.0 
        / SUM(SUM(oi.line_total)) OVER (), 2
    )                                                          AS revenue_share_pct,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value,
    ROUND(AVG(oi.unit_price), 2)                               AS avg_unit_price,
    ROUND(AVG(oi.quantity * 1.0), 2)                           AS avg_qty_per_line
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status IN ('Completed', 'Shipped')
GROUP BY p.category
ORDER BY category_revenue DESC;


-- ============================================================================
-- 5. TOP CATEGORIES (Category Ranking with Growth Trend)
-- ============================================================================
-- Ranks categories by revenue and adds YoY growth to identify categories
-- that are growing vs. declining. Uses a pivot-style CTE to compare
-- the two most recent full years (2023 vs 2024).
--
-- Growth % = (2024 Revenue − 2023 Revenue) / 2023 Revenue × 100
--
-- This helps leadership decide where to invest (growing categories)
-- and where to intervene (declining categories).
-- ============================================================================

WITH category_yearly AS (
    SELECT
        p.category,
        CAST(strftime('%Y', o.order_date) AS INTEGER)          AS revenue_year,
        SUM(oi.line_total)                                     AS yearly_revenue
    FROM order_items oi
    JOIN orders o   ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_status IN ('Completed', 'Shipped')
      AND strftime('%Y', o.order_date) IN ('2023', '2024')
    GROUP BY p.category, strftime('%Y', o.order_date)
),
pivoted AS (
    SELECT
        category,
        SUM(CASE WHEN revenue_year = 2023 THEN yearly_revenue ELSE 0 END) AS revenue_2023,
        SUM(CASE WHEN revenue_year = 2024 THEN yearly_revenue ELSE 0 END) AS revenue_2024
    FROM category_yearly
    GROUP BY category
)
SELECT
    category,
    ROUND(revenue_2023, 2)                                     AS revenue_2023,
    ROUND(revenue_2024, 2)                                     AS revenue_2024,
    ROUND(revenue_2024 - revenue_2023, 2)                      AS revenue_change,
    ROUND(
        (revenue_2024 - revenue_2023) / revenue_2023 * 100, 2
    )                                                          AS yoy_growth_pct,
    RANK() OVER (ORDER BY revenue_2024 DESC)                   AS rank_2024,
    CASE
        WHEN revenue_2024 > revenue_2023 THEN 'Growing'
        WHEN revenue_2024 < revenue_2023 THEN 'Declining'
        ELSE 'Stable'
    END                                                        AS trend
FROM pivoted
ORDER BY revenue_2024 DESC;


-- ============================================================================
-- 6. PRODUCT PROFITABILITY
-- ============================================================================
-- Calculates profit and profit margin at the product level.
--
-- COGS (Cost of Goods Sold) = unit_cost × quantity sold
-- Gross Profit              = Revenue − COGS
-- Gross Margin %            = Gross Profit / Revenue × 100
--
-- Products are ranked by gross profit (not revenue) to identify which
-- products generate the most actual value for the business. A high-revenue
-- product with thin margins may be less valuable than a moderate-revenue
-- product with high margins.
--
-- Also flags products where margin < 20% as 'Low Margin' for review.
-- ============================================================================

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    p.unit_price                                               AS list_price,
    p.unit_cost,
    SUM(oi.quantity)                                           AS total_units_sold,
    ROUND(SUM(oi.line_total), 2)                               AS total_revenue,
    ROUND(SUM(oi.quantity * p.unit_cost), 2)                   AS total_cogs,
    ROUND(SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost), 2)
                                                               AS gross_profit,
    ROUND(
        (SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost))
        / SUM(oi.line_total) * 100, 2
    )                                                          AS gross_margin_pct,
    RANK() OVER (ORDER BY 
        SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost) DESC
    )                                                          AS profit_rank,
    CASE
        WHEN (SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost))
             / SUM(oi.line_total) * 100 < 20 THEN 'Low Margin'
        WHEN (SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost))
             / SUM(oi.line_total) * 100 BETWEEN 20 AND 40 THEN 'Medium Margin'
        ELSE 'High Margin'
    END                                                        AS margin_tier
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status IN ('Completed', 'Shipped')
GROUP BY p.product_id, p.product_name, p.category, p.brand,
         p.unit_price, p.unit_cost
ORDER BY gross_profit DESC;


-- ============================================================================
-- 6b. CATEGORY PROFITABILITY SUMMARY
-- ============================================================================
-- Rolls up profitability to the category level for executive dashboards.
-- Shows which categories are most profitable and which have thin margins.
-- ============================================================================

SELECT
    p.category,
    SUM(oi.quantity)                                            AS total_units_sold,
    ROUND(SUM(oi.line_total), 2)                               AS total_revenue,
    ROUND(SUM(oi.quantity * p.unit_cost), 2)                   AS total_cogs,
    ROUND(SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost), 2)
                                                               AS gross_profit,
    ROUND(
        (SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost))
        / SUM(oi.line_total) * 100, 2
    )                                                          AS gross_margin_pct,
    ROUND(
        (SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost)) * 100.0
        / SUM(SUM(oi.line_total) - SUM(oi.quantity * p.unit_cost)) OVER (), 2
    )                                                          AS profit_share_pct
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status IN ('Completed', 'Shipped')
GROUP BY p.category
ORDER BY gross_profit DESC;
