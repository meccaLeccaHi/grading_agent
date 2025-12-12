-- Assignment — Public Housing Inspections Star Schema

-- Create Schema
CREATE DATABASE IF NOT EXISTS public_housing;
USE public_housing;

-- Create table
CREATE TABLE public_housing_inspection_data (
    INSPECTION_ID INT PRIMARY KEY,  
    PUBLIC_HOUSING_AGENCY_NAME VARCHAR(255), 
    COST_OF_INSPECTION_IN_DOLLARS INT, 
    INSPECTED_DEVELOPMENT_NAME VARCHAR(255), 
    INSPECTED_DEVELOPMENT_ADDRESS VARCHAR(255), 
    INSPECTED_DEVELOPMENT_CITY VARCHAR(255), 
    INSPECTED_DEVELOPMENT_STATE VARCHAR(10), 
    INSPECTION_DATE VARCHAR(10), 
    INSPECTION_SCORE INT 
);

-- Identify PHAs with Increased Inspection Costs
WITH Inspection_MR AS (
    SELECT 
        PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
        STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') AS INSPECTION_DATE, -- Convert dates from TEXT to Date format
        COST_OF_INSPECTION_IN_DOLLARS AS MR_INSPECTION_COST, -- The most recent inspection cost
        -- Get the previous inspection date
        LAG(STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y')) 
        OVER ( 
			PARTITION BY PUBLIC_HOUSING_AGENCY_NAME -- Group by PHA
            ORDER BY INSPECTION_DATE ASC -- Order by date in asc order so LAG() retrieves the earlier inspection
		) AS SECOND_MR_INSPECTION_DATE,
        -- Get the previous inspection cost
        LAG(COST_OF_INSPECTION_IN_DOLLARS) 
        OVER (
			PARTITION BY PUBLIC_HOUSING_AGENCY_NAME 
            ORDER BY INSPECTION_DATE ASC
		) AS SECOND_MR_INSPECTION_COST,
        -- Rank each PHA's inspections from most recent to oldest
        ROW_NUMBER() 
        OVER (
            PARTITION BY PUBLIC_HOUSING_AGENCY_NAME 
            -- Order by date in descending order so the most recent inspection is ranked 1
            ORDER BY STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') DESC
		) AS rn
    FROM public_housing_inspection_data
)
-- Select the required columns for final output
SELECT 
    PHA_NAME,
    INSPECTION_DATE AS MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST, -- Calculate cost difference
    ((MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST) * 100 AS PERCENT_CHANGE_IN_COST
FROM Inspection_MR
WHERE SECOND_MR_INSPECTION_COST IS NOT NULL  -- filter out PHAs that only performed one inspection
AND (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) > 0 -- Only PHAs with increased costs are retained
AND rn = 1 -- Only keep the most recent inspection per PHA
ORDER BY PERCENT_CHANGE_IN_COST DESC; -- Sort by percentage increase in cost, highest first
