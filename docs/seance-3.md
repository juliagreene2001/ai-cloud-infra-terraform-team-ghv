# Session 3 — connect the scoring service to a transaction stream

English adaptation of the latest instructor assignment, incorporated from upstream on 12 November
2026. Original `seance-3` paths are retained for the instructor's synchronization check.
**Status: instructions and scaffold only. Session 3 has not been implemented or deployed.**

The assigned namespace is `team-ghv`. The existing private service is already managed through the
shared GHV Terraform backend. Keep it: importing and repairing it has already been completed.
Do not repeat the upstream template's delete/recreate instructions for this adopted service.
All new implementation work belongs on branch `Ali` in both repositories.

| Stage | Instructor timebox | Required result |
| --- | --- | --- |
| 0. Check the deployed baseline | 40 min | Private GHV service: 403 anonymously, 200 with an authorized identity token |
| 1. Connect Pub/Sub | 30 min | Authenticated push subscription delivers to `/pubsub`; failed messages can reach a dead-letter topic |
| 2. Adapt the API | 25 min | Each valid message is scored, logged, then acknowledged with 204 |
| 3. Observe load and failure | 20 min | Backlog/latency measurements and an invalid transaction recovered from dead-letter storage |
| Report | 5 min | Fill `docs/seance-3/compte-rendu.md` with actual observations |

Instructor's 40-minute rule: one teammate starts the connection stage while others finish deployment;
apply the Pub/Sub resources only after the service exists. Do not use placeholder report values as results.

## Stage 0 — synchronize and verify the baseline

The fork's `main` has received the instructor's named-team validation and Session 3 materials.
Merge current `origin/main` into `Ali` rather than discarding team commits. Preserve the complete
private `infra/terraform.tfvars` invoker list. The correct settings are:

```hcl
# infra/backend.tf
prefix = "team-ghv"
# infra/terraform.tfvars
team = "team-ghv"
tx_topic = "projects/cymbal-fraudfinder/topics/ff-tx"
```

Keep the upstream validation expression `^team(-?[a-z0-9]+)+$` and its 20-character limit.
The execution helper separately requires this fork's actual GHV namespace.

From the infrastructure repository root, after saving and reviewing changes:

```bash
git branch --show-current
python3 scripts/terraform.py init -reconfigure
python3 scripts/terraform.py plan -out=session3-baseline.tfplan
```

Expected branch: `Ali`. The baseline plan should show no changes. The helper passes a short-lived
course login token to Terraform; state remains shared in GCS. Do not import the service again or
apply a plan proposing its creation, replacement or deletion. A 403 on the backend can indicate a
wrong prefix: verify it before diagnosing a missing project permission.

From the application repository, with the private course files available:

```bash
uv sync --frozen
uv run --frozen python scripts/check_http.py --url https://team-ghv-fraud-api-191726065850.europe-west1.run.app --private
```

This checks anonymous rejection, authorized health, and 500 reference scores. It uses your current
gcloud identity; an authorized school identity must be in the complete team invoker list.

## Stage 1 — connect authenticated delivery

```text
transaction topic -> team-ghv-tx-push -> POST /pubsub -> team-ghv-fraud-api
                            |
                            +-> team-ghv-tx-dead -> team-ghv-tx-dead-pull
```

1. Read the scaffold `docs/seance-3/pubsub.tf` before copying it into `infra/`.
2. Fill its three exercise holes: endpoint `api.uri` plus `/pubsub`; the push account's email;
   the dead topic ID and `max_delivery_attempts = 5`.
3. Resolve the scaffold's IAM integration with the current configuration: the main service has an
   authoritative `roles/run.invoker` binding. Include the push account in that binding; do not add
   another member resource managing the same role alongside it. Keep all existing approved callers.
4. Check prerequisites for authenticated delivery: the operator needs permission to act as the push
   account; the Pub/Sub service agent must be able to mint its identity token. Verify existing grants
   before requesting or adding narrowly scoped missing ones.
5. Check dead-letter forwarding permissions: the Pub/Sub service agent needs publisher access to
   the dead-letter topic and subscriber access to the source subscription. These are not all present
   in the instructor's starter skeleton. Verify the grants; do not assume another team configured them.
6. Extend `scripts/terraform.py` and its tests to permit only the exact planned GHV Pub/Sub resources
   and associated least-privilege grants. The Session 2 helper intentionally rejects unknown resource
   types; do not bypass it or disable namespace/service protections.
7. Run format, validation, policy/guard tests and inspect a saved plan before any apply. The only
   service change at this stage should be the reviewed private invoker binding.

The instructor intentionally connects delivery before adding the endpoint, so initial requests can
return 404. Observe this briefly; do not leave a failing stream running between learning sessions.

```bash
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="team-ghv-fraud-api" AND httpRequest.requestUrl:"/pubsub"' --project advanced-cloud-ai --freshness 10m --limit 5 --format 'value(timestamp,httpRequest.status)'
gcloud pubsub subscriptions pull team-ghv-tx-dead-pull --project advanced-cloud-ai --limit 1
```

The pull command above does not acknowledge/remove messages. Investigate persistent 403 separately
from 404: the former is authentication/authorization; the latter means the route is missing.
Observe `subscription/num_undelivered_messages` and `subscription/oldest_unacked_message_age`.
Explain why delivery identity `team-ghv-push` needs service invocation, while the mandated runtime
identity needs data access. They have different jobs and must not share unnecessary permissions.

## Stage 2 — implement the API endpoint

Add `POST /pubsub` to `app.py` in the application repository. The JSON request wraps a transaction
in `message.data`, which is base64-encoded JSON. See `enveloppe.json`. The existing `Transaction`
model accepts uppercase course fields. No additional dependency is needed for base64 or JSON.

```python
class PushMessage(BaseModel):
    data: str
    messageId: str
    publishTime: str | None = None
    attributes: dict[str, str] = Field(default_factory=dict)


class PushEnvelope(BaseModel):
    message: PushMessage
    subscription: str
    deliveryAttempt: int | None = None
```

Import `Field` when using this example. Implement and test the following behavior before deployment:

| Order | Action | Expected result |
| --- | --- | --- |
| 1 | Decode base64 and parse JSON | Malformed input returns a controlled client error rather than an uncaught 500 |
| 2 | Validate with `Transaction.model_validate` | Invalid amount, including zero or negative, logs `rejected` and returns 422 |
| 3 | Score through the existing path with `record=False` | No mutation of daily event counters |
| 4 | Print one JSON line | Valid: severity INFO, message scored, tx_id, score, delivery_attempt; invalid: severity ERROR and message rejected |
| 5 | Return an empty `Response(status_code=204)` | Acknowledge only after scoring and logging succeed |

The instructor requires the fields above. Add `message_id` to the structured log if needed to
distinguish redelivery of one message from two publications of the same transaction. Do not log
credentials or whole payloads. Repeated prediction must leave counters unchanged; this lab does
not guarantee an identical score across arbitrary history/revision changes or global deduplication.

Test locally with Uvicorn running in one terminal and curl in another:

```bash
# Application repository, terminal 1
uv run --frozen uvicorn app:app --host 127.0.0.1 --port 8000
# Application repository, terminal 2
curl -i -X POST http://127.0.0.1:8000/pubsub -H 'Content-Type: application/json' --data-binary @../ai-cloud-infra-terraform-team-ghv/docs/seance-3/enveloppe.json
```

This currently returns 404 until you implement the route. After implementation, expect 204 and one
`scored` log. Also test negative amounts (422/rejected), malformed data, failure before acknowledgment,
redelivery, and unchanged existing reference predictions. Keep the full API suite and Ruff passing.

Build a Linux amd64 image, push only to the team's private course registry, and pin its new digest
in the ignored infrastructure `terraform.tfvars`. Use the existing Terraform image owner to deploy
a reviewed saved plan, preserving the runtime account, mount, private IAM and service protection.
Do not enable competing CD while Terraform owns the image. A new image tag alone does not deploy it.

The instructor offers `ref-fraud-api:td3` as a fallback if the exercise timebox expires. It is not
selected automatically here; fallback use must be recorded and must satisfy the team's image policy.

Check Cloud Logging for `jsonPayload.message="scored"` on the GHV service, one line per delivery.
If output appears under `textPayload`, check that you print one `json.dumps(...)` line.

## Stage 3 — observe the instructor's replay and invalid message

Coordinate the replay window with the instructor. Switch `tx_topic` to
`projects/advanced-cloud-ai/topics/ff-replay` only after the endpoint and connection work.
Changing topic replaces the push subscription and loses its old pending backlog. Review that
replacement explicitly; it must never replace the main Cloud Run service.

The instructor asks to clear old dead-letter messages first. `seek --time` changes the subscription
cursor and can skip earlier messages, so capture required evidence before using it. Use only your
own exact `team-ghv` subscription, not a project-wide pattern.

At each announced load level, record:

| Source | Measurements |
| --- | --- |
| Pub/Sub subscription | Undelivered messages and oldest unacknowledged message age |
| Cloud Run | Peak instances, configured maximum, request p50/p99 |
| Structured logs | Scored/rejected counts, tx_id, message_id if added, delivery_attempt |

Trace the instructor's invalid `tx_id`, then inspect the dead-letter subscription. Configure five
maximum attempts, but report the attempts actually observed: forwarding is best effort and the
count is approximate, not a guarantee of exactly 1 through 5.

```bash
gcloud pubsub subscriptions pull team-ghv-tx-dead-pull --project advanced-cloud-ai --limit 5
```

One designated teammate may add `--auto-ack` after capturing the required evidence; doing so removes
the pulled messages. Do not claim the teacher's poisoned-message result from a local synthetic test.
Answer: at what rate did backlog grow, what absorbed it, what happened to the invalid message,
and were duplicate deliveries distinguishable from separate publications?

## Report, review, and cleanup

Fill `docs/seance-3/compte-rendu.md` from actual observations and submit reviewed team changes.
Do not push personal notes, raw logs/state, private invoker identities, or course data. The optional
bonus publishes scores to a team topic with confirmed completion before acknowledgment; it is
outside the required baseline and needs a publisher client and scoped runtime permission.

Remove the newly introduced push subscription and associated disposable Session 3 resources through
a reviewed scoped Terraform change when the session ends. An active push subscription continues
calling the service. Keep the adopted protected main service and shared course foundation.
Do not run the upstream template's blanket `terraform destroy` against the shared GHV state.

## Verified platform references

- [Push request format and acknowledgment responses](https://docs.cloud.google.com/pubsub/docs/push)
- [Authenticated push identities and required permissions](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions)
- [Dead-letter forwarding, IAM, and approximate delivery attempts](https://docs.cloud.google.com/pubsub/docs/dead-letter-topics)
