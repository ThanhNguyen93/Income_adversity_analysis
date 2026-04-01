
-- =============================================================================
-- Health insurance
-- =============================================================================


-- Check b27 columns (health insurance)
SELECT "COLUMN_NAME" FROM INCOME_ADVERSITY_DB.INFORMATION_SCHEMA.COLUMNS
WHERE "TABLE_NAME" = 'CBG_B27_2019' AND "TABLE_SCHEMA" = 'STAGING'
ORDER BY "ORDINAL_POSITION";


-- See all unique B27 series prefixes available
SELECT DISTINCT LEFT("COLUMN_NAME", 6) AS "series_prefix"
FROM INCOME_ADVERSITY_DB.INFORMATION_SCHEMA.COLUMNS
WHERE "TABLE_NAME"   = 'CBG_B27_2019' 
  AND "TABLE_SCHEMA" = 'STAGING'
  AND "COLUMN_NAME" != 'CENSUS_BLOCK_GROUP'
ORDER BY "series_prefix";


-- Confirm B27010 columns (health insurance)
SELECT "COLUMN_NAME" 
FROM INCOME_ADVERSITY_DB.INFORMATION_SCHEMA.COLUMNS
WHERE "TABLE_NAME"   = 'CBG_B27_2019' 
  AND "TABLE_SCHEMA" = 'STAGING'
  AND "COLUMN_NAME" LIKE 'B27010%'
ORDER BY "ORDINAL_POSITION";

-- =============================================================================
-- stg_health_geo — test SELECT first
-- =============================================================================

SELECT
    b27."CENSUS_BLOCK_GROUP",
    2019                              AS "acs_year",

    -- Health insurance (B27010)
    -- e1 = total population universe
    -- e17 = uninsured males 19-64, e33 = uninsured females 19-64
    "B27010e1"                        AS "insurance_universe",
    COALESCE("B27010e17", 0)
  + COALESCE("B27010e33", 0)          AS "uninsured_working_age",
    ROUND(
        (COALESCE("B27010e17", 0) + COALESCE("B27010e33", 0))
        / NULLIF("B27010e1", 0) * 100
    , 2)                              AS "uninsured_rate_pct",

    -- Geography
    f."STATE"                         AS "state",
    f."COUNTY"                        AS "county",
    g."LATITUDE"                      AS "latitude",
    g."LONGITUDE"                     AS "longitude"

FROM INCOME_ADVERSITY_DB.STAGING.CBG_B27_2019        b27
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_FIPS_CODES      f
    ON LEFT(b27."CENSUS_BLOCK_GROUP", 5) = LPAD(f."STATE_FIPS", 2, '0') || f."COUNTY_FIPS"
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_GEOGRAPHIC_DATA g
    ON b27."CENSUS_BLOCK_GROUP" = g."CENSUS_BLOCK_GROUP"
WHERE "B27010e1" > 0
LIMIT 10;


-- =============================================================================
-- create "STG_HEALTH_GEO"
-- =============================================================================
CREATE OR REPLACE VIEW INCOME_ADVERSITY_DB.STAGING.STG_HEALTH_GEO AS

-- 2019
SELECT
    b27."CENSUS_BLOCK_GROUP",
    2019                              AS "acs_year",
    "B27010e1"                        AS "insurance_universe",
    COALESCE("B27010e17", 0)
  + COALESCE("B27010e33", 0)          AS "uninsured_working_age",
    ROUND(
        (COALESCE("B27010e17", 0) + COALESCE("B27010e33", 0))
        / NULLIF("B27010e1", 0) * 100
    , 2)                              AS "uninsured_rate_pct",
    f."STATE"                         AS "state",
    f."COUNTY"                        AS "county",
    g."LATITUDE"                      AS "latitude",
    g."LONGITUDE"                     AS "longitude"

FROM INCOME_ADVERSITY_DB.STAGING.CBG_B27_2019        b27
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_FIPS_CODES      f
    ON LEFT(b27."CENSUS_BLOCK_GROUP", 5) = LPAD(f."STATE_FIPS", 2, '0') || f."COUNTY_FIPS"
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_GEOGRAPHIC_DATA g
    ON b27."CENSUS_BLOCK_GROUP" = g."CENSUS_BLOCK_GROUP"
WHERE "B27010e1" > 0

UNION ALL

-- 2020
SELECT
    b27."CENSUS_BLOCK_GROUP",
    2020                              AS "acs_year",
    "B27010e1"                        AS "insurance_universe",
    COALESCE("B27010e17", 0)
  + COALESCE("B27010e33", 0)          AS "uninsured_working_age",
    ROUND(
        (COALESCE("B27010e17", 0) + COALESCE("B27010e33", 0))
        / NULLIF("B27010e1", 0) * 100
    , 2)                              AS "uninsured_rate_pct",
    f."STATE"                         AS "state",
    f."COUNTY"                        AS "county",
    g."LATITUDE"                      AS "latitude",
    g."LONGITUDE"                     AS "longitude"

FROM INCOME_ADVERSITY_DB.STAGING.CBG_B27_2020        b27
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_FIPS_CODES      f
    ON LEFT(b27."CENSUS_BLOCK_GROUP", 5) = LPAD(f."STATE_FIPS", 2, '0') || f."COUNTY_FIPS"
JOIN INCOME_ADVERSITY_DB.STAGING.CBG_GEOGRAPHIC_DATA g
    ON b27."CENSUS_BLOCK_GROUP" = g."CENSUS_BLOCK_GROUP"
WHERE "B27010e1" > 0;



-- =============================================================================
-- Verification
-- =============================================================================

-- Uninsured rate + state count ( (50 states + DC + Puerto Rico))
SELECT "acs_year",
    ROUND(AVG("uninsured_rate_pct"), 2) AS "avg_uninsured_rate"
FROM INCOME_ADVERSITY_DB.STAGING.STG_HEALTH_GEO
GROUP BY "acs_year";



SELECT COUNT(DISTINCT "state") AS "state_count"
FROM INCOME_ADVERSITY_DB.STAGING.STG_HEALTH_GEO;