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

## Session 3: next assignment

The latest upstream instructions add authenticated Pub/Sub delivery, a `/pubsub` endpoint,
retry/dead-letter observations and a separate report. Read [Session 3](docs/seance-3.md).
The English [scaffold](docs/seance-3/pubsub.tf), [sample envelope](docs/seance-3/enveloppe.json)
and [unfilled report](docs/seance-3/compte-rendu.md) retain the instructor's original paths.
They are learning materials, not deployed resources.
Only the unused `tx_topic` input is added to active configuration. Session 3 is not completed by
this pull request. Its implementation belongs on the `Ali` branch with separate review.
