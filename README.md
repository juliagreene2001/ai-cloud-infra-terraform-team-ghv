# Team GHV cloud infrastructure

Terraform configuration for `team-ghv-fraud-api` in project `advanced-cloud-ai`, region
`europe-west1`. The companion application is
[fraud-api-albertschool-team-ghv](https://github.com/juliagreene2001/fraud-api-albertschool-team-ghv).

## Team reports and measurements

| Lab | Report and evidence |
| --- | --- |
| TD1 · Measure the scorer | [Direct benchmark and 30 request timings](docs/seance-1/mesures.md). The indexed comparison, load test and completed notebook are still outstanding. |
| TD2 · Deploy on Cloud Run | [Deployment report](docs/rapport-seance-2.md), [Monitoring and Terraform results](docs/seance-2/measurements.json) and [200 client requests](docs/seance-2/client-samples.csv). |
| TD3 · Score a transaction stream | [Replay observations and six answers](docs/seance-3/compte-rendu.md), including backlog recovery and delivery of the invalid transaction. |
| TD4 · Store and read features | [Team report](docs/seance-4/compte-rendu.md) and [query, latency and vector-search measurements](docs/seance-4/measurements.json). Only Parquet has a 500-request latency sample. |
| TD5 · Retrain and decide | [Training runs, costs and registry decision](docs/seance-5/compte-rendu.md) and [parallel search results](docs/seance-5/search-speedup.png). |
| TD6 · Roll out and recover | [Stage decisions](docs/seance-6/mesures.md), [validation output](docs/seance-6/validation.txt), [post-mortem](docs/seance-6/post-mortem.md) and [checklist](docs/seance-6/checklist.md). The rollout stopped at 10%. |
| TD7 · Serve, measure and cost an LLM | [Measurements](docs/seance-7/mesures.md), [cost](docs/seance-7/cout.md) and [sizing sheet](docs/seance-7/fiche.md), with raw outputs in [raw/](docs/seance-7/raw/). One L4 saturates at 336.4 tokens/s. Decision: keep the 4-bit model (87.0% score for both precisions) and serve on a GPU, which costs 25.12 $/day against 29.68 $/day for the API (a thin 15% margin; switch-over at 73,807 alerts/day). The GPU service was destroyed after about 24 minutes of use. The Cloud Trace screenshot is [trace.png](docs/seance-7/trace.png); the 8-bit throughput was not measured. |

## Project status (updated 25 November 2026)

`main` includes `Ali` (up to `6e54a20`, 23 November 2026) and the end-of-project work from `marouane-s4` (TD6 after-class Terraform, TD7 and the TD4 analysis), merged on 25 November 2026. The companion API repository's `main` includes the `/pubsub` endpoint used by `infra/pubsub.tf`.

| Lab | Status | Still to finish before the end of the project |
| --- | --- | --- |
| TD1 | Out of scope | Not worked on in this repository's end-of-project pass: the indexed comparison, load test and notebook stay as listed in the TD1 report row above. |
| TD2 | Done | None recorded. |
| TD3 | Done, gaps noted | Full replay schedule, total distinct transactions, full-run maximum backlog and sustainable rate remain unmeasured; initial three-minute dead-letter pull was not captured. |
| TD4 | Partial | Part C replay measurements (p50/p99, backlog/throughput, Firestore freshness) need the instructor's stream; the latency/freshness analysis without replay is written, and the report ends with the source chosen for live scoring (Firestore, provisional until the replay percentiles exist). Cleanup inventory listed, deletion to decide as a team (the `team-ghv-vectors` service is always on). Team review before merging into `main`. |
| TD5 | Mostly done | Step 4: DDP throughput and validation AP with one and two processes (values not recorded). Candidate accepted as registry version 2 (`challenger`); `champion` stays on version 1. |
| TD6 | Done, gaps noted | Rollout stopped at 10% (alert rate 28.0% against a 23.3% rollback bound) and rollback verified. "After the TD" Terraform done: `infra/scorer/` imports the scorer (plan only, 1 to import, 0 change) and `infra/release.tf` holds the live `team-ghv-scorer-release` alert plus the shadow subscription, off by default. Drift and retraining-policy extensions written. Missing: `next` incident measured under traffic; shadow test on the live topic; Degradable (teacher's variable) and Owned (named owners) checklist lines. Weakness to decide: the alert watches `td6_score` (coarse buckets), so it would not have caught the candidate's alert-rate rise. |
| TD7 | Done, gaps noted | Steps 0 to 5 measured, costed and written up; `explain_alert.py` instrumented; GPU service destroyed and verified. Trace screenshot in `docs/seance-7/trace.png`. Missing: the 8-bit throughput (not measured, to save GPU cost). The API price uses the global Vertex AI endpoint (confirmed). |

Free extensions are listed in [docs/extensions.md](docs/extensions.md): alert as code, drift check, retraining policy, scorer described in Terraform, execution guard.

Cross-cutting: commit and push the completed reports, check that `terraform.tfvars` and raw logs stay untracked, and remove temporary plan files (`infra/*.tfplan`) before submission.

## Scope

- Uses the actual `team-ghv` namespace for resources, labels, images and shared state.
- Adopts the existing service rather than creating a replacement.
- Keeps the required `cloudai-runner` runtime account, port 8000 and read-only data-bucket mount.
- Enforces a private invoker allowlist, min zero and max three instances.
- Protects the existing service with deletion protection and `prevent_destroy`.
- Makes the separate account/IAM exercise explicit through `create_team_account`, default false.
- Uses shared state at `gs://advanced-cloud-ai-tfstate/team-ghv/default.tfstate`.

## Review and operate

Install Terraform >=1.9 and gcloud. The committed provider lock selects Google provider 8.10.0.
Sign in with the course account. The execution helper supplies a short-lived token in memory.

For a fresh checkout, copy `infra/terraform.tfvars.example` to `infra/terraform.tfvars`, replace the
placeholder with the complete team-approved invoker list, and keep the file untracked. The helper
rejects unchanged placeholder users. Existing operators should preserve their current private file.

```bash
python3 scripts/terraform.py init
python3 scripts/terraform.py plan -out=review.tfplan
python3 scripts/terraform.py apply review.tfplan
```

The main service is already imported in shared state. Do not import a duplicate into another state.
The helper requires a reviewed saved plan and rejects another namespace or main-service recreation,
replacement or deletion. Local cloud-state mode is disabled. Terraform owns image updates while
optional CD is inactive.

## Tests and documentation

```bash
python3 scripts/test_terraform.py
```

This validates a temporary copy with mocked Google resources and no shared backend. Execution-guard
unit tests are in `tests/`; run them with pytest or the companion application's development environment.
Pull-request CI runs the mocked policy tests and guard tests without cloud credentials.

See [operations](docs/OPERATIONS.md), [the English GHV assignment](docs/session-2.md), and
[the deployment report](docs/rapport-seance-2.md).

## Session 3: integrated on Ali

`infra/pubsub.tf` configures authenticated delivery to `/pubsub`, the dedicated `team-ghv-push`
account, and the dead-letter topic and subscription. The Terraform helper accepts these exact
team resource names only in project `advanced-cloud-ai`. The existing private invoker list is kept.
The [teaching scaffold](docs/seance-3/pubsub.tf) and [sample envelope](docs/seance-3/enveloppe.json)
remain available alongside the active implementation.

Read the current preparation section in [Session 3](docs/seance-3.md). Preserve your ignored
`infra/terraform.tfvars`; align its image with the reviewed `/pubsub` image and explicitly set
`tx_topic = "projects/advanced-cloud-ai/topics/ff-replay"` before reviewing a new plan.
The default topic remains the original `ff-tx` teaching stream. Source integration does not deploy
an image, change the operator's gcloud login, or modify the existing private variables.

The [Session 3 report](docs/seance-3/compte-rendu.md) records the November 16 replay.
The [implementation summary](docs/summary-sessions-2-3.md) documents the earlier setup.

## Session 5: teacher materials

The [Session 5 handout](docs/seance-5.md) covers reproducible model retraining,
parallel hyperparameter search with 1, 4 and 8 workers, training costs, and a
measured decision about admitting a challenger model to the Vertex AI registry.

| File | Purpose |
| --- | --- |
| [job.tf](docs/seance-5/job.tf) | Cloud Run training/search job scaffold, training account and private Optuna connectivity |
| [custom-job.sh](docs/seance-5/custom-job.sh) | Vertex AI final-training job script |
| [compte-rendu.md](docs/seance-5/compte-rendu.md) | Team training measurements and registry decision |

The handout reserves the test set for the final gate. The team report links to the first
test read and records its decision.

## Sessions 6 and 7: teacher materials

The [Session 6 handout](docs/seance-6.md) covers staged rollout of a challenger
model, diagnosing an incident, and rolling back. The [Session 7 handout](docs/seance-7.md)
covers serving an LLM on GPU, measuring its latency and throughput, costing it,
tracing it, and judging a candidate model.

| File | Purpose |
| --- | --- |
| [release.tf](docs/seance-6/release.tf) | Shadow subscription and alert-policy scaffold |
| [release.sh](docs/seance-6/release.sh) | Tagged, trafficless revision release script |
| [shadow.sh](docs/seance-6/shadow.sh) | Shadow subscription script |
| [validate.sh](docs/seance-6/validate.sh) | Validation job script |
| [promote.sh](docs/seance-6/promote.sh) | `champion` alias promotion script |
| [lib.sh](docs/seance-6/lib.sh) | Shared library loaded by the above scripts |
| [release.yml](docs/seance-6/release.yml) | `workflow_dispatch` CD workflow with WIF authentication |
| [measure.py](docs/seance-6/measure.py) | Per-revision measurement from service logs |
| [mesures.md](docs/seance-6/mesures.md), [post-mortem.md](docs/seance-6/post-mortem.md), [checklist.md](docs/seance-6/checklist.md) | Team rollout, rollback and supporting evidence |
| [llm/](docs/seance-7/llm/) | Team LLM service Terraform module (one L4 GPU, shared-bucket state, `<team>/llm` prefix) |
| [load.py](docs/seance-7/load.py) | Load-testing script |
| [eval.py](docs/seance-7/eval.py) | Evaluation script against [kyc_eval/](docs/seance-7/kyc_eval/) |
| [memory.py](docs/seance-7/memory.py) | Server memory script |
| [explain_alert.py](docs/seance-7/explain_alert.py) | Alert-explanation script, with [alerts.jsonl](docs/seance-7/alerts.jsonl) |
| [llmclient.py](docs/seance-7/llmclient.py) | Shared LLM client library |
| [mesures.md](docs/seance-7/mesures.md), [cout.md](docs/seance-7/cout.md), [fiche.md](docs/seance-7/fiche.md) | Session 7 report templates |

The exercise scaffolds use sample team identifiers. Read the relevant handout before
running the scripts against the shared project.
