DROP DATABASE IF EXISTS Housing;
CREATE DATABASE IF NOT EXISTS Housing;
USE Housing; 

SELECT *
FROM inspection
ORDER BY INSPECTION_DATE DESC;

-- after import csv file through wizard,
-- Edit date format in table

SET SQL_SAFE_UPDATES = 0;
-- change all delimiters from / to -
UPDATE inspection
SET INSPECTION_DATE = REPLACE(INSPECTION_DATE, '/', '-')
WHERE INSPECTION_DATE LIKE '%/%';

-- convert the string to date using STR_TO_DATE
UPDATE inspection
SET INSPECTION_DATE = CASE
    WHEN INSPECTION_DATE LIKE '%-%-____' THEN STR_TO_DATE(INSPECTION_DATE, '%c-%e-%Y')
    ELSE INSPECTION_DATE
END
WHERE INSPECTION_DATE LIKE '%-%-____';

-- they now have a silimar format, transform the column format to DATE
ALTER TABLE inspection
MODIFY COLUMN INSPECTION_DATE DATE;
-- check for any distinct values left out
SELECT DISTINCT INSPECTION_DATE
FROM inspection;
-- validate the date transformation if successful 
describe inspection;
SET SQL_SAFE_UPDATES = 1;


-- Q5
-- step1: Create a new table to retrieve the most recent and second most recent inspections for each PHA
DROP TABLE IF EXISTS pha_inspections;
CREATE TABLE pha_inspections AS
SELECT 
    PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
    INSPECTION_DATE AS MR_INSPECTION_DATE,
    COST_OF_INSPECTION_IN_DOLLARS AS MR_INSPECTION_COST,
    Lead(INSPECTION_DATE, 1) OVER (PARTITION BY PUBLIC_HOUSING_AGENCY_NAME ORDER BY INSPECTION_DATE DESC) AS SECOND_MR_INSPECTION_DATE,
    Lead(COST_OF_INSPECTION_IN_DOLLARS, 1) OVER (PARTITION BY PUBLIC_HOUSING_AGENCY_NAME ORDER BY INSPECTION_DATE DESC) AS SECOND_MR_INSPECTION_COST
FROM inspection;

SELECT * FROM pha_inspections;-- view the table
    
-- Step2: Filter out PHAs that do not have a second most recent inspection
DROP TABLE IF EXISTS t2;
CREATE TABLE t2 AS
SELECT *
FROM pha_inspections
WHERE SECOND_MR_INSPECTION_DATE IS NOT NULL AND SECOND_MR_INSPECTION_COST IS NOT NULL;

SELECT * FROM t2;

-- step3: Add on cost change (positive), and percent change to t2
DROP TABLE IF EXISTS t3;
CREATE TABLE t3 AS
SELECT 
	PHA_NAME,
    MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    -- new columns, change in cost
    (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST,
	CAST(((MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST) * 100 AS DECIMAL(10, 2)) AS PERCENT_CHANGE_IN_COST
FROM pha_inspections
WHERE (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) > 0; -- only store the positive costs diffs

SELECT * FROM t3;

-- step4: Limit PHA name to only one time display, create ranking as a new column
DROP TABLE IF EXISTS t4;
CREATE TABLE t4 AS
SELECT
    *,
    RANK() OVER (PARTITION BY PHA_NAME ORDER BY MR_INSPECTION_DATE DESC) AS RANKING
FROM t3;
SELECT * FROM t4;

-- step5: final output
DROP TABLE IF EXISTS final_output;
CREATE TABLE final_output AS
SELECT
    PHA_NAME,
    MR_INSPECTION_DATE,
    MR_INSPECTION_COST,
    SECOND_MR_INSPECTION_DATE,
    SECOND_MR_INSPECTION_COST,
    CHANGE_IN_COST,
    PERCENT_CHANGE_IN_COST
FROM t4
WHERE RANKING = 1; -- filter out the first mr record of each PHA

SELECT * FROM final_output;

-- Export final_output through wizard.

