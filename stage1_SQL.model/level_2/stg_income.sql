/// LAYER 1B: STAGING VIEW (clean + label columns)



-- =============================================================================
-- SECTION 0: Set working context to the shared marketplace database
-- =============================================================================

USE DATABASE INCOME_ADVERSITY_DB;
USE SCHEMA STAGING;


-- Verification: confirm schemas were created successfully
SHOW SCHEMAS IN DATABASE INCOME_ADVERSITY_DB;
SHOW TABLES IN DATABASE INCOME_ADVERSITY_DB;

---------------
-- testing
SELECT * 
FROM INCOME_ADVERSITY_DB.STAGING.CBG_B19_2019 
LIMIT 5;


-- =============================================================================
-- stg_income_brackets — standardizes the raw B19 columns into named income tiers:
-- =============================================================================

CREATE OR REPLACE VIEW INCOME_ADVERSITY_DB.STAGING.STG_INCOME_BRACKETS AS
-- 2019
SELECT
    "CENSUS_BLOCK_GROUP",
    2019                          AS "acs_year",
    "B19013e1"                    AS "median_hh_income",
    "B19001e1"                    AS "hh_total",

    COALESCE("B19001e2", 0)
  + COALESCE("B19001e3", 0)
  + COALESCE("B19001e4", 0)
  + COALESCE("B19001e5", 0)      AS "hh_under_25k",

    COALESCE("B19001e6",  0)
  + COALESCE("B19001e7",  0)
  + COALESCE("B19001e8",  0)
  + COALESCE("B19001e9",  0)
  + COALESCE("B19001e10", 0)     AS "hh_25k_to_50k",

    COALESCE("B19001e11", 0)
  + COALESCE("B19001e12", 0)
  + COALESCE("B19001e13", 0)     AS "hh_50k_to_100k",

    COALESCE("B19001e14", 0)
  + COALESCE("B19001e15", 0)
  + COALESCE("B19001e16", 0)
  + COALESCE("B19001e17", 0)     AS "hh_over_100k",

    CASE
        WHEN "B19013e1" <  25000 THEN 'Tier 1: Under $25k'
        WHEN "B19013e1" <  50000 THEN 'Tier 2: $25k-$50k'
        WHEN "B19013e1" < 100000 THEN 'Tier 3: $50k-$100k'
        ELSE                          'Tier 4: $100k+'
    END                           AS "income_tier"

FROM INCOME_ADVERSITY_DB.STAGING.CBG_B19_2019
WHERE "B19001e1" > 0

UNION ALL

-- 2020
SELECT
    "CENSUS_BLOCK_GROUP",
    2020                          AS "acs_year",
    "B19013e1"                    AS "median_hh_income",
    "B19001e1"                    AS "hh_total",

    COALESCE("B19001e2", 0)
  + COALESCE("B19001e3", 0)
  + COALESCE("B19001e4", 0)
  + COALESCE("B19001e5", 0)      AS "hh_under_25k",

    COALESCE("B19001e6",  0)
  + COALESCE("B19001e7",  0)
  + COALESCE("B19001e8",  0)
  + COALESCE("B19001e9",  0)
  + COALESCE("B19001e10", 0)     AS "hh_25k_to_50k",

    COALESCE("B19001e11", 0)
  + COALESCE("B19001e12", 0)
  + COALESCE("B19001e13", 0)     AS "hh_50k_to_100k",

    COALESCE("B19001e14", 0)
  + COALESCE("B19001e15", 0)
  + COALESCE("B19001e16", 0)
  + COALESCE("B19001e17", 0)     AS "hh_over_100k",

    CASE
        WHEN "B19013e1" <  25000 THEN 'Tier 1: Under $25k'
        WHEN "B19013e1" <  50000 THEN 'Tier 2: $25k-$50k'
        WHEN "B19013e1" < 100000 THEN 'Tier 3: $50k-$100k'
        ELSE                          'Tier 4: $100k+'
    END                           AS "income_tier"

FROM INCOME_ADVERSITY_DB.STAGING.CBG_B19_2020
WHERE "B19001e1" > 0;

---------
-- Verification:

-- Should be ~440k rows
SELECT COUNT(*) 
FROM INCOME_ADVERSITY_DB.STAGING.STG_INCOME_BRACKETS;

-- Should show 4 tiers × 2 years
SELECT 
    "income_tier",
    "acs_year",
    COUNT(*) AS "cbg_count"
FROM INCOME_ADVERSITY_DB.STAGING.STG_INCOME_BRACKETS
GROUP BY "income_tier", "acs_year"
ORDER BY "acs_year", "income_tier";







-- ── STG_INCOME_BRACKETS ──────────────────────────────────────────
-- 1. Row count — expect ~440k
SELECT COUNT(*) AS "total_rows"
FROM INCOME_ADVERSITY_DB.STAGING.STG_INCOME_BRACKETS;

-- 2. Distribution — expect 4 tiers × 2 years = 8 rows
SELECT "income_tier", "acs_year", COUNT(*) AS "cbg_count"
FROM INCOME_ADVERSITY_DB.STAGING.STG_INCOME_BRACKETS
GROUP BY "income_tier", "acs_year"
ORDER BY "acs_year", "income_tier";

-- 3. Sanity check — no nulls in key columns
SELECT COUNT(*) AS "null_median_income"
FROM INCOME_ADVERSITY_DB.STAGING.STG_INCOME_BRACKETS
WHERE "median_hh_income" IS NULL;



