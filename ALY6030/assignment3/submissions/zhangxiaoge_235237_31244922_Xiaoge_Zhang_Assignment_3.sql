-- Date Format Conversion and Column Type Update
SET SQL_SAFE_UPDATES = 0;

UPDATE public_housing.public_housing_inspection_data
SET INSPECTION_DATE = STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y');

SET SQL_SAFE_UPDATES = 1;

SELECT INSPECTION_DATE FROM public_housing.public_housing_inspection_data LIMIT 10;

ALTER TABLE public_housing.public_housing_inspection_data
MODIFY COLUMN INSPECTION_DATE DATE;

DESCRIBE public_housing.public_housing_inspection_data;


-- Task 1: Filter Public Housing Agencies (PHAs) with Increased Inspection Costs

WITH inspection_ranked AS (
    SELECT 
        PUBLIC_HOUSING_AGENCY_NAME,
        INSPECTION_DATE,
        COST_OF_INSPECTION_IN_DOLLARS,
        ROW_NUMBER() OVER (PARTITION BY PUBLIC_HOUSING_AGENCY_NAME ORDER BY INSPECTION_DATE DESC) AS `rank`
    FROM public_housing.public_housing_inspection_data
)
SELECT 
    a.PUBLIC_HOUSING_AGENCY_NAME,
    a.INSPECTION_DATE AS MR_INSPECTION_DATE,
    a.COST_OF_INSPECTION_IN_DOLLARS AS MR_INSPECTION_COST,
    b.INSPECTION_DATE AS SECOND_MR_INSPECTION_DATE,
    b.COST_OF_INSPECTION_IN_DOLLARS AS SECOND_MR_INSPECTION_COST,
    a.COST_OF_INSPECTION_IN_DOLLARS - b.COST_OF_INSPECTION_IN_DOLLARS AS CHANGE_IN_COST,
    ((a.COST_OF_INSPECTION_IN_DOLLARS - b.COST_OF_INSPECTION_IN_DOLLARS) / b.COST_OF_INSPECTION_IN_DOLLARS) * 100 AS PERCENT_CHANGE_IN_COST
FROM inspection_ranked a
JOIN inspection_ranked b
    ON a.PUBLIC_HOUSING_AGENCY_NAME = b.PUBLIC_HOUSING_AGENCY_NAME
   AND a.`rank` = 1
   AND b.`rank` = 2
WHERE a.COST_OF_INSPECTION_IN_DOLLARS > b.COST_OF_INSPECTION_IN_DOLLARS;



-- Task 2: Aggregate Inspection Costs by Month
SELECT 
    DATE_FORMAT(INSPECTION_DATE, '%Y-%m') AS inspection_month,
    SUM(COST_OF_INSPECTION_IN_DOLLARS) AS total_inspection_cost
FROM public_housing.public_housing_inspection_data
GROUP BY inspection_month
ORDER BY inspection_month;

-- Task 3: List Top 10 PHAs by Total Inspection Costs
SELECT 
    PUBLIC_HOUSING_AGENCY_NAME,
    SUM(COST_OF_INSPECTION_IN_DOLLARS) AS total_inspection_cost
FROM public_housing.public_housing_inspection_data
GROUP BY PUBLIC_HOUSING_AGENCY_NAME
ORDER BY total_inspection_cost DESC
LIMIT 10;

-- Task 4: Calculate Average Inspection Score per State
SELECT 
    INSPECTED_DEVELOPMENT_STATE,
    AVG(INSPECTION_SCORE) AS avg_inspection_score
FROM public_housing.public_housing_inspection_data
GROUP BY INSPECTED_DEVELOPMENT_STATE
ORDER BY avg_inspection_score DESC;


