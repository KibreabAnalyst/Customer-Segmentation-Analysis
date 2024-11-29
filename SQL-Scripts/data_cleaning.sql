-- Step 1: Create the Staging Table Structure
-- Creates a table `online_retail_staging` with the same structure as `online_retail`, but without rows.

SELECT TOP 0 *
INTO online_retail_staging
FROM online_retail;

-- Step 2: Import Data into the Staging Table
-- Copies all data from `online_retail` to `online_retail_staging`.

INSERT INTO online_retail_staging
SELECT *
FROM online_retail;

-- Step 3: Data Cleaning in the Staging Table

-- Step 3a: Handle Missing Values
-- Deletes rows where `description` or `customer_id` is NULL or blank.

DELETE FROM online_retail_staging
WHERE description = ' '
   OR description IS NULL
   OR customer_id = ' '
   OR customer_id IS NULL;

-- Step 3b: Ensure Date Format Consistency
-- Attempt to convert `invoice_date` to DATE. Identify and handle invalid entries.

-- Identify invalid date values (non-date values and numeric junk).
SELECT invoice_date
FROM online_retail_staging
WHERE TRY_CONVERT(DATE, invoice_date, 103) IS NULL;

-- Delete rows with invalid date values.
DELETE FROM online_retail_staging
WHERE TRY_CONVERT(DATE, invoice_date, 103) IS NULL;

-- Identify invalid date values (alphabetic characters (words))
SELECT invoice_date
FROM online_retail_staging
WHERE invoice_date LIKE '%[A-Za-z]%';

-- Delete rows with invalid date values.
DELETE FROM online_retail_staging
WHERE invoice_date LIKE '%[A-Za-z]%';

-- Identify rows containing the double quote (") symbol
SELECT invoice_date
FROM online_retail_staging
WHERE invoice_date LIKE '%"%';

-- Delete rows containing the double quote (") symbol
DELETE FROM online_retail_staging
WHERE invoice_date LIKE '%"%';

-- Step 3c: Clean the `stock_code` Column
-- Deletes rows with suspicious `stock_code` values, such as invalid characters or specific business rules.

DELETE FROM online_retail_staging
WHERE LEN(stock_code) = 1
   OR stock_code LIKE '%[^A-Za-z0-9]%'
   OR stock_code IN ('POST', 'BANK CHARGES', 'AMAZONFEE', '0', 'C2', 'DOT', 'PADS', 'CRUK')
   OR stock_code LIKE 'DCGS%';

-- Step 3d: Remove Invalid `quantity` and `unit_price` Values
-- Deletes rows with negative or zero `quantity` or `unit_price`.

DELETE FROM online_retail_staging
WHERE quantity <= 0
   OR unit_price <= 0;

-- Step 3e: Clean the `description` Column
-- Removes double quotes and trims leading/trailing spaces.

-- Identify rows containing double quotes (")
SELECT *
FROM online_retail_staging
WHERE description LIKE '%"%';

-- Remove double quotes (")
-- This update query replaces all occurrences of double quotes with an empty string ('').
UPDATE online_retail_staging
SET description = REPLACE(description, '"', '')
WHERE description LIKE '%"%';

UPDATE online_retail_staging
SET description = TRIM(description);

-- Step 4: Ensure Correct Data Types for Numeric Columns

-- Drop computed column `total_price` (if it exists).
ALTER TABLE online_retail_staging
DROP COLUMN total_price;

-- Convert `quantity` to INT.
ALTER TABLE online_retail_staging
ALTER COLUMN quantity INT;

-- Recreate the `total_price` computed column with appropriate data type.
ALTER TABLE online_retail_staging
ADD total_price AS CAST(quantity * unit_price AS DECIMAL(10, 2));

-- Step 5: Remove Duplicates
-- Deletes duplicate rows based on `invoice_no` and `stock_code`, keeping the most recent entry.

WITH duplicate AS (
   SELECT *,
          ROW_NUMBER() OVER (PARTITION BY invoice_no, stock_code ORDER BY invoice_date DESC) AS row_num
   FROM online_retail_staging
)
DELETE FROM duplicate
WHERE row_num > 1;

-- Step 6: Verify the Cleaned Data

-- Check for remaining invalid `quantity` values.
SELECT DISTINCT quantity
FROM online_retail_staging
WHERE quantity LIKE '%[^0-9]%'
   OR quantity LIKE '% %';

-- Check the data type of `quantity`.
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'online_retail_staging' AND COLUMN_NAME = 'quantity';

-- Preview the cleaned data.
SELECT TOP 100 *
FROM online_retail_staging;

-- Verify data integrity and ensure no invalid or suspicious entries remain.
SELECT *
FROM online_retail_staging;
