-- =============================================================================
-- Layer 3 — mart_income_adversity
-- =============================================================================


-- Create the marts schema (only need to do this once)
CREATE SCHEMA IF NOT EXISTS INCOME_ADVERSITY_DB.MARTS;

-- Master fact table — joins all 3 staging views together
CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.MARTS.MART_INCOME_ADVERSITY AS

SELECT
    -- ── Identity ─────────────────────────────────────────────────
    i."CENSUS_BLOCK_GROUP",
    i."acs_year",
    h."state",
    h."county",
    h."latitude",
    h."longitude",

    -- ── Income ───────────────────────────────────────────────────
    i."median_hh_income",
    i."income_tier",
    i."hh_total",
    i."hh_under_25k",
    i."hh_25k_to_50k",
    i."hh_50k_to_100k",
    i."hh_over_100k",

    -- ── Labor ────────────────────────────────────────────────────
    l."labor_force",
    l."unemployed",
    l."unemployment_rate_pct",

    -- ── Housing ──────────────────────────────────────────────────
    l."renter_hh_total",
    l."rent_burdened_30_plus",
    l."rent_severely_burdened",
    l."rent_burden_rate_pct",

    -- ── Health insurance ─────────────────────────────────────────
    h."uninsured_working_age",
    h."uninsured_rate_pct",

    -- ── Composite adversity score (0–100) ────────────────────────
    -- Weights: unemployment 33%, rent burden 33%, uninsured 34%
    -- Each divided by a realistic max to normalize to 0–100
    ROUND(
        (COALESCE(l."unemployment_rate_pct", 0) / 30  * 100 * 0.33)
      + (COALESCE(l."rent_burden_rate_pct",  0) / 80  * 100 * 0.33)
      + (COALESCE(h."uninsured_rate_pct",    0) / 50  * 100 * 0.34)
    , 1)                              AS "adversity_score",

    -- ── Binary risk label (for classifier in Stage 2) ────────────
    CASE
        WHEN ROUND(
            (COALESCE(l."unemployment_rate_pct", 0) / 30  * 100 * 0.33)
          + (COALESCE(l."rent_burden_rate_pct",  0) / 80  * 100 * 0.33)
          + (COALESCE(h."uninsured_rate_pct",    0) / 50  * 100 * 0.34)
        , 1) >= 50
        THEN 'High Risk'
        ELSE 'Low Risk'
    END                               AS "risk_label"

FROM INCOME_ADVERSITY_DB.STAGING.STG_INCOME_BRACKETS  i

JOIN INCOME_ADVERSITY_DB.STAGING.STG_LABOR_HOUSING     l
    ON  i."CENSUS_BLOCK_GROUP" = l."CENSUS_BLOCK_GROUP"
    AND i."acs_year"           = l."acs_year"

JOIN INCOME_ADVERSITY_DB.STAGING.STG_HEALTH_GEO        h
    ON  i."CENSUS_BLOCK_GROUP" = h."CENSUS_BLOCK_GROUP"
    AND i."acs_year"           = h."acs_year"

-- Exclude CBGs with no usable income data
WHERE i."median_hh_income" IS NOT NULL
  AND i."hh_total" > 50;


-- =============================================================================
-- Testing
-- =============================================================================

  -- Row count
SELECT COUNT(*) AS "total_rows"
FROM INCOME_ADVERSITY_DB.MARTS.MART_INCOME_ADVERSITY;

-- =============================================================================


-- Risk label split — how many high vs low risk CBGs
SELECT "risk_label", "acs_year", COUNT(*) AS "cbg_count"
FROM INCOME_ADVERSITY_DB.MARTS.MART_INCOME_ADVERSITY
GROUP BY "risk_label", "acs_year"
ORDER BY "acs_year", "risk_label";

-- =============================================================================


-- Preview 5 rows — confirm all columns populated
SELECT * 
FROM INCOME_ADVERSITY_DB.MARTS.MART_INCOME_ADVERSITY 
LIMIT 5;


