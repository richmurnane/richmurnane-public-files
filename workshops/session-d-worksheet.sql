-- =============================================================================
-- Session D: Cortex AI, Apps, and the Art of the Possible - Worksheet SQL
-- =============================================================================
-- This session shows what's possible when you add AI to your data platform.
-- Everything here runs as SQL -- no Python, no ML expertise, no external tools.
--
-- By the end you'll have: analyzed sentiment, built a semantic model,
-- asked natural-language questions, created an AI agent, and deployed a dashboard.
-- =============================================================================

-- =====================
-- SET SESSION CONTEXT
-- =====================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE ACME_WH;
USE DATABASE ACME;
USE SCHEMA RAW;


-- =====================
-- PART 1: Cortex AI Functions
-- =====================
-- Snowflake has built-in AI functions you can call directly in SQL.
-- No model training, no API keys, no Python -- just SQL.
-- Docs: https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions

-- 1.1 Sentiment analysis
-- AI_SENTIMENT analyzes text and returns a sentiment label (positive, negative, or neutral).
SELECT
    feedback_id,
    feedback_text,
    rating,
    SNOWFLAKE.CORTEX.AI_SENTIMENT(feedback_text):categories[0]:sentiment::STRING AS sentiment
FROM ACME.RAW.CUSTOMER_FEEDBACK
ORDER BY rating;

-- 1.2 Classification
-- AI_CLASSIFY categorizes text into labels you define. Returns the best-matching label.
SELECT
    feedback_id,
    feedback_text,
    SNOWFLAKE.CORTEX.AI_CLASSIFY(
        feedback_text,
        ['Complaint', 'Praise', 'Suggestion', 'Question']
    ):labels[0]::STRING AS classification
FROM ACME.RAW.CUSTOMER_FEEDBACK
LIMIT 10;

-- 1.3 Entity extraction
-- AI_EXTRACT pulls structured data out of unstructured text.
-- The result is JSON with the fields you asked for.
SELECT
    feedback_id,
    feedback_text,
    SNOWFLAKE.CORTEX.AI_EXTRACT(
        feedback_text,
        ['product_name', 'issue', 'positive_aspect']
    ):response:product_name::STRING AS product_name,
    SNOWFLAKE.CORTEX.AI_EXTRACT(
        feedback_text,
        ['product_name', 'issue', 'positive_aspect']
    ):response:issue::STRING AS issue
FROM ACME.RAW.CUSTOMER_FEEDBACK
LIMIT 10;

-- 1.4 LLM prompting with AI_COMPLETE
-- AI_COMPLETE sends a prompt to a Cortex-hosted LLM and returns the response.
-- Here we generate a professional reply to a negative review.
SELECT
    feedback_text,
    SNOWFLAKE.CORTEX.AI_COMPLETE(
        'claude-sonnet-4-6',
        'You are a customer success manager at ACME, an advertising company. '
        || 'Write a professional, empathetic 2-sentence response to this customer feedback: '
        || feedback_text
    ) AS suggested_response
FROM ACME.RAW.CUSTOMER_FEEDBACK
WHERE rating <= 2
LIMIT 3;

-- TRY IT: Use AI_SENTIMENT to find all negative feedback.
-- Hint: WHERE ... :categories[0]:sentiment::STRING = 'negative'


-- =====================
-- PART 2: Create a Semantic View
-- =====================
-- A semantic view defines a business-level data model on top of your tables.
-- It tells Snowflake how tables relate, what the dimensions and metrics are,
-- and how to join them. This is what powers Cortex Analyst (natural-language SQL).
-- Docs: https://docs.snowflake.com/en/user-guide/views-semantic/sql

USE SCHEMA ACME.ANALYTICS;

-- 2.1 Create the semantic view
-- This defines ACME's campaign performance model: clients, campaigns, and daily metrics.
CREATE OR REPLACE SEMANTIC VIEW ACME.ANALYTICS.ACME_CAMPAIGN_MODEL

  TABLES (
    clients AS ACME.RAW.CLIENTS
      PRIMARY KEY (client_id)
      COMMENT = 'ACME advertising clients',
    campaigns AS ACME.RAW.CAMPAIGNS
      PRIMARY KEY (campaign_id)
      COMMENT = 'Advertising campaigns',
    daily_impressions AS ACME.RAW.DAILY_IMPRESSIONS
      PRIMARY KEY (date, campaign_id)
      COMMENT = 'Daily performance metrics'
  )

  RELATIONSHIPS (
    campaigns (client_id) REFERENCES clients,
    daily_impressions (campaign_id) REFERENCES campaigns
  )

  DIMENSIONS (
    clients.client_name AS client_name
      COMMENT = 'Name of the advertising client',
    clients.region AS region
      COMMENT = 'Geographic region (North America, EMEA, APAC)'
      SAMPLE_VALUES ('North America', 'EMEA', 'APAC') IS_ENUM,
    clients.industry AS industry
      COMMENT = 'Client industry vertical',
    campaigns.campaign_name AS campaign_name
      COMMENT = 'Name of the advertising campaign',
    campaigns.channel AS channel
      COMMENT = 'Advertising channel'
      SAMPLE_VALUES ('Display', 'Social', 'Video', 'Search') IS_ENUM,
    campaigns.status AS status
      COMMENT = 'Campaign status'
      SAMPLE_VALUES ('Active', 'Completed', 'Planned') IS_ENUM,
    daily_impressions.date AS date
      COMMENT = 'Date of the impression data'
  )

  METRICS (
    campaigns.campaign_count AS COUNT(campaign_id)
      COMMENT = 'Number of campaigns',
    daily_impressions.total_impressions AS SUM(impressions)
      COMMENT = 'Total ad impressions',
    daily_impressions.total_clicks AS SUM(clicks)
      COMMENT = 'Total ad clicks',
    daily_impressions.total_spend AS SUM(spend)
      COMMENT = 'Total ad spend in dollars',
    daily_impressions.total_conversions AS SUM(conversions)
      COMMENT = 'Total conversions',
    daily_impressions.ctr AS SUM(clicks) / NULLIF(SUM(impressions), 0) * 100
      COMMENT = 'Click-through rate percentage',
    daily_impressions.cost_per_click AS SUM(spend) / NULLIF(SUM(clicks), 0)
      COMMENT = 'Average cost per click in dollars'
  )

  COMMENT = 'ACME campaign performance model for Cortex Analyst and Cortex Agents';

-- 2.2 Verify the semantic view was created
DESCRIBE SEMANTIC VIEW ACME.ANALYTICS.ACME_CAMPAIGN_MODEL;

-- 2.3 Query the semantic view directly
-- SEMANTIC_VIEW() lets you query using the business-level names you defined.
SELECT * FROM SEMANTIC_VIEW(
  ACME.ANALYTICS.ACME_CAMPAIGN_MODEL
  METRICS daily_impressions.total_spend, daily_impressions.ctr
  DIMENSIONS campaigns.channel
);

-- TRY IT: Query the semantic view for total_spend and total_clicks by region.
-- Hint: change DIMENSIONS to clients.region


-- =====================
-- PART 3: Create a Cortex Agent (Natural-Language Queries)
-- =====================
-- A Cortex Agent is a conversational interface to your data.
-- It uses the semantic view you just created as a tool -- specifically, it uses
-- Cortex Analyst under the hood to convert natural-language questions into SQL.
-- You can query it via SQL, in the Snowsight UI, or in CoWork.
-- Docs: https://docs.snowflake.com/en/sql-reference/sql/create-agent

-- 3.1 Create the agent
CREATE OR REPLACE AGENT ACME.ANALYTICS.ACME_AGENT
  COMMENT = 'ACME campaign performance assistant'
  PROFILE = '{"display_name": "ACME Campaign Assistant", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: "You are an advertising analytics assistant for ACME. Answer questions about campaign performance, client budgets, and channel effectiveness. Be concise and include numbers."
    sample_questions:
      - question: "What is the total spend by channel?"
      - question: "Which client has the highest CTR?"
      - question: "Show me the top 5 campaigns by spend"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "CampaignAnalyst"
        description: "Analyzes ACME campaign performance data including spend, impressions, clicks, and conversions"

  tool_resources:
    CampaignAnalyst:
      semantic_view: "ACME.ANALYTICS.ACME_CAMPAIGN_MODEL"
  $$;

-- 3.2 Verify the agent was created
DESCRIBE AGENT ACME.ANALYTICS.ACME_AGENT;

-- 3.3 Ask the agent a question via SQL
-- DATA_AGENT_RUN sends a natural-language question to the agent.
-- Under the hood, the agent uses Cortex Analyst to convert your question to SQL,
-- runs the SQL, and returns the answer.
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'ACME.ANALYTICS.ACME_AGENT',
    $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What is the total spend by channel?"}]}]}$$,
    TRUE
  )
) AS agent_response;

-- 3.4 Try more questions
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'ACME.ANALYTICS.ACME_AGENT',
    $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Which region has the most campaigns?"}]}]}$$,
    TRUE
  )
) AS agent_response;

-- 3.5 Try more questions
SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'ACME.ANALYTICS.ACME_AGENT',
    $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Which client has the highest total spend?"}]}]}$$,
    TRUE
  )
) AS agent_response;

SELECT TRY_PARSE_JSON(
  SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'ACME.ANALYTICS.ACME_AGENT',
    $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Show me daily spend trends for Social campaigns in October 2026"}]}]}$$,
    TRUE
  )
) AS agent_response;

-- 3.6 Use the agent in Snowsight (UI playground)
-- You can also interact with the agent through the Snowsight UI:
--   1. Click "AI & ML" in the left sidebar
--   2. Click "Agents"
--   3. Find "ACME_AGENT" in the list and click on it
--   4. Type a question in the agent playground and press Enter
--   5. The agent generates SQL, runs it, and returns the answer

-- 3.7 Add the agent to CoWork
-- CoWork is Snowflake's collaborative AI workspace where teams interact with agents.
--   1. Go to CoWork (snowflake.com/cowork or click "CoWork" in the left sidebar)
--   2. Start a new conversation
--   3. Tag the agent by typing @ACME Campaign Assistant
--   4. Ask a question like "What is our total spend this month?"
-- The agent shows up in CoWork automatically after creation -- no extra setup needed.

-- TRY IT: Ask the agent your own question. Some ideas:
--   "What is the average cost per click by channel?"
--   "Which region has the most active campaigns?"
--   "Compare Display and Social channels -- which has better CTR?"


-- =====================
-- PART 4: Cortex Code + Streamlit (Build an App with AI)
-- =====================
-- Cortex Code is Snowflake's AI coding assistant. It can generate Streamlit apps.
-- Streamlit in Snowflake lets you build and deploy interactive data apps.
-- This is the capstone: AI analyzed your data, now AI builds your dashboard.

-- 4.1 Use Cortex Code to generate a Streamlit app
-- In Snowsight:
--   1. Click "Projects" in the left sidebar
--   2. Click "Streamlit" > "+ Streamlit App"
--   3. Name it "ACME Dashboard", set warehouse to ACME_WH, database to ACME
--   4. In the code editor, open the AI assistant (Cortex Code)
--   5. Paste this prompt:
--
--      "Build a Streamlit app that shows ACME campaign performance.
--       Include: a bar chart of total spend by channel from ACME.RAW.DAILY_IMPRESSIONS
--       joined to ACME.RAW.CAMPAIGNS, a table of top campaigns by CTR,
--       and a section that shows AI_SENTIMENT scores from ACME.RAW.CUSTOMER_FEEDBACK
--       joined to campaign names."
--
--   6. Let Cortex Code generate the code
--   7. Click "Run" to see the app

-- 4.2 FALLBACK: If Cortex Code isn't available, paste this starter app:
-- (Create a new Streamlit app and paste the code below into the editor)
--
-- import streamlit as st
-- from snowflake.snowpark.context import get_active_session
--
-- session = get_active_session()
-- st.title("ACME Campaign Dashboard")
--
-- # Spend by channel
-- st.subheader("Total Spend by Channel")
-- spend_df = session.sql("""
--     SELECT ca.channel, SUM(di.spend) AS total_spend
--     FROM ACME.RAW.DAILY_IMPRESSIONS di
--     JOIN ACME.RAW.CAMPAIGNS ca ON di.campaign_id = ca.campaign_id
--     GROUP BY ca.channel ORDER BY total_spend DESC
-- """).to_pandas()
-- st.bar_chart(spend_df.set_index("CHANNEL"))
--
-- # Top campaigns by CTR
-- st.subheader("Top Campaigns by CTR")
-- ctr_df = session.sql("""
--     SELECT ca.campaign_name, ca.channel,
--            ROUND(SUM(di.clicks) / NULLIF(SUM(di.impressions), 0) * 100, 2) AS ctr
--     FROM ACME.RAW.DAILY_IMPRESSIONS di
--     JOIN ACME.RAW.CAMPAIGNS ca ON di.campaign_id = ca.campaign_id
--     GROUP BY ca.campaign_name, ca.channel
--     HAVING SUM(di.impressions) > 0
--     ORDER BY ctr DESC LIMIT 10
-- """).to_pandas()
-- st.dataframe(ctr_df)
--
-- # Sentiment analysis
-- st.subheader("Customer Feedback Sentiment")
-- sent_df = session.sql("""
--     SELECT cf.feedback_text, cf.rating,
--            SNOWFLAKE.CORTEX.AI_SENTIMENT(cf.feedback_text):categories[0]:sentiment::STRING AS sentiment
--     FROM ACME.RAW.CUSTOMER_FEEDBACK cf
--     ORDER BY cf.rating
-- """).to_pandas()
-- st.dataframe(sent_df)

-- TRY IT: Modify the Streamlit app to add a filter for channel or region.


-- =====================
-- PART 5: Stretch Goals
-- =====================
-- Finished early? Try these.

-- 5A: Summarize all feedback for a specific campaign
SELECT SNOWFLAKE.CORTEX.AI_COMPLETE(
    'claude-sonnet-4-6',
    'Summarize the following customer feedback into 3 bullet points highlighting '
    || 'key themes and sentiment. Feedback: '
    || LISTAGG(cf.feedback_text, ' | ') WITHIN GROUP (ORDER BY cf.feedback_date)
) AS campaign_summary
FROM ACME.RAW.CUSTOMER_FEEDBACK cf
JOIN ACME.RAW.CAMPAIGNS ca ON cf.campaign_id = ca.campaign_id
WHERE ca.campaign_name = 'Truck Month Madness'
GROUP BY ca.campaign_name;

-- 5B: Add a verified query to the semantic view
-- Verified queries teach Cortex Analyst the "right" SQL for common questions.
-- They must be included in a CREATE OR ALTER SEMANTIC VIEW statement.
-- To add one, you re-issue the full semantic view definition with the verified query appended.
-- Here's what the clause looks like (add it at the end of the CREATE SEMANTIC VIEW from Part 2,
-- after the COMMENT line and before the semicolon):
--
--   AI_VERIFIED_QUERIES (
--     spend_by_channel AS (
--       QUESTION 'What is the total spend by channel?'
--       SQL 'SELECT campaigns.channel, SUM(daily_impressions.spend) AS total_spend
--            FROM ACME.RAW.DAILY_IMPRESSIONS daily_impressions
--            JOIN ACME.RAW.CAMPAIGNS campaigns ON daily_impressions.campaign_id = campaigns.campaign_id
--            GROUP BY campaigns.channel
--            ORDER BY total_spend DESC'
--     )
--   )

-- 5C: Translate feedback to another language
SELECT
    feedback_text,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(feedback_text, 'en', 'es') AS spanish,
    SNOWFLAKE.CORTEX.AI_TRANSLATE(feedback_text, 'en', 'fr') AS french
FROM ACME.RAW.CUSTOMER_FEEDBACK
LIMIT 5;
