# Team GHV session report

Date: 12 November 2026. This is an anonymized team summary; individual identities, workstation paths,
raw logs, private configuration, state and personal learning material are not included.

## Deployment and verification

The existing `team-ghv-fraud-api` service was adopted in the shared GHV Terraform state and repaired
in place. Its original service identity was preserved. The corrected configuration uses port 8000,
the administrator-required runtime account, a read-only historical-data mount, private invocation,
one CPU, one worker/thread, min zero and max three instances. A separate disposable GHV manual
service was also verified and removed. The main service remains protected.

The shared backend is `advanced-cloud-ai-tfstate` under `team-ghv/default.tfstate` and is operational.
The image is `europe-west1-docker.pkg.dev/advanced-cloud-ai/cloud-ai/team-ghv-fraud-api` at digest
`sha256:937ef32b4786cf88e2b3fa35761685d0710d321c7b396f2431214b8a07fa5bea`.

Anonymous HTTP requests returned 403. Authorized reference checks matched all 500 replay scores
within the 1e-6 tolerance at both memory settings. A final check also passed after restoring 1 GiB.
The separate account/grants exercise was created, verified and cleaned up; it did not replace the
required runtime identity. The optional CD workflow remains inactive.

## Cloud Monitoring results

Request percentiles use the successful-response series and a five-minute percentile alignment.
These are histogram estimates over mixed health/prediction/reference requests, not per-endpoint
client timings. Startup values are means of the recorded distribution events.

| Memory | Server p50 (ms) | Server p99 (ms) | Startup mean (s) | Observed peak instances |
| --- | --- | --- | --- | --- |
| 1Gi | 5.05 | 10.00 | 10.094 (1 event) | 1 |
| 2Gi | 5.15 | 23.49 | 15.283 (1 event) | 1 |

## Client-side experiment

Each endpoint run used 50 sequential requests at concurrency one, after warming the service with
reference verification. Timings include TLS/network overhead and differ from server measurements.

| Memory / endpoint | Client p50 (ms) | Client p99 (ms) | Failures |
| --- | --- | --- | --- |
| 1Gi /health | 160.49 | 462.59 | 0 |
| 1Gi /predict | 156.25 | 1034.17 | 0 |
| 2Gi /health | 92.25 | 244.08 | 0 |
| 2Gi /predict | 94.93 | 142.38 | 0 |

Changing memory from 1 GiB to 2 GiB updated one Terraform service resource and created a new revision.
Predictions remained consistent. The service was subsequently restored to 1 GiB. Short sequential
runs at different times do not establish a causal memory-performance effect or production capacity.
Instance counts are sampled observations, and each startup sample is limited to its recorded events.

## Scope and cleanup

Imperative gcloud commands were used for the manual deployment equivalent of the console settings.
No GUI click-through is claimed. The adopted main service was retained; only temporary manual and
account/IAM exercise resources were removed. No VM or firewall rule was created. Public CI validates
synthetic features and mocked policies; full course-data checks were run separately with private data.
