"""
Data Cleaning Pipeline
======================
Sales Performance & Revenue Analytics Dashboard

This module provides a professional, modular data cleaning pipeline
that processes raw retail data and outputs clean, analysis-ready datasets.

Steps:
    1. Load raw data
    2. Remove duplicate records
    3. Fix data types (dates, numerics, categoricals)
    4. Handle missing values
    5. Remove invalid records
    6. Standardize text columns
    7. Validate referential integrity
    8. Save cleaned datasets

Author: JaswanthRamN
Date: 2026-07-20
"""

import pandas as pd
import numpy as np
import os
import re
from datetime import datetime


# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(BASE_DIR, "data", "raw")
PROCESSED_DIR = os.path.join(BASE_DIR, "data", "processed")

# Valid domain values
VALID_REGIONS = ["Northeast", "Southeast", "Midwest", "Southwest", "West"]
VALID_CHANNELS = ["Online", "In-Store", "Marketplace"]
VALID_ORDER_STATUSES = ["Completed", "Shipped", "Processing", "Cancelled", "Returned"]
VALID_PAYMENT_METHODS = ["Credit Card", "Debit Card", "PayPal", "Apple Pay", "Cash", "Gift Card"]
VALID_SEGMENTS = ["Regular", "Premium", "VIP", "New"]
VALID_STORE_TYPES = ["Flagship", "Standard", "Outlet", "Pop-Up"]
VALID_REFUND_STATUSES = ["Processed", "Pending", "Denied"]
VALID_MARKETPLACES = ["Amazon", "eBay", "Walmart Marketplace"]


# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

def log_step(step_name, before_count, after_count):
    """Log the result of a cleaning step with row impact."""
    removed = before_count - after_count
    pct = (removed / before_count * 100) if before_count > 0 else 0
    print(f"    {step_name}: {before_count:,} → {after_count:,} rows "
          f"({removed:,} removed, {pct:.2f}%)")


def log_section(title):
    """Print a section header for console output."""
    print(f"\n{'─' * 60}")
    print(f"  {title}")
    print(f"{'─' * 60}")


def standardize_text(series, case="title"):
    """
    Standardize text values in a Series.
    
    Args:
        series: pandas Series with string data
        case: 'title', 'upper', or 'lower'
    
    Returns:
        Cleaned pandas Series
    """
    cleaned = series.astype(str).str.strip()
    cleaned = cleaned.str.replace(r'\s+', ' ', regex=True)  # collapse multiple spaces
    
    if case == "title":
        cleaned = cleaned.str.title()
    elif case == "upper":
        cleaned = cleaned.str.upper()
    elif case == "lower":
        cleaned = cleaned.str.lower()
    
    # Restore NaN where original was NaN
    cleaned = cleaned.where(series.notna(), other=np.nan)
    return cleaned


def validate_email(email_series):
    """Validate email format and return boolean mask of valid emails."""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return email_series.apply(
        lambda x: bool(re.match(pattern, str(x))) if pd.notna(x) else True
    )


def validate_phone(phone_series):
    """Validate phone format and return boolean mask of valid phones."""
    pattern = r'^\+1-\d{3}-\d{3}-\d{4}$'
    return phone_series.apply(
        lambda x: bool(re.match(pattern, str(x))) if pd.notna(x) else True
    )


# ==============================================================================
# CLEANING FUNCTIONS (One per table)
# ==============================================================================

def clean_customers(df):
    """
    Clean the customers dataset.
    
    Steps:
        - Remove exact duplicate rows
        - Deduplicate on email (keep earliest registration)
        - Fix data types (registration_date → datetime, is_active → bool)
        - Standardize name columns to title case
        - Standardize email to lowercase
        - Validate email and phone formats
        - Remove records with invalid regions/segments
        - Handle missing values (email, phone)
    """
    log_section("CLEANING: customers")
    initial_count = len(df)
    
    # --- Step 1: Remove exact duplicate rows ---
    df = df.drop_duplicates()
    log_step("Remove exact duplicates", initial_count, len(df))
    
    # --- Step 2: Deduplicate on email (business key) ---
    # Keep the earliest registration for each email
    before = len(df)
    df["registration_date"] = pd.to_datetime(df["registration_date"], errors="coerce")
    df = df.sort_values("registration_date")
    df = df.drop_duplicates(subset=["email"], keep="first")
    log_step("Deduplicate on email (business key)", before, len(df))
    
    # --- Step 3: Fix data types ---
    df["is_active"] = df["is_active"].astype(int)
    
    # --- Step 4: Standardize text columns ---
    df["first_name"] = standardize_text(df["first_name"], case="title")
    df["last_name"] = standardize_text(df["last_name"], case="title")
    df["email"] = df["email"].str.strip().str.lower().where(df["email"].notna(), other=np.nan)
    df["city"] = standardize_text(df["city"], case="title")
    df["region"] = standardize_text(df["region"], case="title")
    df["state"] = df["state"].str.strip().str.upper().where(df["state"].notna(), other=np.nan)
    df["customer_segment"] = standardize_text(df["customer_segment"], case="title")
    
    # --- Step 5: Validate email format ---
    valid_emails = validate_email(df["email"])
    invalid_email_count = (~valid_emails).sum()
    if invalid_email_count > 0:
        df.loc[~valid_emails, "email"] = np.nan
        print(f"    Invalidated {invalid_email_count} malformed emails → set to NaN")
    
    # --- Step 6: Validate phone format ---
    valid_phones = validate_phone(df["phone"])
    invalid_phone_count = (~valid_phones).sum()
    if invalid_phone_count > 0:
        df.loc[~valid_phones, "phone"] = np.nan
        print(f"    Invalidated {invalid_phone_count} malformed phones → set to NaN")
    
    # --- Step 7: Remove records with invalid categorical values ---
    before = len(df)
    df = df[df["region"].isin(VALID_REGIONS)]
    df = df[df["customer_segment"].isin(VALID_SEGMENTS)]
    log_step("Remove invalid region/segment values", before, len(df))
    
    # --- Step 8: Handle missing values ---
    # email & phone are optional — leave as NaN (noted in metadata)
    # customer_id is required — drop rows without it
    before = len(df)
    df = df.dropna(subset=["customer_id", "first_name", "last_name"])
    log_step("Drop rows missing required fields", before, len(df))
    
    # --- Summary ---
    print(f"\n    ✓ Customers cleaned: {initial_count:,} → {len(df):,} rows")
    return df.reset_index(drop=True)


def clean_products(df):
    """
    Clean the products dataset.
    
    Steps:
        - Remove exact duplicates
        - Fix data types (unit_price, unit_cost → float)
        - Handle missing unit_cost (impute with category median margin)
        - Remove products with invalid/negative pricing
        - Standardize category and brand names
    """
    log_section("CLEANING: products")
    initial_count = len(df)
    
    # --- Step 1: Remove exact duplicates ---
    df = df.drop_duplicates()
    log_step("Remove exact duplicates", initial_count, len(df))
    
    # --- Step 2: Fix data types ---
    df["unit_price"] = pd.to_numeric(df["unit_price"], errors="coerce")
    df["unit_cost"] = pd.to_numeric(df["unit_cost"], errors="coerce")
    df["stock_quantity"] = pd.to_numeric(df["stock_quantity"], errors="coerce").astype("Int64")
    df["is_active"] = df["is_active"].astype(int)
    
    # --- Step 3: Impute missing unit_cost ---
    # Use category-level median cost-to-price ratio
    missing_cost = df["unit_cost"].isna().sum()
    if missing_cost > 0:
        cost_ratio = df.dropna(subset=["unit_cost", "unit_price"])
        cost_ratio = cost_ratio.groupby("category").apply(
            lambda x: (x["unit_cost"] / x["unit_price"]).median()
        )
        for idx in df[df["unit_cost"].isna()].index:
            category = df.loc[idx, "category"]
            price = df.loc[idx, "unit_price"]
            ratio = cost_ratio.get(category, 0.50)  # default 50% margin
            df.loc[idx, "unit_cost"] = round(price * ratio, 2)
        print(f"    Imputed {missing_cost} missing unit_cost values using category median ratio")
    
    # --- Step 4: Remove invalid pricing ---
    before = len(df)
    df = df[(df["unit_price"] > 0) & (df["unit_cost"] >= 0)]
    df = df[df["unit_cost"] <= df["unit_price"]]  # cost cannot exceed price
    log_step("Remove invalid pricing (negative/cost>price)", before, len(df))
    
    # --- Step 5: Standardize text ---
    df["product_name"] = standardize_text(df["product_name"], case="title")
    df["category"] = standardize_text(df["category"], case="title")
    df["subcategory"] = standardize_text(df["subcategory"], case="title")
    df["brand"] = standardize_text(df["brand"], case="title")
    
    # --- Step 6: Remove invalid stock quantities ---
    before = len(df)
    df = df[df["stock_quantity"] >= 0]
    log_step("Remove negative stock quantities", before, len(df))
    
    print(f"\n    ✓ Products cleaned: {initial_count:,} → {len(df):,} rows")
    return df.reset_index(drop=True)


def clean_stores(df):
    """
    Clean the stores dataset.
    
    Steps:
        - Remove duplicates
        - Fix data types (opening_date → datetime)
        - Validate store_type and region values
        - Standardize text columns
    """
    log_section("CLEANING: stores")
    initial_count = len(df)
    
    # --- Step 1: Remove duplicates ---
    df = df.drop_duplicates()
    log_step("Remove exact duplicates", initial_count, len(df))
    
    # --- Step 2: Fix data types ---
    df["opening_date"] = pd.to_datetime(df["opening_date"], errors="coerce")
    df["square_footage"] = pd.to_numeric(df["square_footage"], errors="coerce").astype("Int64")
    df["is_active"] = df["is_active"].astype(int)
    
    # --- Step 3: Validate categorical values ---
    before = len(df)
    df = df[df["store_type"].isin(VALID_STORE_TYPES)]
    df = df[df["region"].isin(VALID_REGIONS)]
    log_step("Remove invalid store_type/region", before, len(df))
    
    # --- Step 4: Standardize text ---
    df["store_name"] = standardize_text(df["store_name"], case="title")
    df["city"] = standardize_text(df["city"], case="title")
    df["state"] = df["state"].str.strip().str.upper()
    
    # --- Step 5: Remove invalid square footage ---
    before = len(df)
    df = df[df["square_footage"] > 0]
    log_step("Remove invalid square footage", before, len(df))
    
    print(f"\n    ✓ Stores cleaned: {initial_count:,} → {len(df):,} rows")
    return df.reset_index(drop=True)


def clean_sales_reps(df):
    """
    Clean the sales_reps dataset.
    
    Steps:
        - Remove duplicates
        - Fix data types (hire_date → datetime, quarterly_quota → float)
        - Standardize name and team columns
        - Validate region and quota values
        - Handle missing manager_id (top-level managers → NaN is valid)
    """
    log_section("CLEANING: sales_reps")
    initial_count = len(df)
    
    # --- Step 1: Remove duplicates ---
    df = df.drop_duplicates()
    log_step("Remove exact duplicates", initial_count, len(df))
    
    # --- Step 2: Fix data types ---
    df["hire_date"] = pd.to_datetime(df["hire_date"], errors="coerce")
    df["quarterly_quota"] = pd.to_numeric(df["quarterly_quota"], errors="coerce")
    df["is_active"] = df["is_active"].astype(int)
    
    # --- Step 3: Standardize text ---
    df["first_name"] = standardize_text(df["first_name"], case="title")
    df["last_name"] = standardize_text(df["last_name"], case="title")
    df["email"] = df["email"].str.strip().str.lower()
    df["team"] = standardize_text(df["team"], case="title")
    df["region"] = standardize_text(df["region"], case="title")
    
    # --- Step 4: Validate region ---
    before = len(df)
    df = df[df["region"].isin(VALID_REGIONS)]
    log_step("Remove invalid region values", before, len(df))
    
    # --- Step 5: Validate quota (must be positive) ---
    before = len(df)
    df = df[df["quarterly_quota"] > 0]
    log_step("Remove invalid quota values", before, len(df))
    
    # --- Step 6: manager_id is NaN for top-level — this is valid ---
    print(f"    Note: {df['manager_id'].isna().sum()} reps have no manager (top-level)")
    
    print(f"\n    ✓ Sales reps cleaned: {initial_count:,} → {len(df):,} rows")
    return df.reset_index(drop=True)


def clean_orders(df, valid_customer_ids, valid_store_ids, valid_rep_ids):
    """
    Clean the orders dataset.
    
    Steps:
        - Remove exact duplicate rows
        - Deduplicate on order_id (keep first occurrence)
        - Fix data types (order_date → datetime, numerics)
        - Validate foreign key references
        - Validate categorical values (channel, status, payment)
        - Handle conditional NULLs (store_id, marketplace)
        - Remove records with future dates
        - Remove invalid shipping/discount values
    
    Args:
        df: Raw orders DataFrame
        valid_customer_ids: Set of valid customer IDs from cleaned customers
        valid_store_ids: Set of valid store IDs from cleaned stores
        valid_rep_ids: Set of valid sales rep IDs from cleaned sales_reps
    """
    log_section("CLEANING: orders")
    initial_count = len(df)
    
    # --- Step 1: Remove exact duplicate rows ---
    before = len(df)
    df = df.drop_duplicates()
    log_step("Remove exact duplicate rows", before, len(df))
    
    # --- Step 2: Deduplicate on order_id (primary key) ---
    before = len(df)
    df = df.drop_duplicates(subset=["order_id"], keep="first")
    log_step("Deduplicate on order_id (PK)", before, len(df))
    
    # --- Step 3: Fix data types ---
    df["order_date"] = pd.to_datetime(df["order_date"], errors="coerce")
    df["shipping_cost"] = pd.to_numeric(df["shipping_cost"], errors="coerce")
    df["discount_amount"] = pd.to_numeric(df["discount_amount"], errors="coerce")
    
    # --- Step 4: Remove future-dated orders ---
    before = len(df)
    today = pd.Timestamp(datetime.now().date())
    df = df[df["order_date"] <= today]
    log_step("Remove future-dated orders", before, len(df))
    
    # --- Step 5: Remove orders with invalid dates ---
    before = len(df)
    df = df.dropna(subset=["order_date"])
    log_step("Remove orders with unparseable dates", before, len(df))
    
    # --- Step 6: Validate categorical columns ---
    before = len(df)
    df = df[df["channel"].isin(VALID_CHANNELS)]
    df = df[df["order_status"].isin(VALID_ORDER_STATUSES)]
    df = df[df["payment_method"].isin(VALID_PAYMENT_METHODS)]
    log_step("Remove invalid channel/status/payment", before, len(df))
    
    # --- Step 7: Validate conditional NULLs ---
    # store_id should only be populated for In-Store orders
    df.loc[df["channel"] != "In-Store", "store_id"] = np.nan
    # marketplace should only be populated for Marketplace orders
    df.loc[df["channel"] != "Marketplace", "marketplace"] = np.nan
    
    # Validate marketplace values where populated
    valid_marketplace_mask = (
        df["marketplace"].isna() | df["marketplace"].isin(VALID_MARKETPLACES)
    )
    before = len(df)
    df = df[valid_marketplace_mask]
    log_step("Remove invalid marketplace values", before, len(df))
    
    # --- Step 8: Validate foreign keys ---
    # Set orphan customer_ids to NaN (treat as guest checkout)
    orphan_customers = ~df["customer_id"].isin(valid_customer_ids) & df["customer_id"].notna()
    orphan_count = orphan_customers.sum()
    if orphan_count > 0:
        df.loc[orphan_customers, "customer_id"] = np.nan
        print(f"    Nullified {orphan_count} orphan customer_id references (→ guest checkout)")
    
    # Validate store_id references
    if valid_store_ids:
        invalid_stores = (
            df["store_id"].notna() & ~df["store_id"].isin(valid_store_ids)
        )
        df.loc[invalid_stores, "store_id"] = np.nan
        inv_count = invalid_stores.sum()
        if inv_count > 0:
            print(f"    Nullified {inv_count} invalid store_id references")
    
    # Validate sales_rep_id references
    if valid_rep_ids:
        invalid_reps = (
            df["sales_rep_id"].notna() & ~df["sales_rep_id"].isin(valid_rep_ids)
        )
        df.loc[invalid_reps, "sales_rep_id"] = np.nan
        inv_count = invalid_reps.sum()
        if inv_count > 0:
            print(f"    Nullified {inv_count} invalid sales_rep_id references")
    
    # --- Step 9: Fix numeric ranges ---
    # Shipping cost cannot be negative
    df["shipping_cost"] = df["shipping_cost"].clip(lower=0)
    # Discount cannot be negative
    df["discount_amount"] = df["discount_amount"].clip(lower=0)
    # In-store orders should have 0 shipping
    df.loc[df["channel"] == "In-Store", "shipping_cost"] = 0.00
    
    # --- Step 10: Standardize text ---
    df["channel"] = standardize_text(df["channel"], case="title")
    df["order_status"] = standardize_text(df["order_status"], case="title")
    df["payment_method"] = standardize_text(df["payment_method"], case="title")
    
    print(f"\n    ✓ Orders cleaned: {initial_count:,} → {len(df):,} rows")
    return df.reset_index(drop=True)


def clean_order_items(df, valid_order_ids, valid_product_ids, product_prices):
    """
    Clean the order_items dataset.
    
    Steps:
        - Remove duplicates
        - Fix data types
        - Backfill missing unit_price from products master
        - Validate foreign keys (order_id, product_id)
        - Remove items with invalid quantities or pricing
        - Recalculate line_total for consistency
    
    Args:
        df: Raw order_items DataFrame
        valid_order_ids: Set of valid order IDs from cleaned orders
        valid_product_ids: Set of valid product IDs from cleaned products
        product_prices: Dict mapping product_id → unit_price (from products table)
    """
    log_section("CLEANING: order_items")
    initial_count = len(df)
    
    # --- Step 1: Remove duplicates ---
    df = df.drop_duplicates()
    log_step("Remove exact duplicates", initial_count, len(df))
    
    # --- Step 2: Fix data types ---
    df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce")
    df["unit_price"] = pd.to_numeric(df["unit_price"], errors="coerce")
    df["line_discount"] = pd.to_numeric(df["line_discount"], errors="coerce").fillna(0)
    df["line_total"] = pd.to_numeric(df["line_total"], errors="coerce")
    
    # --- Step 3: Backfill missing unit_price from product master ---
    missing_price = df["unit_price"].isna().sum()
    if missing_price > 0:
        df["unit_price"] = df.apply(
            lambda row: product_prices.get(row["product_id"], np.nan)
            if pd.isna(row["unit_price"]) else row["unit_price"],
            axis=1
        )
        filled = missing_price - df["unit_price"].isna().sum()
        print(f"    Backfilled {filled}/{missing_price} missing unit_price from product master")
    
    # --- Step 4: Validate foreign keys ---
    before = len(df)
    df = df[df["order_id"].isin(valid_order_ids)]
    log_step("Remove items with invalid order_id", before, len(df))
    
    before = len(df)
    df = df[df["product_id"].isin(valid_product_ids)]
    log_step("Remove items with invalid product_id", before, len(df))
    
    # --- Step 5: Remove invalid quantities and pricing ---
    before = len(df)
    df = df[df["quantity"] > 0]
    df = df[df["unit_price"] > 0]
    df = df[df["line_discount"] >= 0]
    log_step("Remove invalid quantity/price/discount", before, len(df))
    
    # --- Step 6: Recalculate line_total for consistency ---
    df["line_total"] = (df["unit_price"] * df["quantity"] - df["line_discount"]).round(2)
    # Ensure line_total is not negative after discount
    df["line_total"] = df["line_total"].clip(lower=0)
    print(f"    Recalculated line_total = (unit_price × quantity) − line_discount")
    
    print(f"\n    ✓ Order items cleaned: {initial_count:,} → {len(df):,} rows")
    return df.reset_index(drop=True)


def clean_returns(df, valid_order_ids, valid_item_ids, valid_customer_ids):
    """
    Clean the returns dataset.
    
    Steps:
        - Remove duplicates
        - Fix data types (return_date → datetime, refund_amount → float)
        - Validate foreign keys
        - Remove returns with invalid dates (before order date)
        - Validate refund_status values
        - Standardize reason text
    
    Args:
        df: Raw returns DataFrame
        valid_order_ids: Set of valid order IDs
        valid_item_ids: Set of valid order_item IDs
        valid_customer_ids: Set of valid customer IDs
    """
    log_section("CLEANING: returns")
    initial_count = len(df)
    
    # --- Step 1: Remove duplicates ---
    df = df.drop_duplicates()
    log_step("Remove exact duplicates", initial_count, len(df))
    
    # --- Step 2: Fix data types ---
    df["return_date"] = pd.to_datetime(df["return_date"], errors="coerce")
    df["refund_amount"] = pd.to_numeric(df["refund_amount"], errors="coerce")
    
    # --- Step 3: Validate foreign keys ---
    before = len(df)
    df = df[df["order_id"].isin(valid_order_ids)]
    log_step("Remove returns with invalid order_id", before, len(df))
    
    before = len(df)
    df = df[df["order_item_id"].isin(valid_item_ids)]
    log_step("Remove returns with invalid order_item_id", before, len(df))
    
    # Nullify invalid customer_ids (inherited from guest checkouts)
    invalid_customers = (
        df["customer_id"].notna() & ~df["customer_id"].isin(valid_customer_ids)
    )
    if invalid_customers.sum() > 0:
        df.loc[invalid_customers, "customer_id"] = np.nan
        print(f"    Nullified {invalid_customers.sum()} invalid customer_id references")
    
    # --- Step 4: Remove invalid return dates ---
    before = len(df)
    df = df.dropna(subset=["return_date"])
    today = pd.Timestamp(datetime.now().date())
    df = df[df["return_date"] <= today]
    log_step("Remove invalid/future return dates", before, len(df))
    
    # --- Step 5: Validate refund values ---
    before = len(df)
    df = df[df["refund_amount"] >= 0]
    log_step("Remove negative refund amounts", before, len(df))
    
    # --- Step 6: Validate refund_status ---
    before = len(df)
    df = df[df["refund_status"].isin(VALID_REFUND_STATUSES)]
    log_step("Remove invalid refund_status", before, len(df))
    
    # --- Step 7: Standardize text ---
    df["reason"] = standardize_text(df["reason"], case="title")
    df["refund_status"] = standardize_text(df["refund_status"], case="title")
    
    print(f"\n    ✓ Returns cleaned: {initial_count:,} → {len(df):,} rows")
    return df.reset_index(drop=True)


# ==============================================================================
# MAIN PIPELINE
# ==============================================================================

def run_pipeline():
    """
    Execute the full data cleaning pipeline.
    
    Loads raw CSVs → cleans each table → validates integrity → saves to processed/.
    """
    print("=" * 60)
    print("  DATA CLEANING PIPELINE")
    print("  Sales Performance & Revenue Analytics Dashboard")
    print("=" * 60)
    print(f"\n  Source: {RAW_DIR}")
    print(f"  Output: {PROCESSED_DIR}")
    print(f"  Run at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Create output directory
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    
    # ─────────────────────────────────────────────────────────────
    # LOAD RAW DATA
    # ─────────────────────────────────────────────────────────────
    log_section("LOADING RAW DATA")
    
    customers_raw = pd.read_csv(os.path.join(RAW_DIR, "customers.csv"))
    products_raw = pd.read_csv(os.path.join(RAW_DIR, "products.csv"))
    stores_raw = pd.read_csv(os.path.join(RAW_DIR, "stores.csv"))
    sales_reps_raw = pd.read_csv(os.path.join(RAW_DIR, "sales_reps.csv"))
    orders_raw = pd.read_csv(os.path.join(RAW_DIR, "orders.csv"))
    order_items_raw = pd.read_csv(os.path.join(RAW_DIR, "order_items.csv"))
    returns_raw = pd.read_csv(os.path.join(RAW_DIR, "returns.csv"))
    
    print(f"    customers:    {len(customers_raw):>10,} rows")
    print(f"    products:     {len(products_raw):>10,} rows")
    print(f"    stores:       {len(stores_raw):>10,} rows")
    print(f"    sales_reps:   {len(sales_reps_raw):>10,} rows")
    print(f"    orders:       {len(orders_raw):>10,} rows")
    print(f"    order_items:  {len(order_items_raw):>10,} rows")
    print(f"    returns:      {len(returns_raw):>10,} rows")
    
    # ─────────────────────────────────────────────────────────────
    # CLEAN DIMENSION TABLES FIRST (referenced by fact tables)
    # ─────────────────────────────────────────────────────────────
    customers_clean = clean_customers(customers_raw)
    products_clean = clean_products(products_raw)
    stores_clean = clean_stores(stores_raw)
    sales_reps_clean = clean_sales_reps(sales_reps_raw)
    
    # Build reference sets for FK validation
    valid_customer_ids = set(customers_clean["customer_id"])
    valid_product_ids = set(products_clean["product_id"])
    valid_store_ids = set(stores_clean["store_id"])
    valid_rep_ids = set(sales_reps_clean["sales_rep_id"])
    product_prices = dict(zip(products_clean["product_id"], products_clean["unit_price"]))
    
    # ─────────────────────────────────────────────────────────────
    # CLEAN FACT TABLES (depend on dimension tables)
    # ─────────────────────────────────────────────────────────────
    orders_clean = clean_orders(
        orders_raw, valid_customer_ids, valid_store_ids, valid_rep_ids
    )
    
    valid_order_ids = set(orders_clean["order_id"])
    
    order_items_clean = clean_order_items(
        order_items_raw, valid_order_ids, valid_product_ids, product_prices
    )
    
    valid_item_ids = set(order_items_clean["order_item_id"])
    
    returns_clean = clean_returns(
        returns_raw, valid_order_ids, valid_item_ids, valid_customer_ids
    )
    
    # ─────────────────────────────────────────────────────────────
    # SAVE CLEANED DATASETS
    # ─────────────────────────────────────────────────────────────
    log_section("SAVING CLEANED DATASETS")
    
    datasets = {
        "customers": customers_clean,
        "products": products_clean,
        "stores": stores_clean,
        "sales_reps": sales_reps_clean,
        "orders": orders_clean,
        "order_items": order_items_clean,
        "returns": returns_clean
    }
    
    for name, df in datasets.items():
        filepath = os.path.join(PROCESSED_DIR, f"{name}_clean.csv")
        df.to_csv(filepath, index=False)
        print(f"    ✓ {name}_clean.csv ({len(df):,} rows, {len(df.columns)} cols)")
    
    # ─────────────────────────────────────────────────────────────
    # FINAL SUMMARY
    # ─────────────────────────────────────────────────────────────
    log_section("PIPELINE SUMMARY")
    
    raw_totals = {
        "customers": len(customers_raw),
        "products": len(products_raw),
        "stores": len(stores_raw),
        "sales_reps": len(sales_reps_raw),
        "orders": len(orders_raw),
        "order_items": len(order_items_raw),
        "returns": len(returns_raw)
    }
    
    print(f"\n    {'Table':<18} {'Raw Rows':<12} {'Clean Rows':<12} {'Removed':<10} {'% Retained'}")
    print(f"    {'─' * 62}")
    
    total_raw = 0
    total_clean = 0
    for name, df in datasets.items():
        raw = raw_totals[name]
        clean = len(df)
        removed = raw - clean
        pct = (clean / raw * 100) if raw > 0 else 0
        total_raw += raw
        total_clean += clean
        print(f"    {name:<18} {raw:<12,} {clean:<12,} {removed:<10,} {pct:.1f}%")
    
    print(f"    {'─' * 62}")
    print(f"    {'TOTAL':<18} {total_raw:<12,} {total_clean:<12,} "
          f"{total_raw - total_clean:<10,} {(total_clean/total_raw*100):.1f}%")
    
    print(f"\n    Output directory: {PROCESSED_DIR}")
    print(f"\n{'=' * 60}")
    print("  PIPELINE COMPLETE ✓")
    print(f"{'=' * 60}\n")
    
    return datasets


# ==============================================================================
# ENTRY POINT
# ==============================================================================

if __name__ == "__main__":
    run_pipeline()
