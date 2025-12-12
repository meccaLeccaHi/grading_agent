
-- Ensure the inspection_date column is converted from TEXT to DATE
-- Adjust the table name if yours differs
ALTER TABLE public_housing_inspection_data
MODIFY inspection_date DATE;

-- CTE to rank inspections per PHA by date (most recent first)
WITH ranked_inspections AS (
    SELECT
        PHA_NAME,
        inspection_date,
        inspection_cost,
        ROW_NUMBER() OVER (PARTITION BY PHA_NAME ORDER BY inspection_date DESC) AS rn
    FROM public_housing_inspection_data
),

-- CTE to pivot the two most recent inspections into one row
pivoted_costs AS (
    SELECT
        ri1.PHA_NAME,
        ri1.inspection_date AS MR_INSPECTION_DATE,
        ri1.inspection_cost AS MR_INSPECTION_COST,
        ri2.inspection_date AS SECOND_MR_INSPECTION_DATE,
        ri2.inspection_cost AS SECOND_MR_INSPECTION_COST
    FROM ranked_inspections ri1
    JOIN ranked_inspections ri2
        ON ri1.PHA_NAME = ri2.PHA_NAME
        AND ri1.rn = 1
        AND ri2.rn = 2
)

-- Final output with increase in cost and percentage change
SELECT
    PHA_NAME,
    MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST,
    ROUND(((MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST) * 100, 2) AS PERCENT_CHANGE_IN_COST
FROM pivoted_costs
WHERE MR_INSPECTION_COST > SECOND_MR_INSPECTION_COST;
