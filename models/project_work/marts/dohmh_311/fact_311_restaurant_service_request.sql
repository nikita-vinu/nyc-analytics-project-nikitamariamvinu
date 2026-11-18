-- Grain: one row per service request retained by staging.

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_dohmh') }}
),

dates AS (
    SELECT * FROM {{ ref('dim_date') }}
),

geographies AS (
    SELECT * FROM {{ ref('dim_geography') }}
),

complaints AS (
    SELECT * FROM {{ ref('dim_311_complaint') }}
    WHERE complaint_key <> '-1'
),

statuses AS (
    SELECT * FROM {{ ref('dim_311_status') }}
    WHERE status_key <> '-1'
),

agencies AS (
    SELECT * FROM {{ ref('dim_311_agency') }}
    WHERE agency_key <> '-1'
),


joined AS (
    SELECT
        s.*,
        created.date_key AS created_date_key,
        closed.date_key AS closed_date_key,
        g.geography_key,
        CASE WHEN s.complaint_type IS NULL THEN '-1'
            ELSE c.complaint_key END AS complaint_key,
        CASE WHEN s.status IS NULL THEN '-1'
            ELSE t.status_key END AS status_key,
        CASE WHEN s.agency IS NULL THEN '-1'
            ELSE a.agency_key END AS agency_key
    FROM stg_311 AS s
    LEFT JOIN dates AS created
        ON CAST(s.created_date AS DATE) = created.full_date
    LEFT JOIN dates AS closed
        ON CAST(s.closed_date AS DATE) = closed.full_date
    LEFT JOIN geographies AS g
        ON CAST(s.borough AS STRING) IS NOT DISTINCT FROM g.borough
        AND CAST(s.zip AS STRING) IS NOT DISTINCT FROM g.zipcode
        AND CAST(s.community_board AS STRING) IS NOT DISTINCT FROM g.community_board
        AND CAST(s.council_district AS STRING) IS NOT DISTINCT FROM g.council_district
    LEFT JOIN complaints AS c
        ON s.complaint_type = c.complaint_type
        AND s.descriptor IS NOT DISTINCT FROM c.descriptor
        AND s.descriptor_2 IS NOT DISTINCT FROM c.descriptor_2
        AND s.location_type IS NOT DISTINCT FROM c.location_type
    LEFT JOIN statuses AS t
        ON s.status = t.status
        AND s.resolution_description IS NOT DISTINCT FROM t.resolution_description
    LEFT JOIN agencies AS a
        ON s.agency = a.agency
        AND s.agency_name IS NOT DISTINCT FROM a.agency_name
),

fact_service_requests AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['request_id']) }} AS service_request_fact_key,
        request_id AS unique_key,
        created_date_key,
        closed_date_key,
        CAST(created_date AS DATETIME) AS created_datetime,
        CAST(closed_date AS DATETIME) AS closed_datetime,
        geography_key,
        complaint_key,
        status_key,
        agency_key,
        1 AS request_count,
        CASE
            WHEN status = 'CLOSED'
                AND closed_date IS NOT NULL
                AND closed_date >= created_date
            THEN ROUND(
                CAST(TIMESTAMP_DIFF(closed_date, created_date, SECOND) AS NUMERIC) / 3600,
                2
            )
            ELSE CAST(NULL AS NUMERIC)
        END AS time_to_close_hours,
        CASE
            WHEN status IS NULL THEN CAST(NULL AS BOOLEAN)
            ELSE status = 'CLOSED'
        END AS is_closed,
        CAST(longitude AS FLOAT64) AS longitude,
        CAST(latitude AS FLOAT64) AS latitude
    FROM joined
)

SELECT * FROM fact_service_requests
