"""
Generate Retail Dataset for Sales Performance & Revenue Analytics Dashboard.
Creates realistic synthetic data aligned with the Business Requirements Document.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os
import random
import string

# Set seed for reproducibility
np.random.seed(42)
random.seed(42)

# Output directory
RAW_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "raw")
os.makedirs(RAW_DIR, exist_ok=True)

# ==============================================================================
# 1. CUSTOMERS TABLE
# ==============================================================================
print("Generating customers...")

NUM_CUSTOMERS = 5000

first_names = ["James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael",
               "Linda", "David", "Elizabeth", "William", "Barbara", "Richard", "Susan",
               "Joseph", "Jessica", "Thomas", "Sarah", "Charles", "Karen", "Daniel",
               "Lisa", "Matthew", "Nancy", "Anthony", "Betty", "Mark", "Margaret",
               "Donald", "Sandra", "Steven", "Ashley", "Andrew", "Dorothy", "Paul",
               "Kimberly", "Joshua", "Emily", "Kenneth", "Donna", "Kevin", "Michelle",
               "Brian", "Carol", "George", "Amanda", "Timothy", "Melissa", "Ronald", "Deborah"]

last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
              "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
              "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
              "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
              "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King",
              "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Green",
              "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
              "Carter", "Roberts"]

regions = ["Northeast", "Southeast", "Midwest", "Southwest", "West"]
states_by_region = {
    "Northeast": ["NY", "MA", "PA", "NJ", "CT", "ME", "VT", "NH", "RI"],
    "Southeast": ["FL", "GA", "NC", "SC", "VA", "TN", "AL", "MS", "LA"],
    "Midwest": ["IL", "OH", "MI", "IN", "WI", "MN", "MO", "IA", "KS"],
    "Southwest": ["TX", "AZ", "NM", "OK", "NV"],
    "West": ["CA", "WA", "OR", "CO", "UT", "ID", "MT", "WY", "HI"]
}

cities_by_state = {
    "NY": ["New York", "Buffalo", "Rochester"], "MA": ["Boston", "Worcester", "Springfield"],
    "PA": ["Philadelphia", "Pittsburgh", "Allentown"], "NJ": ["Newark", "Jersey City", "Trenton"],
    "CT": ["Hartford", "New Haven", "Stamford"], "FL": ["Miami", "Orlando", "Tampa"],
    "GA": ["Atlanta", "Savannah", "Augusta"], "NC": ["Charlotte", "Raleigh", "Durham"],
    "TX": ["Houston", "Dallas", "Austin", "San Antonio"], "AZ": ["Phoenix", "Tucson", "Mesa"],
    "CA": ["Los Angeles", "San Francisco", "San Diego", "San Jose"],
    "WA": ["Seattle", "Tacoma", "Spokane"], "OR": ["Portland", "Salem", "Eugene"],
    "CO": ["Denver", "Colorado Springs", "Aurora"], "IL": ["Chicago", "Springfield", "Naperville"],
    "OH": ["Columbus", "Cleveland", "Cincinnati"], "MI": ["Detroit", "Grand Rapids", "Ann Arbor"],
    "SC": ["Charleston", "Columbia", "Greenville"], "VA": ["Richmond", "Virginia Beach", "Norfolk"],
    "TN": ["Nashville", "Memphis", "Knoxville"], "MN": ["Minneapolis", "St. Paul", "Rochester"],
    "MO": ["St. Louis", "Kansas City", "Springfield"], "NM": ["Albuquerque", "Santa Fe", "Las Cruces"],
    "OK": ["Oklahoma City", "Tulsa", "Norman"], "NV": ["Las Vegas", "Reno", "Henderson"],
    "IN": ["Indianapolis", "Fort Wayne", "Evansville"], "WI": ["Milwaukee", "Madison", "Green Bay"],
    "UT": ["Salt Lake City", "Provo", "Ogden"], "AL": ["Birmingham", "Montgomery", "Huntsville"],
    "ME": ["Portland", "Lewiston", "Bangor"], "VT": ["Burlington", "Montpelier"],
    "NH": ["Manchester", "Nashua"], "RI": ["Providence", "Warwick"],
    "MS": ["Jackson", "Gulfport"], "LA": ["New Orleans", "Baton Rouge"],
    "IA": ["Des Moines", "Cedar Rapids"], "KS": ["Wichita", "Overland Park"],
    "ID": ["Boise", "Meridian"], "MT": ["Billings", "Missoula"],
    "WY": ["Cheyenne", "Casper"], "HI": ["Honolulu", "Hilo"]
}

customer_segments = ["Regular", "Premium", "VIP", "New"]
segment_weights = [0.50, 0.25, 0.10, 0.15]

customers = []
for i in range(1, NUM_CUSTOMERS + 1):
    region = np.random.choice(regions, p=[0.25, 0.20, 0.20, 0.15, 0.20])
    state = np.random.choice(states_by_region[region])
    city = np.random.choice(cities_by_state.get(state, ["Unknown"]))
    segment = np.random.choice(customer_segments, p=segment_weights)
    
    reg_date = datetime(2023, 1, 1) + timedelta(days=np.random.randint(0, 1095))
    
    customers.append({
        "customer_id": f"CUST-{i:05d}",
        "first_name": np.random.choice(first_names),
        "last_name": np.random.choice(last_names),
        "email": f"customer{i}@{'gmail.com' if random.random() > 0.4 else 'yahoo.com'}",
        "phone": f"+1-{random.randint(200,999)}-{random.randint(100,999)}-{random.randint(1000,9999)}",
        "region": region,
        "state": state,
        "city": city,
        "customer_segment": segment,
        "registration_date": reg_date.strftime("%Y-%m-%d"),
        "is_active": np.random.choice([1, 0], p=[0.85, 0.15])
    })

# Introduce missing values (~3% in phone, ~1% in email)
for i in random.sample(range(NUM_CUSTOMERS), int(NUM_CUSTOMERS * 0.03)):
    customers[i]["phone"] = None
for i in random.sample(range(NUM_CUSTOMERS), int(NUM_CUSTOMERS * 0.01)):
    customers[i]["email"] = None

df_customers = pd.DataFrame(customers)
df_customers.to_csv(os.path.join(RAW_DIR, "customers.csv"), index=False)
print(f"  -> {len(df_customers)} customers generated")

# ==============================================================================
# 2. PRODUCTS TABLE
# ==============================================================================
print("Generating products...")

NUM_PRODUCTS = 500

categories = {
    "Electronics": ["Laptops", "Smartphones", "Tablets", "Headphones", "Cameras", "Smartwatches"],
    "Clothing": ["Men's Shirts", "Women's Dresses", "Jeans", "Jackets", "Shoes", "Activewear"],
    "Home & Kitchen": ["Cookware", "Furniture", "Bedding", "Appliances", "Decor", "Storage"],
    "Sports & Outdoors": ["Fitness Equipment", "Camping Gear", "Cycling", "Running", "Team Sports"],
    "Beauty & Health": ["Skincare", "Haircare", "Supplements", "Fragrances", "Makeup"],
    "Books & Media": ["Fiction", "Non-Fiction", "Textbooks", "Audiobooks", "Magazines"],
    "Toys & Games": ["Board Games", "Action Figures", "Puzzles", "Outdoor Toys", "Video Games"]
}

brands = ["TechPro", "StyleMax", "HomeComfort", "ActiveLife", "GlowUp", "ReadMore",
           "FunZone", "EliteGear", "PrimeChoice", "ValueMart", "LuxeLine", "EcoSmart",
           "SwiftTech", "UrbanTrend", "NatureFirst"]

products = []
for i in range(1, NUM_PRODUCTS + 1):
    category = np.random.choice(list(categories.keys()))
    subcategory = np.random.choice(categories[category])
    
    # Price ranges based on category
    price_ranges = {
        "Electronics": (49.99, 1999.99),
        "Clothing": (19.99, 299.99),
        "Home & Kitchen": (14.99, 899.99),
        "Sports & Outdoors": (24.99, 599.99),
        "Beauty & Health": (9.99, 149.99),
        "Books & Media": (4.99, 79.99),
        "Toys & Games": (9.99, 199.99)
    }
    
    low, high = price_ranges[category]
    unit_price = round(np.random.uniform(low, high), 2)
    cost = round(unit_price * np.random.uniform(0.35, 0.70), 2)
    
    products.append({
        "product_id": f"PROD-{i:04d}",
        "product_name": f"{np.random.choice(brands)} {subcategory} {random.choice(string.ascii_uppercase)}{random.randint(100,999)}",
        "category": category,
        "subcategory": subcategory,
        "brand": np.random.choice(brands),
        "unit_price": unit_price,
        "unit_cost": cost,
        "stock_quantity": np.random.randint(0, 500),
        "is_active": np.random.choice([1, 0], p=[0.92, 0.08])
    })

# Introduce ~2% missing in unit_cost (simulating incomplete cost data)
for i in random.sample(range(NUM_PRODUCTS), int(NUM_PRODUCTS * 0.02)):
    products[i]["unit_cost"] = None

df_products = pd.DataFrame(products)
df_products.to_csv(os.path.join(RAW_DIR, "products.csv"), index=False)
print(f"  -> {len(df_products)} products generated")

# ==============================================================================
# 3. STORES TABLE
# ==============================================================================
print("Generating stores...")

NUM_STORES = 50

store_types = ["Flagship", "Standard", "Outlet", "Pop-Up"]

stores = []
for i in range(1, NUM_STORES + 1):
    region = np.random.choice(regions)
    state = np.random.choice(states_by_region[region])
    city = np.random.choice(cities_by_state.get(state, ["Unknown"]))
    
    stores.append({
        "store_id": f"STORE-{i:03d}",
        "store_name": f"{city} {np.random.choice(store_types)} Store",
        "store_type": np.random.choice(store_types, p=[0.15, 0.50, 0.25, 0.10]),
        "region": region,
        "state": state,
        "city": city,
        "opening_date": (datetime(2018, 1, 1) + timedelta(days=np.random.randint(0, 2000))).strftime("%Y-%m-%d"),
        "square_footage": np.random.randint(1500, 15000),
        "is_active": np.random.choice([1, 0], p=[0.90, 0.10])
    })

df_stores = pd.DataFrame(stores)
df_stores.to_csv(os.path.join(RAW_DIR, "stores.csv"), index=False)
print(f"  -> {len(df_stores)} stores generated")

# ==============================================================================
# 4. SALES REPRESENTATIVES TABLE
# ==============================================================================
print("Generating sales reps...")

NUM_SALES_REPS = 80

sales_reps = []
for i in range(1, NUM_SALES_REPS + 1):
    region = np.random.choice(regions)
    hire_date = datetime(2019, 1, 1) + timedelta(days=np.random.randint(0, 2000))
    
    # Quarterly quota between $50K and $300K
    quarterly_quota = round(np.random.uniform(50000, 300000), 2)
    
    sales_reps.append({
        "sales_rep_id": f"REP-{i:03d}",
        "first_name": np.random.choice(first_names),
        "last_name": np.random.choice(last_names),
        "email": f"rep{i}@company.com",
        "region": region,
        "team": np.random.choice(["Team Alpha", "Team Beta", "Team Gamma", "Team Delta"]),
        "hire_date": hire_date.strftime("%Y-%m-%d"),
        "quarterly_quota": quarterly_quota,
        "manager_id": f"REP-{random.randint(1, 10):03d}" if i > 10 else None,
        "is_active": np.random.choice([1, 0], p=[0.88, 0.12])
    })

df_sales_reps = pd.DataFrame(sales_reps)
df_sales_reps.to_csv(os.path.join(RAW_DIR, "sales_reps.csv"), index=False)
print(f"  -> {len(df_sales_reps)} sales reps generated")

# ==============================================================================
# 5. ORDERS TABLE
# ==============================================================================
print("Generating orders...")

NUM_ORDERS = 50000

channels = ["Online", "In-Store", "Marketplace"]
channel_weights = [0.45, 0.30, 0.25]

marketplaces = ["Amazon", "eBay", "Walmart Marketplace", None]
payment_methods = ["Credit Card", "Debit Card", "PayPal", "Apple Pay", "Cash", "Gift Card"]
order_statuses = ["Completed", "Shipped", "Processing", "Cancelled", "Returned"]
status_weights = [0.65, 0.12, 0.08, 0.08, 0.07]

orders = []
for i in range(1, NUM_ORDERS + 1):
    order_date = datetime(2023, 1, 1) + timedelta(
        days=np.random.randint(0, 912)  # ~2.5 years of data through mid-2025
    )
    
    channel = np.random.choice(channels, p=channel_weights)
    customer_id = f"CUST-{random.randint(1, NUM_CUSTOMERS):05d}"
    
    # Assign store only for in-store, sales rep for all
    store_id = f"STORE-{random.randint(1, NUM_STORES):03d}" if channel == "In-Store" else None
    sales_rep_id = f"REP-{random.randint(1, NUM_SALES_REPS):03d}"
    marketplace = np.random.choice(marketplaces[:3]) if channel == "Marketplace" else None
    
    status = np.random.choice(order_statuses, p=status_weights)
    
    # Payment method - cash only for in-store
    if channel == "In-Store":
        payment = np.random.choice(payment_methods)
    else:
        payment = np.random.choice([p for p in payment_methods if p != "Cash"])
    
    orders.append({
        "order_id": f"ORD-{i:06d}",
        "customer_id": customer_id,
        "order_date": order_date.strftime("%Y-%m-%d"),
        "channel": channel,
        "store_id": store_id,
        "sales_rep_id": sales_rep_id,
        "marketplace": marketplace,
        "payment_method": payment,
        "order_status": status,
        "shipping_cost": round(np.random.uniform(0, 25.99), 2) if channel != "In-Store" else 0.00,
        "discount_amount": round(np.random.uniform(0, 50), 2) if random.random() > 0.6 else 0.00
    })

# Introduce ~0.5% missing customer_id (data quality issue)
for i in random.sample(range(NUM_ORDERS), int(NUM_ORDERS * 0.005)):
    orders[i]["customer_id"] = None

# Introduce ~1% missing sales_rep_id
for i in random.sample(range(NUM_ORDERS), int(NUM_ORDERS * 0.01)):
    orders[i]["sales_rep_id"] = None

df_orders = pd.DataFrame(orders)
df_orders.to_csv(os.path.join(RAW_DIR, "orders.csv"), index=False)
print(f"  -> {len(df_orders)} orders generated")

# ==============================================================================
# 6. ORDER ITEMS TABLE
# ==============================================================================
print("Generating order items...")

order_items = []
item_counter = 0
for order in orders:
    num_items = np.random.choice([1, 2, 3, 4, 5], p=[0.40, 0.30, 0.15, 0.10, 0.05])
    selected_products = random.sample(range(1, NUM_PRODUCTS + 1), min(num_items, NUM_PRODUCTS))
    
    for prod_idx in selected_products:
        item_counter += 1
        product = products[prod_idx - 1]
        quantity = np.random.choice([1, 2, 3, 4, 5], p=[0.50, 0.25, 0.13, 0.07, 0.05])
        unit_price = product["unit_price"]
        
        # Apply random line-level discount (0-15%)
        line_discount = round(unit_price * quantity * np.random.uniform(0, 0.15), 2) if random.random() > 0.7 else 0.00
        
        order_items.append({
            "order_item_id": f"ITEM-{item_counter:07d}",
            "order_id": order["order_id"],
            "product_id": product["product_id"],
            "quantity": quantity,
            "unit_price": unit_price,
            "line_discount": line_discount,
            "line_total": round(unit_price * quantity - line_discount, 2)
        })

# Introduce ~0.3% missing unit_price
sample_size = int(len(order_items) * 0.003)
for i in random.sample(range(len(order_items)), sample_size):
    order_items[i]["unit_price"] = None

df_order_items = pd.DataFrame(order_items)
df_order_items.to_csv(os.path.join(RAW_DIR, "order_items.csv"), index=False)
print(f"  -> {len(df_order_items)} order items generated")

# ==============================================================================
# 7. RETURNS TABLE
# ==============================================================================
print("Generating returns...")

# Returns based on orders with 'Returned' status + some additional partial returns
returned_orders = [o for o in orders if o["order_status"] == "Returned"]
additional_returns = random.sample(
    [o for o in orders if o["order_status"] == "Completed"],
    int(len([o for o in orders if o["order_status"] == "Completed"]) * 0.03)
)

return_reasons = ["Defective Product", "Wrong Item Shipped", "Size/Fit Issue",
                  "Changed Mind", "Better Price Found", "Arrived Late",
                  "Not As Described", "Damaged in Transit"]

returns = []
return_counter = 0
for order in returned_orders + additional_returns:
    return_counter += 1
    order_date = datetime.strptime(order["order_date"], "%Y-%m-%d")
    return_date = order_date + timedelta(days=np.random.randint(3, 45))
    
    # Get items from this order
    order_item_ids = [oi["order_item_id"] for oi in order_items if oi["order_id"] == order["order_id"]]
    if not order_item_ids:
        continue
    
    # Return 1 or more items from the order
    num_returned = min(np.random.randint(1, 3), len(order_item_ids))
    for item_id in random.sample(order_item_ids, num_returned):
        return_counter += 1
        item = next((oi for oi in order_items if oi["order_item_id"] == item_id), None)
        if item is None:
            continue
        
        refund_amount = item["line_total"] if item["line_total"] else 0
        
        returns.append({
            "return_id": f"RET-{return_counter:06d}",
            "order_id": order["order_id"],
            "order_item_id": item_id,
            "customer_id": order["customer_id"],
            "return_date": return_date.strftime("%Y-%m-%d"),
            "reason": np.random.choice(return_reasons),
            "refund_amount": round(refund_amount, 2),
            "refund_status": np.random.choice(["Processed", "Pending", "Denied"], p=[0.75, 0.15, 0.10])
        })

df_returns = pd.DataFrame(returns)
df_returns.to_csv(os.path.join(RAW_DIR, "returns.csv"), index=False)
print(f"  -> {len(df_returns)} returns generated")

# ==============================================================================
# SUMMARY
# ==============================================================================
print("\n" + "=" * 60)
print("DATASET GENERATION COMPLETE")
print("=" * 60)
print(f"\nFiles saved to: {RAW_DIR}")
print(f"\n{'Table':<20} {'Rows':<10} {'Columns':<10}")
print("-" * 40)
for name, df in [("customers", df_customers), ("products", df_products),
                 ("stores", df_stores), ("sales_reps", df_sales_reps),
                 ("orders", df_orders), ("order_items", df_order_items),
                 ("returns", df_returns)]:
    print(f"{name:<20} {len(df):<10} {len(df.columns):<10}")

# ==============================================================================
# Intentional duplicates for data quality testing
# ==============================================================================
print("\nInserting intentional duplicates for data quality testing...")

# Add ~20 duplicate customers (same email different ID - simulating re-registrations)
dup_customers = df_customers.sample(20).copy()
dup_customers["customer_id"] = [f"CUST-{NUM_CUSTOMERS + i + 1:05d}" for i in range(20)]
dup_customers["registration_date"] = pd.to_datetime(dup_customers["registration_date"]) + timedelta(days=30)
dup_customers["registration_date"] = dup_customers["registration_date"].dt.strftime("%Y-%m-%d")
df_customers_final = pd.concat([df_customers, dup_customers], ignore_index=True)
df_customers_final.to_csv(os.path.join(RAW_DIR, "customers.csv"), index=False)

# Add ~50 exact duplicate orders (simulating ETL double-loads)
dup_orders = df_orders.sample(50).copy()
df_orders_final = pd.concat([df_orders, dup_orders], ignore_index=True)
df_orders_final.to_csv(os.path.join(RAW_DIR, "orders.csv"), index=False)

print(f"  -> Added 20 duplicate customer records (same email, different ID)")
print(f"  -> Added 50 exact duplicate order records")
print(f"\nFinal row counts:")
print(f"  customers.csv: {len(df_customers_final)}")
print(f"  orders.csv: {len(df_orders_final)}")
print("\nDone!")
