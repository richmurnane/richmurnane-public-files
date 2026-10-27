-- =============================================================================
-- Session A: Snowflake Foundations - Worksheet SQL
-- =============================================================================
-- This file contains all SQL from the Session A hands-on worksheet.
-- Attendees can paste these into a Snowsight worksheet and follow along.
-- =============================================================================

-- =====================
-- SET SESSION CONTEXT
-- =====================
-- Run these first to make sure your worksheet is pointed at the right place.
-- ROLE controls what you're allowed to do; WAREHOUSE is the compute that runs your queries.
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE ACME_WH;
USE DATABASE ACME;
USE SCHEMA RAW;


-- =====================
-- PART 1: Explore the Data
-- =====================
-- The ACME database has three schemas:
--   RAW        - pre-loaded sample data (clients, campaigns, daily impressions, creatives, briefs)
--   STAGING    - a file stage and file format for the COPY INTO exercise
--   ANALYTICS  - your workspace to create tables, views, and pipelines

-- 1.1 Browse the clients table (15 fictional advertising clients)
SELECT * FROM ACME.RAW.CLIENTS;

-- Filter to just APAC clients
SELECT * FROM ACME.RAW.CLIENTS
WHERE region = 'APAC';

-- 1.2 Campaigns and budgets - ORDER BY sorts results (DESC = largest first)
SELECT
    campaign_name,
    channel,
    budget,
    status
FROM ACME.RAW.CAMPAIGNS
ORDER BY budget DESC;

-- 1.3 JOIN two tables together - connect campaigns back to their client
-- JOIN matches rows where client_id is the same in both tables
SELECT
    cl.client_name,
    ca.campaign_name,
    ca.channel,
    ca.budget,
    ca.status
FROM ACME.RAW.CAMPAIGNS ca
JOIN ACME.RAW.CLIENTS cl ON ca.client_id = cl.client_id
ORDER BY ca.budget DESC;

-- 1.4 Aggregate daily performance with GROUP BY
-- SUM() adds up values per group; ROUND() controls decimal places
-- NULLIF() prevents divide-by-zero when calculating click-through rate
SELECT
    ca.campaign_name,
    SUM(di.impressions) AS total_impressions,
    SUM(di.clicks) AS total_clicks,
    SUM(di.spend) AS total_spend,
    ROUND(SUM(di.clicks) / NULLIF(SUM(di.impressions), 0) * 100, 2) AS ctr_pct
FROM ACME.RAW.DAILY_IMPRESSIONS di
JOIN ACME.RAW.CAMPAIGNS ca ON di.campaign_id = ca.campaign_id
GROUP BY ca.campaign_name
ORDER BY total_spend DESC;

-- TRY IT: Modify the above to show performance by CHANNEL instead of campaign name

-- TRY IT: Write a query that finds the top 3 clients by annual_budget.
-- Hint: SELECT ... FROM ACME.RAW.CLIENTS ORDER BY ... LIMIT ...


-- =====================
-- PART 2: Create Your Own Table
-- =====================
-- Switch to the ANALYTICS schema - this is your workspace to build in.
USE SCHEMA ACME.ANALYTICS;

-- 2.1 Create a summary table using CTAS (CREATE TABLE ... AS SELECT)
-- This runs the query and stores the results as a new table in one step.
CREATE OR REPLACE TABLE CAMPAIGN_SUMMARY AS
SELECT
    ca.campaign_id,
    ca.campaign_name,
    cl.client_name,
    ca.channel,
    ca.budget,
    SUM(di.impressions) AS total_impressions,
    SUM(di.clicks) AS total_clicks,
    SUM(di.conversions) AS total_conversions,
    SUM(di.spend) AS total_spend
FROM ACME.RAW.CAMPAIGNS ca
JOIN ACME.RAW.CLIENTS cl ON ca.client_id = cl.client_id
LEFT JOIN ACME.RAW.DAILY_IMPRESSIONS di ON ca.campaign_id = di.campaign_id
GROUP BY ca.campaign_id, ca.campaign_name, cl.client_name, ca.channel, ca.budget;

SELECT * FROM CAMPAIGN_SUMMARY ORDER BY total_spend DESC;

-- 2.2 Create a view
-- A view is a saved query - it doesn't store data, it runs the query each time you SELECT from it.
-- Useful for giving people a simplified, curated lens on the data.
CREATE OR REPLACE VIEW TOP_CAMPAIGNS AS
SELECT
    campaign_name,
    client_name,
    channel,
    total_spend,
    total_clicks,
    ROUND(total_clicks / NULLIF(total_impressions, 0) * 100, 2) AS ctr_pct
FROM CAMPAIGN_SUMMARY
WHERE total_spend > 0
ORDER BY total_spend DESC
LIMIT 10;

SELECT * FROM TOP_CAMPAIGNS;

-- TRY IT: Create your own view called UNDERPERFORMERS that shows campaigns
-- where total_spend is greater than budget (i.e., they overspent).
-- Hint: use CAMPAIGN_SUMMARY and a WHERE clause comparing total_spend to budget.


-- =====================
-- PART 3: Load Data from a File
-- =====================
-- A CSV file with 5 new clients is already sitting in an internal stage.
-- A STAGE is a named location where files live before (or after) being loaded into tables.
-- Internal stages are storage managed by Snowflake; external stages point to S3, Azure Blob, or GCS.
-- Docs: https://docs.snowflake.com/en/sql-reference/sql/create-stage

-- 3.1 Preview the staged file without loading it
-- A FILE FORMAT tells Snowflake how to parse a file - delimiter, whether there's a header row,
-- quoting rules, etc. Think of it as a reusable "instructions label" for reading files.
-- We created CSV_FORMAT in advance; you can also define them inline.
-- Docs: https://docs.snowflake.com/en/sql-reference/sql/create-file-format
-- $1, $2, etc. reference columns by position since we haven't mapped them to a table yet.
SELECT $1, $2, $3, $4, $5, $6, $7, $8
FROM @ACME.STAGING.WORKSHOP_FILES/new_clients.csv
(FILE_FORMAT => ACME.STAGING.CSV_FORMAT)
LIMIT 10;

-- 3.2 Create the target table that will receive the data
CREATE OR REPLACE TABLE ACME.ANALYTICS.NEW_CLIENTS (
    client_id INT,
    client_name VARCHAR(100),
    industry VARCHAR(50),
    region VARCHAR(30),
    account_manager VARCHAR(80),
    contract_start_date DATE,
    annual_budget DECIMAL(12,2),
    is_active BOOLEAN
);

-- 3.3 Load the file with COPY INTO
-- COPY INTO is Snowflake's bulk loader - it reads from a stage and inserts into a table.
COPY INTO ACME.ANALYTICS.NEW_CLIENTS
FROM @ACME.STAGING.WORKSHOP_FILES/new_clients.csv
FILE_FORMAT = ACME.STAGING.CSV_FORMAT;

-- Verify the load - you should see 5 rows
SELECT * FROM ACME.ANALYTICS.NEW_CLIENTS;

-- TRY IT: Write a query that combines NEW_CLIENTS with the original CLIENTS table.
-- Hint: SELECT * FROM ACME.RAW.CLIENTS UNION ALL SELECT * FROM ACME.ANALYTICS.NEW_CLIENTS;


-- =====================
-- PART 4: Time Travel and Cloning
-- =====================
-- Two features unique to Snowflake. Time Travel lets you query (or restore) data as it existed
-- at a previous point in time. Cloning creates instant, zero-copy duplicates of tables or schemas.

-- 4.1 "Accidentally" delete data
DELETE FROM ACME.ANALYTICS.NEW_CLIENTS WHERE region = 'APAC';

-- Every query in Snowflake gets a unique query ID (a UUID like '01b8a4e2-0001-b572-...').
-- LAST_QUERY_ID() returns the ID of the most recently executed statement (our DELETE above).
-- SET stores it in a session variable so we can reference it later for Time Travel.
SET delete_query_id = LAST_QUERY_ID();

-- Check - Blue Coral Resorts should be gone
SELECT * FROM ACME.ANALYTICS.NEW_CLIENTS;

-- 4.2 Use Time Travel to see the table BEFORE the delete
-- Time Travel can reference a point in time two ways:
--   BEFORE(STATEMENT => 'query_id')  - the state right before a specific query ran
--   AT(OFFSET => -N)                 - the state N seconds ago (e.g., -300 = 5 min ago)
-- We use BEFORE + statement ID here because it's precise regardless of how fast you run the steps.
SELECT * FROM ACME.ANALYTICS.NEW_CLIENTS
BEFORE(STATEMENT => $delete_query_id);

-- 4.3 Restore the deleted data
-- We INSERT back only the rows that were deleted (WHERE region = 'APAC')
-- by selecting them from the historical version of the table.
INSERT INTO ACME.ANALYTICS.NEW_CLIENTS
SELECT * FROM ACME.ANALYTICS.NEW_CLIENTS
BEFORE(STATEMENT => $delete_query_id)
WHERE region = 'APAC';

-- Verify restoration - all 5 rows should be back
SELECT * FROM ACME.ANALYTICS.NEW_CLIENTS;

-- 4.4 Zero-copy cloning
-- CLONE creates an instant copy that shares the underlying storage.
-- No data is physically duplicated - changes to either copy are independent.
-- Works on tables, schemas, and entire databases. Common for dev/test snapshots.
CREATE OR REPLACE TABLE ACME.ANALYTICS.CLIENTS_BACKUP
CLONE ACME.RAW.CLIENTS;

SELECT COUNT(*) FROM ACME.ANALYTICS.CLIENTS_BACKUP;

-- TRY IT: Clone the entire RAW schema into a new schema called RAW_SNAPSHOT
CREATE OR REPLACE SCHEMA ACME.RAW_SNAPSHOT CLONE ACME.RAW;

-- TRY IT: Now that you have RAW_SNAPSHOT, UPDATE a row in RAW_SNAPSHOT.CLIENTS
-- (e.g., change a client's region) and then compare it to the original RAW.CLIENTS.
-- This proves the clone is independent - your change only affects the copy.


-- =====================
-- PART 5: Stretch Goals
-- =====================
-- Finished early? Try these bonus exercises.

-- 5A: Explore UNDROP
-- When you DROP an object, Snowflake doesn't delete it immediately - it moves to a
-- recoverable state (governed by the DATA_RETENTION_TIME_IN_DAYS setting, default 1 day).
-- UNDROP brings it back. Works on tables, schemas, and databases.

-- First, drop the backup table we just cloned
DROP TABLE ACME.ANALYTICS.CLIENTS_BACKUP;

-- Confirm it's gone
SHOW TABLES LIKE 'CLIENTS_BACKUP' IN SCHEMA ACME.ANALYTICS;

-- Bring it back
UNDROP TABLE ACME.ANALYTICS.CLIENTS_BACKUP;

-- Verify it's restored
SELECT COUNT(*) FROM ACME.ANALYTICS.CLIENTS_BACKUP;

-- 5B: Query semi-structured JSON data
-- Snowflake stores JSON natively in VARIANT columns - no ETL needed to flatten it first.
SELECT * FROM ACME.RAW.CAMPAIGN_BRIEFS;

-- Use colon notation ( : ) to reach into JSON keys, and ::TYPE to cast the result
SELECT
    brief_id,
    brief_data:title::STRING AS title,
    brief_data:client::STRING AS client,
    brief_data:objective::STRING AS objective
FROM ACME.RAW.CAMPAIGN_BRIEFS;

-- Use dot notation for nested keys (e.g., target_audience.age_range)
SELECT
    brief_data:title::STRING AS title,
    brief_data:target_audience.age_range::STRING AS target_age,
    brief_data:success_metrics.target_roas::FLOAT AS target_roas
FROM ACME.RAW.CAMPAIGN_BRIEFS;

-- TRY IT: Extract all the interests from the target_audience as a flattened list.
-- Hint: use LATERAL FLATTEN(input => brief_data:target_audience.interests) and look at value::STRING
