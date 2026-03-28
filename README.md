# Income Adversity Analysis — Project README

> **Research question:** How are people adversely affected due to their income brackets?

> **Data source:** SafeGraph US Open Census Data (Snowflake Marketplace — free listing)
- Data link: https://app.snowflake.com/marketplace/listing/GZSNZ2UNN0/safegraph-us-open-census-data-neighborhood-insights-free-dataset?search=housing&pricing=free

> **Stack:** Snowflake · Python · scikit-learn · Dash

---

## Project Overview

This project is structured in three sequential stages:

| Stage | Name | Output |
|-------|------|--------|
| 1 | SQL Data Model | Snowflake views + mart tables |
| 2 | Classification Model | Binary risk classifier (high / low adversity) |
| 3 | Interactive Dashboard | Dash app with national and CBG-level visuals |

---

## Repository Structure

```
income_adversity/
│
├── README.md                        ← this file
│
├── stage_1_sql/
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
├── stage_2_model/
│   ├── README_stage2.md
│   ├── notebooks/
│   │   ├── 01_eda.ipynb
│   │   ├── 02_feature_engineering.ipynb
│   │   ├── 03_train_classifier.ipynb
│   │   └── 04_evaluate_explain.ipynb
│   ├── src/
│   │   ├── extract.py               ← Snowflake → DataFrame
│   │   ├── features.py              ← feature engineering pipeline
│   │   ├── train.py                 ← model training + cross-validation
│   │   └── evaluate.py              ← SHAP, confusion matrix, metrics
│   └── models/
│       └── rf_binary_classifier.joblib   ← saved model (generated)
│
├── stage_3_dashboard/
│   ├── README_stage3.md
│   ├── app.py                       ← Dash entry point
│   ├── pages/
│   │   ├── overview.py              ← national KPI cards
│   │   ├── income_explorer.py       ← adversity by income tier charts
│   │   ├── risk_map.py              ← choropleth map by county
│   │   └── model_insights.py        ← classifier results + SHAP
│   ├── components/
│   │   ├── kpi_card.py
│   │   ├── bar_chart.py
│   │   └── scatter_plot.py
│   └── assets/
│       └── style.css
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

### How to run

```sql
-- Step 1: Get the listing
-- Snowflake UI → Marketplace → search "SafeGraph Open Census" → Get (free)

-- Step 2: Run staging views (order matters)
-- Execute files in stage_1_sql/01_staging/ in any order

-- Step 3: Run marts
-- Execute files in stage_1_sql/02_marts/ in order:
--   mart_income_adversity.sql first (others depend on it)

-- Step 4: Validate
-- Execute stage_1_sql/03_validation/qa_checks.sql
-- All checks should return 0 rows
```

---

## Stage 2 — Binary Classification Model

### Goal
Train a binary classifier that labels each Census Block Group as **high adversity** or **low adversity**, based on its income profile, then explain which income-related features drive the prediction.

### Target Variable Definition

```
HIGH ADVERSITY (1) = CBG where adversity_score >= 50
LOW ADVERSITY  (0) = CBG where adversity_score <  50

adversity_score is a weighted composite of:
  - unemployment_rate_pct   (weight 0.33)
  - rent_burden_rate_pct    (weight 0.33)
  - uninsured_rate_pct      (weight 0.34)
```

### Feature Set

| Feature | Source | Type |
|---------|--------|------|
| `log_median_income` | B19 | Continuous |
| `gini_index` | B19 | Continuous |
| `pct_under_25k` | B19 | Continuous |
| `pct_25k_to_50k` | B19 | Continuous |
| `pct_over_100k` | B19 | Continuous |
| `unemployment_rate_pct` | B23 | Continuous |
| `rent_burden_rate_pct` | B25 | Continuous |
| `uninsured_rate_pct` | B27 | Continuous |
| `state` (encoded) | FIPS | Categorical |

### Model Pipeline

```
Raw mart data
     ↓
Feature engineering   (log transforms, ratio features, state dummies)
     ↓
Train/test split      (80/20, stratified on target)
     ↓
Class balancing       (SMOTE or class_weight='balanced')
     ↓
Random Forest         (primary) + Logistic Regression (baseline)
     ↓
Cross-validation      (5-fold, scoring: ROC-AUC, F1)
     ↓
SHAP explainability   (feature importance per prediction)
     ↓
Save model            (joblib → models/rf_binary_classifier.joblib)
```

### Expected metrics (rough targets)

| Metric | Target |
|--------|--------|
| ROC-AUC | > 0.82 |
| F1 (macro) | > 0.75 |
| Precision (high risk) | > 0.78 |
| Recall (high risk) | > 0.72 |

### How to run

```bash
# Install dependencies
pip install -r requirements.txt

# Run in order (or use notebooks for step-by-step)
python stage_2_model/src/extract.py      # pulls from Snowflake → data/
python stage_2_model/src/features.py     # engineers features → data/features.csv
python stage_2_model/src/train.py        # trains + saves model
python stage_2_model/src/evaluate.py     # prints metrics, generates SHAP plot
```

---

## Stage 3 — Interactive Dash Dashboard

### Goal
A multi-page Dash app that lets users explore how income brackets correlate with adverse outcomes nationally, and inspect the classifier's predictions at the CBG level.

### Pages

#### Page 1 — National overview (`/`)
- 4 KPI cards: avg unemployment / rent burden / uninsured rate / adversity score
- Dropdown to filter by income tier
- Bar chart: adversity score by income tier

#### Page 2 — Income explorer (`/explorer`)
- Side-by-side bar charts: unemployment, rent burden, uninsured — all by income tier
- Scatter plot: median income vs adversity score (one dot per state)
- Table: top 20 most adversely affected counties

#### Page 3 — Risk map (`/map`)
- Plotly choropleth (county level) colored by adversity score
- Click a county → drill-down sidebar shows CBG breakdown
- Filter by state dropdown

#### Page 4 — Model insights (`/model`)
- Confusion matrix heatmap
- ROC curve
- SHAP summary bar chart (global feature importance)
- Single CBG predictor: input income profile → get risk label + confidence

### How to run

```bash
# From repo root
python stage_3_dashboard/app.py

# App runs at http://localhost:8050
```

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
