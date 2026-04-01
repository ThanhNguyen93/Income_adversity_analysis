-- =============================================================================
-- BUILDING mart_national_summary
-- =============================================================================




CREATE OR REPLACE TABLE INCOME_ADVERSITY_DB.MARTS.MART_NATIONAL_SUMMARY AS

SELECT
    "income_tier",
    "acs_year",
    COUNT(*)                                        AS "cbg_count",

    -- Income
    ROUND(AVG("median_hh_income"), 0)               AS "avg_median_income",
    SUM("hh_total")                                 AS "total_households",

    -- Unemployment
    ROUND(AVG("unemployment_rate_pct"), 2)          AS "avg_unemployment_pct",
    SUM("unemployed")                               AS "total_unemployed",

    -- Housing burden
    ROUND(AVG("rent_burden_rate_pct"), 2)           AS "avg_rent_burden_pct",
    SUM("rent_burdened_30_plus")                    AS "total_rent_burdened_hh",
    SUM("rent_severely_burdened")                   AS "total_severely_burdened_hh",

    -- Health insurance
    ROUND(AVG("uninsured_rate_pct"), 2)             AS "avg_uninsured_pct",
    SUM("uninsured_working_age")                    AS "total_uninsured",

    -- Risk distribution
    SUM(CASE WHEN "risk_label" = 'High Risk' THEN 1 ELSE 0 END)  AS "high_risk_cbg_count",
    SUM(CASE WHEN "risk_label" = 'Low Risk'  THEN 1 ELSE 0 END)  AS "low_risk_cbg_count",
    ROUND(
        SUM(CASE WHEN "risk_label" = 'High Risk' THEN 1 ELSE 0 END)
        / COUNT(*) * 100
    , 1)                                            AS "high_risk_pct",

    -- Composite adversity score
    ROUND(AVG("adversity_score"), 1)                AS "avg_adversity_score"

FROM INCOME_ADVERSITY_DB.MARTS.MART_INCOME_ADVERSITY
GROUP BY "income_tier", "acs_year"
ORDER BY "acs_year", "avg_median_income";

------------------
SELECT
    "income_tier",
    "acs_year",
    CONCAT('$', TO_CHAR("avg_median_income", '999,999'))  AS "avg_income",
    "avg_unemployment_pct"                                AS "unemployed_%",
    "avg_rent_burden_pct"                                 AS "rent_burden_%",
    "avg_uninsured_pct"                                   AS "uninsured_%",
    "avg_adversity_score"                                 AS "adversity_score",
    "high_risk_pct"                                       AS "high_risk_%"
FROM INCOME_ADVERSITY_DB.MARTS.MART_NATIONAL_SUMMARY
ORDER BY "acs_year", "avg_median_income";