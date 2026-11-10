-- Date dimension shared by DOT 311 service requests and Restaurant citation

-- Build initial CTEs for Jinja syntax to make refs to staging models easier
WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_dohmh') }}
),

stg_inspection AS (
    SELECT * FROM {{ ref('stg_restaurant_inspection') }}
),

-- Then union dates from the staging data together, collecting all poss dates
all_dates AS (

    -- 311 service requests: date roles referenced by fact_311_restaurant_service_request
    SELECT DISTINCT CAST(created_date AS DATE) AS full_date
    FROM stg_311
    WHERE created_date IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT CAST(closed_date AS DATE) AS full_date
    FROM stg_311
    WHERE closed_date IS NOT NULL

    UNION DISTINCT

    -- Restaurant inspection results: date roles referenced by fact_restaurant_insp_results
    SELECT DISTINCT CAST(inspection_date AS DATE) AS full_date
    FROM stg_inspection
    WHERE inspection_date IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT CAST(grade_date AS DATE) AS full_date
    FROM stg_inspection
    WHERE grade_date IS NOT NULL


),

-- Date dimension with NYC fiscal year, Jul 1 - Jun 30, diff from federal
date_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['full_date']) }} AS date_key,

        full_date,
        EXTRACT(YEAR FROM full_date) AS calendar_year,
        EXTRACT(QUARTER FROM full_date) AS calendar_quarter,
        EXTRACT(MONTH FROM full_date) AS month_number,
        FORMAT_DATE('%B', full_date) AS month_name,
        EXTRACT(DAY FROM full_date) AS day_of_month,
        EXTRACT(DAYOFMONTH FROM full_date) AS day_of_month,
        FORMAT_DATE('%A', full_date) AS day_of_week_name,
        EXTRACT(DAYOFWEEK FROM full_date) IN (1, 7) AS is_weekend

    FROM all_dates

),

-- Null placeholder row: to handle NULL values.
-- Building fact tables should COALESCE a null source date to this key
-- Keeps all fact and date_dim joins INNER JOINs safely
-- Kimball convention to be explicit. (More to come on this)

null_placeholder AS (

    SELECT
        '-1' AS date_key,
        CAST(NULL AS DATE) AS full_date,
        CAST(NULL AS INT64) AS calendar_year,
        CAST(NULL AS INT64) AS calendar_quarter,
        CAST(NULL AS INT64) AS month_number,
        CAST(NULL AS STRING) AS month_name,
        CAST(NULL AS INT64) AS day_of_month,
        CAST(NULL AS STRING) AS day_of_week_name,
        CAST(NULL AS BOOLEAN) AS is_weekend
) 
-- make sure BQ knows the col types


SELECT * FROM date_dimension

UNION ALL

SELECT * FROM null_placeholder
