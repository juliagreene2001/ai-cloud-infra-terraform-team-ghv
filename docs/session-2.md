# Session 2 — Your scoring service on Cloud Run, manually and then as code

Three hours, working as a team. Start with the packaged scoring service (application repository)
and finish with a private Cloud Run service described in Terraform, with its behavior measured.

This is the English GHV adaptation of the instructor's template. Use `team-ghv` consistently for
resource names, images, labels and the state prefix. Numeric examples in the original upstream
files were placeholders. The current local implementation and live report use the actual GHV team.

The main `team-ghv-fraud-api` service predates this work. It is imported and protected from deletion.
The manual exercise uses a separate disposable `team-ghv-manual` service. The separate account/IAM
exercise is explicitly enabled with `create_team_account=true`, then disabled for cleanup; the
administrator-mandated `cloudai-runner` account remains the actual service runtime identity.

Read [the measured GHV report](report-session-2.md) for actual results and retained-service policy.

| Part | Suggested duration | Result |
| --- | --- | --- |
| A. Manual deployment | 45 min | A service created in the console responds on Cloud Run |
| B. Terraform | 1 h 15 | The same service is recreated with `terraform apply` |
| C. Observe the service | 20 min | Read latency, instance count, and startup metrics in the console |
| D. Continuous deployment (optional) | 15 min | A `git push` deploys a new revision |

What the service expects on every platform:

| Item | Value |
| --- | --- |
| Container listening port | `8000` |
| Customer and terminal counters | `customer_daily.parquet` and `terminal_daily.parquet` in `DATA_DIR`; they are **not** included in the image |
| Model bucket | `advanced-cloud-ai-models`, containing those two files under `data/` |
| Recommended variables for 1 vCPU | `WEB_CONCURRENCY=1`, `XGB_NTHREAD=1` |

The application image includes the trained model. The bucket mount supplies the separate daily
counter data. Both Dockerfiles launch Uvicorn; keep `WEB_CONCURRENCY=1` for the recommended
one-worker configuration.

## A. Manual deployment

### A1. Build and push the image

Run these commands from the **application repository**, where the Dockerfile lives. Cloud Run needs
a compatible Linux image. Build explicitly for `linux/amd64`, including on Apple Silicon:

```bash
IMAGE=europe-west1-docker.pkg.dev/advanced-cloud-ai/cloud-ai/team-ghv-fraud-api:v1
docker build --platform linux/amd64 -t "$IMAGE" .
docker push "$IMAGE"
```

Check the console: Artifact Registry → `cloud-ai` → `team-ghv-fraud-api`.

### A2. Create the service in the console

Cloud Run → **Deploy container** → Service.

| Field | Value |
| --- | --- |
| Image | The image you just pushed |
| Name | `team-ghv-manual` |
| Region | `europe-west1` |
| Authentication | **Require authentication** |
| Container port | `8000` |
| Memory / CPU | 1 GiB / 1 |
| Maximum instances | 3 |
| Security → Service account | `cloudai-runner` |
| Volumes | Type **Cloud Storage bucket**, bucket `advanced-cloud-ai-models`, read only |
| Container → Volume mounts | Path `/mnt/models` |
| Environment variables | `DATA_DIR=/mnt/models/data`, `WEB_CONCURRENCY=1`, `XGB_NTHREAD=1` |

`cloudai-runner` is the instructor-provided identity for this manual exercise. The Terraform part
can explicitly create the separate `team-ghv-run` account with `create_team_account=true`; the deployed runtime remains `cloudai-runner` as required by the administrator.

### A3. Invoke the service

```bash
URL=$(gcloud run services describe team-ghv-manual --region europe-west1 --format 'value(status.url)')
curl -i "$URL/health"
```

Record the HTTP status (403 means the request was rejected before reaching your container). Grant
yourself invocation access, then retry with an identity token:

```bash
gcloud run services add-iam-policy-binding team-ghv-manual --region europe-west1 \
  --member "user:$(gcloud config get-value account)" --role roles/run.invoker
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$URL/health"
```

### A4. Questions before continuing

1. How many fields did you fill in manually? Could a teammate reproduce the same service without this assignment?
2. Which service account runs your code, and what can it access?
3. Delete `team-ghv-manual` using the console or `gcloud run services delete`.

## B. Terraform

### B1. The backend

In this infrastructure repository, verify the `team-ghv` prefix in `infra/backend.tf`, then run:

```bash
cd infra
cp -n terraform.tfvars.example terraform.tfvars   # Edit team, image, and authorized identities.
terraform init
```

Your state is the `team-ghv/default.tfstate` object in the `advanced-cloud-ai-tfstate` bucket. According
to the course setup, you cannot access other teams' prefixes. Running `gcloud storage ls` at the
bucket root is expected to be denied; `terraform init` should still work with your assigned prefix
and permissions.

The GHV identity is verified by both fork names and the existing cloud service/CD account. The local variable validation accepts only
`team-ghv`; inherited numeric examples are not valid for this fork.

### B2. Write the team resources

`infra/main.tf` already reads the shared foundation (image registry and model bucket). Write these
resources in order, running `terraform plan` after adding each one:

1. The optional `team-ghv-run` account for the separate account/IAM exercise.
2. Its two permissions: read the model bucket and write logs.
3. The `team-ghv-fraud-api` Cloud Run service, including the settings configured in A2.
4. Invocation access (`roles/run.invoker`) for the identities in `var.invokers`.
5. In `outputs.tf`, the service URL (named `service_url`) and service account email address.

Resource documentation: <https://registry.terraform.io/providers/hashicorp/google/latest/docs>.

Constraints:

- Keep the service private: never grant access to `allUsers`.
- Set `max_instance_count` to at most 3.
- Keep deletion protection and `prevent_destroy` enabled on the adopted main service. The original
  disposable-lab deletion setting does not apply to the group service that already existed.

The current implementation enforces private invocation, bounded scaling and protection of the adopted main service.

### B3. Verify

After implementing the resources, review the plan before applying it:

```bash
terraform fmt -check
terraform validate
terraform plan
terraform apply
URL=$(terraform output -raw service_url)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$URL/health"
```

Change one setting (memory, for example), review the plan, then apply it. How many resources change,
and what does Cloud Run create after each configuration change?

## C. Observe the deployed service

Use the console: Cloud Run → your service → **Metrics** and **Revisions**.

1. Send a few dozen requests:

   ```bash
   TOKEN=$(gcloud auth print-identity-token)
   for i in $(seq 50); do curl -s -o /dev/null -H "Authorization: Bearer $TOKEN" "$URL/health"; done
   ```

2. In Metrics, record latency (p50 and p99), instance count, and container startup latency.
3. Change a Terraform setting (memory, concurrency, or maximum instances), apply it, and find the new
   revision in the Revisions tab.

The loop above exercises the health endpoint sequentially. It does not measure fraud prediction
latency or concurrent load; use `/predict` requests separately if evaluating model-serving performance.

Submit `docs/report-session-2.md` in your fork with p50 and p99 latency, startup latency, peak
instance count, and the repository link. Report measured results; the repository contains no measurements.

## D. Continuous deployment (optional, separate activation)

The course provides `team-ghv-cd`, bound to the application repository through Workload Identity
Federation. The paired application's proposed workflow is manual and opt-in; this change does not
activate automatic cloud deployment. Before enabling it, agree whether Terraform or CD owns the
image field, provide the WIF/deployment-account settings, and review that ownership change separately.
GitHub pull-request checks use synthetic tests and mocked infrastructure without cloud credentials.

## End of session

Remove only resources created for the temporary exercise. Delete `team-ghv-manual` if you created it
for this exercise. Set `create_team_account=false`, review the plan and remove only that newly
created account and its two grants. Keep the adopted main service, the instructor's account,
registry and buckets. The execution helper refuses main-service deletion/replacement.

The original template's `terraform destroy` step is for disposable lab resources. It must not be
copied into the imported GHV production state. Min instances zero and max instances three keep
this retained course service bounded. No VM or public firewall rule is required by this lab.
