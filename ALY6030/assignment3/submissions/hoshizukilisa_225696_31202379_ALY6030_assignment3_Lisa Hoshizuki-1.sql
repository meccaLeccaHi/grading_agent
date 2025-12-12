DROP DATABASE IF EXISTS `ALY6030_assignment3_Lisa`;
CREATE DATABASE IF NOT EXISTS `ALY6030_assignment3_Lisa`;
USE `ALY6030_assignment3_Lisa`;

-- -----------------------------------------------------------
-- Q3: Choosing the Appropriate Fact Table Types 
-- for Storing Inspection Data and Costs.
-- -----------------------------------------------------------

-- CREATE TABLE TransactionFactTable
CREATE TABLE `TransactionFactTable` (
    `INSPECTION_ID` INT PRIMARY KEY,
    `PUBLIC_HOUSING_AGENCY_NAME` VARCHAR(100),
    `COST_OF_INSPECTION_IN_DOLLARS` INT,
    `INSPECTED_DEVELOPMENT_NAME` VARCHAR(100),
    `INSPECTED_DEVELOPMENT_ADDRESS` VARCHAR(100),
    `INSPECTED_DEVELOPMENT_CITY` VARCHAR(100),
    `INSPECTED_DEVELOPMENT_STATE` VARCHAR(10),
    `INSPECTION_DATE` DATE,
    `INSPECTION_SCORE` INT
);

-- CREATE TABLE PeriodicSnapshotFactTable
CREATE TABLE `PeriodicSnapshotFactTable` (
    `PUBLIC_HOUSING_AGENCY_NAME` VARCHAR(100) PRIMARY KEY ,
    `SNAPSHOT_DATE` DATE,
    `TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS` INT
);


SET GLOBAL local_infile = 1;
-- Insert info into TransactionFactTable
LOAD DATA LOCAL INFILE 
"/Users/zhangliping/Desktop/NEU/ALY6030/module3/cleaned_public_housing_inspection_data.csv"
 INTO TABLE `TransactionFactTable`
 FIELDS TERMINATED BY ',' 
 LINES TERMINATED BY '\n' 
 IGNORE 1 LINES
    (`INSPECTION_ID`, `PUBLIC_HOUSING_AGENCY_NAME`, `COST_OF_INSPECTION_IN_DOLLARS`, `INSPECTED_DEVELOPMENT_NAME` ,
    `INSPECTED_DEVELOPMENT_ADDRESS`, `INSPECTED_DEVELOPMENT_CITY`, `INSPECTED_DEVELOPMENT_STATE`,
    @INSPECTION_DATE, `INSPECTION_SCORE`)
    SET `INSPECTION_DATE` = STR_TO_DATE(@INSPECTION_DATE, '%m/%d/%Y');
    
-- Perform a data quality check to identify missing values in the Transaction Fact Table.
-- For each column, calculate the total number of missing (NULL) values and output the results.     
SELECT 
    SUM(CASE WHEN `INSPECTION_ID` IS NULL THEN 1 ELSE 0 END) AS `INSPECTION_ID_Missing`,
    SUM(CASE WHEN `PUBLIC_HOUSING_AGENCY_NAME` IS NULL THEN 1 ELSE 0 END) AS `PUBLIC_HOUSING_AGENCY_NAME_Missing`,
    SUM(CASE WHEN `COST_OF_INSPECTION_IN_DOLLARS` IS NULL THEN 1 ELSE 0 END) AS `COST_OF_INSPECTION_IN_DOLLARS_Missing`,
    SUM(CASE WHEN `INSPECTED_DEVELOPMENT_NAME` IS NULL THEN 1 ELSE 0 END) AS `INSPECTED_DEVELOPMENT_NAME_Missing`,
    SUM(CASE WHEN `INSPECTED_DEVELOPMENT_ADDRESS` IS NULL THEN 1 ELSE 0 END) AS `INSPECTED_DEVELOPMENT_ADDRESS_Missing`,
    SUM(CASE WHEN `INSPECTED_DEVELOPMENT_CITY` IS NULL THEN 1 ELSE 0 END) AS `INSPECTED_DEVELOPMENT_CITY_Missing`,
    SUM(CASE WHEN `INSPECTED_DEVELOPMENT_STATE` IS NULL THEN 1 ELSE 0 END) AS `INSPECTED_DEVELOPMENT_STATE_Missing`,
    SUM(CASE WHEN `INSPECTION_DATE` IS NULL THEN 1 ELSE 0 END) AS `INSPECTION_DATE_Missing`,
    SUM(CASE WHEN `INSPECTION_SCORE` IS NULL THEN 1 ELSE 0 END) AS `INSPECTION_SCORE_Missing`
FROM `TransactionFactTable`;


-- Insert info into PeriodicSnapshotFactTable
INSERT IGNORE INTO `PeriodicSnapshotFactTable` (`PUBLIC_HOUSING_AGENCY_NAME`, `SNAPSHOT_DATE`, 
`TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS`)
SELECT
    `PUBLIC_HOUSING_AGENCY_NAME`,
    DATE_FORMAT(`INSPECTION_DATE`, '%Y-%m-01') AS `SNAPSHOT_DATE`,
    SUM(`COST_OF_INSPECTION_IN_DOLLARS`) AS `TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS`
FROM
    `TransactionFactTable`
GROUP BY
    `PUBLIC_HOUSING_AGENCY_NAME`, `SNAPSHOT_DATE`
ORDER BY
    `PUBLIC_HOUSING_AGENCY_NAME`, `SNAPSHOT_DATE`;

-- -----------------------------------------------------------
-- Q4: How to handle changes in public housing agency names 
-- and addresses (slowly changing dimensions).
-- -----------------------------------------------------------

-- Create temporary table staging_periodic_snapshot
CREATE TABLE `staging_periodic_snapshot` (
    `PUBLIC_HOUSING_AGENCY_NAME` VARCHAR(100),
    `SNAPSHOT_DATE` DATE,
    `TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS` INT
);

-- Insert new data into staging_periodic_snapshot
INSERT INTO `staging_periodic_snapshot` (`PUBLIC_HOUSING_AGENCY_NAME`, `SNAPSHOT_DATE`, `TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS`)
SELECT 
    `PUBLIC_HOUSING_AGENCY_NAME`,
    DATE_FORMAT(`INSPECTION_DATE`, '%Y-%m-01') AS `SNAPSHOT_DATE`,
    SUM(`COST_OF_INSPECTION_IN_DOLLARS`) AS `TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS`
FROM 
    `TransactionFactTable`
GROUP BY 
    `PUBLIC_HOUSING_AGENCY_NAME`, `SNAPSHOT_DATE`;

-- Drop and recreate PeriodicSnapshotFactTable with updated schema
DROP TABLE IF EXISTS `PeriodicSnapshotFactTable`;

CREATE TABLE `PeriodicSnapshotFactTable` (
    `PUBLIC_HOUSING_AGENCY_NAME` VARCHAR(100),
    `SNAPSHOT_DATE` DATE,
    `TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS` INT,
    `effective_start_date` DATE NOT NULL,
    `effective_end_date` DATE,
    `is_current` BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (`PUBLIC_HOUSING_AGENCY_NAME`, `SNAPSHOT_DATE`)
);

-- Insert new data into PeriodicSnapshotFactTable, checking if the snapshot already exists
-- and marking older entries as non-current
-- Insert or update records in `PeriodicSnapshotFactTable`
INSERT INTO `PeriodicSnapshotFactTable` (
    `PUBLIC_HOUSING_AGENCY_NAME`,
    `SNAPSHOT_DATE`,
    `TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS`,
    `effective_start_date`,
    `effective_end_date`,
    `is_current`
)
SELECT 
    s.`PUBLIC_HOUSING_AGENCY_NAME`,
    s.`SNAPSHOT_DATE`,
    s.`TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS`,
    s.`SNAPSHOT_DATE` AS `effective_start_date`,  -- Set start date to snapshot date
    NULL AS `effective_end_date`,                 -- New records have NULL as end date
    TRUE AS `is_current`
FROM 
    `staging_periodic_snapshot` AS s
LEFT JOIN 
    `PeriodicSnapshotFactTable` AS p
ON 
    s.`PUBLIC_HOUSING_AGENCY_NAME` = p.`PUBLIC_HOUSING_AGENCY_NAME`
    AND s.`SNAPSHOT_DATE` = p.`SNAPSHOT_DATE`
WHERE 
    p.`PUBLIC_HOUSING_AGENCY_NAME` IS NULL;       -- Insert only if no matching record exists

-- Mark old records as non-current and set the end date only if there’s a newer record
UPDATE `PeriodicSnapshotFactTable` AS p
INNER JOIN `staging_periodic_snapshot` AS s
ON p.`PUBLIC_HOUSING_AGENCY_NAME` = s.`PUBLIC_HOUSING_AGENCY_NAME`
    AND p.`SNAPSHOT_DATE` < s.`SNAPSHOT_DATE`    -- Only for older records
SET 
    p.`is_current` = FALSE,
    p.`effective_end_date` = s.`SNAPSHOT_DATE`   -- Set the end date to the new snapshot date
WHERE 
    p.`is_current` = TRUE;
    
    
-- -------------------------------------------------------------------------
-- Q5:Filter out the PHA data according to the specified conditions 
-- and calculate the change in inspection costs.
-- -------------------------------------------------------------------------
SET SESSION sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));
-- Drop the temporary table if it exists
DROP TEMPORARY TABLE IF EXISTS `TempSnapshotTable`;
CREATE TEMPORARY TABLE TempSnapshotTable AS
SELECT
    PUBLIC_HOUSING_AGENCY_NAME,  
    INSPECTION_DATE AS MR_INSPECTION_DATE,
    COST_OF_INSPECTION_IN_DOLLARS AS MR_INSPECTION_COST,
    LEAD(INSPECTION_DATE) OVER (PARTITION BY PUBLIC_HOUSING_AGENCY_NAME 
    ORDER BY INSPECTION_DATE DESC) AS SECOND_MR_INSPECTION_DATE,
    LEAD(COST_OF_INSPECTION_IN_DOLLARS) OVER (PARTITION BY PUBLIC_HOUSING_AGENCY_NAME 
    ORDER BY INSPECTION_DATE DESC) AS SECOND_MR_INSPECTION_COST,
    ROW_NUMBER() OVER (PARTITION BY PUBLIC_HOUSING_AGENCY_NAME 
    ORDER BY INSPECTION_DATE DESC) AS InspectionCount
FROM
    TransactionFactTable;

-- Retrieve data from TempSnapshotTable based on specified conditions
SELECT
    PUBLIC_HOUSING_AGENCY_NAME,
    MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    (SECOND_MR_INSPECTION_COST - MR_INSPECTION_COST) AS CHANGE_IN_COST,
    ((SECOND_MR_INSPECTION_COST - MR_INSPECTION_COST) / MR_INSPECTION_COST) * 100 
    AS PERCENT_CHANGE_IN_COST
FROM
    TempSnapshotTable
WHERE
    InspectionCount > 1
    AND (SECOND_MR_INSPECTION_COST - MR_INSPECTION_COST) > 0
GROUP BY
    PUBLIC_HOUSING_AGENCY_NAME;
    
    