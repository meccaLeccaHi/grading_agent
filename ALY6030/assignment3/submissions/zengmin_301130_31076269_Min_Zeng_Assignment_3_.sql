use `Public Housing`;

-- Step 1: Identify PHAs with at Least Two Inspections
DROP TEMPORARY TABLE IF EXISTS phas_with_multiple_inspections;
CREATE TEMPORARY TABLE phas_with_multiple_inspections AS
SELECT 
    public_housing_agency_name
FROM public_housing_inspection_data
GROUP BY public_housing_agency_name
HAVING COUNT(*) >= 2;
select * from phas_with_multiple_inspections; 

-- Step 2: Use JOIN to create my filtered data
DROP TEMPORARY TABLE IF EXISTS filtered_phas;
CREATE TEMPORARY TABLE filtered_phas AS
SELECT p.*
FROM public_housing_inspection_data p
JOIN phas_with_multiple_inspections pm
ON p.public_housing_agency_name = pm.public_housing_agency_name;
select * from filtered_phas;

-- Step 3: Use LEAD to Rank and Compare Costs
DROP TEMPORARY TABLE IF EXISTS ranked_phas;
CREATE TEMPORARY TABLE ranked_phas AS
SELECT 
    public_housing_agency_name AS PHA_NAME,
    inspection_date,
    cost_of_inspection_in_dollars AS MR_INSPECTION_COST,
    RANK() OVER (
		PARTITION BY public_housing_agency_name
        ORDER BY inspection_date DESC
	) AS RANK_1,
    LEAD(inspection_date) OVER (
        PARTITION BY public_housing_agency_name
        ORDER BY inspection_date DESC
    ) AS SECOND_MR_INSPECTION_DATE,
    LEAD(cost_of_inspection_in_dollars) OVER (
        PARTITION BY public_housing_agency_name
        ORDER BY inspection_date DESC
    ) AS SECOND_MR_INSPECTION_COST
FROM filtered_phas;
select * from ranked_phas;

-- Step 4: Filter Rows with Cost Increases
DROP TEMPORARY TABLE IF EXISTS phas_with_increases;
CREATE TEMPORARY TABLE phas_with_increases AS
SELECT 
    PHA_NAME,
    RANK_1,
    inspection_date AS MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    (SECOND_MR_INSPECTION_COST - MR_INSPECTION_COST) AS CHANGE_IN_COST,
    ROUND(((SECOND_MR_INSPECTION_COST - MR_INSPECTION_COST) / MR_INSPECTION_COST) * 100,2) AS PERCENT_CHANGE_IN_COST
FROM ranked_phas
WHERE RANK_1 = 1 AND SECOND_MR_INSPECTION_COST > MR_INSPECTION_COST;
select * from phas_with_increases ;

-- Step 5: Get Final Results
SELECT DISTINCT
    PHA_NAME,
    MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    CHANGE_IN_COST,
    PERCENT_CHANGE_IN_COST
FROM phas_with_increases;