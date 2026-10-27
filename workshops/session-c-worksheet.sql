-- =============================================================================
-- Session C: Data Engineering and Pipelines - Worksheet SQL
-- =============================================================================
-- This file contains all SQL from the Session C hands-on worksheet.
-- Today we automate: instead of running queries by hand, we build pipelines
-- that keep data fresh.
--
-- Pre-requisites: setup-golden-account.sql has been run (PIPELINES schema,
-- DATA_ENGINEER role, EXECUTE TASK grants all exist).
-- =============================================================================

-- =====================
-- SET SESSION CONTEXT
-- =====================
-- We use DATA_ENGINEER for this session - it has the privileges needed to
-- create streams, tasks, and dynamic tables.
USE ROLE DATA_ENGINEER;
USE WAREHOUSE ACME_WH;
USE DATABASE ACME;
USE SCHEMA PIPELINES;


-- =====================
-- PART 1: Streams (Change Data Capture)
-- =====================
-- A STREAM tracks changes (inserts, updates, deletes) on a table.
-- Think of it as a "diff" that Snowflake maintains automatically.
-- When you query a stream, you see only what changed since the last time it was consumed.
-- Docs: https://docs.snowflake.com/en/user-guide/streams-intro

-- 1.1 Create a stream on the CAMPAIGNS table
-- This starts tracking all changes to CAMPAIGNS from this point forward.
CREATE OR REPLACE STREAM ACME.PIPELINES.CAMPAIGNS_STREAM
ON TABLE ACME.RAW.CAMPAIGNS
COMMENT = 'Tracks inserts, updates, and deletes on RAW.CAMPAIGNS';

-- 1.2 Check the stream - it should be empty (no changes since we created it)
SELECT * FROM ACME.PIPELINES.CAMPAIGNS_STREAM;

-- 1.3 Insert a new campaign into RAW.CAMPAIGNS to generate a change
-- (Switch to ACCOUNTADMIN briefly since DATA_ENGINEER has SELECT-only on RAW)
USE ROLE ACCOUNTADMIN;

INSERT INTO ACME.RAW.CAMPAIGNS VALUES
(121, 'Holiday Email Blast 2026', 1, 'Email', 'Conversions',
 '2026-12-01', '2026-12-25', 150000.00, 'Planned');

USE ROLE DATA_ENGINEER;

-- 1.4 Now query the stream - you should see the new row with metadata columns
SELECT * FROM ACME.PIPELINES.CAMPAIGNS_STREAM;
-- Notice the extra columns:
--   METADATA$ACTION     = 'INSERT' (the type of change)
--   METADATA$ISUPDATE   = FALSE (not part of an update)
--   METADATA$ROW_ID     = unique row identifier

-- 1.5 Streams are consumed when you use them in a DML statement.
-- Let's consume it by inserting the new campaign into a tracking table.
CREATE OR REPLACE TABLE ACME.PIPELINES.NEW_CAMPAIGNS_LOG (
    campaign_id INT,
    campaign_name VARCHAR(150),
    channel VARCHAR(30),
    budget DECIMAL(12,2),
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO ACME.PIPELINES.NEW_CAMPAIGNS_LOG (campaign_id, campaign_name, channel, budget)
SELECT campaign_id, campaign_name, channel, budget
FROM ACME.PIPELINES.CAMPAIGNS_STREAM
WHERE METADATA$ACTION = 'INSERT';

-- 1.6 The stream is now empty again - it was consumed by our INSERT
SELECT * FROM ACME.PIPELINES.CAMPAIGNS_STREAM;

-- Check our log table
SELECT * FROM ACME.PIPELINES.NEW_CAMPAIGNS_LOG;

-- TRY IT: Insert another campaign into RAW.CAMPAIGNS (as ACCOUNTADMIN),
-- then query the stream again as DATA_ENGINEER to see the new change.


-- =====================
-- PART 2: Tasks (Scheduled Automation)
-- =====================
-- A TASK is a scheduled SQL statement. It can run on a CRON schedule or
-- when triggered by a stream (i.e., "run this whenever new data arrives").
-- Tasks can be chained into DAGs (directed acyclic graphs) for multi-step pipelines.
-- Docs: https://docs.snowflake.com/en/user-guide/tasks-intro

-- 2.1 Create a task that reads from the stream and logs new campaigns
-- WHEN SYSTEM$STREAM_HAS_DATA(...) means: only run if the stream has unconsumed changes.
CREATE OR REPLACE TASK ACME.PIPELINES.LOG_NEW_CAMPAIGNS_TASK
    WAREHOUSE = ACME_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('ACME.PIPELINES.CAMPAIGNS_STREAM')
AS
INSERT INTO ACME.PIPELINES.NEW_CAMPAIGNS_LOG (campaign_id, campaign_name, channel, budget)
SELECT campaign_id, campaign_name, channel, budget
FROM ACME.PIPELINES.CAMPAIGNS_STREAM
WHERE METADATA$ACTION = 'INSERT';

-- 2.2 Tasks are created in a SUSPENDED state. You must resume them to activate.
-- For the workshop, we'll run it manually instead of waiting for the schedule.
-- First, let's add a new campaign so the stream has data:
USE ROLE ACCOUNTADMIN;

INSERT INTO ACME.RAW.CAMPAIGNS VALUES
(122, 'New Year Fitness Push', 2, 'Social', 'Conversions',
 '2027-01-02', '2027-01-31', 200000.00, 'Planned');

USE ROLE DATA_ENGINEER;

-- Confirm the stream has data
SELECT * FROM ACME.PIPELINES.CAMPAIGNS_STREAM;

-- 2.3 Execute the task manually
EXECUTE TASK ACME.PIPELINES.LOG_NEW_CAMPAIGNS_TASK;

-- 2.4 Check the results
-- The stream should be empty (consumed by the task)
SELECT * FROM ACME.PIPELINES.CAMPAIGNS_STREAM;

-- The log table should have the new row
SELECT * FROM ACME.PIPELINES.NEW_CAMPAIGNS_LOG ORDER BY detected_at DESC;

-- 2.5 In production, you'd resume the task so it runs on schedule:
--   ALTER TASK ACME.PIPELINES.LOG_NEW_CAMPAIGNS_TASK RESUME;
-- And to stop it:
--   ALTER TASK ACME.PIPELINES.LOG_NEW_CAMPAIGNS_TASK SUSPEND;
-- For this workshop, leave it suspended to avoid consuming credits.

-- TRY IT: Create a second task that runs AFTER the first one (a child task).
-- Hint: use AFTER ACME.PIPELINES.LOG_NEW_CAMPAIGNS_TASK instead of SCHEDULE.
-- This is how you build multi-step pipelines (DAGs) in Snowflake.


-- =====================
-- PART 3: Dynamic Tables (Declarative Pipelines)
-- =====================
-- Dynamic tables are the "easy mode" for pipelines. You write a SELECT query,
-- set a TARGET_LAG (how fresh you want the data), and Snowflake handles the rest.
-- No streams, no tasks, no scheduling -- Snowflake figures out when to refresh.
-- Docs: https://docs.snowflake.com/en/user-guide/dynamic-tables-intro

-- 3.1 Create a dynamic table that summarizes campaign performance
-- TARGET_LAG = '1 minute' means Snowflake will refresh within 1 minute of source changes.
-- (In production, you'd set this to match your SLA -- e.g., '15 minutes' or '1 hour'.)
CREATE OR REPLACE DYNAMIC TABLE ACME.PIPELINES.CAMPAIGN_PERFORMANCE_DT
    WAREHOUSE = ACME_WH
    TARGET_LAG = '1 minute'
AS
SELECT
    ca.campaign_id,
    ca.campaign_name,
    cl.client_name,
    ca.channel,
    ca.budget,
    ca.status,
    COUNT(di.date) AS days_active,
    SUM(di.impressions) AS total_impressions,
    SUM(di.clicks) AS total_clicks,
    SUM(di.conversions) AS total_conversions,
    SUM(di.spend) AS total_spend,
    ROUND(SUM(di.spend) / NULLIF(SUM(di.clicks), 0), 2) AS cost_per_click,
    ROUND(SUM(di.clicks) / NULLIF(SUM(di.impressions), 0) * 100, 2) AS ctr_pct
FROM ACME.RAW.CAMPAIGNS ca
JOIN ACME.RAW.CLIENTS cl ON ca.client_id = cl.client_id
LEFT JOIN ACME.RAW.DAILY_IMPRESSIONS di ON ca.campaign_id = di.campaign_id
GROUP BY ca.campaign_id, ca.campaign_name, cl.client_name, ca.channel, ca.budget, ca.status;

-- 3.2 Query the dynamic table
SELECT * FROM ACME.PIPELINES.CAMPAIGN_PERFORMANCE_DT
ORDER BY total_spend DESC;

-- 3.3 Check the refresh status
-- This shows when the dynamic table last refreshed and its current lag.
SELECT name, state, refresh_action, refresh_trigger, refresh_end_time
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE name = 'CAMPAIGN_PERFORMANCE_DT'
ORDER BY refresh_end_time DESC
LIMIT 5;

-- 3.4 Now add new impression data and watch the dynamic table catch up
USE ROLE ACCOUNTADMIN;

INSERT INTO ACME.RAW.DAILY_IMPRESSIONS VALUES
('2026-10-29', 121, 'Email', 18000, 450, 35, 2500.00),
('2026-10-29', 122, 'Social', 25000, 800, 60, 3200.00);

USE ROLE DATA_ENGINEER;

-- Wait about a minute, then query again -- the new campaigns should appear
-- with their impression data rolled up automatically.
SELECT * FROM ACME.PIPELINES.CAMPAIGN_PERFORMANCE_DT
WHERE campaign_id IN (121, 122);

-- 3.5 Streams + Tasks vs. Dynamic Tables: when to use which?
-- Streams + Tasks:
--   - Full control over WHEN and HOW data moves
--   - Can run arbitrary SQL (MERGE, stored procedures, multi-step logic)
--   - Good for complex transformations, conditional logic, error handling
-- Dynamic Tables:
--   - Declarative: you define WHAT, Snowflake handles WHEN and HOW
--   - Simpler to build and maintain
--   - Snowflake optimizes the refresh (incremental when possible)
--   - Good for aggregations, joins, straightforward transformations
-- In practice, many teams use dynamic tables for most pipelines and reserve
-- streams + tasks for cases that need procedural logic.

-- TRY IT: Create a second dynamic table that depends on the first one.
-- For example, a "top 5 campaigns by spend" table that reads from
-- CAMPAIGN_PERFORMANCE_DT. This shows how dynamic tables chain together
-- into multi-step pipelines -- Snowflake manages the dependency graph.


-- =====================
-- PART 4: Snowpark and Notebooks (Quick Intro)
-- =====================
-- Snowpark lets you write Python (or Java/Scala) that runs inside Snowflake.
-- Snowflake Notebooks give you an interactive environment (like Jupyter) that
-- combines SQL cells and Python cells.
--
-- This is a GUIDED section -- Rich will walk through this on screen.
--
-- What you'll see:
--   1. Open a Snowflake Notebook from Snowsight (Projects > Notebooks > + Notebook)
--   2. Write a SQL cell: SELECT * FROM ACME.RAW.DAILY_IMPRESSIONS LIMIT 100;
--   3. Write a Python cell using Snowpark:
--
--      import snowflake.snowpark as snowpark
--
--      # Get a Snowpark DataFrame from the DAILY_IMPRESSIONS table
--      df = session.table("ACME.RAW.DAILY_IMPRESSIONS")
--
--      # Add a computed column: cost per click
--      df = df.with_column("COST_PER_CLICK",
--          (df["SPEND"] / df["CLICKS"]).cast("DECIMAL(10,2)"))
--
--      # Show the result
--      df.select("DATE", "CAMPAIGN_ID", "CHANNEL", "CLICKS", "SPEND", "COST_PER_CLICK") \
--        .sort("DATE") \
--        .show(20)
--
--   4. Notebooks can also be scheduled as tasks for recurring Python pipelines.
--
-- Key points:
--   - Snowpark DataFrames look like pandas but run inside Snowflake (no data leaves)
--   - You get full Python: pandas, numpy, scikit-learn, etc.
--   - Notebooks combine SQL + Python in one place -- great for exploration and prototyping
--   - Session D will go deeper into Cortex AI and Streamlit apps


-- =====================
-- PART 5: Stretch Goals
-- =====================
-- Finished early? Try these.

-- 5A: Create a dynamic table chain
-- Build a "top performers" table that reads from the campaign performance DT.
CREATE OR REPLACE DYNAMIC TABLE ACME.PIPELINES.TOP_PERFORMERS_DT
    WAREHOUSE = ACME_WH
    TARGET_LAG = '2 minutes'
AS
SELECT
    campaign_name,
    client_name,
    channel,
    total_spend,
    total_clicks,
    ctr_pct,
    cost_per_click
FROM ACME.PIPELINES.CAMPAIGN_PERFORMANCE_DT
WHERE total_spend > 0
ORDER BY ctr_pct DESC
LIMIT 10;

SELECT * FROM ACME.PIPELINES.TOP_PERFORMERS_DT;

-- 5B: Explore task history
-- See when tasks have run and whether they succeeded.
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE name = 'LOG_NEW_CAMPAIGNS_TASK'
ORDER BY scheduled_time DESC
LIMIT 10;

-- 5C: Create a stream on the CLIENTS table
-- Then update a client's region and query the stream to see the UPDATE metadata.
CREATE OR REPLACE STREAM ACME.PIPELINES.CLIENTS_STREAM
ON TABLE ACME.RAW.CLIENTS;

USE ROLE ACCOUNTADMIN;
UPDATE ACME.RAW.CLIENTS SET region = 'LATAM' WHERE client_id = 9;
USE ROLE DATA_ENGINEER;

-- An UPDATE shows as a DELETE + INSERT pair in the stream
SELECT * FROM ACME.PIPELINES.CLIENTS_STREAM;


-- =====================
-- HOUSEKEEPING: Reduce dynamic table refresh frequency
-- =====================
-- The dynamic tables we created have a 1-minute target lag, which means the warehouse
-- wakes up frequently to check for changes. While no-change checks are nearly free,
-- it's good practice to relax the lag when you're done experimenting.
ALTER DYNAMIC TABLE ACME.PIPELINES.CAMPAIGN_PERFORMANCE_DT SET TARGET_LAG = '1 day';
ALTER DYNAMIC TABLE ACME.PIPELINES.TOP_PERFORMERS_DT SET TARGET_LAG = '1 day';

-- Suspend the task in case you resumed it during the TRY IT exercise
ALTER TASK IF EXISTS ACME.PIPELINES.LOG_NEW_CAMPAIGNS_TASK SUSPEND;
