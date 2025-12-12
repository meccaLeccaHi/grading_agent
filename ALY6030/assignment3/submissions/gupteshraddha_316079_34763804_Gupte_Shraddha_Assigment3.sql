#Creating a database
CREATE DATABASE Public_datab;
USE Public_datab;
SHOW TABLES;
USE Public_datab;
SHOW TABLES;

#Creating the Table
CREATE TABLE IF NOT EXISTS Public_data (
    INSPECTION_ID INT,
    PUBLIC_HOUSING_AGENCY_NAME VARCHAR(255),
    COST_OF_INSPECTION_IN_DOLLARS INT,
    INSPECTED_DEVELOPMENT_NAME VARCHAR(255),
    INSPECTED_DEVELOPMENT_ADDRESS VARCHAR(255),
    INSPECTED_DEVELOPMENT_CITY VARCHAR(255),
    INSPECTED_DEVELOPMENT_STATE VARCHAR(255),
    INSPECTION_DATE Date,
    INSPECTION_SCORE INT
);

# Enable local_infile
SHOW GLOBAL VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;

#Load the data
LOAD DATA LOCAL INFILE '/Users/shraddha/Desktop/MPSA - SHRADDHA GUPTE/Spring 2025/ALY 6030 - Data Warehousing/Assignement 3/public_housing_inspection_data.csv'
INTO TABLE Public_data
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(INSPECTION_ID, PUBLIC_HOUSING_AGENCY_NAME, COST_OF_INSPECTION_IN_DOLLARS, INSPECTED_DEVELOPMENT_NAME, INSPECTED_DEVELOPMENT_ADDRESS, INSPECTED_DEVELOPMENT_CITY, INSPECTED_DEVELOPMENT_STATE, INSPECTION_DATE, INSPECTION_SCORE);
show Tables;

#Facts and Dimension
#Date Dimension
CREATE TABLE dim_date (
    date_id INT PRIMARY KEY AUTO_INCREMENT,
    inspection_date DATE,
    year INT,
    month INT,
    day INT
);
SELECT COUNT(*) FROM dim_date;
#Agency Dimension
CREATE TABLE dim_agency (
    agency_id INT PRIMARY KEY AUTO_INCREMENT,
    public_housing_agency_name VARCHAR(255)
);
SELECT COUNT(*) FROM dim_agency;
#Development Dimension
CREATE TABLE dim_development (
    development_id INT PRIMARY KEY AUTO_INCREMENT,
    inspected_development_name VARCHAR(255),
    inspected_development_address VARCHAR(255),
    inspected_development_city VARCHAR(255),
    inspected_development_state VARCHAR(255)
);
#Location Dimension
CREATE TABLE dim_location (
    location_id INT PRIMARY KEY AUTO_INCREMENT,
    city VARCHAR(255),
    state VARCHAR(255)
);
#Fact Table
CREATE TABLE fact_inspections (
    inspection_id INT PRIMARY KEY,
    date_id INT,
    agency_id INT,
    development_id INT,
    inspection_score INT,
    cost_of_inspection_in_dollars INT,
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    FOREIGN KEY (agency_id) REFERENCES dim_agency(agency_id),
    FOREIGN KEY (development_id) REFERENCES dim_development(development_id)
);
SELECT COUNT(*) FROM fact_inspections;
show Tables;
#Transactional Fact Table: This table would capture detailed metrics such as the inspection score and inspection cost, 
#along with the foreign keys linking to the dimensions 
CREATE TABLE fact_inspection (
    inspection_id INT PRIMARY KEY,
    inspection_score INT,
    cost_of_inspection_in_dollars INT,
    inspection_date DATE,
    agency_id INT,  -- Foreign key to the Public Housing Agency dimension
    development_id INT,  -- Foreign key to the Development dimension
    location_id INT,  -- Foreign key to the Location dimension
    FOREIGN KEY (agency_id) REFERENCES dim_agency(agency_id),
    FOREIGN KEY (development_id) REFERENCES dim_development(development_id),
    FOREIGN KEY (location_id) REFERENCES dim_location(location_id)
);

#Summary Fact Table: This type of table is typically used for high-level reporting, allowing senior management to track trends over time.
CREATE TABLE fact_inspection_monthly_summary (
    summary_id INT PRIMARY KEY AUTO_INCREMENT,
    year INT,
    month INT,
    total_cost_of_inspection_in_dollars INT,
    total_inspection_count INT
);

#SQL Table Definition for SCD Type 2 
CREATE TABLE dim_public_housing_agency (
    agency_sk INT PRIMARY KEY AUTO_INCREMENT,  -- Surrogate Key
    agency_name VARCHAR(255),
    agency_address VARCHAR(255),
    agency_city VARCHAR(100),
    agency_state VARCHAR(50),
    effective_date DATE,
    expiry_date DATE,
    is_current BOOLEAN
);
WITH inspections_with_dates AS (
    SELECT 
        PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
        CAST(STR_TO_DATE(INSPECTION_DATE, '%Y-%m-%d') AS DATE) AS INSPECTION_DATE,
        COST_OF_INSPECTION_IN_DOLLARS
    FROM Public_data
),
ranked_inspections AS (
    SELECT 
        PHA_NAME,
        INSPECTION_DATE,
        COST_OF_INSPECTION_IN_DOLLARS,
        ROW_NUMBER() OVER (PARTITION BY PHA_NAME ORDER BY INSPECTION_DATE DESC) AS rn
    FROM inspections_with_dates
),
filtered_inspections AS (
    SELECT 
        PHA_NAME,
        MAX(CASE WHEN rn = 1 THEN INSPECTION_DATE END) AS MR_INSPECTION_DATE,
        MAX(CASE WHEN rn = 1 THEN COST_OF_INSPECTION_IN_DOLLARS END) AS MR_INSPECTION_COST,
        MAX(CASE WHEN rn = 2 THEN INSPECTION_DATE END) AS SECOND_MR_INSPECTION_DATE,
        MAX(CASE WHEN rn = 2 THEN COST_OF_INSPECTION_IN_DOLLARS END) AS SECOND_MR_INSPECTION_COST
    FROM ranked_inspections
    WHERE rn <= 2
    GROUP BY PHA_NAME
),
final_result AS (
    SELECT 
        PHA_NAME,
        MR_INSPECTION_DATE,
        MR_INSPECTION_COST,
        SECOND_MR_INSPECTION_DATE,
        SECOND_MR_INSPECTION_COST,
        (MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) AS CHANGE_IN_COST,
        ROUND(((MR_INSPECTION_COST - SECOND_MR_INSPECTION_COST) / SECOND_MR_INSPECTION_COST) * 100, 2) AS PERCENT_CHANGE_IN_COST
    FROM filtered_inspections
    WHERE 
        SECOND_MR_INSPECTION_COST IS NOT NULL -- filters out PHAs with only 1 inspection
        AND MR_INSPECTION_COST > SECOND_MR_INSPECTION_COST -- only PHAs with increased cost
)
SELECT *
FROM final_result;
#Handling TEXT to DATE
#creating a temporary table with cleaned dates
CREATE TEMPORARY TABLE temp_top2 AS
SELECT 
    PUBLIC_HOUSING_AGENCY_NAME AS PHA_NAME,
    STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') AS INSPECTION_DATE,
    COST_OF_INSPECTION_IN_DOLLARS,
    ROW_NUMBER() OVER (
        PARTITION BY PUBLIC_HOUSING_AGENCY_NAME 
        ORDER BY STR_TO_DATE(INSPECTION_DATE, '%m/%d/%Y') DESC
    ) AS rn
FROM Public_data;
CREATE TEMPORARY TABLE top1 AS
SELECT * FROM temp_top2 WHERE rn = 1;

CREATE TEMPORARY TABLE top2 AS
SELECT * FROM temp_top2 WHERE rn = 2;
SELECT 
    top1.PHA_NAME,
    top1.INSPECTION_DATE AS MR_INSPECTION_DATE,
    top1.COST_OF_INSPECTION_IN_DOLLARS AS MR_INSPECTION_COST,
    top2.INSPECTION_DATE AS SECOND_MR_INSPECTION_DATE,
    top2.COST_OF_INSPECTION_IN_DOLLARS AS SECOND_MR_INSPECTION_COST,
    (top1.COST_OF_INSPECTION_IN_DOLLARS - top2.COST_OF_INSPECTION_IN_DOLLARS) AS CHANGE_IN_COST,
    ROUND(
        ((top1.COST_OF_INSPECTION_IN_DOLLARS - top2.COST_OF_INSPECTION_IN_DOLLARS) / 
         top2.COST_OF_INSPECTION_IN_DOLLARS) * 100, 2
    ) AS PERCENT_CHANGE_IN_COST
FROM top1
JOIN top2 
    ON top1.PHA_NAME = top2.PHA_NAME
WHERE top1.COST_OF_INSPECTION_IN_DOLLARS > top2.COST_OF_INSPECTION_IN_DOLLARS;
SELECT COUNT(*) FROM Public_data;


