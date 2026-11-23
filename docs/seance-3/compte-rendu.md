# Session 3 — Team GHV transaction stream

Marouane contributed the Pub/Sub endpoint and infrastructure. Ali integrated and tested both changes and recorded the November 16 replay observations.

The replay topic `ff-replay` fed `team-ghv-tx-push`, which sent authenticated requests to `POST /pubsub` on `team-ghv-fraud-api` in `europe-west1`. Cloud Run showed revision `team-ghv-fraud-api-00005-xws` serving 100% of traffic with concurrency 1, a maximum of three instances, one CPU and 1 GiB of memory. The private-service test from November 12 recorded anonymous HTTP 403 and successful authenticated health and prediction checks. A separate token/no-token test for the November 16 revision was not captured. [Session 2 baseline](../report-session-2.md) · [Service and IAM](../../infra/main.tf) · [Subscription configuration](../../infra/pubsub.tf)

## Replay observations

Times are CET on November 16, 2026. The first two rows are readings from Cloud Monitoring for `team-ghv-tx-push`. Times refer to when the charts were viewed. The Cloud Run figures are approximate readings from a separate one-day chart viewed at 18:32.

| Evidence | Reading |
| --- | --- |
| Pub/Sub, 18:03–18:04 | 330 messages waiting, oldest age 13 s. Successful push acknowledgments ran at 338.67/s. Push latency p50/p95/p99 was 0.13/0.62/1.44 s. |
| Pub/Sub, about 18:07 | 498.83 messages published/s, 498.28 sent/s and 497.52 acknowledged/s. Backlog fell to 65 and oldest age to 0 s. |
| Cloud Run during the burst | About 3 active instances. Request latency p50 was approximately 5 ms and p99 approximately 10–11 ms. CPU utilization approached 100% and the pending-latency chart reached roughly 14–15 s. |
| Dead-letter subscription | The Messages view for `team-ghv-tx-dead-pull` contained `poison-20261116`, amount −1, about 97 s after source publication. |

The full replay schedule, total distinct transactions, full-run maximum backlog and sustainable rate remain unmeasured. [Push subscription](https://console.cloud.google.com/cloudpubsub/subscription/detail/team-ghv-tx-push?project=advanced-cloud-ai) · [Cloud Run metrics](https://console.cloud.google.com/run/detail/europe-west1/team-ghv-fraud-api/metrics?project=advanced-cloud-ai) · [Dead-letter subscription](https://console.cloud.google.com/cloudpubsub/subscription/detail/team-ghv-tx-dead-pull?project=advanced-cloud-ai)

## Questions from the brief

**1.1 — What happens during the initial 404s?** While the endpoint is missing, the service returns 404 and Pub/Sub retries. As new messages arrive, the unacknowledged count can grow and the oldest message ages until delivery or forwarding. The team has no chart for this initial phase. The 330-message reading above belongs to the later scoring replay.

**1.2 — Why use two identities?** The push subscription requests an identity token for `team-ghv-push`. Terraform grants that account `roles/run.invoker` on this service. The container uses the administrator-required `cloudai-runner` identity for tasks such as reading model data from the bucket. This lets the team authorize delivery without giving the delivery account access to the data. Effective project-wide grants on the shared runner were not independently inventoried. [Subscription](../../infra/pubsub.tf) · [IAM](../../infra/main.tf)

**1.3 — What was in the dead-letter queue after three minutes?** The initial three-minute pull was not captured. Even a valid transaction can reach the dead-letter queue if repeated attempts encounter a missing endpoint. The policy requests forwarding after approximately five failed attempts. The later pull in the table verifies the separate poisoned-message exercise.

**3.1 — When did the service fall behind, and what absorbed the load?** Pub/Sub held the waiting transactions during the burst. Cloud Run could scale out to three instances, each configured for one concurrent request. The observed plateau near three active instances, high CPU and time spent waiting for an instance are consistent with capacity pressure. By about 18:07, acknowledgments nearly matched 499 publications/s and the queue had fallen from 330 to 65. The available samples do not identify the first stage of sustained growth or isolate which limit determined it.

**3.2 — What happened to the invalid message?** The pulled body contained `TX_ID=poison-20261116` and `TX_AMOUNT=-1`. The API requires a positive amount. The original publication attribute was `2026-11-16T16:57:46.091Z` and the forwarded message displayed 17:59:23 CET, to the nearest displayed second. This gives about 97 s from publication to isolation. Without dead-letter forwarding, the invalid message could keep consuming retry attempts until the source subscription's retention expired. Terraform configures one hour of retention. [Dead-letter policy](../../infra/pubsub.tf)

**3.3 — How do we recognize a redelivery, and why acknowledge last?** Cloud Logging showed source message `23290635766501881` with the same transaction ID and delivery counters 1, 2, 4 and 5. The first and fifth visible rejections were at 17:57:46.203 and 17:58:58.819 CET. To distinguish another publication of the same transaction, compare the source message ID as well as the transaction ID. On valid input, our handler scores with `record=False`, writes the scored log and returns 204. A retry can repeat the log while leaving feature counters unchanged. An early 204 would acknowledge work that could still fail. The deployed image predates the linked merge, so the source link establishes the ordering in the reviewed implementation. [API handler](https://github.com/juliagreene2001/fraud-api-albertschool-team-ghv/blob/b6f2f16811ace9a419e2d7364b87e85b0b7c4bfb/app.py#L145-L176) · [API tests](https://github.com/juliagreene2001/fraud-api-albertschool-team-ghv/blob/b6f2f16811ace9a419e2d7364b87e85b0b7c4bfb/tests/test_api.py)

The team has no recorded command output confirming cleanup of the Session 3 subscriptions.
