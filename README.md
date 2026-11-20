# Team GHV cloud infrastructure

Terraform configuration for `team-ghv-fraud-api` in project `advanced-cloud-ai`, region
`europe-west1`. The companion application is
[fraud-api-albertschool-team-ghv](https://github.com/juliagreene2001/fraud-api-albertschool-team-ghv).

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
[the anonymized session report](docs/report-session-2.md). Raw evidence, personal study notes,
archives and local configuration are excluded from version control.

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

The replay measurements and [Session 3 report](docs/seance-3/compte-rendu.md) are still pending.
See the [implementation summary](docs/summary-sessions-2-3.md) for completed code and remaining work.

## Session 5: teacher materials

The [Session 5 handout](docs/seance-5.md) covers reproducible model retraining,
parallel hyperparameter search with 1, 4 and 8 workers, training costs, and a
measured decision about admitting a challenger model to the Vertex AI registry.

| File | Purpose |
| --- | --- |
| [job.tf](docs/seance-5/job.tf) | Cloud Run training/search job scaffold, training account and private Optuna connectivity |
| [custom-job.sh](docs/seance-5/custom-job.sh) | Vertex AI final-training job script |
| [compte-rendu.md](docs/seance-5/compte-rendu.md) | Session 5 report template |

These are the teacher's original exercise templates, with placeholders to
complete. Substitute `team-ghv` for the sample `team1` identifier when preparing
your configuration. Read the handout before copying or executing them; its test
dataset is reserved for the final gate. Downloading the materials does not
create training jobs or change the existing scoring service.

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
| [mesures.md](docs/seance-6/mesures.md), [post-mortem.md](docs/seance-6/post-mortem.md), [checklist.md](docs/seance-6/checklist.md) | Session 6 report templates |
| [llm/](docs/seance-7/llm/) | Team LLM service Terraform module (one L4 GPU, shared-bucket state, `<team>/llm` prefix) |
| [load.py](docs/seance-7/load.py) | Load-testing script |
| [eval.py](docs/seance-7/eval.py) | Evaluation script against [kyc_eval/](docs/seance-7/kyc_eval/) |
| [memory.py](docs/seance-7/memory.py) | Server memory script |
| [explain_alert.py](docs/seance-7/explain_alert.py) | Alert-explanation script, with [alerts.jsonl](docs/seance-7/alerts.jsonl) |
| [llmclient.py](docs/seance-7/llmclient.py) | Shared LLM client library |
| [mesures.md](docs/seance-7/mesures.md), [cout.md](docs/seance-7/cout.md), [fiche.md](docs/seance-7/fiche.md) | Session 7 report templates |

As with Session 5, these are the teacher's original templates: substitute
`team-ghv` for the sample identifier, and read each handout before copying or
executing the scripts.
