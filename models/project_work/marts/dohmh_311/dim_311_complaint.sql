
-- Complaint type dimension for DOHMH 311 service requests.
-- Grain: one row per distinct (complaint_type, descriptor, descriptor_2, location_type) combination.

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_dohmh') }}
),

-- Identify distinct complaint combinations
distinct_complaint_types AS (

    SELECT DISTINCT
        complaint_type,
        descriptor,
        descriptor_2,
        location_type
    FROM stg_311
    WHERE complaint_type IS NOT NULL

),

-- Generate surrogate key for each unique complaint combination
dim_311_complaint AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'complaint_type', 'descriptor', 'descriptor_2', 'location_type'
        ]) }} AS complaint_key,

        complaint_type,
        descriptor,
        descriptor_2,
        location_type

    FROM distinct_complaint_types

),

-- Null placeholder row to handle NULL values
null_placeholder AS (

    SELECT
        '-1' AS complaint_key,
        CAST(NULL AS STRING) AS complaint_type,
        CAST(NULL AS STRING) AS descriptor,
        CAST(NULL AS STRING) AS descriptor_2,
        CAST(NULL AS STRING) AS location_type

)

SELECT * FROM dim_311_complaint

UNION ALL

SELECT * FROM null_placeholder
