-- Step 1: Convert the text-formatted inspection dates to proper DATE values
WITH formatted_data AS (
  SELECT
    PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
    STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') AS INSPECTION_DATE,
    COST_OF_INSPECTION_IN_DOLLARS AS INSPECTION_COST
  FROM public_housing_inspections.public_housing_inspection_data
),

-- Step 2: Use LEAD() to retrieve the second most recent inspection for each PHA
-- Sort by INSPECTION_DATE in descending order to anchor each row as the most recent
lead_data AS (
  SELECT
    PHA_NAME,
    INSPECTION_DATE AS MR_INSPECTION_DATE,
    INSPECTION_COST AS MR_INSPECTION_COST,
    LEAD(INSPECTION_DATE) OVER (PARTITION BY PHA_NAME ORDER BY INSPECTION_DATE DESC) AS SECOND_MR_INSPECTION_DATE,
    LEAD(INSPECTION_COST) OVER (PARTITION BY PHA_NAME ORDER BY INSPECTION_DATE DESC) AS SECOND_MR_INSPECTION_COST
  FROM formatted_data
),

-- Step 3: Filter only for PHAs with a cost increase
-- Also calculate change in cost and percent change
cost_increases AS (
  SELECT
    *,
    (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST,
    ROUND(100.0 * (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST, 2) AS PERCENT_CHANGE_IN_COST
  FROM lead_data
  WHERE SECOND_MR_INSPECTION_COST IS NOT NULL
    AND MR_INSPECTION_COST > SECOND_MR_INSPECTION_COST
),

-- Step 4: Keep only the most recent cost increase per PHA using ROW_NUMBER()
most_recent_increase_per_pha AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY PHA_NAME ORDER BY MR_INSPECTION_DATE DESC) AS rn
  FROM cost_increases
)

-- Step 5: Final output – one row per PHA with the most recent inspection cost increase
SELECT
  PHA_NAME,
  MR_INSPECTION_DATE,
  MR_INSPECTION_COST,
  SECOND_MR_INSPECTION_DATE,
  SECOND_MR_INSPECTION_COST,
  CHANGE_IN_COST,
  PERCENT_CHANGE_IN_COST
FROM most_recent_increase_per_pha
WHERE rn = 1;