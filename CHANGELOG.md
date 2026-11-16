# Changelog

## Session 3 integration on Ali — 16 November 2026

- Merge the contributed authenticated Pub/Sub implementation while preserving the existing
  course project, team namespace, private operator configuration and protected main service.
- Restore the teaching scaffold, correct the GHV example variables and refresh English
  documentation for the instructor's replay preparation.
- Add execution-guard coverage for the new Pub/Sub resources and reject another project's targets.
- Preserve local draft history in Git stashes; cloud deployment and GitHub publication remain separate.

## Unreleased

- Implement the GHV Cloud Run service, explicit private invoker binding and outputs.
- Configure the shared GHV backend and validate namespace/image ownership.
- Protect the pre-existing service from recreation and deletion.
- Keep optional account/IAM resources off by default while using the required course runtime account.
- Add mocked policy tests, execution guards and pull-request CI without cloud credentials.
- Add English operations documentation and an anonymized measured report.
- Incorporate the latest upstream Session 3 assignment, topic input and English learning scaffolds.
- Keep Session 3 explicitly unimplemented; its Pub/Sub resources and endpoint require separate work.
- Preserve upstream's named-team validation; the GHV execution helper separately enforces this fork's actual namespace.
