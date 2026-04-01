/* =============================================================================
   LAYER 1A: RAW SOURCE INGESTION
   Project  : Income Adversity Analysis
   Source   : US_OPEN_CENSUS_DATA__NEIGHBORHOOD_INSIGHTS__FREE_DATASET (Snowflake Marketplace)
   Target   : INCOME_ADVERSITY_DB.STAGING
   Purpose  : Copy shared marketplace tables into a local working database
              so downstream transformations are not dependent on the marketplace
              schema and can be run without re-acquiring the dataset.
   Tables   : ACS Census Block Group (CBG) series — B17, B19, B23, B25, B27
              for survey years 2019 and 2020, plus geographic reference tables.
   ============================================================================= */


-- =============================================================================
-- SECTION 0: Set working context to the shared marketplace database
-- =============================================================================

USE DATABASE US_OPEN_CENSUS_DATA__NEIGHBORHOOD_INSIGHTS__FREE_DATASET;
USE SCHEMA PUBLIC;


-- =============================================================================
-- SECTION 1: Provision working database and schemas
-- =============================================================================
-- MARTS   — final, analytics-ready tables  
-- STAGING — raw copies of source tables; no transformations applied here

CREATE DATABASE IF NOT EXISTS INCOME_ADVERSITY_DB;
CREATE SCHEMA  IF NOT EXISTS INCOME_ADVERSITY_DB.MARTS;
CREATE SCHEMA  IF NOT EXISTS INCOME_ADVERSITY_DB.STAGING;


-- Verification: confirm schemas were created successfully
SHOW SCHEMAS IN DATABASE INCOME_ADVERSITY_DB;
SHOW TABLES  IN DATABASE INCOME_ADVERSITY_DB;


-- =============================================================================
-- SECTION 2: Ingest ACS income tables (B19 — Income in the Past 12 Months)
-- =============================================================================

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b19_2019 AS
SELECT * FROM "2019_CBG_B19";

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b19_2020 AS
SELECT * FROM "2020_CBG_B19";


-- =============================================================================
-- SECTION 3: Ingest ACS poverty tables (B17 — Poverty Status in the Past 12 Months)
-- Note: not use B17 in the actual analysis
-- =============================================================================

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b17_2019 AS
SELECT * FROM "2019_CBG_B17";

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b17_2020 AS
SELECT * FROM "2020_CBG_B17";


-- =============================================================================
-- SECTION 4: Ingest ACS employment tables (B23 — Employment Status)
-- =============================================================================

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b23_2019 AS
SELECT * FROM "2019_CBG_B23";

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b23_2020 AS
SELECT * FROM "2020_CBG_B23";


-- =============================================================================
-- SECTION 5: Ingest ACS housing tables (B25 — Housing Characteristics)
-- =============================================================================

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b25_2019 AS
SELECT * FROM "2019_CBG_B25";

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b25_2020 AS
SELECT * FROM "2020_CBG_B25";


-- =============================================================================
-- SECTION 6: Ingest ACS health insurance tables (B27 — Health Insurance Coverage)
-- =============================================================================

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b27_2019 AS
SELECT * FROM "2019_CBG_B27";

CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_b27_2020 AS
SELECT * FROM "2020_CBG_B27";


-- =============================================================================
-- SECTION 7: Ingest geographic reference tables
-- =============================================================================
-- These tables are year-agnostic; the 2020 vintage is used as the stable
-- reference for all joins throughout the project.

-- Discovery: locate FIPS code table in the shared database
USE DATABASE US_OPEN_CENSUS_DATA__NEIGHBORHOOD_INSIGHTS__FREE_DATASET;

SELECT TABLE_SCHEMA, TABLE_NAME
FROM   INFORMATION_SCHEMA.TABLES
WHERE  TABLE_NAME ILIKE '%CBG_FIPS%';

-- FIPS code lookup (census block group → state / county / tract identifiers)
CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_fips_codes AS
SELECT * FROM "2020_METADATA_CBG_FIPS_CODES";

-- Geographic data (centroid coordinates, land / water area, urban classification)
CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.STAGING.cbg_geographic_data AS
SELECT * FROM "2020_METADATA_CBG_GEOGRAPHIC_DATA";


-- =============================================================================
-- SECTION 8: Post-load validation
-- =============================================================================

-- 8a. Confirm the working database exists
SHOW DATABASES LIKE '%INCOME_ADVERSITY%';

-- 8b. Confirm both schemas are present
SHOW SCHEMAS IN DATABASE INCOME_ADVERSITY_DB;

-- 8c. Confirm all staging tables were created
SHOW TABLES IN SCHEMA INCOME_ADVERSITY_DB.STAGING;

-- 8d. Row-count sanity check on income tables (~220k rows expected per year)
SELECT COUNT(*) AS row_count, 
'2019' AS survey_year 
FROM INCOME_ADVERSITY_DB.STAGING.cbg_b19_2019
UNION ALL
SELECT COUNT(*),              
'2020'                 
FROM INCOME_ADVERSITY_DB.STAGING.cbg_b19_2020;

-- 8e. Column-level preview — confirm schema looks correct before proceeding
SELECT * FROM INCOME_ADVERSITY_DB.STAGING.cbg_b19_2019 LIMIT 5;
