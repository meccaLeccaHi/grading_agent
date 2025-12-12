-- Drop and recreate the schema
DROP SCHEMA IF EXISTS `Public_Housing_Inspections`;
CREATE SCHEMA Public_Housing_Inspections;

-- Use the created schema
USE Public_Housing_Inspections;

-- Create the table
CREATE TABLE Public_Housing_Inspections (
    Inspection_ID INT PRIMARY KEY,
    PHA_Name VARCHAR(255),
    Cost_of_inspection INT,
    Development_Name VARCHAR(255),
    Address VARCHAR(255),
    City VARCHAR(100),
    State VARCHAR(50),
    Inspection_Date DATE,
    Inspection_Score INT,
    Inspection_Cost DECIMAL(10, 2)
);
SHOW VARIABLES LIKE "secure_file_priv";
-- Load data into the table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/public_housing_inspection_data_corrected.csv'
INTO TABLE Public_Housing_Inspections
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Inspection_ID, PHA_Name, Cost_of_inspection, Development_Name, Address, City, State, Inspection_Date, Inspection_Score, Inspection_Cost);

-- Query to calculate changes in inspection costs
WITH Inspection_Costs AS (
    SELECT 
        PUBLIC_HOUSING_AGENCY_NAME,
        INSPECTION_DATE,
        COST_OF_INSPECTION_IN_DOLLARS
    FROM public_housing_inspections.public_housing_inspection_data_corrected
),
Inspection_Pairs AS (
    SELECT 
        a.PUBLIC_HOUSING_AGENCY_NAME,
        a.INSPECTION_DATE AS MR_INSPECTION_DATE,
        a.COST_OF_INSPECTION_IN_DOLLARS AS MR_INSPECTION_COST,
        b.INSPECTION_DATE AS SECOND_MR_INSPECTION_DATE,
        b.COST_OF_INSPECTION_IN_DOLLARS AS SECOND_MR_INSPECTION_COST
    FROM Inspection_Costs a
    JOIN Inspection_Costs b
        ON a.PUBLIC_HOUSING_AGENCY_NAME = b.PUBLIC_HOUSING_AGENCY_NAME
        AND a.INSPECTION_DATE > b.INSPECTION_DATE
),
Filtered_Inspection_Pairs AS (
    SELECT 
        PUBLIC_HOUSING_AGENCY_NAME,
        MR_INSPECTION_DATE,
        MR_INSPECTION_COST,
        SECOND_MR_INSPECTION_DATE,
        SECOND_MR_INSPECTION_COST,
        (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST,
        ((MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST) * 100 AS PERCENT_CHANGE_IN_COST
    FROM Inspection_Pairs
    WHERE MR_INSPECTION_COST > SECOND_MR_INSPECTION_COST
)
SELECT DISTINCT
    PUBLIC_HOUSING_AGENCY_NAME,
    MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    CHANGE_IN_COST,
    PERCENT_CHANGE_IN_COST
FROM Filtered_Inspection_Pairs;

