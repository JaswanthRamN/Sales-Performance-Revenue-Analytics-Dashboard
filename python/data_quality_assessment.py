"""
Data Quality Assessment - Analyze raw retail dataset for the Data Dictionary.
"""

import pandas as pd
import os

RAW_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "raw")

# Load all datasets
print("Loading datasets...\n")
customers = pd.read_csv(os.path.join(RAW_DIR, "customers.csv"))
products = pd.read_csv(os.path.join(RAW_DIR, "products.csv"))
stores = pd.read_csv(os.path.join(RAW_DIR, "stores.csv"))
sales_reps = pd.read_csv(os.path.join(RAW_DIR, "sales_reps.csv"))
orders = pd.read_csv(os.path.join(RAW_DIR, "orders.csv"))
order_items = pd.read_csv(os.path.join(RAW_DIR, "order_items.csv"))
returns = pd.read_csv(os.path.join(RAW_DIR, "returns.csv"))

datasets = {
    "customers": customers,
    "products": products,
    "stores": stores,
    "sales_reps": sales_reps,
    "orders": orders,
    "order_items": order_items,
    "returns": returns
}

# ==============================================================================
# 1. SCHEMA INFO (Data Types, Shape)
# ==============================================================================
print("=" * 70)
print("1. DATASET OVERVIEW")
print("=" * 70)
for name, df in datasets.items():
    print(f"\n{'─' * 70}")
    print(f"TABLE: {name}")
    print(f"{'─' * 70}")
    print(f"  Rows: {len(df):,}  |  Columns: {len(df.columns)}")
    print(f"  Memory usage: {df.memory_usage(deep=True).sum() / 1024 / 1024:.2f} MB")
    print(f"\n  {'Column':<25} {'Dtype':<15} {'Non-Null':<12} {'Null':<8} {'Null%':<8} {'Unique':<10}")
    print(f"  {'─' * 78}")
    for col in df.columns:
        non_null = df[col].notna().sum()
        null_count = df[col].isna().sum()
        null_pct = f"{(null_count / len(df)) * 100:.2f}%"
        unique = df[col].nunique()
        print(f"  {col:<25} {str(df[col].dtype):<15} {non_null:<12} {null_count:<8} {null_pct:<8} {unique:<10}")

# ==============================================================================
# 2. MISSING VALUES REPORT
# ==============================================================================
print("\n\n" + "=" * 70)
print("2. MISSING VALUES REPORT")
print("=" * 70)

total_missing = 0
for name, df in datasets.items():
    missing = df.isnull().sum()
    missing_cols = missing[missing > 0]
    if len(missing_cols) > 0:
        print(f"\n  TABLE: {name}")
        print(f"  {'Column':<25} {'Missing Count':<18} {'Missing %':<12} {'Impact'}")
        print(f"  {'─' * 70}")
        for col, count in missing_cols.items():
            pct = (count / len(df)) * 100
            impact = "HIGH" if pct > 5 else ("MEDIUM" if pct > 1 else "LOW")
            print(f"  {col:<25} {count:<18} {pct:.2f}%{'':>8} {impact}")
            total_missing += count

print(f"\n  TOTAL MISSING VALUES ACROSS ALL TABLES: {total_missing:,}")

# ==============================================================================
# 3. DUPLICATE REPORT
# ==============================================================================
print("\n\n" + "=" * 70)
print("3. DUPLICATE RECORDS REPORT")
print("=" * 70)

# Exact row duplicates
print("\n  3a. EXACT ROW DUPLICATES")
print(f"  {'Table':<20} {'Total Rows':<15} {'Duplicate Rows':<18} {'Dup %':<10}")
print(f"  {'─' * 65}")
for name, df in datasets.items():
    dups = df.duplicated().sum()
    pct = (dups / len(df)) * 100
    print(f"  {name:<20} {len(df):<15,} {dups:<18} {pct:.2f}%")

# Primary key uniqueness
print("\n  3b. PRIMARY KEY UNIQUENESS CHECK")
pk_map = {
    "customers": "customer_id",
    "products": "product_id",
    "stores": "store_id",
    "sales_reps": "sales_rep_id",
    "orders": "order_id",
    "order_items": "order_item_id",
    "returns": "return_id"
}
print(f"  {'Table':<20} {'PK Column':<20} {'Total':<12} {'Unique':<12} {'Duplicates':<12} {'Status'}")
print(f"  {'─' * 85}")
for name, pk in pk_map.items():
    df = datasets[name]
    total = len(df)
    unique = df[pk].nunique()
    dups = total - unique
    status = "✓ PASS" if dups == 0 else "✗ FAIL"
    print(f"  {name:<20} {pk:<20} {total:<12,} {unique:<12,} {dups:<12} {status}")

# Business key duplicates (email in customers)
print("\n  3c. BUSINESS KEY DUPLICATES (Potential Data Issues)")
dup_emails = customers[customers["email"].notna()].groupby("email").filter(lambda x: len(x) > 1)
print(f"  Customers with duplicate emails: {dup_emails['email'].nunique()} unique emails, {len(dup_emails)} records")

# ==============================================================================
# 4. REFERENTIAL INTEGRITY CHECK
# ==============================================================================
print("\n\n" + "=" * 70)
print("4. REFERENTIAL INTEGRITY CHECK")
print("=" * 70)

checks = [
    ("orders.customer_id", orders, "customer_id", customers, "customer_id"),
    ("orders.store_id", orders[orders["store_id"].notna()], "store_id", stores, "store_id"),
    ("orders.sales_rep_id", orders[orders["sales_rep_id"].notna()], "sales_rep_id", sales_reps, "sales_rep_id"),
    ("order_items.order_id", order_items, "order_id", orders, "order_id"),
    ("order_items.product_id", order_items, "product_id", products, "product_id"),
    ("returns.order_id", returns, "order_id", orders, "order_id"),
    ("returns.customer_id", returns[returns["customer_id"].notna()], "customer_id", customers, "customer_id"),
]

print(f"\n  {'FK Reference':<30} {'Total FKs':<12} {'Valid':<12} {'Orphaned':<12} {'Status'}")
print(f"  {'─' * 80}")
for label, child_df, child_col, parent_df, parent_col in checks:
    total = len(child_df)
    valid = child_df[child_col].isin(parent_df[parent_col]).sum()
    orphaned = total - valid
    status = "✓ PASS" if orphaned == 0 else f"✗ FAIL ({orphaned} orphans)"
    print(f"  {label:<30} {total:<12,} {valid:<12,} {orphaned:<12} {status}")

# ==============================================================================
# 5. DATA RANGE / VALUE DISTRIBUTION
# ==============================================================================
print("\n\n" + "=" * 70)
print("5. NUMERIC DATA RANGES & STATISTICS")
print("=" * 70)

numeric_cols = {
    "products": ["unit_price", "unit_cost", "stock_quantity"],
    "orders": ["shipping_cost", "discount_amount"],
    "order_items": ["quantity", "unit_price", "line_discount", "line_total"],
    "sales_reps": ["quarterly_quota"],
    "returns": ["refund_amount"]
}

for table, cols in numeric_cols.items():
    df = datasets[table]
    print(f"\n  TABLE: {table}")
    print(f"  {'Column':<20} {'Min':<12} {'Max':<12} {'Mean':<12} {'Median':<12} {'Std Dev':<12} {'Zeros':<8}")
    print(f"  {'─' * 80}")
    for col in cols:
        if col in df.columns:
            s = df[col].dropna()
            zeros = (s == 0).sum()
            print(f"  {col:<20} {s.min():<12.2f} {s.max():<12.2f} {s.mean():<12.2f} {s.median():<12.2f} {s.std():<12.2f} {zeros:<8}")

# ==============================================================================
# 6. CATEGORICAL VALUE DISTRIBUTIONS
# ==============================================================================
print("\n\n" + "=" * 70)
print("6. CATEGORICAL VALUE DISTRIBUTIONS")
print("=" * 70)

cat_cols = {
    "customers": ["region", "customer_segment", "is_active"],
    "orders": ["channel", "order_status", "payment_method"],
    "products": ["category", "is_active"],
    "stores": ["store_type", "region"],
    "returns": ["reason", "refund_status"]
}

for table, cols in cat_cols.items():
    df = datasets[table]
    print(f"\n  TABLE: {table}")
    for col in cols:
        print(f"\n    {col}:")
        vc = df[col].value_counts()
        for val, count in vc.items():
            pct = (count / len(df)) * 100
            print(f"      {str(val):<30} {count:>8,}  ({pct:.1f}%)")

# ==============================================================================
# 7. DATE RANGE ANALYSIS
# ==============================================================================
print("\n\n" + "=" * 70)
print("7. DATE RANGE ANALYSIS")
print("=" * 70)

date_cols = {
    "customers": ["registration_date"],
    "orders": ["order_date"],
    "stores": ["opening_date"],
    "sales_reps": ["hire_date"],
    "returns": ["return_date"]
}

print(f"\n  {'Table':<20} {'Column':<25} {'Min Date':<15} {'Max Date':<15} {'Span (days)'}")
print(f"  {'─' * 80}")
for table, cols in date_cols.items():
    df = datasets[table]
    for col in cols:
        dates = pd.to_datetime(df[col])
        span = (dates.max() - dates.min()).days
        print(f"  {table:<20} {col:<25} {str(dates.min().date()):<15} {str(dates.max().date()):<15} {span}")

print("\n\nData Quality Assessment Complete!")
