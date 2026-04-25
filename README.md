# UPI Transaction Trends India — 2024 Analysis

An end-to-end data analytics project analysing India's UPI payment ecosystem in 2024,
covering data ingestion, Python-based cleaning, SQL analysis, and a Power BI dashboard.

---

## Project Structure

```
upi-analysis-2024/
├── data/
│   ├── raw/
│   │   ├── npci_monthly_2024.csv       ← Real NPCI aggregate data
│   │   └── upi_transactions_2024.csv   ← Synthetic transaction-level data (generated)
│   └── processed/
│       ├── transactions_clean.csv
│       └── monthly_summary.csv
├── notebooks/
│   ├── generate_synthetic_data.py      ← Run this first
│   ├── 01_data_load_validation.ipynb
│   ├── 02_data_cleaning.ipynb
│   └── 03_eda_visualisation.ipynb
├── sql/
│   ├── schema.sql                      ← PostgreSQL table definitions
│   └── queries.sql                     ← 15 interview-ready SQL questions
├── dashboard/
│   ├── upi_dashboard.pbix
│   └── screenshots/
├── excel/
│   └── upi_summary_report.xlsx
├── requirements.txt
└── README.md
```

---

## Data Sources

| Dataset | Source | Type |
|---|---|---|
| Monthly UPI Volume & Value 2024 | [NPCI Official Statistics](https://www.npci.org.in/product/upi/product-statistics) | Real |
| Transaction-level data | Synthetically generated (calibrated to NPCI 2024 data) | Synthetic |

> The synthetic dataset is generated using `notebooks/generate_synthetic_data.py`.
> Distributions for app market share, city-wise usage, transaction types, and
> amount buckets are calibrated to match real 2024 NPCI aggregate statistics.

---

## Tech Stack

| Layer | Tool |
|---|---|
| Data generation & cleaning | Python (pandas, numpy) |
| Database | PostgreSQL |
| Exploratory Analysis | Jupyter, matplotlib, seaborn |
| Dashboard | Power BI |
| Excel summary | openpyxl / Excel |

---

## How to Run

```bash
# 1. Clone the repo
git clone https://github.com/yourusername/upi-analysis-2024.git
cd upi-analysis-2024

# 2. Set up environment
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 3. Generate the synthetic transaction dataset
python notebooks/generate_synthetic_data.py

# 4. Launch Jupyter
jupyter lab

# 5. Run notebooks in order: 01 → 02 → 03
```

---

## Key Insights

*(To be filled in after analysis)*

- UPI crossed ₹23 lakh crore in transaction value in December 2024
- PhonePe maintained ~48% market share throughout the year
- P2M transactions grew faster than P2P — driven by small-ticket retail
- Peak transaction hours: 9am–12pm and 7pm–10pm

---

## About

Built as a portfolio project to demonstrate end-to-end data analytics skills
including data engineering, SQL, Python EDA, and business dashboarding.

**Author:** Saarthak  
**Dataset period:** January–December 2024
