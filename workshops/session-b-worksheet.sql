-- =============================================================================
-- Session B: Collaboration, Sharing, and Governance - Worksheet SQL
-- =============================================================================
-- This file contains all SQL from the Session B hands-on worksheet.
-- Attendees paste these into a Snowsight worksheet and follow along.
--
-- Pre-requisites: setup-golden-account.sql has been run (roles and policies exist).
-- =============================================================================

-- =====================
-- SET SESSION CONTEXT
-- =====================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE ACME_WH;
USE DATABASE ACME;
USE SCHEMA RAW;


-- =====================
-- PART 1: Role-Based Access Control (RBAC)
-- =====================
-- Snowflake uses RBAC to control who can see and do what.
-- Roles are granted privileges (SELECT, INSERT, CREATE, etc.) on objects.
-- Users are assigned roles. A user can switch between their assigned roles at any time.

-- 1.1 See what roles exist in your account
SHOW ROLES;

-- Three custom roles were pre-created for this workshop:
--   ANALYST          - read-only access to RAW and ANALYTICS
--   CAMPAIGN_MANAGER - read RAW, read+write ANALYTICS, restricted by row access policy
--   DATA_ENGINEER    - full access for building pipelines (Session C)

-- 1.2 See what grants ANALYST has
SHOW GRANTS TO ROLE ANALYST;

-- 1.3 Switch to the ANALYST role and try querying
USE ROLE ANALYST;

SELECT * FROM ACME.RAW.CLIENTS;
-- This works - ANALYST has SELECT on RAW tables.

-- Now try accessing the STAGING schema:
-- (Uncomment and run the line below - it should fail)
-- SELECT * FROM @ACME.STAGING.WORKSHOP_FILES;
-- Expected error: insufficient privileges. ANALYST has no grants on STAGING.

-- 1.4 Switch to CAMPAIGN_MANAGER and try creating a table in ANALYTICS
USE ROLE CAMPAIGN_MANAGER;

CREATE OR REPLACE TABLE ACME.ANALYTICS.MY_NOTES (
    note_id INT,
    note_text VARCHAR(500)
);
-- This works - CAMPAIGN_MANAGER has CREATE TABLE on ANALYTICS.

INSERT INTO ACME.ANALYTICS.MY_NOTES VALUES (1, 'Testing RBAC in Session B');

SELECT * FROM ACME.ANALYTICS.MY_NOTES;

-- 1.5 Switch back to ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- TRY IT: As ACCOUNTADMIN, grant SELECT on ACME.RAW.CREATIVES to the ANALYST role,
-- then switch to ANALYST and verify you can query it.
-- Hint: GRANT SELECT ON TABLE ACME.RAW.CREATIVES TO ROLE ANALYST;
-- (This grant already exists from setup, so it will succeed silently - that's fine.)


-- =====================
-- PART 2: Column-Level Security (Dynamic Data Masking)
-- =====================
-- A masking policy controls what value a user sees for a column based on their role.
-- The data isn't changed -- it's masked at query time. Different roles see different values.
-- Docs: https://docs.snowflake.com/en/sql-reference/sql/create-masking-policy

-- 2.1 Look at the pre-created masking policy
-- This policy returns the real value for ACCOUNTADMIN/SYSADMIN, and NULL for everyone else.
-- Here's what the policy looks like (it was pre-created in the account setup):
--
--   CREATE OR REPLACE MASKING POLICY ACME.RAW.BUDGET_MASK AS (val DECIMAL(12,2))
--   RETURNS DECIMAL(12,2) ->
--     CASE
--       WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN') THEN val
--       ELSE NULL
--     END;
--
-- It's a CASE statement: if the calling role is an admin, return the real value. Otherwise, NULL.
DESCRIBE MASKING POLICY ACME.RAW.BUDGET_MASK;

-- 2.2 Apply the masking policy to the annual_budget column on CLIENTS
ALTER TABLE ACME.RAW.CLIENTS
MODIFY COLUMN annual_budget
SET MASKING POLICY ACME.RAW.BUDGET_MASK;

-- 2.3 Query as ACCOUNTADMIN - you should see the real budget values
SELECT client_name, region, annual_budget FROM ACME.RAW.CLIENTS;

-- 2.4 Now switch to ANALYST and query the same table
USE ROLE ANALYST;

SELECT client_name, region, annual_budget FROM ACME.RAW.CLIENTS;
-- The annual_budget column should show NULL for every row.
-- The data is still there -- the ANALYST role just can't see it.

-- 2.5 Switch back to ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- TRY IT: Apply the same masking policy to the budget column on the CAMPAIGNS table.
-- Then switch to ANALYST and verify the budget is masked there too.
-- Hint: ALTER TABLE ACME.RAW.CAMPAIGNS MODIFY COLUMN budget SET MASKING POLICY ACME.RAW.BUDGET_MASK;


-- =====================
-- PART 3: Row-Level Security (Row Access Policies)
-- =====================
-- A row access policy controls which ROWS a user sees, based on their role.
-- Like masking, the data isn't deleted -- it's filtered at query time.
-- Docs: https://docs.snowflake.com/en/sql-reference/sql/create-row-access-policy

-- 3.1 Look at the pre-created row access policy
-- This policy controls which rows are visible based on the calling role.
-- Here's what the policy looks like (it was pre-created in the account setup):
--
--   CREATE OR REPLACE ROW ACCESS POLICY ACME.RAW.REGION_FILTER AS (region_val VARCHAR)
--   RETURNS BOOLEAN ->
--     CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN', 'DATA_ENGINEER')
--     OR (CURRENT_ROLE() = 'CAMPAIGN_MANAGER' AND region_val = 'North America')
--     OR (CURRENT_ROLE() = 'ANALYST');
--
-- It returns TRUE or FALSE per row. ACCOUNTADMIN/SYSADMIN/DATA_ENGINEER/ANALYST see all rows.
-- CAMPAIGN_MANAGER only sees rows where region = 'North America'.
DESCRIBE ROW ACCESS POLICY ACME.RAW.REGION_FILTER;

-- 3.2 Apply the row access policy to the CLIENTS table on the region column
ALTER TABLE ACME.RAW.CLIENTS
ADD ROW ACCESS POLICY ACME.RAW.REGION_FILTER ON (region);

-- 3.3 Query as ACCOUNTADMIN - you should see all 15 clients
SELECT client_name, region FROM ACME.RAW.CLIENTS;

-- 3.4 Switch to CAMPAIGN_MANAGER - should only see North America clients
USE ROLE CAMPAIGN_MANAGER;

SELECT client_name, region FROM ACME.RAW.CLIENTS;
-- You should see ~6 rows (only North America clients).

-- 3.5 Switch to ANALYST - should see all regions
USE ROLE ANALYST;

SELECT client_name, region FROM ACME.RAW.CLIENTS;
-- ANALYST sees all 15 rows (the policy allows all regions for ANALYST).

-- 3.6 Switch back to ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- TRY IT: Apply the same row access policy to the CAMPAIGNS table on the region column...
-- wait, CAMPAIGNS doesn't have a region column! Think about how you'd filter campaigns
-- by region. You'd need to JOIN to CLIENTS. This is a real-world design challenge:
-- row access policies work on columns in the table they're applied to.
-- One approach: add a region column to CAMPAIGNS. Another: use a secure view that joins.


-- =====================
-- PART 4: Secure Data Sharing (Guided Demo)
-- =====================
-- Rich will demo this from his screen using two Snowflake accounts.
-- Data Sharing lets you share live, read-only data with another account - no copies, no ETL.
-- The consumer always sees the provider's current data.
--
-- What you'll see:
--   1. Provider account creates a SHARE and adds tables/views to it
--   2. Consumer account creates a DATABASE FROM SHARE to access the data
--   3. Consumer queries the shared data as if it were local
--
-- Key points:
--   - No data is copied -- it's a pointer to the provider's storage
--   - The provider controls what's shared and can revoke access instantly
--   - Sharing works across accounts, regions, and even cloud providers
--   - Secure views let you share a filtered/masked subset of your data
-- Docs: https://docs.snowflake.com/en/user-guide/data-sharing-intro

-- After the demo, you can explore what shares exist in your account:
SHOW SHARES;


-- =====================
-- PART 5: Snowflake Marketplace (Guided Walkthrough)
-- =====================
-- The Marketplace is a catalog of free and paid data products from third-party providers.
-- You can browse it from Snowsight: click "Marketplace" in the left sidebar.
--
-- We're going to get a FREE weather dataset and join it to ACME's ad performance data.
-- The story: "Does weather affect how our ad campaigns perform?"

-- Make sure you're on ACCOUNTADMIN before browsing the Marketplace.
-- Custom roles may not have permission to get listings.
USE ROLE ACCOUNTADMIN;

-- 5.1 Follow along as Rich walks through the Marketplace:
--   1. Click "Marketplace" in the left sidebar
--   2. Search for "weather"
--   3. Find "Global Weather & Climate Data by Pelmorex Weather Source"
--      (or go directly to: https://app.snowflake.com/marketplace/listing/GZSOZ1LLD8)
--   4. Click "Get" -- accept the terms and give the database a name (e.g., WEATHER_SOURCE)
--   5. It appears instantly as a shared database in your account

-- 5.2 Once you've gotten the listing, explore the weather data
-- The listing has 3 tables in the PWS_BI_SAMPLE schema:
--   POINT_HISTORY_DAY      - historical daily weather (what we'll use)
--   POINT_FORECAST_DAY     - daily forecasts
--   POINT_CLIMATOLOGY_DAY  - climatological normals
-- Data covers 10 cities: new_york, los_angeles, houston, paris, tokyo, sydney, and more.
SELECT * FROM WEATHER_SOURCE.PWS_BI_SAMPLE.POINT_HISTORY_DAY
WHERE city_name = 'new_york'
LIMIT 10;

-- 5.3 Join weather to ACME campaign performance
-- This is the power of the Marketplace: enrich YOUR data with third-party data, no ETL.
-- Example: compare daily ad spend to temperature to see if weather affects performance.
SELECT
    di.date,
    ca.campaign_name,
    ca.channel,
    di.impressions,
    di.clicks,
    di.spend,
    w.avg_temperature_air_2m_f AS avg_temp_f,
    w.tot_precipitation_in AS precipitation_in
FROM ACME.RAW.DAILY_IMPRESSIONS di
JOIN ACME.RAW.CAMPAIGNS ca ON di.campaign_id = ca.campaign_id
LEFT JOIN WEATHER_SOURCE.PWS_BI_SAMPLE.POINT_HISTORY_DAY w
    ON di.date = w.date_valid_std
    AND w.city_name = 'new_york'
WHERE di.date BETWEEN '2026-08-01' AND '2026-08-31'
ORDER BY di.date;
-- Note: the free sample only has 10 cities. Try swapping 'new_york' for 'tokyo' or 'paris'.

-- TRY IT: Browse the Marketplace on your own. Search for a topic relevant to your work
-- (demographics, financial data, geospatial, etc.) and see what's available.


-- =====================
-- PART 6: Understanding Compute Costs
-- =====================
-- Snowflake charges for three things: compute (warehouses), storage, and cloud services.
-- Compute is usually the biggest cost driver. Let's look at usage.

-- 6.1 Check your warehouse credit usage (may be minimal since this is a new account)
-- ACCOUNT_USAGE views have up to 45-minute latency, so recent queries may not appear yet.
SELECT
    warehouse_name,
    start_time,
    end_time,
    credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 20;

-- 6.2 See how much storage your account is using
SELECT
    ROUND(storage_bytes / POWER(1024, 3), 2) AS storage_gb,
    ROUND(stage_bytes / POWER(1024, 3), 2) AS stage_gb,
    ROUND(failsafe_bytes / POWER(1024, 3), 2) AS failsafe_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE usage_date = CURRENT_DATE();

-- 6.3 Quick credit-per-hour reference
-- Warehouse sizes and their credit consumption per hour:
--   XS = 1 credit/hr, S = 2, M = 4, L = 8, XL = 16, 2XL = 32, etc.
-- Your ACME_WH is X-Small with AUTO_SUSPEND = 60 seconds.
-- When nobody is querying, it suspends and stops consuming credits.
SHOW WAREHOUSES LIKE 'ACME_WH';

-- TRY IT: Run SHOW WAREHOUSES to see all warehouses. Look at the auto_suspend
-- and auto_resume settings. What would happen if auto_suspend was set to 0?
-- (Answer: the warehouse would never suspend and would consume credits 24/7.)


-- =====================
-- PART 7: Stretch Goals
-- =====================
-- Finished early? Try these.

-- 7A: Check who has accessed CLIENTS data
-- ACCESS_HISTORY tracks which queries accessed which objects.
-- Note: this view has up to 3-hour latency on new accounts.
SELECT
    ah.query_id,
    ah.query_start_time,
    ah.user_name,
    f.value:objectName::STRING AS object_accessed
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah,
     LATERAL FLATTEN(input => ah.base_objects_accessed) f
WHERE f.value:objectName::STRING ILIKE '%CLIENTS%'
ORDER BY ah.query_start_time DESC
LIMIT 10;

-- 7B: Object tagging (Horizon Catalog preview)
-- Tags let you classify and organize objects. Useful for governance at scale.
CREATE OR REPLACE TAG ACME.RAW.DATA_SENSITIVITY
    ALLOWED_VALUES 'PII', 'CONFIDENTIAL', 'PUBLIC'
    COMMENT = 'Data classification tag';

ALTER TABLE ACME.RAW.CLIENTS
SET TAG ACME.RAW.DATA_SENSITIVITY = 'CONFIDENTIAL';

ALTER TABLE ACME.RAW.CAMPAIGNS
SET TAG ACME.RAW.DATA_SENSITIVITY = 'PUBLIC';

-- Query tagged objects
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('ACME.RAW.CLIENTS', 'TABLE'));

-- 7C: Clean up the policies we applied (so Session A exercises still work normally)
-- Remove the row access policy from CLIENTS
ALTER TABLE ACME.RAW.CLIENTS
DROP ROW ACCESS POLICY ACME.RAW.REGION_FILTER;

-- Remove the masking policy from CLIENTS
ALTER TABLE ACME.RAW.CLIENTS
MODIFY COLUMN annual_budget
UNSET MASKING POLICY;
