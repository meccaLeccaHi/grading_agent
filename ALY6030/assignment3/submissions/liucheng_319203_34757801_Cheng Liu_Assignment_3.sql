-- ======================================================================
-- CHENG LIU - ASSIGNMENT 3
-- PUBLIC HOUSING INSPECTIONS ANALYSIS
-- Course: ALY6030 Data Warehousing & SQL
-- Date: May 10, 2025
-- ======================================================================

USE assignment3_db;

-- ======================================================================
-- QUESTION 5 ANALYSIS: PHAs WITH INCREASED INSPECTION COSTS
-- ======================================================================

-- This query identifies Public Housing Agencies (PHAs) that saw an increase in the cost of inspection between their most recent (MR) and second most recent (SMR) inspections.

-- CTE 1: Convert INSPECTION_DATE from TEXT to DATE for processing, rank inspections for each PHA by the converted date, and retrieve the cost.
WITH InspectionDataFormatted AS (
    SELECT
        PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
        INSPECTION_DATE AS Original_Inspection_Date_Text,
        COST_OF_INSPECTION_IN_DOLLARS AS Inspection_Cost,
        -- Convert INSPECTION_DATE TEXT to a DATE type for correct ordering.
        STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') AS Converted_Inspection_Date
    FROM
        public_housing_inspection
    WHERE
        INSPECTION_DATE IS NOT NULL AND TRIM(INSPECTION_DATE) != ''
        AND COST_OF_INSPECTION_IN_DOLLARS IS NOT NULL
),

InspectionCostsWithLag AS (
    SELECT
        PHA_NAME,
        Converted_Inspection_Date AS Current_Inspection_Date,
        Inspection_Cost AS Current_Inspection_Cost,

        LAG(Converted_Inspection_Date, 1, NULL) OVER (
            PARTITION BY PHA_NAME
            ORDER BY Converted_Inspection_Date ASC
        ) AS Previous_Inspection_Date,

        LAG(Inspection_Cost, 1, NULL) OVER (
            PARTITION BY PHA_NAME
            ORDER BY Converted_Inspection_Date ASC
        ) AS Previous_Inspection_Cost,

        ROW_NUMBER() OVER (
            PARTITION BY PHA_NAME
            ORDER BY Converted_Inspection_Date DESC
        ) AS rn
    FROM
        InspectionDataFormatted
    WHERE
        Converted_Inspection_Date IS NOT NULL
),

-- CTE 2: Calculate cost changes and identify the specific records for output.
CalculatedChanges AS (
    SELECT
        PHA_NAME,
        Current_Inspection_Date AS MR_INSPECTION_DATE,
        Current_Inspection_Cost AS MR_INSPECTION_COST,
        Previous_Inspection_Date AS SECOND_MR_INSPECTION_DATE,
        Previous_Inspection_Cost AS SECOND_MR_INSPECTION_COST,
        (Current_Inspection_Cost - Previous_Inspection_Cost) AS CHANGE_IN_COST,

        CASE
            WHEN Previous_Inspection_Cost IS NOT NULL AND Previous_Inspection_Cost != 0
            THEN ((Current_Inspection_Cost - Previous_Inspection_Cost) * 100.0 / Previous_Inspection_Cost)
            ELSE NULL
        END AS PERCENT_CHANGE_IN_COST,
        rn
    FROM
        InspectionCostsWithLag
    WHERE
        Previous_Inspection_Date IS NOT NULL
)

-- Final SELECT statement:
-- Filter for the most recent inspection record for each PHA where there was an increase in cost.
SELECT
    PHA_NAME,
    MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    CHANGE_IN_COST,

    ROUND(PERCENT_CHANGE_IN_COST, 2) AS PERCENT_CHANGE_IN_COST
FROM
    CalculatedChanges
WHERE
    rn = 1
    AND CHANGE_IN_COST > 0
ORDER BY
    PHA_NAME;
