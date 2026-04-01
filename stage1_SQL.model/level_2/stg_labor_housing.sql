
-- =============================================================================
-- HOUSING
-- =============================================================================




-- Check b25 columns (housing cost burden)
SELECT "COLUMN_NAME" 
FROM INCOME_ADVERSITY_DB.INFORMATION_SCHEMA.COLUMNS
WHERE "TABLE_NAME"   = 'CBG_B25_2019' 
  AND "TABLE_SCHEMA" = 'STAGING'
ORDER BY "ORDINAL_POSITION";



-- Find ONLY the rent burden columns in B25 (B25070 series)
SELECT "COLUMN_NAME" 
FROM INCOME_ADVERSITY_DB.INFORMATION_SCHEMA.COLUMNS
WHERE "TABLE_NAME"   = 'CBG_B25_2019' 
  AND "TABLE_SCHEMA" = 'STAGING'
  AND "COLUMN_NAME" LIKE 'B25070%'
ORDER BY "ORDINAL_POSITION";


-- =============================================================================
-- employment
-- =============================================================================


-- Check b23 columns (employment / unemployment)
SELECT "COLUMN_NAME" 
FROM INCOME_ADVERSITY_DB.INFORMATION_SCHEMA.COLUMNS
WHERE "TABLE_NAME"   = 'CBG_B23_2019' 
  AND "TABLE_SCHEMA" = 'STAGING'
ORDER BY "ORDINAL_POSITION";

-- B23 series prefixes
SELECT DISTINCT LEFT("COLUMN_NAME", 6) AS "series_prefix"
FROM INCOME_ADVERSITY_DB.INFORMATION_SCHEMA.COLUMNS
WHERE "TABLE_NAME"   = 'CBG_B23_2019' 
  AND "TABLE_SCHEMA" = 'STAGING'
  AND "COLUMN_NAME"  != 'CENSUS_BLOCK_GROUP'
ORDER BY "series_prefix";


-- Confirm B23025 columns (labor force / unemployment)
SELECT "COLUMN_NAME" 
FROM INCOME_ADVERSITY_DB.INFORMATION_SCHEMA.COLUMNS
WHERE "TABLE_NAME"   = 'CBG_B23_2019' 
  AND "TABLE_SCHEMA" = 'STAGING'
  AND "COLUMN_NAME" LIKE 'B23025%'
ORDER BY "ORDINAL_POSITION";


----------------
-- create STG_LABOR_HOUSING


--------------------
-- do SELECT 1st combine labor/employment b23 + housing b25

SELECT
    b23."CENSUS_BLOCK_GROUP",
    2019                              AS "acs_year",

    -- Labor force and unemployment (B23025)
    "B23025e1"                        AS "pop_16_and_over",
    "B23025e2"                        AS "labor_force",
    "B23025e5"                        AS "unemployed",
    ROUND(
        "B23025e5" / NULLIF("B23025e2", 0) * 100
    , 2)                              AS "unemployment_rate_pct",

    -- Housing cost burden (B25070)
    "B25070e1"                        AS "renter_hh_total",
    COALESCE("B25070e9",  0)
  + COALESCE("B25070e10", 0)          AS "rent_burdened_30_plus",
    COALESCE("B25070e10", 0)          AS "rent_severely_burdened",
    ROUND(
        (COALESCE("B25070e9", 0) + COALESCE("B25070e10", 0))
        / NULLIF("B25070e1", 0) * 100
    , 2)                              AS "rent_burden_rate_pct"

FROM INCOME_ADVERSITY_DB.STAGING.CBG_B23_2019  b23
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_B25_2019  b25
    ON b23."CENSUS_BLOCK_GROUP" = b25."CENSUS_BLOCK_GROUP"
WHERE "B23025e1" > 0
LIMIT 10;



-- now do CREATE OR REPLACE VIEW 

CREATE OR REPLACE VIEW INCOME_ADVERSITY_DB.STAGING.STG_LABOR_HOUSING AS

-- 2019
SELECT
    b23."CENSUS_BLOCK_GROUP",
    2019                              AS "acs_year",
    "B23025e1"                        AS "pop_16_and_over",
    "B23025e2"                        AS "labor_force",
    "B23025e5"                        AS "unemployed",
    ROUND(
        "B23025e5" / NULLIF("B23025e2", 0) * 100
    , 2)                              AS "unemployment_rate_pct",
    "B25070e1"                        AS "renter_hh_total",
    COALESCE("B25070e9",  0)
  + COALESCE("B25070e10", 0)          AS "rent_burdened_30_plus",
    COALESCE("B25070e10", 0)          AS "rent_severely_burdened",
    ROUND(
        (COALESCE("B25070e9", 0) + COALESCE("B25070e10", 0))
        / NULLIF("B25070e1", 0) * 100
    , 2)                              AS "rent_burden_rate_pct"

FROM INCOME_ADVERSITY_DB.STAGING.CBG_B23_2019  b23
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_B25_2019  b25
    ON b23."CENSUS_BLOCK_GROUP" = b25."CENSUS_BLOCK_GROUP"
WHERE "B23025e1" > 0

UNION ALL

-- 2020
SELECT
    b23."CENSUS_BLOCK_GROUP",
    2020                              AS "acs_year",
    "B23025e1"                        AS "pop_16_and_over",
    "B23025e2"                        AS "labor_force",
    "B23025e5"                        AS "unemployed",
    ROUND(
        "B23025e5" / NULLIF("B23025e2", 0) * 100
    , 2)                              AS "unemployment_rate_pct",
    "B25070e1"                        AS "renter_hh_total",
    COALESCE("B25070e9",  0)
  + COALESCE("B25070e10", 0)          AS "rent_burdened_30_plus",
    COALESCE("B25070e10", 0)          AS "rent_severely_burdened",
    ROUND(
        (COALESCE("B25070e9", 0) + COALESCE("B25070e10", 0))
        / NULLIF("B25070e1", 0) * 100
    , 2)                              AS "rent_burden_rate_pct"

FROM INCOME_ADVERSITY_DB.STAGING.CBG_B23_2020  b23
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_B25_2020  b25
    ON b23."CENSUS_BLOCK_GROUP" = b25."CENSUS_BLOCK_GROUP"
WHERE "B23025e1" > 0;



-- =============================================================================
-- Verification
-- =============================================================================

-- Labor + housing averages
SELECT "acs_year",
    ROUND(AVG("unemployment_rate_pct"), 2) AS "avg_unemployment",
    ROUND(AVG("rent_burden_rate_pct"),  2) AS "avg_rent_burden"
FROM INCOME_ADVERSITY_DB.STAGING.STG_LABOR_HOUSING
GROUP BY "acs_year"
ORDER BY "acs_year";
