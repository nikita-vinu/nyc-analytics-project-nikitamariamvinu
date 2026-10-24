-- Clean and standardize DOB NOW: Build job application filings
-- Intended grain: one row per job filing number
-- Source: NYC Open Data w9ak-ipjd

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
    SELECT
        -- Retain all other source fields for downstream dimensional models.
        * EXCEPT (
            job_filing_number,
            filing_status,
            filing_date,
            current_status_date,
            first_permit_date,
            approved_date,
            signoff_date,
            postcode,
            zip,
            borough,
            council_district,
            latitude,
            longitude
        ),

        -- Filing identifier
        CAST(job_filing_number AS STRING)AS job_filing_number,

        -- Filing status: remove surrounding spaces and standardize case
        UPPER(TRIM(CAST(filing_status AS STRING))) AS filing_status,

        -- Dates:
        CAST(filing_date AS TIMESTAMP) AS filing_date,
        CAST(current_status_date AS TIMESTAMP) AS current_status_date,
        CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
        CAST(approved_date AS TIMESTAMP) AS approved_date,
        CAST(signoff_date AS TIMESTAMP) AS signoff_date,

        -- ZIP: match the 311 staging column name (zip)
        CASE
            WHEN UPPER(TRIM(CAST(postcode AS STRING))) IN ('', 'N/A', 'NA', 'NULL') THEN NULL
            WHEN REGEXP_CONTAINS(TRIM(CAST(postcode AS STRING)), r'^\d{5}$')
                THEN TRIM(CAST(postcode AS STRING))
            WHEN REGEXP_CONTAINS(TRIM(CAST(postcode AS STRING)), r'^\d{9}$')
                THEN TRIM(CAST(postcode AS STRING))
            WHEN REGEXP_CONTAINS(TRIM(CAST(postcode AS STRING)), r'^\d{5}-\d{4}$')
                THEN TRIM(CAST(postcode AS STRING))
            ELSE NULL
        END AS zip,

        -- Borough: used the same standardized names as the 311 staging model
        CASE
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Shared geographic fields for future conformed location dimension
        TRIM(CAST(council_district AS STRING)) AS council_district,
        CAST(latitude AS NUMERIC) AS latitude,
        CAST(longitude AS NUMERIC) AS longitude,


        -- Staging metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

     -- Filters (raw column names are used here because WHERE can't see aliases from the SELECT)

   WHERE job_filing_number IS NOT NULL
   AND filing_date IS NOT NULL
   AND CAST(filing_date AS DATE) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 YEAR)
   AND borough IS NOT NULL


    -- Keep the most recent status per filing number, if duplicates exist
    QUALIFY ROW_NUMBER() OVER (
       PARTITION BY job_filing_number
       ORDER BY current_status_date DESC, filing_date DESC
   ) = 1

)

SELECT * FROM cleaned
-- All should be part of this table after running: stg_nyc_dob_job_filings
