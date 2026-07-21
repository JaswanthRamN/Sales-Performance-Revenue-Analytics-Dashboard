-- ============================================================================
-- VALIDATION QUERIES
-- Sales Performance & Revenue Analytics Dashboard
-- ============================================================================
-- Author     : JaswanthRamN
-- Created    : 2026-07-21
-- Description: Post-import validation checks covering row counts, primary key
--              uniqueness, foreign key integrity, domain values, data ranges,
--              and business rule verification.
--
-- Usage      : Run after 02_data_import.sql to verify data integrity.
-- ============================================================================


-- ============================================================================
-- 1. ROW COUNT VALIDATION
-- ============================================================================
-- Expected counts (from cleaned pipeline output):
--   customers: 4,506 | products: 500 | stores: 50 | sales_reps: 80
--   orders: 50,000  | order_items: 104,643 | returns: 5,979
-- ============================================================================

SELECT
    'customers'   AS table_name, COUNT(*) AS row_count, 4506   AS expected FROM customers
UNION ALL
SELECT 'products',                COUNT(*),              500    FROM products
UNION ALL
SELECT 'stores',                  COUNT(*),              50     FROM stores
UNION ALL
SELECT 'sales_reps',              COUNT(*),              80     FROM sales_reps
UNION ALL
SELECT 'orders',                  COUNT(*),              50000  FROM orders
UNION ALL
SELECT 'order_items',             COUNT(*),              104643 FROM order_items
UNION ALL
SELECT 'returns',                 COUNT(*),              5979   FROM returns
ORDER BY table_name;


-- ============================================================================
-- 2. PRIMARY KEY UNIQUENESS
-- ============================================================================
-- Each query should return 0 rows if PK is truly unique.
-- ============================================================================

-- 2.1 Customers PK
SELECT 'customers' AS table_name, customer_id AS pk_value, COUNT(*) AS occurrences
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 2.2 Products PK
SELECT 'products' AS table_name, product_id AS pk_value, COUNT(*) AS occurrences
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- 2.3 Stores PK
SELECT 'stores' AS table_name, store_id AS pk_value, COUNT(*) AS occurrences
FROM stores
GROUP BY store_id
HAVING COUNT(*) > 1;

-- 2.4 Sales Reps PK
SELECT 'sales_reps' AS table_name, sales_rep_id AS pk_value, COUNT(*) AS occurrences
FROM sales_reps
GROUP BY sales_rep_id
HAVING COUNT(*) > 1;

-- 2.5 Orders PK
SELECT 'orders' AS table_name, order_id AS pk_value, COUNT(*) AS occurrences
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 2.6 Order Items PK
SELECT 'order_items' AS table_name, order_item_id AS pk_value, COUNT(*) AS occurrences
FROM order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;

-- 2.7 Returns PK
SELECT 'returns' AS table_name, return_id AS pk_value, COUNT(*) AS occurrences
FROM returns
GROUP BY return_id
HAVING COUNT(*) > 1;


-- ============================================================================
-- 3. FOREIGN KEY INTEGRITY
-- ============================================================================
-- Each query should return 0 rows (no orphan references).
-- ============================================================================

-- 3.1 Orders → Customers (NULLs allowed for guest checkout)
SELECT 'orders.customer_id' AS fk_check, COUNT(*) AS orphan_count
FROM orders o
WHERE o.customer_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id);

-- 3.2 Orders → Stores (NULLs allowed for non-in-store orders)
SELECT 'orders.store_id' AS fk_check, COUNT(*) AS orphan_count
FROM orders o
WHERE o.store_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM stores s WHERE s.store_id = o.store_id);

-- 3.3 Orders → Sales Reps (NULLs allowed for unassigned orders)
SELECT 'orders.sales_rep_id' AS fk_check, COUNT(*) AS orphan_count
FROM orders o
WHERE o.sales_rep_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM sales_reps sr WHERE sr.sales_rep_id = o.sales_rep_id);

-- 3.4 Order Items → Orders
SELECT 'order_items.order_id' AS fk_check, COUNT(*) AS orphan_count
FROM order_items oi
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = oi.order_id);

-- 3.5 Order Items → Products
SELECT 'order_items.product_id' AS fk_check, COUNT(*) AS orphan_count
FROM order_items oi
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.product_id = oi.product_id);

-- 3.6 Returns → Orders
SELECT 'returns.order_id' AS fk_check, COUNT(*) AS orphan_count
FROM returns r
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = r.order_id);

-- 3.7 Returns → Order Items
SELECT 'returns.order_item_id' AS fk_check, COUNT(*) AS orphan_count
FROM returns r
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_item_id = r.order_item_id);

-- 3.8 Returns → Customers (NULLs allowed)
SELECT 'returns.customer_id' AS fk_check, COUNT(*) AS orphan_count
FROM returns r
WHERE r.customer_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = r.customer_id);

-- 3.9 Sales Reps → Manager (self-referencing)
SELECT 'sales_reps.manager_id' AS fk_check, COUNT(*) AS orphan_count
FROM sales_reps sr
WHERE sr.manager_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM sales_reps m WHERE m.sales_rep_id = sr.manager_id);


-- ============================================================================
-- 4. DOMAIN VALUE VALIDATION
-- ============================================================================
-- Verify all categorical columns contain only allowed values.
-- Each query should return 0 rows.
-- ============================================================================

-- 4.1 Customer regions
SELECT 'customers.region' AS check_name, region AS invalid_value, COUNT(*) AS row_count
FROM customers
WHERE region NOT IN ('Northeast', 'Southeast', 'Midwest', 'Southwest', 'West')
GROUP BY region;

-- 4.2 Customer segments
SELECT 'customers.customer_segment' AS check_name, customer_segment AS invalid_value, COUNT(*)
FROM customers
WHERE customer_segment NOT IN ('Regular', 'Premium', 'VIP', 'New')
GROUP BY customer_segment;

-- 4.3 Product categories
SELECT 'products.category' AS check_name, category AS invalid_value, COUNT(*)
FROM products
WHERE category NOT IN (
    'Electronics', 'Clothing', 'Home & Kitchen',
    'Sports & Outdoors', 'Beauty & Health',
    'Books & Media', 'Toys & Games'
)
GROUP BY category;

-- 4.4 Store types
SELECT 'stores.store_type' AS check_name, store_type AS invalid_value, COUNT(*)
FROM stores
WHERE store_type NOT IN ('Flagship', 'Standard', 'Outlet', 'Pop-Up')
GROUP BY store_type;

-- 4.5 Order channels
SELECT 'orders.channel' AS check_name, channel AS invalid_value, COUNT(*)
FROM orders
WHERE channel NOT IN ('Online', 'In-Store', 'Marketplace')
GROUP BY channel;

-- 4.6 Order statuses
SELECT 'orders.order_status' AS check_name, order_status AS invalid_value, COUNT(*)
FROM orders
WHERE order_status NOT IN ('Completed', 'Shipped', 'Processing', 'Cancelled', 'Returned')
GROUP BY order_status;

-- 4.7 Payment methods
SELECT 'orders.payment_method' AS check_name, payment_method AS invalid_value, COUNT(*)
FROM orders
WHERE payment_method NOT IN (
    'Credit Card', 'Debit Card', 'Paypal',
    'Apple Pay', 'Cash', 'Gift Card'
)
GROUP BY payment_method;

-- 4.8 Refund statuses
SELECT 'returns.refund_status' AS check_name, refund_status AS invalid_value, COUNT(*)
FROM returns
WHERE refund_status NOT IN ('Processed', 'Pending', 'Denied')
GROUP BY refund_status;


-- ============================================================================
-- 5. NUMERIC RANGE VALIDATION
-- ============================================================================
-- Verify all numeric columns are within expected bounds.
-- ============================================================================

-- 5.1 Products: price and cost sanity
SELECT
    'products' AS table_name,
    MIN(unit_price)  AS min_price,
    MAX(unit_price)  AS max_price,
    MIN(unit_cost)   AS min_cost,
    MAX(unit_cost)   AS max_cost,
    SUM(CASE WHEN unit_cost > unit_price THEN 1 ELSE 0 END) AS cost_exceeds_price,
    SUM(CASE WHEN unit_price <= 0 THEN 1 ELSE 0 END) AS negative_prices
FROM products;

-- 5.2 Orders: shipping and discount ranges
SELECT
    'orders' AS table_name,
    MIN(shipping_cost)   AS min_shipping,
    MAX(shipping_cost)   AS max_shipping,
    MIN(discount_amount) AS min_discount,
    MAX(discount_amount) AS max_discount,
    SUM(CASE WHEN shipping_cost < 0 THEN 1 ELSE 0 END)   AS negative_shipping,
    SUM(CASE WHEN discount_amount < 0 THEN 1 ELSE 0 END) AS negative_discounts
FROM orders;

-- 5.3 Order Items: quantity and line total ranges
SELECT
    'order_items' AS table_name,
    MIN(quantity)      AS min_qty,
    MAX(quantity)      AS max_qty,
    MIN(unit_price)    AS min_price,
    MAX(unit_price)    AS max_price,
    MIN(line_total)    AS min_total,
    MAX(line_total)    AS max_total,
    SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END)   AS zero_qty,
    SUM(CASE WHEN line_total < 0 THEN 1 ELSE 0 END)  AS negative_totals
FROM order_items;

-- 5.4 Returns: refund amount ranges
SELECT
    'returns' AS table_name,
    MIN(refund_amount)  AS min_refund,
    MAX(refund_amount)  AS max_refund,
    AVG(refund_amount)  AS avg_refund,
    SUM(CASE WHEN refund_amount < 0 THEN 1 ELSE 0 END) AS negative_refunds
FROM returns;

-- 5.5 Sales Reps: quota ranges
SELECT
    'sales_reps' AS table_name,
    MIN(quarterly_quota) AS min_quota,
    MAX(quarterly_quota) AS max_quota,
    AVG(quarterly_quota) AS avg_quota,
    SUM(CASE WHEN quarterly_quota <= 0 THEN 1 ELSE 0 END) AS invalid_quotas
FROM sales_reps;


-- ============================================================================
-- 6. DATE RANGE VALIDATION
-- ============================================================================

-- 6.1 Order dates should fall within Jan 2023 – Jun 2025
SELECT
    'orders' AS table_name,
    MIN(order_date) AS earliest_order,
    MAX(order_date) AS latest_order,
    COUNT(CASE WHEN order_date < '2023-01-01' THEN 1 END) AS before_range,
    COUNT(CASE WHEN order_date > CURRENT_DATE THEN 1 END) AS future_dates
FROM orders;

-- 6.2 Return dates should be after corresponding order dates
SELECT COUNT(*) AS returns_before_order
FROM returns r
JOIN orders o ON r.order_id = o.order_id
WHERE r.return_date < o.order_date;

-- 6.3 Customer registration dates
SELECT
    MIN(registration_date) AS earliest_reg,
    MAX(registration_date) AS latest_reg,
    COUNT(CASE WHEN registration_date > CURRENT_DATE THEN 1 END) AS future_registrations
FROM customers;

-- 6.4 Store opening dates
SELECT
    MIN(opening_date) AS earliest_open,
    MAX(opening_date) AS latest_open
FROM stores;


-- ============================================================================
-- 7. BUSINESS RULE VALIDATION
-- ============================================================================

-- 7.1 In-Store orders must have a store_id
SELECT 'In-Store without store_id' AS rule_check, COUNT(*) AS violations
FROM orders
WHERE channel = 'In-Store' AND store_id IS NULL;

-- 7.2 Online/Marketplace orders should NOT have a store_id
SELECT 'Non-In-Store with store_id' AS rule_check, COUNT(*) AS violations
FROM orders
WHERE channel != 'In-Store' AND store_id IS NOT NULL;

-- 7.3 Marketplace orders must have a marketplace name
SELECT 'Marketplace without name' AS rule_check, COUNT(*) AS violations
FROM orders
WHERE channel = 'Marketplace' AND marketplace IS NULL;

-- 7.4 Non-Marketplace orders should NOT have a marketplace name
SELECT 'Non-Marketplace with name' AS rule_check, COUNT(*) AS violations
FROM orders
WHERE channel != 'Marketplace' AND marketplace IS NOT NULL;

-- 7.5 In-Store orders should have $0 shipping
SELECT 'In-Store with shipping' AS rule_check, COUNT(*) AS violations
FROM orders
WHERE channel = 'In-Store' AND shipping_cost > 0;

-- 7.6 Cash payments should only appear for In-Store orders
SELECT 'Cash payment non-In-Store' AS rule_check, COUNT(*) AS violations
FROM orders
WHERE payment_method = 'Cash' AND channel != 'In-Store';

-- 7.7 Every order should have at least one order item
SELECT 'Orders without items' AS rule_check, COUNT(*) AS violations
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id);

-- 7.8 line_total should equal (unit_price * quantity - line_discount)
SELECT 'line_total mismatch' AS rule_check, COUNT(*) AS violations
FROM order_items
WHERE ABS(line_total - (unit_price * quantity - line_discount)) > 0.01;


-- ============================================================================
-- 8. NULL COUNT SUMMARY
-- ============================================================================
-- Overview of NULL values across all tables for data completeness monitoring.
-- ============================================================================

SELECT 'customers.email'        AS column_name, COUNT(*) - COUNT(email)        AS null_count, COUNT(*) AS total, ROUND((COUNT(*) - COUNT(email))        * 100.0 / COUNT(*), 2) AS null_pct FROM customers
UNION ALL
SELECT 'customers.phone',                       COUNT(*) - COUNT(phone),                      COUNT(*), ROUND((COUNT(*) - COUNT(phone))                      * 100.0 / COUNT(*), 2) FROM customers
UNION ALL
SELECT 'orders.customer_id',                     COUNT(*) - COUNT(customer_id),                COUNT(*), ROUND((COUNT(*) - COUNT(customer_id))                * 100.0 / COUNT(*), 2) FROM orders
UNION ALL
SELECT 'orders.store_id',                        COUNT(*) - COUNT(store_id),                   COUNT(*), ROUND((COUNT(*) - COUNT(store_id))                   * 100.0 / COUNT(*), 2) FROM orders
UNION ALL
SELECT 'orders.sales_rep_id',                    COUNT(*) - COUNT(sales_rep_id),               COUNT(*), ROUND((COUNT(*) - COUNT(sales_rep_id))               * 100.0 / COUNT(*), 2) FROM orders
UNION ALL
SELECT 'orders.marketplace',                     COUNT(*) - COUNT(marketplace),                COUNT(*), ROUND((COUNT(*) - COUNT(marketplace))                * 100.0 / COUNT(*), 2) FROM orders
UNION ALL
SELECT 'sales_reps.manager_id',                  COUNT(*) - COUNT(manager_id),                 COUNT(*), ROUND((COUNT(*) - COUNT(manager_id))                 * 100.0 / COUNT(*), 2) FROM sales_reps
UNION ALL
SELECT 'returns.customer_id',                    COUNT(*) - COUNT(customer_id),                COUNT(*), ROUND((COUNT(*) - COUNT(customer_id))                * 100.0 / COUNT(*), 2) FROM returns
ORDER BY null_pct DESC;


-- ============================================================================
-- 9. DISTRIBUTION SPOT CHECKS
-- ============================================================================

-- 9.1 Orders by channel
SELECT channel, COUNT(*) AS order_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM orders
GROUP BY channel
ORDER BY order_count DESC;

-- 9.2 Orders by status
SELECT order_status, COUNT(*) AS order_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- 9.3 Customers by segment
SELECT customer_segment, COUNT(*) AS customer_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM customers
GROUP BY customer_segment
ORDER BY customer_count DESC;

-- 9.4 Products by category
SELECT category, COUNT(*) AS product_count,
       ROUND(AVG(unit_price), 2) AS avg_price,
       ROUND(AVG(unit_cost), 2)  AS avg_cost,
       ROUND(AVG(unit_price - unit_cost), 2) AS avg_margin
FROM products
GROUP BY category
ORDER BY product_count DESC;

-- 9.5 Returns by reason
SELECT reason, COUNT(*) AS return_count,
       ROUND(AVG(refund_amount), 2) AS avg_refund,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM returns
GROUP BY reason
ORDER BY return_count DESC;
