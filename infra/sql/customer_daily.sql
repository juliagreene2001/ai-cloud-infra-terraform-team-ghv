CREATE OR REPLACE TABLE
  `advanced-cloud-ai.team_ghv.customer_daily` AS

WITH flux AS (
  SELECT
    TX_ID,
    ANY_VALUE(TX_TS) AS TX_TS,
    ANY_VALUE(CUSTOMER_ID) AS CUSTOMER_ID,
    ANY_VALUE(TX_AMOUNT) AS TX_AMOUNT
  FROM `advanced-cloud-ai.team_ghv.tx_history`
  WHERE TX_TS >= TIMESTAMP '2026-10-01'
  GROUP BY TX_ID
),

tx AS (
  SELECT
    TX_TS,
    CUSTOMER_ID,
    TX_AMOUNT
  FROM `advanced-cloud-ai.fraudfinder.tx_seed`
  WHERE TX_TS >= TIMESTAMP '2026-09-10'

  UNION ALL

  SELECT
    TX_TS,
    CUSTOMER_ID,
    TX_AMOUNT
  FROM flux
)

SELECT
  CUSTOMER_ID AS customer_id,
  DATE(TX_TS) AS day,
  COUNT(*) AS n,
  SUM(TX_AMOUNT) AS amount_sum
FROM tx
GROUP BY customer_id, day;