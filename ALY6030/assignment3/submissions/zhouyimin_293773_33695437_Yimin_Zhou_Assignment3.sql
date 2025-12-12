-- Step 1: Clean and parse the date properly
WITH inspections_cleaned AS (
    SELECT 
        PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
        STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') AS INSPECTION_DATE,
        CAST(COST_OF_INSPECTION_IN_DOLLARS AS UNSIGNED) AS INSPECTION_COST
    FROM public_housing_inspection_data
    WHERE INSPECTION_DATE IS NOT NULL
),

-- Step 2: Rank inspections by most recent per PHA
ranked_inspections AS (
    SELECT 
        PHA_NAME,
        INSPECTION_DATE,
        INSPECTION_COST,
        ROW_NUMBER() OVER (PARTITION BY PHA_NAME ORDER BY STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') DESC) AS rn
    FROM inspections_cleaned
),

-- Step 3: Extract most recent and second-most recent inspections
pivoted_costs AS (
    SELECT 
        a.PHA_NAME,
        a.INSPECTION_DATE AS MR_INSPECTION_DATE,
        a.INSPECTION_COST AS MR_INSPECTION_COST,
        b.INSPECTION_DATE AS SECOND_MR_INSPECTION_DATE,
        b.INSPECTION_COST AS SECOND_MR_INSPECTION_COST
    FROM ranked_inspections a
    JOIN ranked_inspections b
        ON a.PHA_NAME = b.PHA_NAME
       AND a.rn = 1
       AND b.rn = 2
),

-- Step 4: Calculate differences and percent change
final_result AS (
    SELECT 
        *,
        (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST,
        ROUND(
            (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST * 100, 
            2
        ) AS PERCENT_CHANGE_IN_COST
    FROM pivoted_costs
    WHERE MR_INSPECTION_COST > SECOND_MR_INSPECTION_COST
)

-- Final output
SELECT 
    PHA_NAME,
    DATE_FORMAT(MR_INSPECTION_DATE, '%Y-%m-%d') AS MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    DATE_FORMAT(SECOND_MR_INSPECTION_DATE, '%Y-%m-%d') AS SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    CHANGE_IN_COST,
    PERCENT_CHANGE_IN_COST
FROM final_result;


