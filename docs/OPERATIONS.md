# GHV operations

## Inputs and identities

The team namespace is `team-ghv`; inherited numeric template examples are not valid for this fork.
The actual container runtime is `cloudai-runner@advanced-cloud-ai.iam.gserviceaccount.com`.
The optional deployment identity is `team-ghv-cd@advanced-cloud-ai.iam.gserviceaccount.com`.
The team account exercise creates `team-ghv-run` only when explicitly enabled.

Keep actual invoker identities in the ignored `infra/terraform.tfvars`. Use the complete approved
team list rather than replacing it with a single operator. The example uses the team's `td3-ali`
image tag; choose the reviewed image digest explicitly before a deployment. Data is external:
mount `advanced-cloud-ai-models` at `/mnt/models`
read-only and set `DATA_DIR=/mnt/models/data`.

Pub/Sub delivery uses `team-ghv-push@advanced-cloud-ai.iam.gserviceaccount.com`, granted invocation
on the existing service. It is separate from the required runtime account. The helper obtains a
short-lived token from the operator's current gcloud login; there is no contributor-specific cloud
account in the implementation. Git authorship does not control cloud execution identity.

For the instructor's replay, explicitly set the ignored `tx_topic` input to
`projects/advanced-cloud-ai/topics/ff-replay`. The original default still points to `ff-tx`.
Keep concurrency and maximum instances unchanged for the comparison exercise. Integration alone
does not update the ignored variables, cloud resources or deployed image.

## Shared state and existing service

Use only the shared `team-ghv` backend. The service was imported at address
`google_cloud_run_v2_service.api`; the invoker binding is
`google_cloud_run_v2_service_iam_binding.invokers`. Existing service identity is preserved.

`init` selects the backend/provider; `plan` previews changes; `apply` executes the saved plan.
Read a plan before applying it. The helper enforces the namespace and protects the adopted service.
Normal reconciliation should not propose its deletion or replacement. Root source/configuration
changes do not affect the live service until an approved plan is applied.

## Lab cleanup

The main service existed before these changes and is protected. Do not use `terraform destroy` on
its shared state. Remove only separately created disposable manual services. For the account/IAM
exercise, set `create_team_account=false`, review the three account/grant deletions and apply them.
This preserves the main service and the instructor-managed course identity, registry and buckets.

## Optional deployment workflow

The application workflow is manual and inactive by default. Activation requires the WIF provider,
`GCP_DEPLOY_SERVICE_ACCOUNT`, `ENABLE_CD=true`, and an explicit `IMAGE_OWNER=cd` decision.
The instructor's GHV deployment account already has the repository federation binding.
Coordinate Terraform's image ownership before activation; do not enable competing image controllers.
There is no automated cloud deployment on pull requests or ordinary merges in this change.

## Team review

Check namespace, port/mount/runtime identity, private invocation, scaling bounds and service protection.
The application tools verify 500 reference predictions when the course data is available. Public CI
uses synthetic unit tests and mocked infrastructure only. Raw logs/state and personal notes remain local.
