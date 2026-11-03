-- =============================================================================
-- ACME Workshop: Golden Account Setup Script
-- =============================================================================
-- Run this script as ACCOUNTADMIN on the golden account before DataOpsLive
-- clones it for attendees. Creates all databases, schemas, tables, sample data,
-- stages, and file formats needed for Sessions A through D.
--
-- Fictional company: ACME (advertising/media scenario)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- Warehouse
-- ---------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS ACME_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Workshop warehouse';

USE WAREHOUSE ACME_WH;

-- ---------------------------------------------------------------------------
-- Database and Schemas
-- ---------------------------------------------------------------------------
CREATE OR REPLACE DATABASE ACME COMMENT = 'Snowflake Workshop Series - Omnicom Teams (Fall 2026)';

CREATE OR REPLACE SCHEMA ACME.RAW       COMMENT = 'Pre-loaded sample data - campaigns, clients, impressions';
CREATE OR REPLACE SCHEMA ACME.STAGING   COMMENT = 'Staging area for data loading exercises';
CREATE OR REPLACE SCHEMA ACME.ANALYTICS COMMENT = 'Attendee workspace - build tables, views, and pipelines here';

-- ---------------------------------------------------------------------------
-- RAW.CLIENTS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ACME.RAW.CLIENTS (
    client_id INT,
    client_name VARCHAR(100),
    industry VARCHAR(50),
    region VARCHAR(30),
    account_manager VARCHAR(80),
    contract_start_date DATE,
    annual_budget DECIMAL(12,2),
    is_active BOOLEAN
) COMMENT = 'ACME advertising clients';

INSERT INTO ACME.RAW.CLIENTS VALUES
(1, 'Bright Horizon Hotels', 'Hospitality', 'North America', 'Sarah Chen', '2024-03-15', 2400000.00, TRUE),
(2, 'Velox Athletic Wear', 'Retail', 'North America', 'Sarah Chen', '2023-08-01', 1800000.00, TRUE),
(3, 'GreenLeaf Foods', 'CPG', 'EMEA', 'Marcus Webb', '2024-01-10', 3200000.00, TRUE),
(4, 'Nova Telecom', 'Telecommunications', 'APAC', 'Aiko Tanaka', '2023-11-20', 5500000.00, TRUE),
(5, 'Pinnacle Financial', 'Financial Services', 'North America', 'James Ortiz', '2024-06-01', 4100000.00, TRUE),
(6, 'Solara Beauty', 'Beauty & Personal Care', 'EMEA', 'Marcus Webb', '2024-02-14', 1500000.00, TRUE),
(7, 'Titan Motors', 'Automotive', 'North America', 'James Ortiz', '2023-05-01', 8200000.00, TRUE),
(8, 'CloudBridge Software', 'Technology', 'APAC', 'Aiko Tanaka', '2024-09-01', 2700000.00, TRUE),
(9, 'Oasis Travel Group', 'Travel', 'EMEA', 'Luisa Fernandez', '2023-07-15', 1950000.00, TRUE),
(10, 'Redwood Brewing Co.', 'Food & Beverage', 'North America', 'Sarah Chen', '2024-04-01', 950000.00, TRUE),
(11, 'Vertex Gaming', 'Entertainment', 'APAC', 'Aiko Tanaka', '2024-11-01', 3800000.00, TRUE),
(12, 'AureliaRx', 'Pharmaceuticals', 'North America', 'James Ortiz', '2023-03-01', 6400000.00, FALSE),
(13, 'Metro Eats', 'Food Delivery', 'North America', 'Sarah Chen', '2024-07-20', 1200000.00, TRUE),
(14, 'Luxe Interiors', 'Home & Living', 'EMEA', 'Luisa Fernandez', '2024-05-10', 850000.00, TRUE),
(15, 'Pacific Rim Airlines', 'Travel', 'APAC', 'Aiko Tanaka', '2023-10-01', 7100000.00, TRUE);

-- ---------------------------------------------------------------------------
-- RAW.CAMPAIGNS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ACME.RAW.CAMPAIGNS (
    campaign_id INT,
    campaign_name VARCHAR(150),
    client_id INT,
    channel VARCHAR(30),
    objective VARCHAR(30),
    start_date DATE,
    end_date DATE,
    budget DECIMAL(12,2),
    status VARCHAR(20)
) COMMENT = 'ACME advertising campaigns';

INSERT INTO ACME.RAW.CAMPAIGNS VALUES
(101, 'Summer Getaway 2026', 1, 'Display', 'Awareness', '2026-06-01', '2026-08-31', 450000.00, 'Completed'),
(102, 'Back to School Sprint', 2, 'Social', 'Conversions', '2026-08-01', '2026-09-15', 320000.00, 'Completed'),
(103, 'Plant-Based Launch', 3, 'Video', 'Awareness', '2026-07-15', '2026-10-15', 580000.00, 'Active'),
(104, '5G Everywhere', 4, 'Search', 'Leads', '2026-05-01', '2026-12-31', 1200000.00, 'Active'),
(105, 'Wealth Builder Series', 5, 'Display', 'Leads', '2026-09-01', '2026-11-30', 650000.00, 'Active'),
(106, 'Glow Up Fall Collection', 6, 'Social', 'Conversions', '2026-09-15', '2026-11-15', 280000.00, 'Active'),
(107, 'Truck Month Madness', 7, 'Video', 'Awareness', '2026-10-01', '2026-10-31', 1500000.00, 'Active'),
(108, 'DevOps Decoded Webinar', 8, 'Search', 'Leads', '2026-10-01', '2026-12-15', 180000.00, 'Active'),
(109, 'Winter Sun Escapes', 9, 'Display', 'Awareness', '2026-11-01', '2027-01-31', 400000.00, 'Planned'),
(110, 'Craft Beer Festival Promo', 10, 'Social', 'Awareness', '2026-09-01', '2026-09-30', 95000.00, 'Completed'),
(111, 'Holiday Gift Guide', 2, 'Display', 'Conversions', '2026-11-15', '2026-12-25', 500000.00, 'Planned'),
(112, 'New Year New You', 6, 'Video', 'Awareness', '2027-01-01', '2027-02-28', 350000.00, 'Planned'),
(113, 'Game Launch: Neon Drift', 11, 'Social', 'Conversions', '2026-11-01', '2026-12-31', 900000.00, 'Active'),
(114, 'Spring Refresh Promo', 1, 'Search', 'Leads', '2026-03-01', '2026-05-31', 380000.00, 'Completed'),
(115, 'Metro Eats City Blitz', 13, 'Social', 'Conversions', '2026-08-15', '2026-10-15', 220000.00, 'Active'),
(116, 'Designer Showcase', 14, 'Display', 'Awareness', '2026-10-01', '2026-12-31', 175000.00, 'Active'),
(117, 'Fly Pacific Holiday Deals', 15, 'Video', 'Conversions', '2026-11-01', '2027-01-15', 1100000.00, 'Planned'),
(118, 'Fiber Optic Future', 4, 'Display', 'Awareness', '2026-09-01', '2026-12-31', 800000.00, 'Active'),
(119, 'GreenLeaf Recipe Series', 3, 'Social', 'Awareness', '2026-06-01', '2026-09-30', 250000.00, 'Completed'),
(120, 'Pinnacle Retirement Plan', 5, 'Search', 'Leads', '2026-06-15', '2026-09-15', 420000.00, 'Completed');

-- ---------------------------------------------------------------------------
-- RAW.DAILY_IMPRESSIONS (generated data)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ACME.RAW.DAILY_IMPRESSIONS (
    date DATE,
    campaign_id INT,
    channel VARCHAR(30),
    impressions INT,
    clicks INT,
    conversions INT,
    spend DECIMAL(10,2)
) COMMENT = 'Daily advertising performance metrics by campaign and channel';

INSERT INTO ACME.RAW.DAILY_IMPRESSIONS
WITH date_range AS (
    SELECT DATEADD(day, seq4(), '2026-06-01')::DATE AS date
    FROM TABLE(GENERATOR(ROWCOUNT => 150))
),
campaign_dates AS (
    SELECT c.campaign_id, c.channel, c.budget, c.start_date, c.end_date,
           DATEDIFF(day, c.start_date, c.end_date) + 1 AS campaign_days
    FROM ACME.RAW.CAMPAIGNS c
    WHERE c.status IN ('Active', 'Completed')
)
SELECT
    d.date,
    cd.campaign_id,
    cd.channel,
    CASE cd.channel
        WHEN 'Display' THEN UNIFORM(8000, 25000, RANDOM())
        WHEN 'Social'  THEN UNIFORM(12000, 40000, RANDOM())
        WHEN 'Video'   THEN UNIFORM(3000, 15000, RANDOM())
        WHEN 'Search'  THEN UNIFORM(5000, 18000, RANDOM())
    END AS impressions,
    CASE cd.channel
        WHEN 'Display' THEN UNIFORM(80, 500, RANDOM())
        WHEN 'Social'  THEN UNIFORM(200, 1200, RANDOM())
        WHEN 'Video'   THEN UNIFORM(50, 300, RANDOM())
        WHEN 'Search'  THEN UNIFORM(300, 1500, RANDOM())
    END AS clicks,
    CASE cd.channel
        WHEN 'Display' THEN UNIFORM(5, 40, RANDOM())
        WHEN 'Social'  THEN UNIFORM(15, 80, RANDOM())
        WHEN 'Video'   THEN UNIFORM(3, 25, RANDOM())
        WHEN 'Search'  THEN UNIFORM(20, 120, RANDOM())
    END AS conversions,
    ROUND(cd.budget / cd.campaign_days * UNIFORM(70, 130, RANDOM()) / 100, 2) AS spend
FROM date_range d
CROSS JOIN campaign_dates cd
WHERE d.date BETWEEN cd.start_date AND LEAST(cd.end_date, '2026-10-28')
ORDER BY d.date, cd.campaign_id;

-- ---------------------------------------------------------------------------
-- RAW.CREATIVES
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ACME.RAW.CREATIVES (
    creative_id INT,
    campaign_id INT,
    format VARCHAR(30),
    headline VARCHAR(200),
    landing_page VARCHAR(200),
    status VARCHAR(20),
    created_date DATE
) COMMENT = 'Creative assets for campaigns';

INSERT INTO ACME.RAW.CREATIVES VALUES
(1001, 101, 'Banner 728x90', 'Your Dream Vacation Awaits', '/summer-getaway', 'Approved', '2026-05-20'),
(1002, 101, 'Banner 300x250', 'Book Now, Save 30%', '/summer-getaway', 'Approved', '2026-05-20'),
(1003, 102, 'Carousel', 'Gear Up for Back to School', '/back-to-school', 'Approved', '2026-07-15'),
(1004, 102, 'Story Ad', 'New Season, New Kicks', '/back-to-school', 'Approved', '2026-07-18'),
(1005, 103, 'Pre-Roll 15s', 'Taste the Future of Food', '/plant-based', 'Approved', '2026-07-01'),
(1006, 103, 'Pre-Roll 30s', 'GreenLeaf: Naturally Delicious', '/plant-based', 'Approved', '2026-07-01'),
(1007, 104, 'Search Text Ad', '5G Coverage in Your Area', '/5g-plans', 'Approved', '2026-04-20'),
(1008, 104, 'Search Text Ad', 'Unlimited 5G Starting at $45/mo', '/5g-plans', 'Approved', '2026-04-22'),
(1009, 105, 'Banner 300x600', 'Build Wealth That Lasts', '/wealth-builder', 'Approved', '2026-08-20'),
(1010, 106, 'Reel', 'Glow Up This Fall', '/fall-collection', 'Approved', '2026-09-01'),
(1011, 106, 'Story Ad', 'New Shades, New You', '/fall-collection', 'Paused', '2026-09-05'),
(1012, 107, 'Pre-Roll 30s', 'Truck Month is HERE', '/truck-month', 'Approved', '2026-09-15'),
(1013, 107, 'Pre-Roll 15s', 'Built Tough. Priced Right.', '/truck-month', 'Approved', '2026-09-15'),
(1014, 107, 'Connected TV 60s', 'The All-New Titan Trail', '/truck-month', 'In Review', '2026-09-20'),
(1015, 108, 'Search Text Ad', 'Free DevOps Webinar Series', '/devops-decoded', 'Approved', '2026-09-25'),
(1016, 110, 'Carousel', 'Craft Beer Fest This Weekend', '/beer-fest', 'Approved', '2026-08-25'),
(1017, 113, 'Reel', 'Neon Drift: Pre-Order Now', '/neon-drift', 'Approved', '2026-10-15'),
(1018, 113, 'Story Ad', 'Race Into the Neon', '/neon-drift', 'Approved', '2026-10-18'),
(1019, 115, 'Carousel', '$5 Off Your First Order', '/metro-eats-promo', 'Approved', '2026-08-10'),
(1020, 118, 'Banner 970x250', 'Fiber Fast. Fiber Now.', '/fiber-optic', 'Approved', '2026-08-28');

-- ---------------------------------------------------------------------------
-- RAW.CAMPAIGN_BRIEFS (semi-structured JSON)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ACME.RAW.CAMPAIGN_BRIEFS (
    brief_id INT,
    campaign_id INT,
    brief_data VARIANT,
    submitted_date DATE
) COMMENT = 'Campaign brief documents as semi-structured JSON';

INSERT INTO ACME.RAW.CAMPAIGN_BRIEFS
SELECT 1, 101, PARSE_JSON('{
    "title": "Summer Getaway 2026",
    "client": "Bright Horizon Hotels",
    "objective": "Drive awareness and bookings for summer travel season",
    "target_audience": {"age_range": "25-54", "interests": ["travel", "leisure", "family vacations"], "income": "mid-to-high"},
    "key_messages": ["Luxury for less", "Your dream vacation awaits", "Book direct and save 30%"],
    "deliverables": ["Display banners (728x90, 300x250)", "Landing page", "Retargeting pixels"],
    "success_metrics": {"target_ctr": 0.015, "target_bookings": 500, "target_roas": 4.2},
    "notes": "Client wants to emphasize family-friendly properties. Avoid any imagery that feels too exclusive or high-end."
}'), '2026-05-15'
UNION ALL
SELECT 2, 103, PARSE_JSON('{
    "title": "Plant-Based Launch",
    "client": "GreenLeaf Foods",
    "objective": "Launch new plant-based protein line across European markets",
    "target_audience": {"age_range": "22-45", "interests": ["health", "sustainability", "cooking"], "income": "mid"},
    "key_messages": ["Taste the future", "100% plant, 100% delicious", "Good for you, good for the planet"],
    "deliverables": ["15s and 30s pre-roll video", "Social carousel ads", "Influencer brief"],
    "success_metrics": {"target_views": 2000000, "target_trial_signups": 10000, "target_roas": 3.5},
    "notes": "Strict brand guidelines on green color palette. All claims must be verified by legal."
}'), '2026-06-28'
UNION ALL
SELECT 3, 107, PARSE_JSON('{
    "title": "Truck Month Madness",
    "client": "Titan Motors",
    "objective": "Drive dealer traffic and test drives during October truck month promotion",
    "target_audience": {"age_range": "30-65", "interests": ["trucks", "outdoors", "towing", "construction"], "income": "mid-to-high"},
    "key_messages": ["Built tough, priced right", "The all-new Titan Trail", "0% APR for 60 months"],
    "deliverables": ["30s and 15s pre-roll", "Connected TV 60s spot", "Dealer co-op display"],
    "success_metrics": {"target_dealer_visits": 15000, "target_test_drives": 3000, "target_leads": 8000},
    "notes": "Must include EPA fuel economy disclaimer. Financing offer subject to credit approval."
}'), '2026-09-10'
UNION ALL
SELECT 4, 113, PARSE_JSON('{
    "title": "Game Launch: Neon Drift",
    "client": "Vertex Gaming",
    "objective": "Maximize pre-orders and day-one sales for Neon Drift racing game",
    "target_audience": {"age_range": "16-35", "interests": ["gaming", "esports", "racing", "tech"], "income": "varies"},
    "key_messages": ["Race into the neon", "Pre-order for exclusive content", "Available on all platforms"],
    "deliverables": ["Social reels and story ads", "Twitch sponsorship brief", "Discord community campaign"],
    "success_metrics": {"target_preorders": 50000, "target_day1_sales": 200000, "target_social_impressions": 10000000},
    "notes": "ESRB rating pending. Gameplay footage must be from approved build only."
}'), '2026-10-10';

-- ---------------------------------------------------------------------------
-- STAGING: File format and internal stage
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT ACME.STAGING.CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMMENT = 'Standard CSV format for workshop exercises';

CREATE OR REPLACE STAGE ACME.STAGING.WORKSHOP_FILES
    COMMENT = 'Internal stage for workshop loading exercises';

-- Stage the new_clients CSV for Session A COPY INTO exercise
CREATE OR REPLACE TEMPORARY TABLE ACME.STAGING._NEW_CLIENTS_TEMP (
    client_id INT, client_name VARCHAR(100), industry VARCHAR(50),
    region VARCHAR(30), account_manager VARCHAR(80),
    contract_start_date DATE, annual_budget DECIMAL(12,2), is_active BOOLEAN
);

INSERT INTO ACME.STAGING._NEW_CLIENTS_TEMP VALUES
(16, 'Summit Health Systems', 'Healthcare', 'North America', 'Sarah Chen', '2026-11-01', 3200000.00, TRUE),
(17, 'Drift Electric', 'Automotive', 'EMEA', 'Marcus Webb', '2026-11-15', 4500000.00, TRUE),
(18, 'Blue Coral Resorts', 'Hospitality', 'APAC', 'Aiko Tanaka', '2026-12-01', 2100000.00, TRUE),
(19, 'Kinetic Fitness', 'Health & Wellness', 'North America', 'James Ortiz', '2026-11-01', 1400000.00, TRUE),
(20, 'Starboard Analytics', 'Technology', 'EMEA', 'Luisa Fernandez', '2026-12-15', 1800000.00, TRUE);

COPY INTO @ACME.STAGING.WORKSHOP_FILES/new_clients.csv
FROM (SELECT * FROM ACME.STAGING._NEW_CLIENTS_TEMP)
FILE_FORMAT = (TYPE = 'CSV' COMPRESSION = 'NONE')
HEADER = TRUE
OVERWRITE = TRUE
SINGLE = TRUE;

-- ===========================================================================
-- SESSION B: Roles, Grants, and Security Policies
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Custom Roles (used in Sessions B, C, and D)
-- ---------------------------------------------------------------------------
-- Role hierarchy: custom roles → SYSADMIN → ACCOUNTADMIN
CREATE ROLE IF NOT EXISTS ANALYST
    COMMENT = 'Read-only analyst role - can query RAW and ANALYTICS but not STAGING';
CREATE ROLE IF NOT EXISTS CAMPAIGN_MANAGER
    COMMENT = 'Campaign manager - can read RAW, write to ANALYTICS, limited by row access policy';
CREATE ROLE IF NOT EXISTS DATA_ENGINEER
    COMMENT = 'Data engineering role - full access to build pipelines (Session C)';

-- Role hierarchy
GRANT ROLE ANALYST TO ROLE SYSADMIN;
GRANT ROLE CAMPAIGN_MANAGER TO ROLE SYSADMIN;
GRANT ROLE DATA_ENGINEER TO ROLE SYSADMIN;

-- Make custom roles usable by ACCOUNTADMIN (the attendee's default)
GRANT ROLE ANALYST TO ROLE ACCOUNTADMIN;
GRANT ROLE CAMPAIGN_MANAGER TO ROLE ACCOUNTADMIN;
GRANT ROLE DATA_ENGINEER TO ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- Grants: ANALYST (read-only on RAW + ANALYTICS)
-- ---------------------------------------------------------------------------
GRANT USAGE ON DATABASE ACME TO ROLE ANALYST;
GRANT USAGE ON WAREHOUSE ACME_WH TO ROLE ANALYST;

GRANT USAGE ON SCHEMA ACME.RAW TO ROLE ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA ACME.RAW TO ROLE ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ACME.RAW TO ROLE ANALYST;

GRANT USAGE ON SCHEMA ACME.ANALYTICS TO ROLE ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA ACME.ANALYTICS TO ROLE ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ACME.ANALYTICS TO ROLE ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA ACME.ANALYTICS TO ROLE ANALYST;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA ACME.ANALYTICS TO ROLE ANALYST;

-- ---------------------------------------------------------------------------
-- Grants: CAMPAIGN_MANAGER (read RAW, read+write ANALYTICS)
-- ---------------------------------------------------------------------------
GRANT USAGE ON DATABASE ACME TO ROLE CAMPAIGN_MANAGER;
GRANT USAGE ON WAREHOUSE ACME_WH TO ROLE CAMPAIGN_MANAGER;

GRANT USAGE ON SCHEMA ACME.RAW TO ROLE CAMPAIGN_MANAGER;
GRANT SELECT ON ALL TABLES IN SCHEMA ACME.RAW TO ROLE CAMPAIGN_MANAGER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ACME.RAW TO ROLE CAMPAIGN_MANAGER;

GRANT USAGE ON SCHEMA ACME.ANALYTICS TO ROLE CAMPAIGN_MANAGER;
GRANT SELECT ON ALL TABLES IN SCHEMA ACME.ANALYTICS TO ROLE CAMPAIGN_MANAGER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ACME.ANALYTICS TO ROLE CAMPAIGN_MANAGER;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ACME.ANALYTICS TO ROLE CAMPAIGN_MANAGER;
GRANT INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA ACME.ANALYTICS TO ROLE CAMPAIGN_MANAGER;
GRANT CREATE TABLE ON SCHEMA ACME.ANALYTICS TO ROLE CAMPAIGN_MANAGER;
GRANT CREATE VIEW ON SCHEMA ACME.ANALYTICS TO ROLE CAMPAIGN_MANAGER;

-- ---------------------------------------------------------------------------
-- Grants: DATA_ENGINEER (full access for pipeline building in Session C)
-- ---------------------------------------------------------------------------
GRANT USAGE ON DATABASE ACME TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE ACME_WH TO ROLE DATA_ENGINEER;

GRANT USAGE ON SCHEMA ACME.RAW TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA ACME.RAW TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ACME.RAW TO ROLE DATA_ENGINEER;

GRANT ALL ON SCHEMA ACME.STAGING TO ROLE DATA_ENGINEER;
GRANT ALL ON ALL TABLES IN SCHEMA ACME.STAGING TO ROLE DATA_ENGINEER;
GRANT ALL ON FUTURE TABLES IN SCHEMA ACME.STAGING TO ROLE DATA_ENGINEER;

GRANT ALL ON SCHEMA ACME.ANALYTICS TO ROLE DATA_ENGINEER;
GRANT ALL ON ALL TABLES IN SCHEMA ACME.ANALYTICS TO ROLE DATA_ENGINEER;
GRANT ALL ON FUTURE TABLES IN SCHEMA ACME.ANALYTICS TO ROLE DATA_ENGINEER;

-- ---------------------------------------------------------------------------
-- Session C: PIPELINES schema and task privileges
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SCHEMA ACME.PIPELINES
    COMMENT = 'Pipeline objects: streams, tasks, dynamic tables (Session C)';

GRANT ALL ON SCHEMA ACME.PIPELINES TO ROLE DATA_ENGINEER;
GRANT ALL ON FUTURE TABLES IN SCHEMA ACME.PIPELINES TO ROLE DATA_ENGINEER;
GRANT ALL ON FUTURE DYNAMIC TABLES IN SCHEMA ACME.PIPELINES TO ROLE DATA_ENGINEER;
GRANT ALL ON FUTURE STREAMS IN SCHEMA ACME.PIPELINES TO ROLE DATA_ENGINEER;
GRANT ALL ON FUTURE TASKS IN SCHEMA ACME.PIPELINES TO ROLE DATA_ENGINEER;

-- DATA_ENGINEER needs EXECUTE TASK to run and schedule tasks
GRANT EXECUTE TASK ON ACCOUNT TO ROLE DATA_ENGINEER;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE DATA_ENGINEER;

-- Also need change tracking enabled on RAW.CAMPAIGNS for streams
ALTER TABLE ACME.RAW.CAMPAIGNS SET CHANGE_TRACKING = TRUE;

-- ---------------------------------------------------------------------------
-- Dynamic Data Masking Policy (Session B, Part 2)
-- Pre-created; attendees will apply it to a column during the exercise.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY ACME.RAW.BUDGET_MASK AS (val DECIMAL(12,2))
RETURNS DECIMAL(12,2) ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN') THEN val
    ELSE NULL
  END
COMMENT = 'Masks budget values for non-admin roles - Session B exercise';

-- ---------------------------------------------------------------------------
-- Row Access Policy (Session B, Part 3)
-- Pre-created; attendees will apply it to the CAMPAIGNS table.
-- CAMPAIGN_MANAGER can only see North America campaigns; admins see all.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE ROW ACCESS POLICY ACME.RAW.REGION_FILTER AS (region_val VARCHAR)
RETURNS BOOLEAN ->
  CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN', 'DATA_ENGINEER')
  OR (CURRENT_ROLE() = 'CAMPAIGN_MANAGER' AND region_val = 'North America')
  OR (CURRENT_ROLE() = 'ANALYST')  -- analysts can see all regions
COMMENT = 'Limits row visibility by region based on role - Session B exercise';

-- ===========================================================================
-- SESSION D: AI/Text Data (pre-load for Cortex AI exercises)
-- ===========================================================================

-- Customer feedback with mixed sentiment for Cortex AI functions
CREATE OR REPLACE TABLE ACME.RAW.CUSTOMER_FEEDBACK (
    feedback_id INT,
    campaign_id INT,
    feedback_date DATE,
    channel VARCHAR(30),
    feedback_text VARCHAR(1000),
    rating INT
) COMMENT = 'Customer feedback for Cortex AI exercises (Session D)';

INSERT INTO ACME.RAW.CUSTOMER_FEEDBACK VALUES
(1, 101, '2026-07-15', 'Email', 'The summer getaway ads were beautiful. Booked a trip to Hawaii because of them!', 5),
(2, 101, '2026-07-22', 'Social', 'Saw the ad on Instagram but the link was broken. Frustrating experience.', 2),
(3, 102, '2026-08-10', 'Social', 'Love the back-to-school campaign. My kids picked out three outfits from the collection.', 5),
(4, 103, '2026-08-05', 'Email', 'The plant-based messaging feels preachy. I already eat healthy, just show me the product.', 2),
(5, 103, '2026-09-01', 'Social', 'GreenLeaf is doing great things. The recipe series inspired me to try meal prepping.', 4),
(6, 104, '2026-06-18', 'Chat', 'Your 5G coverage map says I have coverage but I get zero signal at my house. False advertising.', 1),
(7, 104, '2026-07-30', 'Email', 'Switched to Nova 5G last month. Fastest internet I have ever had. Worth every penny.', 5),
(8, 105, '2026-09-20', 'Email', 'The wealth builder webinar was informative but too long. Get to the point faster.', 3),
(9, 107, '2026-10-05', 'Social', 'TRUCK MONTH! Just test-drove the Titan Trail and I am sold. Picking it up Friday.', 5),
(10, 107, '2026-10-12', 'Chat', 'The 0% APR offer said 60 months but the dealer told me it is only 36. Misleading.', 1),
(11, 110, '2026-09-15', 'Social', 'Great craft beer fest! The Redwood stout was incredible. Hope they do this again.', 5),
(12, 113, '2026-11-05', 'Social', 'Neon Drift is amazing. Best racing game I have played in years. Graphics are insane.', 5),
(13, 113, '2026-11-10', 'Chat', 'Pre-ordered Neon Drift but the exclusive content code never arrived. Support is no help.', 1),
(14, 115, '2026-09-08', 'Email', 'Used the $5 off promo for Metro Eats. Food arrived cold and 45 minutes late.', 1),
(15, 115, '2026-09-25', 'Social', 'Metro Eats city blitz promo got me to try the app. Now I order twice a week. Great deal.', 4),
(16, 106, '2026-10-01', 'Social', 'The Glow Up fall collection is gorgeous. Already ordered three items.', 5),
(17, 106, '2026-10-15', 'Email', 'Received the wrong shade of foundation from the fall collection. Return process was easy though.', 3),
(18, 108, '2026-10-20', 'Email', 'The DevOps Decoded webinar series is exactly what our team needed. Very practical content.', 5),
(19, 114, '2026-04-15', 'Social', 'Bright Horizon spring refresh deals were okay. Nothing special compared to competitors.', 3),
(20, 118, '2026-09-28', 'Chat', 'Fiber optic installation was seamless. Went from 50 Mbps to 1 Gbps overnight. Life changing.', 5);

-- Grant ANALYST and CAMPAIGN_MANAGER read access to feedback table
GRANT SELECT ON TABLE ACME.RAW.CUSTOMER_FEEDBACK TO ROLE ANALYST;
GRANT SELECT ON TABLE ACME.RAW.CUSTOMER_FEEDBACK TO ROLE CAMPAIGN_MANAGER;
GRANT SELECT ON TABLE ACME.RAW.CUSTOMER_FEEDBACK TO ROLE DATA_ENGINEER;

-- ===========================================================================
-- SESSION E: Large table for performance tuning exercises
-- ===========================================================================
-- The existing DAILY_IMPRESSIONS table (~930 rows) fits in a single micro-partition,
-- so clustering and pruning demos don't show meaningful results.
-- This table generates ~1M rows of hourly impression data across cities and devices,
-- ordered randomly so that:
--   - Multiple micro-partitions exist (~8 partitions)
--   - campaign_id and event_hour values are spread across all partitions (high depth)
--   - Clustering keys have something to optimize
--   - Search Optimization and Query Acceleration have data to work with

CREATE OR REPLACE TABLE ACME.RAW.HOURLY_IMPRESSIONS (
    event_hour TIMESTAMP_NTZ,
    campaign_id INT,
    channel VARCHAR(30),
    region VARCHAR(30),
    city VARCHAR(50),
    device_type VARCHAR(20),
    impressions INT,
    clicks INT,
    conversions INT,
    spend DECIMAL(10,2),
    cpm DECIMAL(8,2),
    bounce_rate DECIMAL(5,2),
    session_id VARCHAR(100),
    user_agent VARCHAR(200)
) COMMENT = 'Hourly advertising performance - large table for Session E tuning exercises';

INSERT INTO ACME.RAW.HOURLY_IMPRESSIONS
WITH hours AS (
    SELECT DATEADD(hour, seq4(), '2023-01-01 00:00:00')::TIMESTAMP_NTZ AS event_hour
    FROM TABLE(GENERATOR(ROWCOUNT => 26280))  -- 3 years of hours
),
campaign_info AS (
    SELECT c.campaign_id, c.channel, cl.region, c.budget,
           GREATEST(DATEDIFF(day, c.start_date, c.end_date) + 1, 1) AS campaign_days
    FROM ACME.RAW.CAMPAIGNS c
    JOIN ACME.RAW.CLIENTS cl ON c.client_id = cl.client_id
),
cities AS (
    SELECT column1 AS city FROM VALUES
    ('New York'),('Los Angeles'),('Chicago'),('London'),('Tokyo'),
    ('Sydney'),('Toronto'),('Paris'),('Mumbai'),('Berlin')
),
devices AS (
    SELECT column1 AS device_type FROM VALUES
    ('Mobile'),('Desktop'),('Tablet'),('Connected TV')
)
SELECT
    h.event_hour, ci.campaign_id, ci.channel, ci.region, ct.city, dv.device_type,
    CASE ci.channel
        WHEN 'Display' THEN UNIFORM(100, 500, RANDOM())
        WHEN 'Social'  THEN UNIFORM(200, 800, RANDOM())
        WHEN 'Video'   THEN UNIFORM(50, 300, RANDOM())
        WHEN 'Search'  THEN UNIFORM(80, 400, RANDOM())
    END AS impressions,
    CASE ci.channel
        WHEN 'Display' THEN UNIFORM(1, 12, RANDOM())
        WHEN 'Social'  THEN UNIFORM(3, 25, RANDOM())
        WHEN 'Video'   THEN UNIFORM(1, 8, RANDOM())
        WHEN 'Search'  THEN UNIFORM(5, 30, RANDOM())
    END AS clicks,
    UNIFORM(0, 3, RANDOM()) AS conversions,
    ROUND(ci.budget / ci.campaign_days / 24 / 40 * UNIFORM(50, 150, RANDOM()) / 100, 2) AS spend,
    ROUND(UNIFORM(200, 1500, RANDOM()) / 100.0, 2) AS cpm,
    ROUND(UNIFORM(1500, 8500, RANDOM()) / 100.0, 2) AS bounce_rate,
    UUID_STRING() AS session_id,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0'
        WHEN 2 THEN 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15'
        WHEN 3 THEN 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 Safari/537.36'
        ELSE 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120.0 Mobile'
    END AS user_agent
FROM hours h
CROSS JOIN campaign_info ci
CROSS JOIN cities ct
CROSS JOIN devices dv
WHERE UNIFORM(1, 20, RANDOM()) <= 1  -- ~5% sampling to get ~1M rows
ORDER BY RANDOM();  -- Random order ensures data is spread across partitions

-- Grant access to all roles
GRANT SELECT ON TABLE ACME.RAW.HOURLY_IMPRESSIONS TO ROLE ANALYST;
GRANT SELECT ON TABLE ACME.RAW.HOURLY_IMPRESSIONS TO ROLE CAMPAIGN_MANAGER;
GRANT SELECT ON TABLE ACME.RAW.HOURLY_IMPRESSIONS TO ROLE DATA_ENGINEER;

-- ---------------------------------------------------------------------------
-- Verify setup
-- ---------------------------------------------------------------------------
SELECT 'Setup complete' AS status,
       (SELECT COUNT(*) FROM ACME.RAW.CLIENTS) AS clients,
       (SELECT COUNT(*) FROM ACME.RAW.CAMPAIGNS) AS campaigns,
       (SELECT COUNT(*) FROM ACME.RAW.DAILY_IMPRESSIONS) AS daily_impressions,
       (SELECT COUNT(*) FROM ACME.RAW.CREATIVES) AS creatives,
       (SELECT COUNT(*) FROM ACME.RAW.CAMPAIGN_BRIEFS) AS campaign_briefs,
       (SELECT COUNT(*) FROM ACME.RAW.CUSTOMER_FEEDBACK) AS customer_feedback,
       (SELECT COUNT(*) FROM ACME.RAW.HOURLY_IMPRESSIONS) AS hourly_impressions;
