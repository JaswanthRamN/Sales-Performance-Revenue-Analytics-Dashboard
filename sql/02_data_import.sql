-- ============================================================================
-- DATA IMPORT SCRIPTS
-- Sales Performance & Revenue Analytics Dashboard
-- ============================================================================
-- Author     : JaswanthRamN
-- Created    : 2026-07-21
-- Description: Load cleaned CSV data into the relational schema.
--              Includes PostgreSQL, SQL Server, and MySQL variants.
--
-- PREREQUISITE: Run 01_schema_create.sql first to create all tables.
-- LOAD ORDER : Dimension tables first, then fact tables (FK dependencies).
-- ============================================================================


-- ============================================================================
-- OPTION A: PostgreSQL — COPY FROM
-- ============================================================================
-- Update file paths to match your environment.
-- Run from psql or a PostgreSQL client with superuser / file-read permissions.
-- ============================================================================

/*

-- 1. Dimension tables (no FK dependencies on each other except sales_reps)
COPY customers (customer_id, first_name, last_name, email, phone, region, state, city, customer_segment, registration_date, is_active)
FROM '/path/to/data/processed/customers_clean.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

COPY products (product_id, product_name, category, subcategory, brand, unit_price, unit_cost, stock_quantity, is_active)
FROM '/path/to/data/processed/products_clean.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

COPY stores (store_id, store_name, store_type, region, state, city, opening_date, square_footage, is_active)
FROM '/path/to/data/processed/stores_clean.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

-- NOTE: Load reps without manager_id FK first, then update
-- Temporarily drop the self-referencing FK
ALTER TABLE sales_reps DROP CONSTRAINT fk_sales_reps_manager;

COPY sales_reps (sales_rep_id, first_name, last_name, email, region, team, hire_date, quarterly_quota, manager_id, is_active)
FROM '/path/to/data/processed/sales_reps_clean.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

-- Re-add the self-referencing FK
ALTER TABLE sales_reps ADD CONSTRAINT fk_sales_reps_manager
    FOREIGN KEY (manager_id) REFERENCES sales_reps (sales_rep_id);

-- 2. Fact tables (depend on dimension tables)
COPY orders (order_id, customer_id, order_date, channel, store_id, sales_rep_id, marketplace, payment_method, order_status, shipping_cost, discount_amount)
FROM '/path/to/data/processed/orders_clean.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

COPY order_items (order_item_id, order_id, product_id, quantity, unit_price, line_discount, line_total)
FROM '/path/to/data/processed/order_items_clean.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

COPY returns (return_id, order_id, order_item_id, customer_id, return_date, reason, refund_amount, refund_status)
FROM '/path/to/data/processed/returns_clean.csv'
WITH (FORMAT CSV, HEADER TRUE, NULL '');

*/


-- ============================================================================
-- OPTION B: SQL Server — BULK INSERT
-- ============================================================================
-- Update file paths. Requires BULK INSERT permissions.
-- ============================================================================

/*

BULK INSERT customers
FROM 'C:\path\to\data\processed\customers_clean.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

BULK INSERT products
FROM 'C:\path\to\data\processed\products_clean.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

BULK INSERT stores
FROM 'C:\path\to\data\processed\stores_clean.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

-- Temporarily disable self-referencing FK for sales_reps
ALTER TABLE sales_reps NOCHECK CONSTRAINT fk_sales_reps_manager;

BULK INSERT sales_reps
FROM 'C:\path\to\data\processed\sales_reps_clean.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

ALTER TABLE sales_reps CHECK CONSTRAINT fk_sales_reps_manager;

BULK INSERT orders
FROM 'C:\path\to\data\processed\orders_clean.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

BULK INSERT order_items
FROM 'C:\path\to\data\processed\order_items_clean.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

BULK INSERT returns
FROM 'C:\path\to\data\processed\returns_clean.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

*/


-- ============================================================================
-- OPTION C: MySQL — LOAD DATA INFILE
-- ============================================================================

/*

LOAD DATA INFILE '/path/to/data/processed/customers_clean.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE '/path/to/data/processed/products_clean.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE '/path/to/data/processed/stores_clean.csv'
INTO TABLE stores
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Disable FK check for self-referencing load
SET FOREIGN_KEY_CHECKS = 0;

LOAD DATA INFILE '/path/to/data/processed/sales_reps_clean.csv'
INTO TABLE sales_reps
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SET FOREIGN_KEY_CHECKS = 1;

LOAD DATA INFILE '/path/to/data/processed/orders_clean.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE '/path/to/data/processed/order_items_clean.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE '/path/to/data/processed/returns_clean.csv'
INTO TABLE returns
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

*/


-- ============================================================================
-- OPTION D: Python (SQLAlchemy + Pandas) — Cross-Platform
-- ============================================================================
-- This is the recommended approach for this project.
-- See: python/load_to_database.py
-- ============================================================================


-- ============================================================================
-- POST-IMPORT: Row Count Verification
-- ============================================================================

SELECT 'customers'   AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'products',    COUNT(*) FROM products
UNION ALL
SELECT 'stores',      COUNT(*) FROM stores
UNION ALL
SELECT 'sales_reps',  COUNT(*) FROM sales_reps
UNION ALL
SELECT 'orders',      COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'returns',     COUNT(*) FROM returns
ORDER BY table_name;
