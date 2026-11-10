
-- Complaint dimension for NYC 311 DOHMH restaurant service requests
-- Grain: One row per distinct combination of
-- complaint_type, descriptor, descriptor_2, location_type

WITH stg_311 AS (
    SELECT *
    FROM {{ ref('stg_nyc_311_dohmh') }}
),

-- Standardize blank values and identify unique combinations
distinct_complaints AS (

    SELECT DISTINCT
        NULLIF(TRIM(complaint_type), '') AS complaint_type,
        NULLIF(TRIM(descriptor), '') AS descriptor,
        NULLIF(TRIM(descriptor_2), '') AS descriptor_2,
        NULLIF(TRIM(location_type), '') AS location_type

    FROM stg_311

    WHERE NULLIF(TRIM(complaint_type), '') IS NOT NULL
),

dim_311_complaint AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'complaint_type',
            'descriptor',
            'descriptor_2',
            'location_type'
        ]) }} AS complaint_key,

        complaint_type,
        descriptor,
        descriptor_2,
        location_type

    FROM distinct_complaints

)

SELECT * FROM dim_311_complaint
