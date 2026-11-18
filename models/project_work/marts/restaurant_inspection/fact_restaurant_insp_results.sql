-- Grain: one retained restaurant inspection result / violation row.

WITH stg_inspection AS (
    SELECT * FROM {{ ref('stg_restaurant_inspection') }}
),

dates AS (
    SELECT * FROM {{ ref('dim_date') }}
),

geographies AS (
    SELECT * FROM {{ ref('dim_geography') }}
),

restaurants AS (
    SELECT * FROM {{ ref('dim_restaurant') }}
    WHERE restaurant_key <> '-1'
),

violations AS (
    SELECT * FROM {{ ref('dim_violation') }}
    WHERE violation_key <> '-1'
),

cuisines AS (
    SELECT * FROM {{ ref('dim_cuisine') }}
),

joined AS (
    SELECT
        s.*,
        g.geography_key AS geography_insp_key,
        inspection.date_key AS date_insp_key,
        grade_date.date_key AS grade_date_key,
        CASE WHEN s.restaurant_name IS NULL THEN '-1'
            ELSE r.restaurant_key END AS restaurant_rest_insp_key,
        CASE WHEN s.violation_code IS NULL THEN '-1'
            ELSE v.violation_key END AS violation_rest_insp_key,
        c.cuisine_key
    FROM stg_inspection AS s
    LEFT JOIN dates AS inspection
        ON CAST(s.inspection_date AS DATE) = inspection.full_date
    LEFT JOIN dates AS grade_date
        ON CAST(s.grade_date AS DATE) = grade_date.full_date
    LEFT JOIN geographies AS g
        ON CAST(s.borough AS STRING) IS NOT DISTINCT FROM g.borough
        AND CAST(s.zip AS STRING) IS NOT DISTINCT FROM g.zipcode
        AND CAST(s.community_board AS STRING) IS NOT DISTINCT FROM g.community_board
        AND CAST(s.council_district AS STRING) IS NOT DISTINCT FROM g.council_district
    LEFT JOIN restaurants AS r
        ON s.restaurant_name = r.restaurant_name
        AND s.phone IS NOT DISTINCT FROM r.phone_num
    LEFT JOIN violations AS v
        ON s.violation_code = v.violation_code
        AND s.critical_flag IS NOT DISTINCT FROM v.critical_flag
    LEFT JOIN cuisines AS c
        ON COALESCE(s.cuisine_type, 'Unknown') = c.cuisine_type
),

fact_inspection_results AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'restaurant_id', 'inspection_date', 'violation_code', 'inspection_type'
        ]) }} AS rest_insp_key,
        geography_insp_key,
        date_insp_key,
        grade_date_key,
        restaurant_rest_insp_key,
        violation_rest_insp_key,
        cuisine_key,
        inspection_type,
        action,
        CAST(score AS INT64) AS score,
        grade,
        CAST(longitude AS FLOAT64) AS longitude,
        CAST(latitude AS FLOAT64) AS latitude
    FROM joined
)

SELECT * FROM fact_inspection_results
