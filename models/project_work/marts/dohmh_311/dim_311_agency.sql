
-- Agency dimension for DOHMH 311 service requests.
-- Grain: one row per distinct (agency, agency_name) combination.

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_dohmh') }}
),

-- Identify distinct agency combinations
distinct_agency AS (

    SELECT DISTINCT
        agency,
        agency_name
    FROM stg_311
    WHERE agency IS NOT NULL

),

-- Generate surrogate key for each unique agency combination
dim_311_agency AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'agency', 'agency_name'
        ]) }} AS agency_key,

        agency,
        agency_name

    FROM distinct_agency

),

-- Null placeholder row to handle NULL values
null_placeholder AS (

    SELECT
        '-1' AS agency_key,
        CAST(NULL AS STRING) AS agency,
        CAST(NULL AS STRING) AS agency_name

)

SELECT * FROM dim_311_agency

UNION ALL

SELECT * FROM null_placeholder
