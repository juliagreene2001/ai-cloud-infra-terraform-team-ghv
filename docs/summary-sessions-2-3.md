# Sessions 2 and 3 — Team GHV implementation and next steps

Updated: 16 November 2026. Session 2 has a measured report. Session 3 source is integrated on
`Ali` in both repositories; the instructor's load exercise and completed report remain pending.
This integration performs no cloud deployment or GitHub push.

## Accounts, names and ownership

| Purpose | Preserved setting |
| --- | --- |
| Google Cloud project | `advanced-cloud-ai` |
| Region | `europe-west1` |
| Team resources and shared state prefix | `team-ghv` |
| Cloud Run service | `team-ghv-fraud-api` |
| Runtime account required by the administrator | `cloudai-runner@advanced-cloud-ai.iam.gserviceaccount.com` |
| Pub/Sub delivery account | `team-ghv-push@advanced-cloud-ai.iam.gserviceaccount.com` |
| Operator account | The existing local gcloud login; unchanged by integration |
| Working branch | `Ali` in both repositories |

Git authorship credits the contributor who wrote a commit. It does not select the Google Cloud
project or account used to execute code. Actual team invoker identities remain in the ignored
`infra/terraform.tfvars`. The existing private variables and local login settings were preserved.
The optional continuous-deployment workflow remains inactive.

## What the system does

```text
instructor's topic -> team-ghv-tx-push -> POST /pubsub -> validate -> score -> JSON log -> 204
                              |
                              +-> retries -> team-ghv-tx-dead -> team-ghv-tx-dead-pull
```

The push subscription authenticates as `team-ghv-push`. The container runs as `cloudai-runner` and
reads daily counters through the read-only `advanced-cloud-ai-models` bucket mount at
`/mnt/models/data`. The XGBoost model is packaged in the API image.

The handler decodes Base64 JSON, validates a transaction, scores with `record=False`, and logs one
JSON line before returning 204. Invalid transactions and malformed encoded JSON return 422 with
an error description. Logs include `message_id`, `delivery_attempt`, and `tx_id` when readable.
A failed scoring operation does not return a success acknowledgment. Counters are unchanged by
redelivery. This is not global deduplication or persistent event processing.

The source subscription requests dead-letter forwarding after five failed attempts. That count
is approximate. Effective service-agent permissions must allow publishing to the dead-letter
topic and acknowledging the source subscription; a Console permission-check warning alone does
not establish whether those permissions are present.

## Completed work

Session 2 results are recorded in [report-session-2.md](report-session-2.md): private deployment,
reference predictions, memory comparison, shared Terraform state, protected service adoption and
temporary-resource cleanup. Those are historical measurements, not a new load-test result.

The Session 3 integration includes:

- `infra/pubsub.tf`: the team push account, authenticated subscription, dead-letter topic and
  pull subscription. The complete human invoker list is preserved and the push account is added
  to the existing authoritative binding.
- `scripts/terraform.py`: support for the GHV Pub/Sub resources, explicit project checks for the
  new resources, retained main-service protections and local gcloud executable discovery.
- Terraform policy tests and Python execution-guard tests, including rejection of another team
  namespace or another project's Pub/Sub resources.
- `app.py`: the contributed `/pubsub` handler combined with the local draft's readable validation
  errors and support for lowercase transaction identifiers in rejected-message logs.
- API tests for scores, logging, retries without counter mutation, invalid amounts, malformed input,
  lowercase identifiers and failure before acknowledgment.
- Existing English documentation, verification scripts, private-file exclusions and workflows.
- The teaching copy at `docs/seance-3/pubsub.tf`, restored alongside the active implementation.

The contributor's earlier notes reported deploying image `s3b` and observing successful deliveries.
This source integration does not independently reverify that historical deployment or select that
image for the operator. Current source and the deployed image must be reconciled explicitly.

## Configuration to review before applying

The example file now uses `team-ghv`, the team's `td3-ali` image tag, and the instructor's replay
topic. It is an example, not the operator's active private configuration.

The actual ignored `infra/terraform.tfvars` is unchanged. At integration time it retained the
Session 2 image digest beginning `937ef32` and had no explicit `tx_topic`; the variable default
therefore remained the original `projects/cymbal-fraudfinder/topics/ff-tx` stream.
The November 16 Console screenshot showed the live subscription attached to `ff-replay`.
Before planning or applying, align the private image setting with the reviewed deployed image and
explicitly set `tx_topic = "projects/advanced-cloud-ai/topics/ff-replay"`.
Do not overwrite private invoker identities by copying the example over an existing variables file.

Keep concurrency and the maximum instance count unchanged for the instructor's comparison.
The source defaults are concurrency 1 and maximum 3 instances. A new image tag alone does not
build or deploy code. Review a saved plan; preserve the existing main service and shared state.

## Required remaining work

1. Review the integrated changes on `Ali` and publish the approved source for teammate review.
2. Reconcile the private image and topic settings with the agreed deployment before any apply.
3. Verify `/pubsub` and effective dead-letter forwarding permissions; ask the instructor to inspect
   policies if the operator cannot view them.
4. Clear old dead-letter messages as instructed, after capturing any required evidence.
5. Refresh gcloud and Application Default Credentials on arrival.
6. During the instructor's replay, record maximum backlog and the input rate where it grows,
   maximum oldest-message age, actual peak instances, request p50/p99, and the invalid transaction's
   identifier and delay before reaching the dead-letter subscription.
7. Fill [compte-rendu.md](seance-3/compte-rendu.md) with observed values and submit reviewed changes.

Use matching recent time windows and account for the charts' 2–3 minute delay. Do not substitute
startup latency for request latency, recommended instances for actual instances, or historical
week-long charts for the exercise measurements. Stop or remove only agreed temporary resources
through a reviewed scoped change; preserve the adopted main service and shared foundation.
