-- =============================================================================
-- Session E: Advanced Performance & Optimization - Worksheet SQL
-- =============================================================================
-- This session is for teams working with production workloads.
-- We go deeper on how Snowflake stores data, how to read the Query Profile,
-- and how to tune queries, clustering, and warehouse configuration.
--
-- We'll use HOURLY_IMPRESSIONS (~500K rows) for the tuning exercises --
-- it's large enough to span multiple micro-partitions.
-- =============================================================================

-- =====================
-- SET SESSION CONTEXT
-- =====================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE ACME_WH;
USE DATABASE ACME;
USE SCHEMA RAW;


-- =====================
-- PART 1: How Snowflake Stores Data (Micro-Partitions)
-- =====================
-- Snowflake stores table data in micro-partitions: immutable, compressed columnar files,
-- each holding 50-500 MB of uncompressed data. You don't control partitioning directly --
-- Snowflake handles it automatically based on insertion order.
--
-- Why this matters: when Snowflake runs a query, it reads only the micro-partitions
-- that COULD contain matching rows. This is called "partition pruning."
-- The fewer partitions scanned, the faster (and cheaper) the query.

-- 1.1 Check how many micro-partitions the HOURLY_IMPRESSIONS table has
SELECT
    row_count,
    bytes,
    ROUND(bytes / POWER(1024, 2), 2) AS size_mb,
    clustering_information
FROM TABLE(INFORMATION_SCHEMA.TABLE_STORAGE_METRICS())
WHERE table_name = 'HOURLY_IMPRESSIONS'
  AND table_schema = 'RAW'
  AND catalog_name = 'ACME';

-- A simpler way: SHOW TABLES gives you row count and bytes
SHOW TABLES LIKE 'HOURLY_IMPRESSIONS' IN SCHEMA ACME.RAW;

-- 1.2 Run a query and check how many partitions were scanned
-- This query filters by a specific date range.
SELECT
    DATE_TRUNC('day', event_hour) AS event_date,
    channel,
    city,
    SUM(impressions) AS total_impressions,
    SUM(spend) AS total_spend
FROM ACME.RAW.HOURLY_IMPRESSIONS
WHERE event_hour BETWEEN '2024-06-01' AND '2024-06-30'
GROUP BY event_date, channel, city
ORDER BY event_date;

-- NOW: Click "Query Profile" in the results pane.
-- Look at the TableScan node. You'll see:
--   Partitions scanned: X
--   Partitions total: Y
-- If X < Y, Snowflake pruned some partitions (skipped data it didn't need).
-- If X = Y, no pruning happened -- the filter wasn't helpful for the physical layout.

-- 1.3 Compare: a query that should prune well vs. one that won't
-- Good pruning (filter on the natural ordering -- event_hour):
SELECT COUNT(*) FROM ACME.RAW.HOURLY_IMPRESSIONS
WHERE event_hour = '2024-03-15 10:00:00';

-- Poor pruning (filter on a column that's randomly distributed -- campaign_id):
SELECT COUNT(*) FROM ACME.RAW.HOURLY_IMPRESSIONS
WHERE campaign_id = 107;

-- Check the Query Profile for both. The event_hour filter should scan fewer partitions.
-- campaign_id values are spread across all partitions, so Snowflake has to scan more.

-- TRY IT: Run a query filtering on region. Does it prune well or poorly?
-- Why? (Hint: think about how the data was inserted.)


-- =====================
-- PART 2: Clustering Keys
-- =====================
-- A clustering key tells Snowflake to physically reorganize the data within a table
-- so that rows with similar values in the clustering column(s) are stored together.
-- This improves pruning for queries that filter on those columns.
-- Docs: https://docs.snowflake.com/en/user-guide/tables-clustering-keys

-- 2.1 Check the current clustering depth on campaign_id
-- SYSTEM$CLUSTERING_INFORMATION shows how well-clustered a table is for a given column.
SELECT SYSTEM$CLUSTERING_INFORMATION('ACME.RAW.HOURLY_IMPRESSIONS', '(campaign_id)');

-- The result shows:
--   average_depth: how many partitions overlap for a given value (lower = better)
--   total_partition_count: total micro-partitions
-- A high average_depth means campaign_id values are spread across many partitions.

-- 2.2 Add a clustering key on campaign_id
ALTER TABLE ACME.RAW.HOURLY_IMPRESSIONS CLUSTER BY (campaign_id);

-- Snowflake will reclu ster the data in the background (automatic clustering).
-- For a ~500K row table this should be fast.
-- Check the clustering status:
SELECT SYSTEM$CLUSTERING_INFORMATION('ACME.RAW.HOURLY_IMPRESSIONS', '(campaign_id)');

-- 2.3 Run the campaign_id query again and compare the Query Profile
SELECT COUNT(*) FROM ACME.RAW.HOURLY_IMPRESSIONS
WHERE campaign_id = 107;

-- After clustering, this query should scan fewer partitions than before.
-- Note: automatic reclustering may take a minute. If the numbers haven't changed,
-- wait and re-run.

-- 2.4 Check clustering on a compound key
SELECT SYSTEM$CLUSTERING_INFORMATION('ACME.RAW.HOURLY_IMPRESSIONS', '(channel, region)');

-- TRY IT: Add a clustering key on (channel, region) instead.
-- Hint: ALTER TABLE ACME.RAW.HOURLY_IMPRESSIONS CLUSTER BY (channel, region);
-- Then re-run a query filtering on channel and check the Query Profile.
-- Note: a table can only have one clustering key at a time -- the new one replaces the old.


-- =====================
-- PART 3: Query Profile Deep Dive
-- =====================
-- The Query Profile is the single most important tool for understanding query performance.
-- It shows the execution plan as a graph of operators (TableScan, Join, Aggregate, etc.).

-- 3.1 Run a moderately complex query
SELECT
    cl.client_name,
    cl.region,
    ca.channel,
    SUM(hi.impressions) AS total_impressions,
    SUM(hi.clicks) AS total_clicks,
    SUM(hi.spend) AS total_spend,
    ROUND(SUM(hi.spend) / NULLIF(SUM(hi.clicks), 0), 2) AS cost_per_click
FROM ACME.RAW.HOURLY_IMPRESSIONS hi
JOIN ACME.RAW.CAMPAIGNS ca ON hi.campaign_id = ca.campaign_id
JOIN ACME.RAW.CLIENTS cl ON ca.client_id = cl.client_id
WHERE hi.event_hour >= '2024-07-01'
  AND hi.event_hour < '2024-10-01'
GROUP BY cl.client_name, cl.region, ca.channel
ORDER BY total_spend DESC;

-- 3.2 Open the Query Profile and look for:
--
-- a) PARTITIONS SCANNED vs. TOTAL (on TableScan nodes)
--    - If scanned = total, the filter isn't pruning. Consider a clustering key.
--
-- b) SPILLING TO LOCAL/REMOTE STORAGE (on Sort or Aggregate nodes)
--    - Spilling means the warehouse ran out of memory and used disk.
--    - Fix: use a larger warehouse, or reduce the data volume with tighter filters.
--
-- c) BYTES SENT OVER THE NETWORK (on Exchange nodes)
--    - High network transfer between nodes can indicate a bad join strategy.
--
-- d) PERCENTAGE SCANNED FROM CACHE
--    - If you run the same query twice, the second run uses the result cache (0 partitions).
--    - The data cache (warehouse local SSD) can also reduce scan time.
--
-- Key insight: the slowest node in the profile is your bottleneck.
-- The "Most Expensive Nodes" panel (top right) highlights them.

-- 3.3 Demonstrate the result cache
-- Run this query twice. The second run should return instantly from cache.
SELECT channel, SUM(spend) AS total_spend
FROM ACME.RAW.HOURLY_IMPRESSIONS
GROUP BY channel;

-- Run it again:
SELECT channel, SUM(spend) AS total_spend
FROM ACME.RAW.HOURLY_IMPRESSIONS
GROUP BY channel;

-- Check the second Query Profile: it should say "QUERY RESULT REUSE" --
-- Snowflake returned the cached result without scanning any partitions.

-- TRY IT: Change the query slightly (e.g., add ORDER BY) and run again.
-- Does it still use the cache? (No -- any change to the SQL text invalidates the cache.)


-- =====================
-- PART 4: Warehouse Sizing and Cost Optimization
-- =====================
-- Warehouse size determines how much compute is available for a query.
-- Larger warehouses cost more credits per hour but process data faster.
--
-- Credit rates per hour:
--   XS = 1, S = 2, M = 4, L = 8, XL = 16, 2XL = 32, 3XL = 64, 4XL = 128
--
-- The goal: use the smallest warehouse that runs your query in an acceptable time.

-- 4.1 Check current warehouse configuration
SHOW WAREHOUSES LIKE 'ACME_WH';
-- Note: size, auto_suspend, auto_resume, min/max_cluster_count

-- 4.2 Run a query on XS and note the execution time
ALTER WAREHOUSE ACME_WH SET WAREHOUSE_SIZE = 'XSMALL';

SELECT
    DATE_TRUNC('month', event_hour) AS month,
    channel,
    region,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(spend) AS total_spend
FROM ACME.RAW.HOURLY_IMPRESSIONS
GROUP BY month, channel, region
ORDER BY month, total_spend DESC;

-- Note the execution time in the results bar.

-- 4.3 Scale up to SMALL and run the same query
ALTER WAREHOUSE ACME_WH SET WAREHOUSE_SIZE = 'SMALL';

-- Disable the result cache so we get a fresh execution
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

SELECT
    DATE_TRUNC('month', event_hour) AS month,
    channel,
    region,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(spend) AS total_spend
FROM ACME.RAW.HOURLY_IMPRESSIONS
GROUP BY month, channel, region
ORDER BY month, total_spend DESC;

-- Compare execution times. For this data size, the difference may be small.
-- For production tables with billions of rows, the difference is significant.

-- 4.4 Reset to XS and re-enable cache
ALTER WAREHOUSE ACME_WH SET WAREHOUSE_SIZE = 'XSMALL';
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- 4.5 Key cost optimization settings
-- AUTO_SUSPEND: how many seconds of inactivity before the warehouse suspends.
-- Lower = less credit waste. 60 seconds is good for interactive use.
-- AUTO_RESUME: warehouse starts automatically when a query arrives. Always keep this TRUE.
SHOW WAREHOUSES LIKE 'ACME_WH';

-- TRY IT: What would happen if you set AUTO_SUSPEND = 0? (It never suspends -- credits burn 24/7.)
-- What about AUTO_SUSPEND = 1? (Suspends after 1 second of inactivity -- aggressive but saves credits.)


-- =====================
-- PART 5: Search Optimization and Query Acceleration
-- =====================
-- Two optional services that can speed up specific query patterns.
-- Both add cost (storage for SOS, compute for QAS) so use them when the benefit is clear.

-- 5.1 Search Optimization Service (SOS)
-- SOS builds a search access path (like an index) for selective point lookups.
-- Best for: queries that filter on a specific value in a high-cardinality column.
-- Docs: https://docs.snowflake.com/en/user-guide/search-optimization-service

-- Check if SOS would help for a specific query pattern:
-- (This is an estimate -- it doesn't actually enable SOS.)
SELECT SYSTEM$ESTIMATE_SEARCH_OPTIMIZATION_COSTS('ACME.RAW.HOURLY_IMPRESSIONS');

-- Enable SOS on the table:
ALTER TABLE ACME.RAW.HOURLY_IMPRESSIONS ADD SEARCH OPTIMIZATION;

-- After SOS builds (may take a few minutes), point lookups should be faster:
SELECT * FROM ACME.RAW.HOURLY_IMPRESSIONS
WHERE campaign_id = 107
  AND event_hour = '2024-08-15 14:00:00';

-- Check SOS status:
SHOW TABLES LIKE 'HOURLY_IMPRESSIONS' IN SCHEMA ACME.RAW;
-- Look at the search_optimization column.

-- 5.2 Query Acceleration Service (QAS)
-- QAS offloads portions of a query to shared compute resources.
-- Best for: queries that scan a lot of data but only need a small result (large aggregations).
-- Docs: https://docs.snowflake.com/en/user-guide/query-acceleration-service

-- Check if QAS would help for recent queries on this warehouse:
SELECT SYSTEM$ESTIMATE_QUERY_ACCELERATION('ACME_WH');

-- Enable QAS on the warehouse:
ALTER WAREHOUSE ACME_WH SET ENABLE_QUERY_ACCELERATION = TRUE;

-- QAS activates automatically for eligible queries. You can set a cost limit:
ALTER WAREHOUSE ACME_WH SET QUERY_ACCELERATION_MAX_SCALE_FACTOR = 2;
-- Scale factor of 2 means QAS can use up to 2x the warehouse's compute.

-- TRY IT: Run the monthly aggregation query from Part 4 again.
-- Check the Query Profile for any "Query Acceleration" nodes.


-- =====================
-- PART 6: Stretch Goals
-- =====================
-- Finished early? Try these.

-- 6A: Compare clustering strategies
-- Drop the existing clustering key and try (event_hour) instead:
ALTER TABLE ACME.RAW.HOURLY_IMPRESSIONS CLUSTER BY (event_hour);

-- Wait a moment, then check:
SELECT SYSTEM$CLUSTERING_INFORMATION('ACME.RAW.HOURLY_IMPRESSIONS', '(event_hour)');

-- Run a date-range query and compare the Query Profile to earlier results.

-- 6B: Query the QUERY_HISTORY view for expensive queries
SELECT
    query_id,
    query_text,
    warehouse_size,
    execution_time / 1000 AS execution_seconds,
    bytes_scanned,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 1) AS pct_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(hour, -2, CURRENT_TIMESTAMP())
  AND warehouse_name = 'ACME_WH'
  AND execution_status = 'SUCCESS'
ORDER BY execution_time DESC
LIMIT 20;

-- 6C: Check for spilling queries
SELECT
    query_id,
    query_text,
    warehouse_size,
    bytes_spilled_to_local_storage,
    bytes_spilled_to_remote_storage
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(hour, -2, CURRENT_TIMESTAMP())
  AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_remote_storage DESC
LIMIT 10;


-- =====================
-- HOUSEKEEPING
-- =====================
-- Remove SOS and QAS to avoid ongoing costs
ALTER TABLE ACME.RAW.HOURLY_IMPRESSIONS DROP SEARCH OPTIMIZATION;
ALTER WAREHOUSE ACME_WH SET ENABLE_QUERY_ACCELERATION = FALSE;

-- Remove clustering key (stops automatic reclustering costs)
ALTER TABLE ACME.RAW.HOURLY_IMPRESSIONS DROP CLUSTERING KEY;

-- Reset warehouse to XS
ALTER WAREHOUSE ACME_WH SET WAREHOUSE_SIZE = 'XSMALL';
