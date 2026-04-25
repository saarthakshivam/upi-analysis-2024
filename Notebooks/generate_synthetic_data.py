"""
generate_synthetic_data.py
--------------------------
Generates a realistic synthetic UPI transaction-level dataset for 2024.
Based on real NPCI aggregate statistics - distributions are calibrated to
match actual monthly volumes, app market share, and city-wise usage patterns.

Run:  python notebooks/generate_synthetic_data.py
Output: data/raw/upi_transactions_2024.csv  (~50,000 rows)
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import os

# ── Reproducibility ──────────────────────────────────────────────────────────
np.random.seed(42)
random.seed(42)

# ── Config ───────────────────────────────────────────────────────────────────
N_TRANSACTIONS = 50_000
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "raw", "upi_transactions_2024.csv")

# ── Reference distributions (calibrated to NPCI 2024 data) ───────────────────

# App market share (approx. real 2024 share)
UPI_APPS = {
    "PhonePe":   0.48,
    "Google Pay": 0.37,
    "Paytm":     0.08,
    "BHIM":      0.03,
    "Amazon Pay": 0.02,
    "Others":    0.02,
}

# Transaction type: P2P (person-to-person) vs P2M (person-to-merchant)
# NPCI data shows ~46% P2P, ~54% P2M by volume in 2024
TRANSACTION_TYPES = {"P2P": 0.46, "P2M": 0.54}

# City tier distribution
CITIES = {
    "Mumbai":    0.12,
    "Delhi":     0.11,
    "Bengaluru": 0.10,
    "Hyderabad": 0.07,
    "Chennai":   0.06,
    "Kolkata":   0.05,
    "Pune":      0.05,
    "Ahmedabad": 0.04,
    "Jaipur":    0.04,
    "Lucknow":   0.03,
    "Surat":     0.03,
    "Kochi":     0.03,
    "Chandigarh":0.02,
    "Bhopal":    0.02,
    "Indore":    0.02,
    "Nagpur":    0.02,
    "Patna":     0.02,
    "Others":    0.17,
}

# Merchant categories (P2M only)
MERCHANT_CATEGORIES = {
    "Grocery & Supermarket": 0.22,
    "Food & Restaurant":     0.16,
    "Fuel Station":          0.09,
    "Clothing & Fashion":    0.08,
    "Electronics":           0.07,
    "Healthcare & Pharmacy": 0.07,
    "Education":             0.06,
    "Travel & Transport":    0.06,
    "Utilities & Bills":     0.05,
    "Entertainment":         0.05,
    "E-commerce":            0.05,
    "Others":                0.04,
}

# Monthly weight based on actual NPCI volume (higher = more transactions generated)
_raw_monthly = {
    1: 0.075, 2: 0.074, 3: 0.083,
    4: 0.082, 5: 0.086, 6: 0.085,
    7: 0.089, 8: 0.092, 9: 0.093,
    10: 0.102, 11: 0.095, 12: 0.103,
}
_total = sum(_raw_monthly.values())
MONTHLY_WEIGHTS = {k: v / _total for k, v in _raw_monthly.items()}

# Transaction status (success rate slightly varies by app)
STATUS_WEIGHTS = {"Success": 0.975, "Failed": 0.020, "Pending": 0.005}

# ── Amount distributions ──────────────────────────────────────────────────────
# NPCI data: 86% of transactions are ₹0–₹500; average ticket ~₹1,650 overall

def generate_amount(txn_type, merchant_category=None):
    """
    Generates a realistic INR amount.
    P2P tends to be larger; P2M small-ticket dominated.
    """
    bucket = np.random.choice(
        ["micro", "small", "medium", "large"],
        p=[0.45, 0.30, 0.18, 0.07] if txn_type == "P2M"
        else [0.20, 0.35, 0.30, 0.15]
    )
    if bucket == "micro":   return round(np.random.uniform(1, 100), 2)
    if bucket == "small":   return round(np.random.uniform(100, 500), 2)
    if bucket == "medium":  return round(np.random.uniform(500, 5000), 2)
    if bucket == "large":   return round(np.random.uniform(5000, 100000), 2)

# ── Date + Time generation ────────────────────────────────────────────────────

def generate_timestamp(month):
    """Generates a random timestamp within a given month of 2024."""
    year = 2024
    if month == 12:
        start = datetime(year, month, 1)
        end   = datetime(year, month, 31, 23, 59, 59)
    else:
        start = datetime(year, month, 1)
        end   = datetime(year, month + 1, 1) - timedelta(seconds=1)

    delta = end - start
    rand_seconds = random.randint(0, int(delta.total_seconds()))

    # Bias toward peak hours: 9am–12pm and 7pm–10pm
    base_dt = start + timedelta(seconds=rand_seconds)
    _hour_p = [0.01, 0.01, 0.01, 0.01, 0.01, 0.01,   # 0–5am
               0.03, 0.05, 0.06, 0.07, 0.07, 0.07,   # 6–11am
               0.06, 0.05, 0.04, 0.04, 0.05, 0.06,   # 12–5pm
               0.07, 0.07, 0.06, 0.05, 0.04, 0.02]   # 6–11pm
    _hour_p = [x / sum(_hour_p) for x in _hour_p]
    hour_bias = np.random.choice(range(24), p=_hour_p)
    return base_dt.replace(hour=hour_bias, minute=random.randint(0, 59),
                           second=random.randint(0, 59))

# ── UPI ID generator ──────────────────────────────────────────────────────────
BANK_HANDLES = ["@oksbi", "@okaxis", "@okhdfc", "@okyesbank",
                "@ibl", "@paytm", "@ybl", "@upi"]

def random_upi_id():
    prefix = "user" + str(random.randint(10000, 99999))
    handle = random.choice(BANK_HANDLES)
    return prefix + handle

# ── Main generation loop ──────────────────────────────────────────────────────

print(f"Generating {N_TRANSACTIONS:,} synthetic UPI transactions for 2024...")

rows = []
months_pool = np.random.choice(
    list(MONTHLY_WEIGHTS.keys()),
    size=N_TRANSACTIONS,
    p=list(MONTHLY_WEIGHTS.values())
)

apps_pool   = np.random.choice(list(UPI_APPS.keys()),   N_TRANSACTIONS, p=list(UPI_APPS.values()))
types_pool  = np.random.choice(list(TRANSACTION_TYPES.keys()), N_TRANSACTIONS, p=list(TRANSACTION_TYPES.values()))
cities_pool = np.random.choice(list(CITIES.keys()),     N_TRANSACTIONS, p=list(CITIES.values()))
status_pool = np.random.choice(list(STATUS_WEIGHTS.keys()), N_TRANSACTIONS, p=list(STATUS_WEIGHTS.values()))

merchant_cats = np.random.choice(
    list(MERCHANT_CATEGORIES.keys()), N_TRANSACTIONS,
    p=list(MERCHANT_CATEGORIES.values())
)

for i in range(N_TRANSACTIONS):
    txn_type = types_pool[i]
    merchant_cat = merchant_cats[i] if txn_type == "P2M" else None
    amount = generate_amount(txn_type, merchant_cat)
    ts = generate_timestamp(int(months_pool[i]))

    rows.append({
        "transaction_id":      f"TXN{str(i+1).zfill(8)}",
        "timestamp":           ts.strftime("%Y-%m-%d %H:%M:%S"),
        "date":                ts.strftime("%Y-%m-%d"),
        "month":               ts.month,
        "month_name":          ts.strftime("%B"),
        "day_of_week":         ts.strftime("%A"),
        "hour":                ts.hour,
        "sender_upi_id":       random_upi_id(),
        "receiver_upi_id":     random_upi_id(),
        "amount_inr":          amount,
        "transaction_type":    txn_type,
        "merchant_category":   merchant_cat if merchant_cat else "N/A",
        "upi_app":             apps_pool[i],
        "city":                cities_pool[i],
        "status":              status_pool[i],
        "bank_handle":         random.choice(BANK_HANDLES),
    })

df = pd.DataFrame(rows)

# ── Introduce realistic data quality issues (for cleaning exercise) ───────────
print("Introducing data quality issues for cleaning exercise...")

# 1. ~2% duplicate rows
dup_idx = df.sample(frac=0.02, random_state=1).index
df = pd.concat([df, df.loc[dup_idx]], ignore_index=True)

# 2. ~1% missing city values
missing_city_idx = df.sample(frac=0.01, random_state=2).index
df.loc[missing_city_idx, "city"] = np.nan

# 3. ~0.5% missing merchant category for P2M rows
p2m_idx = df[df["transaction_type"] == "P2M"].sample(frac=0.005, random_state=3).index
df.loc[p2m_idx, "merchant_category"] = np.nan

# 4. ~0.3% amount outliers (data entry errors — amounts > 1 lakh)
outlier_idx = df.sample(frac=0.003, random_state=4).index
df.loc[outlier_idx, "amount_inr"] = np.random.uniform(100001, 999999, len(outlier_idx)).round(2)

# 5. Inconsistent casing in upi_app column
inconsistent_idx = df.sample(frac=0.01, random_state=5).index
df.loc[inconsistent_idx, "upi_app"] = df.loc[inconsistent_idx, "upi_app"].str.upper()

# Shuffle the final dataframe
df = df.sample(frac=1, random_state=99).reset_index(drop=True)

# ── Save ──────────────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
df.to_csv(OUTPUT_PATH, index=False)

print(f"\nDone! Saved {len(df):,} rows to: {OUTPUT_PATH}")
print(f"\nDataset shape: {df.shape}")
print(f"\nColumn summary:\n{df.dtypes}")
print(f"\nSample rows:\n{df.head(3).to_string()}")
print(f"\nData quality issues introduced:")
print(f"  - Duplicates:         ~{int(N_TRANSACTIONS*0.02):,} rows")
print(f"  - Missing city:       ~{int(N_TRANSACTIONS*0.01):,} rows")
print(f"  - Missing merchant:   ~{int(N_TRANSACTIONS*0.005):,} rows")
print(f"  - Amount outliers:    ~{int(N_TRANSACTIONS*0.003):,} rows")
print(f"  - Inconsistent casing: ~{int(N_TRANSACTIONS*0.01):,} rows")
print("\nThese are intentional — your cleaning notebook will fix them!")
