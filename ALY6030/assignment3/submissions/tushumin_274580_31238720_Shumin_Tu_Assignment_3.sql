
# Filter out PHAs that only performed one inspection, convert dates from TEXT to Date format and use date to rank the first inspection and second inspection.
WITH T1 AS (
SELECT
PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') AS INSPECTION_DATE,
COST_OF_INSPECTION_IN_DOLLARS AS INSPECTION_COST,
RANK() OVER (PARTITION BY PUBLIC_HOUSING_AGENCY_NAME ORDER BY INSPECTION_DATE ASC) as RNK
FROM public_housing_inspection_data
WHERE PUBLIC_HOUSING_AGENCY_NAME NOT IN (SELECT PUBLIC_HOUSING_AGENCY_NAME
										 FROM public_housing_inspection_data
                                         GROUP BY PUBLIC_HOUSING_AGENCY_NAME
                                         HAVING COUNT(PUBLIC_HOUSING_AGENCY_NAME) =1
                                         )
),

# Use Lead window function to create the second date and second cost, and remove inspections after the second one.
T2 AS (
SELECT 
PHA_NAME,
INSPECTION_DATE AS MR_INSPECTION_DATE,
INSPECTION_COST AS MR_INSPECTION_COST,
LEAD(INSPECTION_DATE) OVER (PARTITION BY PHA_NAME ORDER BY INSPECTION_DATE ASC) AS SECOND_MR_INSPECTION_DATE,
LEAD(INSPECTION_COST) OVER (PARTITION BY PHA_NAME ORDER BY INSPECTION_DATE ASC) AS SECOND_MR_INSPECTION_COST
FROM T1
WHERE RNK <= 2
)

# List each PHA only once, with no duplicates, and calculate the change in cost and the percent change in cost, 
# restricted to cases where there is an increase in cost between the first and second inspections.
SELECT
DISTINCT PHA_NAME,
MR_INSPECTION_DATE,
MR_INSPECTION_COST,
SECOND_MR_INSPECTION_DATE,
SECOND_MR_INSPECTION_COST,
(SECOND_MR_INSPECTION_COST - MR_INSPECTION_COST) AS CHANGE_IN_COST,
((SECOND_MR_INSPECTION_COST - MR_INSPECTION_COST) / MR_INSPECTION_COST * 100) AS PERCENT_CHANGE_IN_COST
FROM T2 
WHERE (SECOND_MR_INSPECTION_COST - MR_INSPECTION_COST) > 0
