"""
Database Loader
===============
Load cleaned CSV data into a relational database using SQLAlchemy + Pandas.

Supports: PostgreSQL, MySQL, SQL Server, SQLite (default for local dev).

Usage:
    python python/load_to_database.py                          # SQLite (default)
    python python/load_to_database.py --db postgresql           # PostgreSQL
    python python/load_to_database.py --db mysql                # MySQL
    python python/load_to_database.py --db sqlserver            # SQL Server

Prerequisites:
    pip install sqlalchemy pandas
    # For PostgreSQL: pip install psycopg2-binary
    # For MySQL:      pip install pymysql
    # For SQL Server: pip install pyodbc

Author: JaswanthRamN
Date: 2026-07-21
"""

import pandas as pd
import os
import sys
import argparse
from sqlalchemy import create_engine, text
from datetime import datetime

# Fix console encoding for Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")


# ==============================================================================
# CONFIGURATION
# ==============================================================================

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROCESSED_DIR = os.path.join(BASE_DIR, "data", "processed")
SQL_DIR = os.path.join(BASE_DIR, "sql")
SQLITE_PATH = os.path.join(BASE_DIR, "data", "sales_analytics.db")

# Table load order (dimension tables first, then fact tables)
LOAD_ORDER = [
    ("customers",   "customers_clean.csv"),
    ("products",    "products_clean.csv"),
    ("stores",      "stores_clean.csv"),
    ("sales_reps",  "sales_reps_clean.csv"),
    ("orders",      "orders_clean.csv"),
    ("order_items", "order_items_clean.csv"),
    ("returns",     "returns_clean.csv"),
]

# Date columns that need parsing per table
DATE_COLUMNS = {
    "customers":  ["registration_date"],
    "stores":     ["opening_date"],
    "sales_reps": ["hire_date"],
    "orders":     ["order_date"],
    "returns":    ["return_date"],
}


# ==============================================================================
# DATABASE CONNECTION
# ==============================================================================

def get_engine(db_type="sqlite"):
    """
    Create a SQLAlchemy engine for the specified database type.
    
    Args:
        db_type: One of 'sqlite', 'postgresql', 'mysql', 'sqlserver'
    
    Returns:
        SQLAlchemy Engine
    """
    if db_type == "sqlite":
        return create_engine(f"sqlite:///{SQLITE_PATH}", echo=False)
    
    elif db_type == "postgresql":
        # Update these values for your environment
        return create_engine(
            "postgresql://username:password@localhost:5432/sales_analytics"
        )
    
    elif db_type == "mysql":
        return create_engine(
            "mysql+pymysql://username:password@localhost:3306/sales_analytics"
        )
    
    elif db_type == "sqlserver":
        return create_engine(
            "mssql+pyodbc://username:password@localhost/sales_analytics"
            "?driver=ODBC+Driver+17+for+SQL+Server"
        )
    
    else:
        raise ValueError(f"Unsupported database type: {db_type}")


# ==============================================================================
# SCHEMA CREATION
# ==============================================================================

def create_schema(engine):
    """Execute the CREATE TABLE script to build the schema."""
    schema_file = os.path.join(SQL_DIR, "01_schema_create.sql")
    
    with open(schema_file, "r", encoding="utf-8") as f:
        sql_content = f.read()
    
    # Remove block comments (/* ... */) and single-line comments (--)
    import re
    sql_content = re.sub(r'/\*.*?\*/', '', sql_content, flags=re.DOTALL)
    
    # Split on semicolons and execute each statement
    statements = [s.strip() for s in sql_content.split(";") if s.strip()]
    
    with engine.begin() as conn:
        for stmt in statements:
            # Remove inline comments
            lines = [l for l in stmt.split("\n") if not l.strip().startswith("--")]
            clean_stmt = "\n".join(lines).strip()
            if not clean_stmt or clean_stmt.upper().startswith("CREATE DATABASE"):
                continue
            try:
                conn.execute(text(clean_stmt))
            except Exception as e:
                print(f"    Warning: {e}")
    
    print("    ✓ Schema created successfully")


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_table(engine, table_name, csv_file):
    """
    Load a single CSV file into the database table.
    
    Args:
        engine: SQLAlchemy engine
        table_name: Target table name
        csv_file: CSV filename in processed directory
    
    Returns:
        Number of rows loaded
    """
    filepath = os.path.join(PROCESSED_DIR, csv_file)
    
    # Read CSV with appropriate date parsing
    parse_dates = DATE_COLUMNS.get(table_name, [])
    df = pd.read_csv(filepath, parse_dates=parse_dates)
    
    # Replace NaN with None for proper SQL NULL handling
    df = df.where(df.notna(), other=None)
    
    # Load into database (append mode — schema already created)
    df.to_sql(
        name=table_name,
        con=engine,
        if_exists="append",
        index=False,
        chunksize=5000        # process in chunks to manage memory
    )
    
    return len(df)


# ==============================================================================
# VALIDATION
# ==============================================================================

def run_validation(engine):
    """Run key validation queries after import."""
    print("\n    Running validation checks...")
    
    with engine.connect() as conn:
        # Row counts
        print("\n    Row Counts:")
        print(f"    {'Table':<18} {'Count':<10}")
        print(f"    {'─' * 28}")
        
        for table_name, _ in LOAD_ORDER:
            result = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}"))
            count = result.scalar()
            print(f"    {table_name:<18} {count:,}")
        
        # PK uniqueness (orders — the one that had issues in raw data)
        result = conn.execute(text("""
            SELECT order_id, COUNT(*) as cnt
            FROM orders
            GROUP BY order_id
            HAVING COUNT(*) > 1
        """))
        dups = result.fetchall()
        status = "✓ PASS" if len(dups) == 0 else f"✗ FAIL ({len(dups)} duplicates)"
        print(f"\n    PK Uniqueness (orders): {status}")
        
        # FK integrity: orders → customers
        result = conn.execute(text("""
            SELECT COUNT(*) FROM orders o
            WHERE o.customer_id IS NOT NULL
            AND o.customer_id NOT IN (SELECT customer_id FROM customers)
        """))
        orphans = result.scalar()
        status = "✓ PASS" if orphans == 0 else f"✗ FAIL ({orphans} orphans)"
        print(f"    FK Integrity (orders → customers): {status}")
        
        # FK integrity: order_items → orders
        result = conn.execute(text("""
            SELECT COUNT(*) FROM order_items oi
            WHERE oi.order_id NOT IN (SELECT order_id FROM orders)
        """))
        orphans = result.scalar()
        status = "✓ PASS" if orphans == 0 else f"✗ FAIL ({orphans} orphans)"
        print(f"    FK Integrity (order_items → orders): {status}")
        
        # FK integrity: order_items → products
        result = conn.execute(text("""
            SELECT COUNT(*) FROM order_items oi
            WHERE oi.product_id NOT IN (SELECT product_id FROM products)
        """))
        orphans = result.scalar()
        status = "✓ PASS" if orphans == 0 else f"✗ FAIL ({orphans} orphans)"
        print(f"    FK Integrity (order_items → products): {status}")
        
        # FK integrity: returns → orders
        result = conn.execute(text("""
            SELECT COUNT(*) FROM returns r
            WHERE r.order_id NOT IN (SELECT order_id FROM orders)
        """))
        orphans = result.scalar()
        status = "✓ PASS" if orphans == 0 else f"✗ FAIL ({orphans} orphans)"
        print(f"    FK Integrity (returns → orders): {status}")
        
        # Business rule: In-Store orders have $0 shipping
        result = conn.execute(text("""
            SELECT COUNT(*) FROM orders
            WHERE channel = 'In-Store' AND shipping_cost > 0
        """))
        violations = result.scalar()
        status = "✓ PASS" if violations == 0 else f"✗ FAIL ({violations} violations)"
        print(f"    Business Rule (In-Store $0 shipping): {status}")


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(description="Load cleaned retail data into a database.")
    parser.add_argument(
        "--db", type=str, default="sqlite",
        choices=["sqlite", "postgresql", "mysql", "sqlserver"],
        help="Target database type (default: sqlite)"
    )
    args = parser.parse_args()
    
    print("=" * 60)
    print("  DATABASE LOADER")
    print("  Sales Performance & Revenue Analytics Dashboard")
    print("=" * 60)
    print(f"\n  Database:  {args.db}")
    print(f"  Source:    {PROCESSED_DIR}")
    print(f"  Run at:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Create engine
    engine = get_engine(args.db)
    
    if args.db == "sqlite":
        print(f"  DB File:   {SQLITE_PATH}")
    
    # Step 1: Create schema
    print(f"\n{'─' * 60}")
    print("  CREATING SCHEMA")
    print(f"{'─' * 60}")
    create_schema(engine)
    
    # Step 2: Load data
    print(f"\n{'─' * 60}")
    print("  LOADING DATA")
    print(f"{'─' * 60}")
    
    total_rows = 0
    for table_name, csv_file in LOAD_ORDER:
        rows = load_table(engine, table_name, csv_file)
        total_rows += rows
        print(f"    ✓ {table_name:<18} {rows:>10,} rows loaded")
    
    print(f"\n    Total: {total_rows:,} rows loaded across {len(LOAD_ORDER)} tables")
    
    # Step 3: Validate
    print(f"\n{'─' * 60}")
    print("  VALIDATION")
    print(f"{'─' * 60}")
    run_validation(engine)
    
    print(f"\n{'=' * 60}")
    print("  DATABASE LOAD COMPLETE ✓")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    main()
