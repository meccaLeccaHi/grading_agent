USE ALY6030_PHInspection;
-- check initial date format
DESCRIBE public_housing_inspection_data;

-- Question 5
WITH cleaned_data AS (
  SELECT
    PUBLIC_HOUSING_AGENCY_NAME,
    -- convert date format to DATE
    STR_TO_DATE(TRIM(INSPECTION_DATE), '%m/%d/%Y') AS INSPECTION_DATE,
    COST_OF_INSPECTION_IN_DOLLARS
  FROM public_housing_inspection_data
  WHERE INSPECTION_DATE IS NOT NULL
),

-- Sort all inspections for each PHA by date in descending order
ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY PUBLIC_HOUSING_AGENCY_NAME
      ORDER BY STR_TO_DATE(TRIM(INSPECTION_DATE), '%m/%d/%Y') DESC
    ) AS row_num
  FROM cleaned_data
),

-- Use row_num to get the two most recent records for each PHA (numbered 1 and 2)
latest_two AS (
  SELECT *
  FROM ranked
  WHERE row_num <= 2
),

-- Concatenate the records with row_num = 1 and row_num = 2 horizontally and compare
pivoted AS (
  SELECT
    MAX(CASE WHEN row_num = 1 THEN INSPECTION_DATE END) AS MR_INSPECTION_DATE,
    MAX(CASE WHEN row_num = 1 THEN COST_OF_INSPECTION_IN_DOLLARS END) AS MR_INSPECTION_COST,
    MAX(CASE WHEN row_num = 2 THEN INSPECTION_DATE END) AS SECOND_MR_INSPECTION_DATE,
    MAX(CASE WHEN row_num = 2 THEN COST_OF_INSPECTION_IN_DOLLARS END) AS SECOND_MR_INSPECTION_COST,
    PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME
  FROM latest_two
  GROUP BY PUBLIC_HOUSING_AGENCY_NAME
),

final AS (
  SELECT
    PHA_NAME,
    MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST,
    ROUND(100 * (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST, 2) AS PERCENT_CHANGE_IN_COST
  FROM pivoted
  WHERE SECOND_MR_INSPECTION_COST IS NOT NULL
)

SELECT *
FROM final
WHERE CHANGE_IN_COST > 0;




