-- Cuisine dimension for DOHMH restaurant inspections.
-- Grain: one row per distinct cuisine type.

WITH stg_restaurant AS (
    SELECT * FROM {{ ref('stg_restaurant_inspection') }}
),

distinct_cuisine AS (

    SELECT DISTINCT
        cuisine_type
    FROM stg_restaurant
    WHERE cuisine_type IS NOT NULL
    AND cuisine_type <> 'Unknown'

),

-- Derive the group from the cleaned type here so staging can stay unchanged.
enriched AS (

    SELECT
        cuisine_type,
        CASE
            WHEN cuisine_type IN ('Creole', 'Cajun', 'Creole/Cajun') THEN 'Creole/Cajun'
            WHEN cuisine_type IN ('Hotdogs', 'Hotdogs/Pretzels') THEN 'Hotdogs'
            WHEN cuisine_type IN ('Sandwiches', 'Salads', 'Soups',
                'Sandwiches/Salads/Mixed Buffet', 'Soups/Salads/Sandwiches') THEN 'Sandwiches/Salads/Soups'
            WHEN cuisine_type IN ('French', 'New French', 'Haute Cuisine') THEN 'French'
            WHEN cuisine_type IN ('Vegan', 'Vegetarian') THEN 'Vegetarian/Vegan'
            WHEN cuisine_type IN ('Bakery Products/Desserts', 'Frozen Desserts', 'Donuts',
                'Bagels/Pretzels', 'Pancakes/Waffles', 'Nuts/Confectionary') THEN 'Bakery/Desserts'
            WHEN cuisine_type IN ('Coffee/Tea', 'Juice, Smoothies, Fruit Salads',
                'Bottled Beverages') THEN 'Beverages'
            WHEN cuisine_type IN ('Polish', 'Russian', 'Czech', 'Eastern European') THEN 'Eastern European'
            WHEN cuisine_type IN ('Lebanese', 'Egyptian', 'Iranian', 'Turkish',
                'Armenian', 'Middle Eastern') THEN 'Middle Eastern'
            ELSE cuisine_type
        END AS cuisine_group

    FROM distinct_cuisine

),

dim_cuisine AS (

    SELECT
     {{ dbt_utils.generate_surrogate_key(['cuisine_type']) }}
            AS cuisine_key,
        cuisine_type,
        cuisine_group

    FROM enriched
),

-- Null placeholder: inspections with no cuisine recorded
null_placeholder AS (

    SELECT
        '-1' AS cuisine_key,
        'Unknown' AS cuisine_type,
        'Unknown' AS cuisine_group
)

SELECT * FROM dim_cuisine
UNION ALL
SELECT * FROM null_placeholder
