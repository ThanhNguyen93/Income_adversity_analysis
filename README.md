# Income Adversity Analysis — Project README

> **Research question:** How are people adversely affected due to their income brackets?

> **Data source:** SafeGraph US Open Census Data (Snowflake Marketplace — free listing)
- Data link: https://app.snowflake.com/marketplace/listing/GZSNZ2UNN0/safegraph-us-open-census-data-neighborhood-insights-free-dataset?search=housing&pricing=free

> **Stack:** Snowflake · Python · scikit-learn 

---

## Project Overview

This project is structured in three sequential stages:

| Stage | Name | Output |
|-------|------|--------|
| 1 | SQL Data Model | Snowflake views + mart tables |


---

## Repository Structure

```
income_adversity/
│
├── README.md                        ← this file
│
├── stage_1_sql/ (need update)
│   ├── README_stage1.md
│   ├── 01_staging/
│   │   ├── stg_income_brackets.sql
│   │   ├── stg_labor_housing.sql
│   │   └── stg_health_geo.sql
│   ├── 02_marts/
│   │   ├── mart_income_adversity.sql
│   │   ├── mart_labor_by_bracket.sql
│   │   ├── mart_housing_by_bracket.sql
│   │   ├── mart_health_by_bracket.sql
│   │   └── mart_national_summary.sql
│   └── 03_validation/
│       └── qa_checks.sql
│
├── data/
│   └── sample_export.csv            ← optional local dev sample
│
└── requirements.txt
```

---

## Stage 1 — SQL Data Model

### Goal
Transform raw ACS Census Block Group (CBG) data from the SafeGraph Snowflake listing into clean, analysis-ready mart tables.

### ACS Tables Used

| Snowflake Table | Subject | Key Columns |
|----------------|---------|-------------|
| `cbg_b19` | Income distribution | `B19001e2–e17`, `B19013e1` (median), `B19083e1` (Gini) |
| `cbg_b17` | Poverty status | `B17001e1`, `B17001e2` |
| `cbg_b23` | Employment / labor | `B23025e2` (labor force), `B23025e5` (unemployed) |
| `cbg_b25` | Housing cost burden | `B25070e9–e10` (rent >30–50%), `B25091e9–e10` (owners) |
| `cbg_b27` | Health insurance | `B27001e*` (uninsured by age/sex) |
| `cbg_fips_codes` | Geography reference | `state`, `county`, `state_fips`, `county_fips` |
| `cbg_geographic_data` | Lat/long | `latitude`, `longitude` |

### Layer Architecture

```
Raw ACS tables (cbg_b*)
        ↓
Staging views  (stg_*)        ← clean columns, rename, compute rates
        ↓
Analytical marts (mart_*)     ← join all topics, assign income tier
        ↓
mart_national_summary         ← rolled-up KPIs by income bracket
```

### Key mart columns (mart_income_adversity)

| Column | Description |
|--------|-------------|
| `census_block_group` | 12-digit FIPS — primary key |
| `income_tier` | Tier 1–4 based on median HH income |
| `median_hh_income` | Median household income ($) |
| `unemployment_rate_pct` | % of labor force unemployed |
| `rent_burden_rate_pct` | % of renters paying >30% income on rent |
| `uninsured_rate_pct` | % of working-age pop without insurance |
| `adversity_score` | Weighted composite index (0–100) |

### Report: 
- Please read stage 1 findings here: https://thanhnguyen93.github.io/Income_adversity_analysis/stage1_SQL.model/Report_Stage1.html
---

### Environment variables (create a .env file)

```
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_WAREHOUSE=your_warehouse
SNOWFLAKE_DATABASE=SAFEGRAPH_SHARE
SNOWFLAKE_SCHEMA=PUBLIC
```

---

## Requirements

```
# requirements.txt

# Snowflake
snowflake-connector-python>=3.0.0
snowflake-sqlalchemy>=1.5.0

# Data
pandas>=2.0.0
numpy>=1.24.0

# ML
scikit-learn>=1.3.0
imbalanced-learn>=0.11.0    # SMOTE
shap>=0.44.0
joblib>=1.3.0

# Dashboard
dash>=2.14.0
dash-bootstrap-components>=1.5.0
plotly>=5.18.0

# Utilities
python-dotenv>=1.0.0
matplotlib>=3.7.0
seaborn>=0.12.0
```

Install with:
```bash
pip install -r requirements.txt
```

---

## Data Lineage Summary

```
Snowflake Marketplace
  └── SafeGraph Open Census (free)
        ├── cbg_b19  ─────────────────────────────────────────────┐
        ├── cbg_b17  ──────── stg_income_brackets                 │
        ├── cbg_b23  ──────── stg_labor_housing  ──── mart_income_adversity
        ├── cbg_b25  ──────── stg_health_geo          │
        ├── cbg_b27  ─────────────────────────────────┘
        ├── cbg_fips_codes                              │
        └── cbg_geographic_data                         │
                                                        ↓
                                             Binary classifier
                                             (high / low risk)
                                                        │
                                                        ↓
                                             Dash dashboard
                                          (national + CBG views)
```

---

## Notes & Limitations

- ACS data covers 2016–2020. Results reflect pre-pandemic and early-pandemic conditions.
- Census Block Groups vary in population (600–3,000 households). Very small CBGs may produce unreliable rate estimates — filter with `WHERE hh_total > 50`.
- The adversity score is a constructed index, not an official Census measure. Weights are equal across three indicators; adjust in `mart_national_summary.sql` if needed.
- The classifier predicts risk based on structural features. It is descriptive, not prescriptive — it shows where adversity concentrates, not why policies caused it.
- All data is licensed under CC0 (public domain) per SafeGraph's terms.

---

*Project initialized March 2026*
