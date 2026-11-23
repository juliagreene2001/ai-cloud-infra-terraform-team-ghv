# Session 4 report — team-ghv

Initial observation date: 16 November 2026. Part B screenshot checkpoints updated
on 18 November 2026. Times below are Europe/Paris (CET, UTC+1), unless explicitly
marked UTC. This is an in-progress report: verified results are separated from
expected checkpoints and measurements still required.

The accompanying data include BigQuery job IDs and byte counts, the 500
Parquet lookup times used for the percentiles, and both HNSW benchmark tables.
[Download the measurement data](measurements.json).

## Required measurements

| Measurement | Observed result / status |
| --- | --- |
| October 1 history rows, distinct transactions, duplicates | **101,359 rows; 100,859 distinct `TX_ID`; 500 extra rows.** A separate grouping query confirms 500 transaction IDs each appear twice. |
| Distinct Pub/Sub publications | **101,359 distinct `message_id`**; no missing transaction/message IDs in this day's rows. |
| Bytes processed by the count query, with / without the `TX_TS` filter | Fresh uncached comparison: **6,993,771 bytes / 6,182,899 bytes** (6.993771 MB / 6.182899 MB; decimal MB). Both jobs report 10,485,760 bytes billed. |
| Result of the supplied `check.sql` | **Confirmed again after the rebuilds in the November 18 screenshot: customer 0, terminal 0 differing rows.** The supplied comparison is one-way and checks September only. |
| Customer `7989449428740969`, October 1, in `customer_daily` | **Confirmed in the November 18 supplied screenshot: `n = 5`, rounded `amount_sum = 100.79`.** |
| October 1 totals in `terminal_daily` | **Confirmed in the November 18 supplied screenshot: `SUM(n) = 100,859`, `SUM(n_fraud) = 0`.** The zero does not establish absence of fraud: replay labels are unknown. |
| Counter lookup, `parquet`, p50 / p99 | **0.63 ms / 2.64 ms**, from the most recent 500 matching log entries on the observation date. Sample/window details below. |
| Counter lookup, `bigquery`, p50 / p99 | Pending: no matching `scored` entries with `source="bigquery"` were found in the searched date window. |
| Counter lookup, `firestore`, p50 / p99 | Pending: no matching `scored` entries with `source="firestore"` were found in the searched date window. |
| Reference transaction score: `parquet`, `bigquery`, `firestore` | **0.00010230999760096893 / 0.00019268736650701612 / 0.00019268736650701612**; the BigQuery and Firestore scores match for the reference transaction. |
| Part D setting achieving recall@10 >= 0.95 | **Selected by lowest observed passing server median: `m=16, ef=8`, recall 0.991, p50 0.40 ms, p95 0.58 ms.** The only passing tested `m=4` setting is `ef=256`: 0.965, 0.95 ms, 1.49 ms. This selection has not been applied to the currently loaded `m=4` index. |
| Part D: three other clients sharing the document of `0018478647296750` | **`3263319564977208` (0.9997), `2947552228922773` (0.9996), `0553287702820053` (0.9990)**. Matching employee, employer, period and address, with altered salary amounts; confirmed against local synthetic document texts. |
| Terraform and SQL repository | https://github.com/juliagreene2001/ai-cloud-infra-terraform-team-ghv |
| Service repository | https://github.com/juliagreene2001/fraud-api-albertschool-team-ghv |

## Step 0 — Starting state and seed data

The read-only seed query returned seven days, September 24–30, with approximately
100,000 transactions per day. Its job was created at **23:11:17.869 CET** and
reported **11,259,488 bytes processed**, with `cacheHit=false`.

| Transaction day | Transactions | Fraud labels equal to 1 |
| --- | ---: | ---: |
| 2026-09-24 | 100,715 | 1,459 |
| 2026-09-25 | 100,398 | 1,119 |
| 2026-09-26 | 100,323 | 1,079 |
| 2026-09-27 | 100,046 | 694 |
| 2026-09-28 | 100,573 | 1,265 |
| 2026-09-29 | 100,854 | 1,578 |
| 2026-09-30 | 100,809 | 1,504 |
| **Total** | **703,718** | **8,698** |

```sql
SELECT DATE(TX_TS) AS day,
       COUNT(*) AS transactions,
       SUM(TX_FRAUD) AS frauds
FROM `advanced-cloud-ai.fraudfinder.tx_seed`
WHERE TX_TS >= TIMESTAMP '2026-09-24'
GROUP BY day
ORDER BY day;
```

The earlier Step 0 apply changed the scoring subscription to
`projects/cymbal-fraudfinder/topics/ff-tx`, as instructed for Part A. A later live
inspection during record collection found it back on `ff-replay`, with the
Session 4 reference image deployed. This report records both observations without
attributing the later change to an operator.

## Part A — History ingestion

### Verified resources

| Resource / setting | Live observation |
| --- | --- |
| Project / location | `advanced-cloud-ai` / `europe-west1` |
| History subscription | `team-ghv-tx-history`, `ACTIVE` |
| History source | `projects/advanced-cloud-ai/topics/ff-replay` |
| Destination table | `advanced-cloud-ai.team_ghv.tx_history` |
| Partitioning | `DAY` on transaction timestamp `TX_TS` |
| BigQuery subscription state | `ACTIVE`; `useTableSchema=true`, `writeMetadata=true` |
| Teacher's distinct-transaction checkpoint | **100,859**, matched by the October 1 query |

The table and subscription already existed in shared Terraform state when the
refreshed Part A plan was inspected; that plan reported no changes. Their
creation is not attributed to this record-collection task.

### Replay progress recovered from stored query jobs

These figures were retrieved from the original completed jobs, in addition to
the screenshots supplied during the exercise. Counts increased while the replay
was arriving; they are observations at different times, not separate replay totals.

| Query creation time, CET | Scope | Rows | Distinct transactions | Distinct messages | Bytes processed |
| --- | --- | ---: | ---: | ---: | ---: |
| 20:09:20.488 | `TX_TS >= 2026-10-01` | 37,934 | 37,934 | 37,934 | 0 |
| 20:10:14.011 | October 1 only | 64,698 | 64,698 | 64,698 | 0 |
| 20:10:33.261 | No date filter | 74,327 | 74,327 | 74,327 | 0 |
| 20:12:10.387 | October 1 only | **101,359** | **100,859** | **101,359** | 0 |

All four original jobs report `cacheHit=false` and zero bytes billed. The cause
of their zero processed-byte figures was not established. Do not interpret them
as cache hits or as proof that the overall ingestion pipeline costs nothing.

The following bounded query isolates the requested transaction day:

```sql
SELECT
  COUNT(*) AS rows_received,
  COUNT(DISTINCT TX_ID) AS distinct_transactions,
  COUNT(DISTINCT message_id) AS distinct_messages
FROM `advanced-cloud-ai.team_ghv.tx_history`
WHERE TX_TS >= TIMESTAMP '2026-10-01'
  AND TX_TS < TIMESTAMP '2026-10-02';
```

### Post-replay verification and query bytes

A separate read-only verification at **23:10:52.061 CET** confirmed the same
101,359 rows, 100,859 distinct transactions and 101,359 distinct messages.
Grouping by `TX_ID` confirmed **500 repeated transaction IDs**, **two copies at
most per transaction**, and **zero rows with a missing transaction or message ID**.

Two new count jobs were then run with the result cache disabled and a 1 GiB
maximum-bytes-billed limit per query:

| Query | Creation time, CET | Rows / distinct TX / distinct messages | Bytes processed | Bytes billed | Cache hit |
| --- | --- | --- | ---: | ---: | --- |
| With the bounded `TX_TS` filter above | 23:12:30.857 | 101,359 / 100,859 / 101,359 | **6,993,771** | 10,485,760 | false |
| Same query without `WHERE` | 23:12:30.866 | 101,359 / 100,859 / 101,359 | **6,182,899** | 10,485,760 | false |

**No byte saving was observed in this comparison.** The filtered job processed
810,872 more bytes. Both queries selected all current history rows; there was no
row reduction from this date filter. The filter also references `TX_TS`, which
the unfiltered count does not. These results do not demonstrate a partition-pruning
saving across multiple populated transaction days. The earlier zero-byte jobs and
these later nonzero jobs must remain separate observations.

### Answers to the Part A questions

1. **Duplicate origin.** There are 500 extra rows and every stored row has a
   different `message_id`. This supports a second publication of the repeated
   business transactions. Redelivery of an existing Pub/Sub publication retains
   its message ID; these stored duplicates have distinct publication IDs. This
   does not establish global exactly-once processing.
2. **Independence from Cloud Run.** `team-ghv-tx-history` is a BigQuery
   subscription: Pub/Sub writes directly to the history table. The scoring
   service is not required for that path. If history writing were inside
   `/pubsub`, an unavailable service could not execute the write; messages would
   wait/retry subject to retention and delivery policies.
3. **Partition on the transaction date.** `TX_TS` identifies the business day
   being aggregated. The replay contains October 1 transactions published in
   November; partitioning on publication time would group replayed transactions
   by their arrival date instead of the day being analysed.

## Part B — Aggregate rebuilds and validation

### Initial baseline, November 16

The teacher's supplied `check.sql`, with project/dataset names substituted, was
executed read-only at **23:14:31.051 CET**. It returned:

| Comparison | Differing rows |
| --- | ---: |
| Customer | **0** |
| Terminal | **0** |

An independent coverage query found:

| Table | Rows | First day | Last day | Transactions counted for October 1 |
| --- | ---: | --- | --- | ---: |
| `customer_daily` | 790,495 | 2026-09-10 | **2026-09-30** | **0** |
| `terminal_daily` | 104,685 | 2026-09-10 | **2026-09-30** | **0** |

The reference customer query returned September 29 (`n=1`, `amount_sum=16.26`)
and September 30 (`n=3`, `amount_sum=47.22`), with **no October 1 row**.

These initial observations predate the November 18 rebuilds. Passing `check.sql`
alone does not prove that October 1 was aggregated: it compares September data,
and its `EXCEPT DISTINCT` is one-way. No aggregate table was created or replaced
by the assistant during record collection.

### Rebuild checkpoints supplied on November 18

The user supplied successful BigQuery query-result screenshots showing:

| Check | Result | Evidence scope |
| --- | --- | --- |
| Customer `7989449428740969`, 2026-10-01 | **`n=5`, rounded `amount_sum=100.79`** | Matches the teacher's reference-customer checkpoint. |
| October 1 terminal totals | **`SUM(n)=100,859`, `SUM(n_fraud)=0`** | Matches the raw history's distinct-transaction checkpoint; positive fraud labels are absent from replay data. |
| September reference comparison after rebuilding | **Customer 0, terminal 0 differing rows** | November 18 screenshot of the adapted teacher query; the one-way comparison found no differing rows. |
| Reference customer, October 1, without / with deduplication | **Both: `n=5`, rounded `amount_sum=100.79`** | November 18 screenshot of the read-only comparison: no inflation for this customer/day sample. |

Both SQL recipes now exist locally at `infra/sql/customer_daily.sql` and
`infra/sql/terminal_daily.sql`. Source inspection confirms grouping replay rows
by `TX_ID`, combining them with seed transactions, and daily aggregation.
The terminal recipe supplies `NULL` fraud labels for replay transactions and uses
`COUNTIF(TX_FRAUD = 1)`. The screenshots, rather than a new independent cloud
query, are the evidence for these November 18 checkpoint results. Exact query
job IDs and execution times were not supplied for the screenshots.

**Part B's supplied comparison checkpoint now passes after rebuilding:** the
November 18 screenshot shows customer 0 and terminal 0 differing rows. Together
with the October checkpoints, this provides the requested table-result evidence.
It is not a bidirectional completeness proof. The visible **71.78 MB** is the
editor's estimated bytes to process, not a captured actual job statistic.

Remaining Part B work/evidence:

- [x] Save both aggregation queries in `infra/sql/`.
- [x] Deduplicate history by `TX_ID` before combining it with seed transactions.
- [x] Verify the October 1 reference-customer checkpoint and terminal transaction total.
- [x] Rerun and record the September reference comparisons after rebuilding both tables: 0/0.
- [x] Record the result of the teacher's deliberate no-deduplication comparison: unchanged for this customer/day, 5 transactions and 100.79 in both calculations.
- [x] Explain prior-day lookup and fraud-label delay, below.

### Part B explanations

1. **Deduplication experiment:** the supplied comparison for customer
   `7989449428740969` on October 1 returned five rows/transactions and 100.79 total
   spending both before and after grouping by `TX_ID`. This sample shows no
   duplicate inflation. It does not disprove the earlier November 16 table-wide
   observation of 500 repeated transaction IDs; the two observations have
   different scopes and were captured at different times. No larger raw count
   is assumed or substituted for the observed result.
2. **Temporal availability:** daily counters can store multiple days, but the
   lookup for a transaction on day D must read through D-1, excluding D itself.
   For October 2 at 09:00, a complete October 2 daily total could include later
   transactions that were not yet known. This is information leakage. The
   feature-reading code implements the exclusive upper bound at lookup time.
3. **Fraud labels:** replay transactions have unknown labels (`NULL`), so
   `COUNTIF(TX_FRAUD = 1)` produces zero positive-label counts without establishing
   zero actual fraud. Investigation and customer reporting create a delay before
   labels are available; the course feature code models a seven-day label delay.

## Part C — Feature-source measurements

Live inspection found revision **`team-ghv-fraud-api-00007-7mt`** receiving 100%
of service traffic, using `ref-fraud-api:td4` and `FEATURE_SOURCE=parquet`.
Its dataset is `team_ghv`, Firestore database is `team-ghv`, and its runtime
identity is the required course account, `cloudai-runner@advanced-cloud-ai.iam.gserviceaccount.com`.

On November 18, the user supplied the authenticated scoring API `/health`
response below. This confirms the selected source and loaded-data checkpoint;
it is not a replay-latency measurement or a reference prediction.

| Health field | Observed value |
| --- | --- |
| `status` | `ok` |
| `source` | `parquet` |
| `features` | 20 |
| `customers` | 49,394 |
| `terminals` | 4,985 |
| `last_day` | `2026-09-30` |
| `rss_mb` | 327.4 |
| `pid` | 1 |

The user confirmed that the teacher is unavailable for the October 2 replay
on this step. Fresh two-minute source measurements therefore remain pending.
The reference prediction can be collected independently of that replay. The
user subsequently supplied the Parquet reference response recorded below.

| Source | Matching samples retrieved | p50 `features_ms` | p99 `features_ms` | Sample window, CET |
| --- | ---: | ---: | ---: | --- |
| `parquet` | **500** | **0.63 ms** | **2.64 ms** | 20:11:26.500425–20:11:32.279872 |
| `bigquery` | 0 | Pending | Pending | No matching entries found |
| `firestore` | 0 | Pending | Pending | No matching entries found |

Method: search `scored` logs for `team-ghv-fraud-api`, separately by `source`,
over November 16 UTC, retrieving at most the latest 500 entries per source.
The Parquet entries all belong to revision `00007-7mt`. Sort `features_ms` and
use the teacher's order-statistic convention: 1-based position
`floor(N * p) + 1`, clipped to N. These are feature-lookup times, not HTTP or
Pub/Sub push latencies.

The 500 Parquet samples cover approximately 5.78 seconds. They are not a complete
two-minute replay dataset. No matching BigQuery/Firestore entries in this search
does not prove those sources were never tested outside the searched service,
date, log format or retained data.

| Reference transaction `275114cae73280e474ca7ad397c5c429a93121d0` | Score |
| --- | --- |
| `parquet` | **0.00010230999760096893** |
| `bigquery` | **0.00019268736650701612** |
| `firestore` | **0.00019268736650701612** |

Reference input: `TX_TS=2026-10-02 00:00:00`, customer `7989449428740969`,
terminal `93986911`, amount `20.31`.

All three user-supplied reference responses are now recorded. The following
timings are for one request per source on November 18, rounded to two decimal
places; they are separate from the earlier replay-log percentile sample.

| Source | Single-request features (ms) | Predict (ms) | Handler (ms) |
| --- | ---: | ---: | ---: |
| `parquet` | 1.71 | 29.35 | 31.10 |
| `bigquery` | 2,569.37 | 33.45 | 2,602.86 |
| `firestore` | 132.31 | 40.49 | 172.94 |

The November 18 user-supplied reference response returned the exact reference
`tx_id` and `source=parquet`, with `worker_pid=1`. Its single-request timings were
`features=1.7101500000080705 ms`, `predict=29.351808000001256 ms` and
`handler=31.095747999870582 ms`. These are timings for one prediction request;
they do not replace the replay p50/p99 measurements above. The returned model
score is recorded as observed; no decision threshold or calibration assessment
was supplied.

BigQuery preparation on November 18: the user generated
`infra/session4-bigquery.tfplan`. Inspection of the saved plan's JSON confirms
**0 additions, 1 update, 0 deletions**. The only changed value was the scoring
service's `FEATURE_SOURCE`, from `parquet` to `bigquery`; no other resource
change was planned. The user then ran
`terraform -chdir=infra apply session4-bigquery.tfplan`. Their supplied terminal
output confirms **0 added, 1 changed, 0 destroyed**, with the API modification
completing after **21 seconds**. Terraform deployment succeeded according to
this user-provided output. The subsequent user-run authenticated `/health`
request returned `status=ok`, `source=bigquery`,
`dataset=advanced-cloud-ai.team_ghv`, `features=20`, `pid=1` and `rss_mb=154.6`.
This confirms the application's selected source and team dataset. It does not
by itself establish successful counter retrieval for the reference transaction,
prediction correctness or replay performance.

The user then submitted the same reference request to `/predict`. The response
reported the matching `tx_id`, `source=bigquery`, `worker_pid=1` and score
**0.00019268736650701612**. Its single-request timings were
`features=2569.3742909998036 ms`, `predict=33.448408000367635 ms` and
`handler=2602.859059000366 ms`. Feature retrieval took approximately **2.57 s**,
compared with **1.71 ms** for the recorded Parquet reference request. These are
individual observations, not p50/p99 measurements or a measured throughput limit.

The changed score is consistent with the teacher's freshness explanation:
Parquet reports a September 30 cutoff, whereas Part B confirmed October 1
history in the BigQuery counters. The exact feature vectors were not included
in either response, so the contribution of individual feature changes has not
been isolated. No claim of improved predictive accuracy follows from these two
scores. The matching Firestore result is recorded below; the source replay
comparisons remain pending.

Firestore publication on November 18: the user ran the teacher's
`docs/seance-4/publish_features.py` with project `advanced-cloud-ai`, source
dataset `team_ghv` and destination database `team-ghv`. The command returned to
the shell prompt and reported:

| Collection | Documents reported by publisher | Reported elapsed time |
| --- | ---: | ---: |
| `customers` | **49,424** | **118 s** |
| `terminals` | **4,985** | **15 s** |

The reported collection times sum to approximately **133 seconds**; this is not
a separately measured end-to-end command duration. The script selects a
28-day date window relative to each source table's latest `day`, writes one
document per entity and prints each count after closing its bulk writer. These
figures are from the user's command output, not an independent destination
document-count audit. The source window's actual latest dates were not printed.
The Firestore source-switch plan, the user's completion confirmation and the
subsequent authenticated health checkpoint and reference prediction are recorded
below.

Firestore deployment preparation on November 18: the user generated
`infra/session4-firestore.tfplan`. Local inspection of the saved plan's JSON
confirms **0 additions, 1 update, 0 deletions**. The only changed value is
`FEATURE_SOURCE`, from `bigquery` to `firestore`, on
`google_cloud_run_v2_service.api`. Project `advanced-cloud-ai`, Firestore
database `team-ghv` and the course `cloudai-runner` runtime account are
preserved. The saved plan reported itself applyable. After being instructed to
run `terraform -chdir=infra apply session4-firestore.tfplan`, the user replied
"done". Deployment is therefore recorded as user-reported complete; no apply
terminal output, execution duration, new revision ID or independent post-apply
cloud inspection was supplied. The user subsequently supplied an authenticated
`/health` response: `status=ok`, `source=firestore`, `database=team-ghv`,
`features=20`, `pid=1` and `rss_mb=152.9`. This confirms the running application's
source selection and team database. Health alone does not establish correct
counter values or replay performance.

The user then submitted the identical teacher reference request. The response
reported the matching `tx_id`, `source=firestore`, `worker_pid=1` and score
**0.00019268736650701612**, exactly equal to the recorded BigQuery reference
score. The teacher's reference-score agreement checkpoint therefore passes for
this transaction. The single-request timings were
`features=132.30624399875524 ms`, `predict=40.49219900116441 ms` and
`handler=172.9368929991324 ms`. This one prediction does not establish equality
of all counters/documents, latency percentiles or a sustained throughput limit.

Remaining Part C evidence: confirm the teacher's two-minute observation procedure
for each source; collect missing replay lookup timings; record BigQuery-source
backlog/throughput; verify the Firestore copy's freshness; explain the
latency/freshness trade-off and who would schedule future refreshes. The teacher
is unavailable for the replay at the latest user availability check. All three
reference scores and the BigQuery/Firestore equality checkpoint are complete.

## Part D — Vector search measurements

Both index builds, both complete benchmark tables, parameter selection,
document 87 neighbour results and all five Part D explanation questions are
recorded below. The selected `m=16, ef=8` configuration is a report selection;
the last loaded and inspected index remains `m=4`.

Preparation check on November 18: the existing `team-ghv-vectors` service
responded successfully to authenticated `GET /collections` (HTTP 200), returning
an empty collection list. No vector collection/index was found at that check.
The first Part C preparation plan proposed deleting the vector service and its
three invocation permissions because `infra/vectors.tf` was missing locally.
After adding the matching definitions, `session4-reconciled.tfplan` proposed
**0 additions, 1 update, 0 deletions**: change the vector runtime from the default
Compute account to the course-required `cloudai-runner` account. The saved plan's
state version matched shared state at inspection. The user then applied this
plan: the supplied terminal screenshot confirms **0 added, 1 changed, 0 destroyed**,
with the vector modification completing after **12 seconds**. A subsequent
`gcloud run services describe team-ghv-vectors` command in the same screenshot
confirms the runtime identity is
`cloudai-runner@advanced-cloud-ai.iam.gserviceaccount.com`. This completion is
based on the user's terminal evidence. The user subsequently supplied the
authenticated scoring-health result recorded in Part C. The empty collection
list above is the pre-apply observation; a separate user-run post-apply check
is recorded below.

Part D access checkpoint on November 18: after the guided team-vector URL and
authentication setup, the user supplied the `/collections` response
`{"result":{"collections":[]},"status":"ok","time":0.000405999}`.
The response reports success and no listed collections at that check. It is
user-supplied application evidence, not an independent post-apply inspection
by the assistant. No collection loading or HNSW benchmark is established by
this response.

Dataset preparation on November 18: the user downloaded
`gs://advanced-cloud-ai-models/data/kyc_embeddings.parquet`; their transfer
output reports one completed file of 76.3 MiB. A subsequent independent,
read-only local inspection confirmed **80,046,387 bytes** (76.34 MiB),
**49,394 rows** and the required columns `doc_id`, `customer_id`, `doc_type`,
`text` and `embedding`. The embedding array has shape **49,394 × 384**, dtype
`float32`, no null vectors and only finite component values. This matches the
teacher's expected document count and embedding dimensions. The file is kept
in existing ignored local storage. Both loads and their search measurements
are recorded below.

### Index built with `m=16`

The user ran the teacher's `load` command with `m=16`. Their completion output
reports **49,394 / 49,394 documents uploaded in 176 s**, followed by
**49,394 indexed vectors** and collection status **`green`**. The final line
reports **192 s**, with **`m=16`** and **`ef_construct=100`**. The script starts
that timer before uploading, so the 192-second figure includes upload time;
it is not an isolated index-construction duration. These are user-supplied
completion figures, not an independent cloud inspection. The user then ran
`measure` and supplied the following table: **300 queries per configuration**,
**10 neighbours**, with server times excluding network travel. The script uses
the same seeded query sample for exact search and each `ef` setting, calculating
mean recall against the exact-search result sets. Displayed recall is rounded
to three decimal places; displayed times are rounded to two decimal places.

| `ef` | Recall@10 | Server p50 (ms) | Server p95 (ms) |
| ---: | --- | --- | --- |
| exact | 1.000 | 10.74 | 16.29 |
| 4 | 0.991 | 0.45 | 0.83 |
| 8 | 0.991 | 0.40 | 0.58 |
| 16 | 0.996 | 0.43 | 0.57 |
| 32 | 0.996 | 0.53 | 0.72 |
| 64 | 0.999 | 0.70 | 1.09 |
| 128 | 0.999 | 0.85 | 1.32 |
| 256 | 0.999 | 1.07 | 1.47 |

All seven approximate settings exceed the teacher's recall target of 0.95 in
this run. `ef=4` is the smallest tested passing search budget. `ef=8` has the
lowest observed median, **0.40 ms**, versus **10.74 ms** for exact search
(an observed median ratio of **26.85**). `ef=16` has the lowest observed p95,
**0.57 ms**. Small differences between adjacent settings are not evidence of a
stable ordering from one benchmark run. The required `m=4` comparison and
parameter selection are now recorded below.

### Index built with `m=4`

The user rebuilt the collection with **`m=4`**, keeping
**`ef_construct=100`**. Their completion output reports
**49,394 / 49,394 documents uploaded in 238 s**, **49,394 indexed vectors**
and collection status **`green`**. The script's elapsed time from upload start
to index readiness was **253 s**. As with the `m=16` build, this includes
uploading. The longer reported total versus `m=16` (253 s versus 192 s)
coincides with a longer upload (238 s versus 176 s); it does not isolate a
change in index-construction cost. Search measurements for this rebuilt index
are recorded below.

The first user-supplied `m=4` measurement attempt returned **HTTP 401** on
`POST /collections/kyc/points/search`; no completed benchmark table was supplied.
The script reads the exported `TOKEN` once when creating its HTTP client.
A separate read-only diagnostic using a fresh identity token successfully
retrieved `GET /collections/kyc` (**HTTP 200**): collection status **`green`**,
**49,394 points**, **49,394 indexed vectors**, **`m=4`**,
**`ef_construct=100`**. The service's ready revision was
`team-ghv-vectors-00002-fbf` at inspection. Authentication is the immediate
failure category; expiry of the user's previous token is plausible but was
not established, because that token was not inspected. The user was instructed
to refresh the shell token and retry `measure` against the existing collection.
The user subsequently supplied the complete successful table below. The
diagnostic did not load/rebuild the collection or rerun the benchmark.
See [Cloud Run authentication troubleshooting](https://docs.cloud.google.com/run/docs/troubleshooting)
and [developer authentication](https://docs.cloud.google.com/run/docs/authenticating/developers).

| `ef` | Recall@10 | Server p50 (ms) | Server p95 (ms) |
| ---: | --- | --- | --- |
| exact | 1.000 | 9.68 | 12.36 |
| 4 | 0.792 | 0.39 | 0.57 |
| 8 | 0.792 | 0.42 | 0.82 |
| 16 | 0.819 | 0.41 | 0.60 |
| 32 | 0.865 | 0.51 | 1.05 |
| 64 | 0.901 | 0.57 | 0.88 |
| 128 | 0.926 | 0.77 | 1.35 |
| 256 | 0.965 | 0.95 | 1.49 |

This is the user's completed rerun: **300 queries per configuration**, **10
neighbours**, server-reported timings, using the same script and local data file.
It was not independently rerun by the assistant. The preceding load and
read-only collection check establish the `m=4` configuration; the benchmark
output itself does not print `m`. Exact command timestamps and raw per-query
timings were not supplied.

### Parameter selection and measured trade-offs

**Selection for minimum observed median search latency while meeting
recall@10 >=0.95: `m=16, ef=8`.** It returned recall **0.991**, p50
**0.40 ms**, p95 **0.58 ms**. This is a recommendation for the report, not a
change to the deployed collection: the last loaded and inspected index is `m=4`.

| Comparison | `m=4, ef=256` | `m=16, ef=8` |
| --- | ---: | ---: |
| Recall@10 | 0.965 | 0.991 |
| Server p50 (ms) | 0.95 | 0.40 |
| Server p95 (ms) | 1.49 | 0.58 |

Only **`ef=256`** passes the threshold among the seven tested approximate
settings with `m=4`. With `m=16`, every tested setting passes. The selected
`m=16, ef=8` has the lowest observed passing p50 across both tables. At `m=16`,
`ef=4` is the smallest tested passing search budget, while `ef=16` has a
slightly smaller observed p95 (0.57 ms rather than 0.58 ms). The selection uses
median latency as a cost proxy; actual memory use, CPU work and monetary cost
were not measured. It is not proof of a global cost optimum or a statistically
stable ranking of nearby settings from one run.

For the teacher's first Part D question: increasing `ef` from 4 to 256 at
`m=4` raises mean recall from **0.792 to 0.965** (**17.3 percentage points**),
with observed p50 rising from **0.39 to 0.95 ms** and p95 from **0.57 to
1.49 ms**. The intermediate latency observations are not strictly monotonic.
At equal `ef`, `m=16` has higher recall in all seven comparisons, but latency
is not uniformly lower: at `ef=256`, `m=4` has p50 0.95 ms versus 1.07 ms for
`m=16`, while its recall is lower (0.965 versus 0.999). The exact-search
baseline also varies between runs (p50 10.74 ms versus 9.68 ms); no causal
claim that changing `m` accelerates exact search follows from these observations.

### Document 87 — Reused payslip investigation

The user ran the teacher's `neighbours --doc-id 87` command and supplied five
neighbours. The reference document belongs to client **`0018478647296750`**:
a payslip for Jules Laurent, employer Energie du Sud (accented in the original),
period **19/09/2026**, salary **1,115.75 EUR**. The following three candidates
match its employee, employer, date and employee address after ignoring
whitespace, but have different salary amounts:

| Other client ID | Returned similarity score | Salary shown (EUR) | Text comparison |
| --- | ---: | ---: | --- |
| `3263319564977208` | **0.9997** | 317.35 | Same reference fields; altered salary. |
| `2947552228922773` | **0.9996** | 1,384.63 | Same reference fields; altered salary. |
| `0553287702820053` | **0.9990** | 2,053.59 | Same reference fields; altered salary. |

These are the three other clients requested by the teacher. The leading zero
in `0553287702820053` is part of the identifier and must be preserved.
The other returned candidates, `0416950292195505` (**0.9828**) and
`5828267825238113` (**0.9808**), have different employees, periods and
addresses. Their shared payslip format and employer do not establish reuse of
the reference payslip.

An independent local read of the six synthetic document texts confirmed these
comparisons and point 87's reference client. Three pasted texts differ from the
local texts only in whitespace, so spacing differences are not treated as
evidence of changes to the stored documents. It also found the three matching
clients at row/point IDs **16046**, **14479** and **2680**, respectively;
these point IDs are derived from the local file and the loader's row-based ID
assignment, not printed by `neighbours`. The server-returned scores are copied
from the user's output and were not recomputed. They are cosine similarity
scores under the loader's collection configuration, not probabilities of fraud.
The exercise demonstrates candidate detection and document comparison, not a
real-world fraud adjudication.

The `neighbours` function sends no explicit `hnsw_ef` or `exact` search parameter.
Its result is therefore not a benchmark of the selected `m=16, ef=8` setting.
No index rebuild, cloud search, IAM change or deployment was executed by the
assistant to record this checkpoint.

### Remaining Part D explanation questions

Question 1, on `m` and `ef`, is answered in the measured trade-offs above.

2. **When does an index become necessary?** An exact scan compares the query
   against every stored vector: its comparison work is proportional to
   `N * d`, where N is document count and d is vector dimension (384 here).
   With unchanged hardware and dimensions, a simple linear extrapolation from
   **9.68 ms for 49,394 documents** gives approximately **196 ms for one
   million documents**. This is an illustrative estimate, not a measured
   million-document benchmark. There is no universal document-count threshold:
   the decision depends on the required latency, query rate and available CPU.
   On the measured sample, approximate search already gives much lower server
   search times; a larger corpus or more concurrent queries increases the
   motivation to use an index.
3. **Is recall 0.95 acceptable?** Here it means that, averaged over the test
   queries, 95% of exact top-10 result IDs are recovered. It does not guarantee
   detection of 95% of fraud cases or guarantee any particular document will
   be found. For a process that must detect every reused document, this average
   is insufficient as a sole safeguard; stricter retrieval and document checks
   are needed. For suggesting candidates to an analyst it may be acceptable
   if evaluated on representative cases with an explicit tolerance for misses.
   The first three payslip matches were checked using their texts rather than
   treating similarity alone as a fraud verdict.
4. **Scaling and restarts.** The inspected local `infra/vectors.tf` sets
   **`min_instance_count=1`**, **`max_instance_count=1`**, **1 CPU**, **2 GiB**
   and **`cpu_idle=false`**, with Qdrant image **`v1.12.4`**. The configuration
   aims to keep one instance warm for the lab and avoid normal scale-out to
   separate instances with unshared local indexes. Minimum instances do not
   guarantee that a particular instance remains alive. There is no persistent
   volume or volume mount in this resource definition. If the instance is
   stopped and replaced, the locally written collection/index does not survive;
   the lab must reload the data and rebuild the index. This is inferred from
   the local configuration and the documented Cloud Run filesystem lifecycle,
   not an intentionally performed restart test. See the
   [Cloud Run container runtime contract](https://docs.cloud.google.com/run/docs/container-contract#file_system).
5. **Changing the embedding model.** Recompute the stored documents' embeddings
   using the new model, rebuild an index over those vectors, and encode incoming
   query documents with the matching model/vector space. Adapt the collection's
   vector dimensions if the model's output dimension changes, then reevaluate
   recall and latency. Merely changing query embeddings while keeping the old
   document vectors would not be a valid migration for this lab. The original
   text and client IDs remain source data; the fraud-scoring model does not
   automatically need retraining because this independent vector-search model
   changes. See [Qdrant embedding-model migration](https://qdrant.tech/documentation/tutorials-operations/embedding-model-migration/).

## Configuration reconciliation

The November 16 inspection found scoring on `ff-replay` with `ref-fraud-api:td4`,
while local private variables still selected `ff-tx` and the earlier team image.
During the guided November 18 edits, local settings were aligned to the teacher's
Part C image, replay topic and initial `parquet` source; the four environment
variables and feature-store permission definitions were added. The image
validation now permits the exact teacher reference image alongside team images.

The reconciled saved plan showed no changes to scoring, history or feature-store
permissions; its sole action was the vector runtime-account correction described
above. The user's successful apply and subsequent identity check confirm that
correction is complete. Before switching to BigQuery, the user-run authenticated
scoring-health check confirmed `status=ok`, `source=parquet` and
`last_day=2026-09-30`. The user then successfully applied the reviewed BigQuery
source change, as recorded in Part C. The subsequent authenticated health
response confirmed `source=bigquery` and `dataset=advanced-cloud-ai.team_ghv`.
The subsequent BigQuery reference prediction and the user's completed Firestore
publication command are recorded in Part C. The user reported completion of the
Firestore source-switch apply and then supplied a health response confirming
`source=firestore` and `database=team-ghv`. The subsequent Firestore reference
prediction exactly matches the recorded BigQuery score. The remaining replay
source-comparison measurements are still pending.

## Final source choice and completion status

No final source recommendation is justified by the currently recorded comparison:
Parquet has a recovered log sample, while all three sources each have one
reference prediction with individual request timings. BigQuery and Firestore
reference scores match exactly. October 1 customer and terminal checkpoints and
the rebuilt tables' September comparison now pass. Complete the missing replay
timings and source-freshness/throughput checks before writing the teacher's
two-sentence final choice.

- [x] Record the Step 0 seed query and bytes processed.
- [x] Verify Part A ingestion and the distinct-transaction checkpoint.
- [x] Record duplicate origin evidence and filtered/unfiltered query bytes.
- [x] Record initial Part B checks and the November 18 successful October checkpoints.
- [x] Recover the available Part C Parquet timing sample.
- [x] Record the November 18 authenticated Parquet health checkpoint.
- [x] Record the exact Parquet reference score and its single-request timings.
- [x] Review the BigQuery source-change plan and record the user's successful apply.
- [x] Record the authenticated BigQuery health checkpoint and team dataset.
- [x] Record the BigQuery reference score and its single-request timings.
- [x] Record the user's Firestore publication output for customers and terminals.
- [x] Record the reviewed Firestore source-switch plan and the user's completion confirmation.
- [x] Record the authenticated Firestore health checkpoint and team database.
- [x] Record the Firestore reference score/timings and verify exact agreement with BigQuery for the teacher's reference transaction.
- [x] Record the Part D authenticated vector-service response showing no collections.
- [x] Record the KYC dataset download and verify local row count, columns and embedding shape/values.
- [x] Record the user's completed m=16 load, indexed-vector count, green status and timing/configuration.
- [x] Record all m=16 benchmark rows, exact-search baseline and threshold/latency comparisons.
- [x] Record the user's completed m=4 rebuild, indexed-vector count, green status and timing/configuration.
- [x] Record all m=4 benchmark rows and compare both indexes against the recall threshold.
- [x] Select m=16, ef=8 using the lowest observed passing median; state the cost/uncertainty limits and that this selection was not deployed.
- [x] Complete the requested Part B checkpoints and record its explanations.
- [ ] Complete Part C's replay p50/p99, backlog/throughput and freshness/refresh analysis.
- [x] Identify the three other clients reusing document 87's payslip and distinguish the two remaining candidates.
- [x] Record Part D's scaling/restart, exact-search growth, recall interpretation and embedding-model-change explanations, with evidence limits.
- [ ] Record agreed cleanup after the exercise; no cleanup performed by this task.
- [ ] Complete the outstanding Part C measurements and obtain team review before merging into `main`.

Evidence basis: teacher handout [seance-4.md](../seance-4.md), supplied replay
screenshots, original stored BigQuery job results/statistics, new read-only
verification queries, subscription/service descriptions and structured feature
logs. Raw evidence is retained separately in ignored local storage. Measurement
queries used explicit project/location and, for new queries, a 1 GiB billing cap.

Technical references: [BigQuery partition pruning](https://docs.cloud.google.com/bigquery/docs/querying-partitioned-tables),
[Pub/Sub duplicate message IDs](https://docs.cloud.google.com/pubsub/docs/pull-troubleshooting#dealing_with_duplicates).
