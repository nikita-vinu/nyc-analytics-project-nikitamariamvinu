-- Status dimension for DOHMH 311 service requests.
-- Grain: one row per distinct (status, resolution_description) combination.

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_dohmh') }}
),

-- Identify distinct status combinations
distinct_status AS (

    SELECT DISTINCT
        status, 
        resolution_description
    FROM stg_311
    WHERE status IS NOT NULL

),

-- Generate surrogate key for each unique status combination
dim_311_status AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'status','resolution_description'
        ]) }} AS status_key,

        status,
        resolution_description

    FROM distinct_status

)

SELECT * FROM dim_311_status

