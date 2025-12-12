DROP DATABASE IF EXISTS `ALY6030_assignment3_dataCleaningPurpose_Lisa`;
CREATE DATABASE IF NOT EXISTS `ALY6030_assignment3_dataCleaningPurpose_Lisa`;
USE `ALY6030_assignment3_dataCleaningPurpose_Lisa`;

-- -----------------------------------------------------------
-- Q3: Choosing the Appropriate Fact Table Types 
-- for Storing Inspection Data and Costs.
-- -----------------------------------------------------------

-- Create the Transaction Fact Table to store individual inspection records. 
-- This table includes detailed information about each inspection, such as the public housing agency
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

-- Create the Periodic Snapshot Fact Table to store aggregated inspection data.
-- This table tracks total inspection costs for each public housing agency at specific snapshot dates.
CREATE TABLE `PeriodicSnapshotFactTable` (
    `PUBLIC_HOUSING_AGENCY_NAME` VARCHAR(100) PRIMARY KEY ,
    `SNAPSHOT_DATE` DATE,
    `TOTAL_COST_OF_INSPECTIONS_IN_DOLLARS` INT
);

-- Enable loading data from local files into the database.
SET GLOBAL local_infile = 1;
-- Insert info into TransactionFactTable
LOAD DATA LOCAL INFILE "/Users/zhangliping/Desktop/NEU/ALY6030/module3/public_housing_inspection_data.csv"
	INTO TABLE `TransactionFactTable`
	FIELDS TERMINATED BY ',' 
	LINES TERMINATED BY '\n' 
	IGNORE 1 LINES
    (`INSPECTION_ID`, `PUBLIC_HOUSING_AGENCY_NAME`, `COST_OF_INSPECTION_IN_DOLLARS`, `INSPECTED_DEVELOPMENT_NAME`,
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


