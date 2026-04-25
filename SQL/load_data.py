"""
load_data.py
------------
Loads all three CSVs into your PostgreSQL database using psycopg2.

Prerequisites:
  - PostgreSQL running locally
  - Database 'upi_analysis' already created
  - schema.sql already executed
  - pip install psycopg2-binary pandas python-dotenv

How to create the database (run once in psql):
    CREATE DATABASE upi_analysis;

Then run this script:
    python sql/load_data.py
"""

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import os
import time

# ── Connection config ─────────────────────────────────────────────────────────
# Edit these to match your local PostgreSQL setup
DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "dbname":   "upi_analysis",
    "user":     "postgres",       # Change to your PostgreSQL username
    "password": "sql123",       # Change to your PostgreSQL password
}

# ── File paths ────────────────────────────────────────────────────────────────
BASE_DIR     = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRANSACTIONS = os.path.join(BASE_DIR, "data", "processed", "transactions_clean.csv")
NPCI         = os.path.join(BASE_DIR, "data", "raw",       "npci_monthly_2024.csv")
SUMMARY      = os.path.join(BASE_DIR, "data", "processed", "monthly_summary.csv")


def connect():
    """Create and return a database connection."""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        print("✓ Connected to PostgreSQL")
        return conn
    except psycopg2.OperationalError as e:
        print(f"✗ Connection failed: {e}")
        print("\nTroubleshooting:")
        print("  1. Is PostgreSQL running? (check Services or run: pg_ctl status)")
        print("  2. Is the database created? Run: CREATE DATABASE upi_analysis;")
        print("  3. Are the credentials correct in DB_CONFIG above?")
        raise


def load_table(conn, df, table_name, column_map=None):
    """
    Generic loader: inserts a DataFrame into a PostgreSQL table
    using execute_values for fast batch inserts.

    column_map: dict to rename DataFrame columns to match SQL columns
                e.g. {'success_rate_%': 'success_rate_pct'}
    """
    if column_map:
        df = df.rename(columns=column_map)

    # Replace NaN with None so psycopg2 inserts NULL correctly
    df = df.where(pd.notnull(df), None)

    cols = list(df.columns)
    col_str = ", ".join(cols)
    df = df.drop_duplicates(subset=None)
    rows = [tuple(row) for row in df.itertuples(index=False, name=None)]
    cursor = conn.cursor()

    # Clear existing data before re-loading (idempotent)
    cursor.execute(f"DELETE FROM {table_name};")
    cursor.execute("COMMIT;")
    query = f"INSERT INTO {table_name} ({col_str}) VALUES %s"

    start = time.time()
    execute_values(cursor, query, rows, page_size=1000)
    conn.commit()
    elapsed = time.time() - start

    count = cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
    count = cursor.fetchone()[0]
    cursor.close()

    print(f"  ✓ {table_name:<20} {count:>7,} rows loaded in {elapsed:.1f}s")
    return count


def verify(conn):
    """Run a quick sanity check across all three tables."""
    print("\n── Verification queries ─────────────────────────────────")
    cursor = conn.cursor()

    checks = [
        ("Row counts",
         """SELECT 'transactions'   AS tbl, COUNT(*) FROM transactions
            UNION ALL
            SELECT 'monthly_npci',           COUNT(*) FROM monthly_npci
            UNION ALL
            SELECT 'monthly_summary',        COUNT(*) FROM monthly_summary"""),

        ("App distribution (transactions)",
         """SELECT upi_app, COUNT(*) AS txn_count,
                   ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS share_pct
            FROM transactions
            GROUP BY upi_app
            ORDER BY txn_count DESC"""),

        ("Monthly NPCI: Dec 2024 record",
         """SELECT month_name, volume_million, value_crore_inr, active_banks
            FROM monthly_npci
            WHERE month = 12"""),

        ("Null check (transactions)",
         """SELECT COUNT(*) AS nulls_in_city
            FROM transactions
            WHERE city IS NULL"""),
    ]

    for title, sql in checks:
        print(f"\n  {title}:")
        cursor.execute(sql)
        rows = cursor.fetchall()
        col_names = [desc[0] for desc in cursor.description]
        print("  " + " | ".join(f"{c:<25}" for c in col_names))
        print("  " + "-" * (28 * len(col_names)))
        for row in rows:
            print("  " + " | ".join(f"{str(v):<25}" for v in row))

    cursor.close()


def main():
    print("=" * 55)
    print("UPI Analysis — PostgreSQL Data Loader")
    print("=" * 55)

    conn = connect()

    print("\nLoading tables...")

    # 1. monthly_npci (real NPCI data — load first, it's the smallest)
    # 1. monthly_npci
    npci_df = pd.read_csv(NPCI)
    npci_df = npci_df.rename(columns={"month": "month_name", "month_num": "month"})
    npci_df = npci_df[["month", "year", "month_name", "volume_million",
                    "value_crore_inr", "p2p_volume_million", "p2m_volume_million",
                    "p2p_value_crore", "p2m_value_crore", "active_banks"]]
    load_table(conn, npci_df, "monthly_npci")

    # 2. monthly_summary (rename % columns to match SQL schema)
    summary_df = pd.read_csv(SUMMARY)
    load_table(conn, summary_df, "monthly_summary", column_map={
        "success_rate_%":   "success_rate_pct",
        "p2p_share_%":      "p2p_share_pct",
        "p2m_share_%":      "p2m_share_pct",
        "mom_txn_growth_%": "mom_txn_growth_pct",
    })

    # 3. transactions (largest table — ~50K rows)
    print("\n  Loading transactions (~50,000 rows, may take a few seconds)...")
    txn_df = pd.read_csv(TRANSACTIONS)

    # Drop redundant columns that are already derivable or stored in other tables
    txn_df = txn_df.drop(columns=["month_num"], errors="ignore")

    # Convert boolean column — psycopg2 handles Python bool directly
    txn_df["is_outlier"] = txn_df["is_outlier"].astype(bool)

    load_table(conn, txn_df, "transactions")

    # Verify everything loaded correctly
    verify(conn)

    conn.close()
    print("\n✓ All done. Database is ready for queries.")
    print("\nConnect in psql:")
    print(f"  psql -U {DB_CONFIG['user']} -d {DB_CONFIG['dbname']}")


if __name__ == "__main__":
    main()
