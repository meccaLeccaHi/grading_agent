-- -------------------------------------------------------
-- Enzo Prado
-- College of Professional Studies, Northeastern University 
-- ALY 6030: Data Warehousing & SQL
-- Professor Adam Jones
-- Assignment 3: Public Housing Inspections Star Schema
-- -------------------------------------------------------

-- Question 1 - 4 are answered within the additional PDF report.
-- Question 5 is providing senior management with their subset of the data. This SQL Query fulfils their request, and the output is the additional CSV uploaded.
-- Step 1: Parse date from text to DATE format for compatibility with MySQL Workbench
WITH parsed_data AS (
  SELECT 
    PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
    -- Convert inspection date from text (MM/DD/YYYY) to DATE type (YYYY-MM-DD)
    STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') AS INSPECTION_DATE,
    COST_OF_INSPECTION_IN_DOLLARS AS INSPECTION_COST
  FROM public_housing_inspection_data
),

-- Step 2: Rank each inspection per PHA by most recent date and fetch the next inspection using LEAD()
ranked_data AS (
  SELECT 
    *,
    -- Rank inspections in descending order so most recent gets row_num = 1
    ROW_NUMBER() OVER (PARTITION BY PHA_NAME ORDER BY INSPECTION_DATE DESC) AS row_num,
    
    -- Get second most recent inspection date and cost using LEAD
    LEAD(INSPECTION_DATE, 1) OVER (PARTITION BY PHA_NAME ORDER BY INSPECTION_DATE DESC) AS SECOND_MR_INSPECTION_DATE,
    LEAD(INSPECTION_COST, 1) OVER (PARTITION BY PHA_NAME ORDER BY INSPECTION_DATE DESC) AS SECOND_MR_INSPECTION_COST
  FROM parsed_data
),

-- Step 3: Select only the most recent inspection per PHA, where a second exists and cost increased
final AS (
  SELECT
    PHA_NAME,
    INSPECTION_DATE AS MR_INSPECTION_DATE,
    INSPECTION_COST AS MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    
    -- Calculate absolute change in inspection cost
    (INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST,

    -- Calculate percent change in cost
    ROUND(
      ((INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST) * 100,
      2
    ) AS PERCENT_CHANGE_IN_COST
  FROM ranked_data
  WHERE row_num = 1                          -- Only include most recent inspection per PHA
    AND SECOND_MR_INSPECTION_COST IS NOT NULL  -- Must have at least two inspections
    AND INSPECTION_COST > SECOND_MR_INSPECTION_COST -- Include only PHAs with increased cost
)

-- Step 4: Return clean output for senior management with no duplicates
SELECT *
FROM final;
