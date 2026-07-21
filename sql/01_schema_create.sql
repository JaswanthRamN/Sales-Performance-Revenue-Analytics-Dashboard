-- ============================================================================
-- SCHEMA DEFINITION
-- Sales Performance & Revenue Analytics Dashboard
-- ============================================================================
-- Database   : sales_analytics
-- Author     : JaswanthRamN
-- Created    : 2026-07-21
-- Description: Relational schema for multi-channel retail sales data.
--              Supports PostgreSQL / SQL Server / MySQL with minor adjustments.
-- ============================================================================

-- ============================================================================
-- 1. CREATE DATABASE
-- ============================================================================

-- PostgreSQL / MySQL
-- CREATE DATABASE sales_analytics;

-- SQL Server
-- CREATE DATABASE sales_analytics;
-- GO
-- USE sales_analytics;
-- GO


-- ============================================================================
-- 2. DROP EXISTING TABLES (in dependency order: children first)
-- ============================================================================

DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS sales_reps;
DROP TABLE IF EXISTS stores;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;


-- ============================================================================
-- 3. DIMENSION TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- 3.1 CUSTOMERS
-- --------------------------------------------------------------------------
-- Master table for all registered customers.
-- Business key: email (unique when not null).
-- --------------------------------------------------------------------------

CREATE TABLE customers (
    customer_id       VARCHAR(10)   NOT NULL,
    first_name        VARCHAR(50)   NOT NULL,
    last_name         VARCHAR(50)   NOT NULL,
    email             VARCHAR(100)  NULL,
    phone             VARCHAR(20)   NULL,
    region            VARCHAR(20)   NOT NULL,
    state             VARCHAR(2)    NOT NULL,
    city              VARCHAR(50)   NOT NULL,
    customer_segment  VARCHAR(10)   NOT NULL,
    registration_date DATE          NOT NULL,
    is_active         SMALLINT      NOT NULL DEFAULT 1,

    -- Primary key
    CONSTRAINT pk_customers PRIMARY KEY (customer_id),

    -- Business key uniqueness (NULLs allowed — guest / missing email)
    CONSTRAINT uq_customers_email UNIQUE (email),

    -- Domain constraints
    CONSTRAINT chk_customers_region CHECK (
        region IN ('Northeast', 'Southeast', 'Midwest', 'Southwest', 'West')
    ),
    CONSTRAINT chk_customers_segment CHECK (
        customer_segment IN ('Regular', 'Premium', 'VIP', 'New')
    ),
    CONSTRAINT chk_customers_active CHECK (is_active IN (0, 1))
);


-- --------------------------------------------------------------------------
-- 3.2 PRODUCTS
-- --------------------------------------------------------------------------
-- Product catalog with pricing and cost of goods sold.
-- --------------------------------------------------------------------------

CREATE TABLE products (
    product_id     VARCHAR(9)     NOT NULL,
    product_name   VARCHAR(100)   NOT NULL,
    category       VARCHAR(30)    NOT NULL,
    subcategory    VARCHAR(30)    NOT NULL,
    brand          VARCHAR(30)    NOT NULL,
    unit_price     DECIMAL(10,2)  NOT NULL,
    unit_cost      DECIMAL(10,2)  NOT NULL,
    stock_quantity INT            NOT NULL DEFAULT 0,
    is_active      SMALLINT       NOT NULL DEFAULT 1,

    CONSTRAINT pk_products PRIMARY KEY (product_id),

    CONSTRAINT chk_products_price    CHECK (unit_price > 0),
    CONSTRAINT chk_products_cost     CHECK (unit_cost >= 0),
    CONSTRAINT chk_products_margin   CHECK (unit_cost <= unit_price),
    CONSTRAINT chk_products_stock    CHECK (stock_quantity >= 0),
    CONSTRAINT chk_products_active   CHECK (is_active IN (0, 1)),
    CONSTRAINT chk_products_category CHECK (
        category IN (
            'Electronics', 'Clothing', 'Home & Kitchen',
            'Sports & Outdoors', 'Beauty & Health',
            'Books & Media', 'Toys & Games'
        )
    )
);


-- --------------------------------------------------------------------------
-- 3.3 STORES
-- --------------------------------------------------------------------------
-- Physical retail locations.
-- --------------------------------------------------------------------------

CREATE TABLE stores (
    store_id       VARCHAR(9)    NOT NULL,
    store_name     VARCHAR(100)  NOT NULL,
    store_type     VARCHAR(20)   NOT NULL,
    region         VARCHAR(20)   NOT NULL,
    state          VARCHAR(2)    NOT NULL,
    city           VARCHAR(50)   NOT NULL,
    opening_date   DATE          NOT NULL,
    square_footage INT           NOT NULL,
    is_active      SMALLINT      NOT NULL DEFAULT 1,

    CONSTRAINT pk_stores PRIMARY KEY (store_id),

    CONSTRAINT chk_stores_type CHECK (
        store_type IN ('Flagship', 'Standard', 'Outlet', 'Pop-Up')
    ),
    CONSTRAINT chk_stores_region CHECK (
        region IN ('Northeast', 'Southeast', 'Midwest', 'Southwest', 'West')
    ),
    CONSTRAINT chk_stores_sqft   CHECK (square_footage > 0),
    CONSTRAINT chk_stores_active CHECK (is_active IN (0, 1))
);


-- --------------------------------------------------------------------------
-- 3.4 SALES REPRESENTATIVES
-- --------------------------------------------------------------------------
-- Sales team members with quota targets.
-- Self-referencing FK: manager_id → sales_rep_id.
-- --------------------------------------------------------------------------

CREATE TABLE sales_reps (
    sales_rep_id    VARCHAR(7)     NOT NULL,
    first_name      VARCHAR(50)    NOT NULL,
    last_name       VARCHAR(50)    NOT NULL,
    email           VARCHAR(50)    NOT NULL,
    region          VARCHAR(20)    NOT NULL,
    team            VARCHAR(20)    NOT NULL,
    hire_date       DATE           NOT NULL,
    quarterly_quota DECIMAL(12,2)  NOT NULL,
    manager_id      VARCHAR(7)     NULL,
    is_active       SMALLINT       NOT NULL DEFAULT 1,

    CONSTRAINT pk_sales_reps PRIMARY KEY (sales_rep_id),

    CONSTRAINT uq_sales_reps_email UNIQUE (email),

    -- Self-referencing FK: manager must be an existing sales rep
    CONSTRAINT fk_sales_reps_manager
        FOREIGN KEY (manager_id) REFERENCES sales_reps (sales_rep_id),

    CONSTRAINT chk_reps_region CHECK (
        region IN ('Northeast', 'Southeast', 'Midwest', 'Southwest', 'West')
    ),
    CONSTRAINT chk_reps_team CHECK (
        team IN ('Team Alpha', 'Team Beta', 'Team Gamma', 'Team Delta')
    ),
    CONSTRAINT chk_reps_quota  CHECK (quarterly_quota > 0),
    CONSTRAINT chk_reps_active CHECK (is_active IN (0, 1))
);


-- ============================================================================
-- 4. FACT TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- 4.1 ORDERS (Fact)
-- --------------------------------------------------------------------------
-- Transaction header records across all sales channels.
-- store_id is conditionally NULL (only for In-Store channel).
-- marketplace is conditionally NULL (only for Marketplace channel).
-- --------------------------------------------------------------------------

CREATE TABLE orders (
    order_id        VARCHAR(10)   NOT NULL,
    customer_id     VARCHAR(10)   NULL,
    order_date      DATE          NOT NULL,
    channel         VARCHAR(15)   NOT NULL,
    store_id        VARCHAR(9)    NULL,
    sales_rep_id    VARCHAR(7)    NULL,
    marketplace     VARCHAR(25)   NULL,
    payment_method  VARCHAR(15)   NOT NULL,
    order_status    VARCHAR(15)   NOT NULL,
    shipping_cost   DECIMAL(6,2)  NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(6,2)  NOT NULL DEFAULT 0.00,

    CONSTRAINT pk_orders PRIMARY KEY (order_id),

    -- Foreign keys
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id),

    CONSTRAINT fk_orders_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id),

    CONSTRAINT fk_orders_sales_rep
        FOREIGN KEY (sales_rep_id) REFERENCES sales_reps (sales_rep_id),

    -- Domain constraints
    CONSTRAINT chk_orders_channel CHECK (
        channel IN ('Online', 'In-Store', 'Marketplace')
    ),
    CONSTRAINT chk_orders_status CHECK (
        order_status IN ('Completed', 'Shipped', 'Processing', 'Cancelled', 'Returned')
    ),
    CONSTRAINT chk_orders_payment CHECK (
        payment_method IN (
            'Credit Card', 'Debit Card', 'Paypal',
            'Apple Pay', 'Cash', 'Gift Card'
        )
    ),
    CONSTRAINT chk_orders_marketplace CHECK (
        marketplace IS NULL OR marketplace IN ('Amazon', 'eBay', 'Walmart Marketplace')
    ),
    CONSTRAINT chk_orders_shipping CHECK (shipping_cost >= 0),
    CONSTRAINT chk_orders_discount CHECK (discount_amount >= 0)
);


-- --------------------------------------------------------------------------
-- 4.2 ORDER ITEMS (Fact - Line Detail)
-- --------------------------------------------------------------------------
-- Line-level detail linking orders to products with quantities and pricing.
-- --------------------------------------------------------------------------

CREATE TABLE order_items (
    order_item_id VARCHAR(12)    NOT NULL,
    order_id      VARCHAR(10)    NOT NULL,
    product_id    VARCHAR(9)     NOT NULL,
    quantity      INT            NOT NULL,
    unit_price    DECIMAL(10,2)  NOT NULL,
    line_discount DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    line_total    DECIMAL(10,2)  NOT NULL,

    CONSTRAINT pk_order_items PRIMARY KEY (order_item_id),

    -- Foreign keys
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),

    -- Data integrity
    CONSTRAINT chk_items_quantity  CHECK (quantity > 0),
    CONSTRAINT chk_items_price     CHECK (unit_price > 0),
    CONSTRAINT chk_items_discount  CHECK (line_discount >= 0),
    CONSTRAINT chk_items_total     CHECK (line_total >= 0)
);


-- --------------------------------------------------------------------------
-- 4.3 RETURNS (Fact)
-- --------------------------------------------------------------------------
-- Product return and refund tracking.
-- --------------------------------------------------------------------------

CREATE TABLE returns (
    return_id     VARCHAR(10)    NOT NULL,
    order_id      VARCHAR(10)    NOT NULL,
    order_item_id VARCHAR(12)    NOT NULL,
    customer_id   VARCHAR(10)    NULL,
    return_date   DATE           NOT NULL,
    reason        VARCHAR(30)    NOT NULL,
    refund_amount DECIMAL(10,2)  NOT NULL,
    refund_status VARCHAR(10)    NOT NULL,

    CONSTRAINT pk_returns PRIMARY KEY (return_id),

    -- Foreign keys
    CONSTRAINT fk_returns_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),

    CONSTRAINT fk_returns_order_item
        FOREIGN KEY (order_item_id) REFERENCES order_items (order_item_id),

    CONSTRAINT fk_returns_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id),

    -- Domain constraints
    CONSTRAINT chk_returns_refund CHECK (refund_amount >= 0),
    CONSTRAINT chk_returns_status CHECK (
        refund_status IN ('Processed', 'Pending', 'Denied')
    ),
    CONSTRAINT chk_returns_reason CHECK (
        reason IN (
            'Defective Product', 'Wrong Item Shipped', 'Size/Fit Issue',
            'Changed Mind', 'Better Price Found', 'Arrived Late',
            'Not As Described', 'Damaged In Transit'
        )
    )
);


-- ============================================================================
-- 5. INDEXES (Performance Optimization)
-- ============================================================================

-- Orders: frequent filter/join columns
CREATE INDEX idx_orders_customer    ON orders (customer_id);
CREATE INDEX idx_orders_date        ON orders (order_date);
CREATE INDEX idx_orders_channel     ON orders (channel);
CREATE INDEX idx_orders_status      ON orders (order_status);
CREATE INDEX idx_orders_store       ON orders (store_id);
CREATE INDEX idx_orders_sales_rep   ON orders (sales_rep_id);

-- Order Items: frequent joins and product lookups
CREATE INDEX idx_items_order        ON order_items (order_id);
CREATE INDEX idx_items_product      ON order_items (product_id);

-- Returns: lookup by order and date
CREATE INDEX idx_returns_order      ON returns (order_id);
CREATE INDEX idx_returns_date       ON returns (return_date);
CREATE INDEX idx_returns_customer   ON returns (customer_id);

-- Customers: segmentation and regional queries
CREATE INDEX idx_customers_region   ON customers (region);
CREATE INDEX idx_customers_segment  ON customers (customer_segment);

-- Products: category browsing
CREATE INDEX idx_products_category  ON products (category);

-- Sales Reps: team and region filtering
CREATE INDEX idx_reps_region        ON sales_reps (region);
CREATE INDEX idx_reps_team          ON sales_reps (team);
