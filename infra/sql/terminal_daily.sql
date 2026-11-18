CREATE OR REPLACE TABLE
  `advanced-cloud-ai.team_ghv.terminal_daily` AS

WITH flux AS (
  SELECT
    TX_ID,
    ANY_VALUE(TX_TS) AS TX_TS,
    ANY_VALUE(TERMINAL_ID) AS TERMINAL_ID
  FROM `advanced-cloud-ai.team_ghv.tx_history`
  WHERE TX_TS >= TIMESTAMP '2026-10-01'
  GROUP BY TX_ID
),

tx AS (
  SELECT
    TX_TS,
    TERMINAL_ID,
    TX_FRAUD
  FROM `advanced-cloud-ai.fraudfinder.tx_seed`
  WHERE TX_TS >= TIMESTAMP '2026-09-10'

  UNION ALL

  SELECT
    TX_TS,
    TERMINAL_ID,
    CAST(NULL AS INT64) AS TX_FRAUD
  FROM flux
)

SELECT
  TERMINAL_ID AS terminal_id,
  DATE(TX_TS) AS day,
  COUNT(*) AS n,
  COUNTIF(TX_FRAUD = 1) AS n_fraud
FROM tx
GROUP BY terminal_id, day;