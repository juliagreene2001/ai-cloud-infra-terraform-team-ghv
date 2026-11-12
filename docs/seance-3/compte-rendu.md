# Session 3 report — Team GHV

Status: not yet performed. Replace pending values with measured results; do not infer them from Session 2.

| Measurement | Observed value |
| --- | --- |
| Messages processed and highest sustained rate without growing backlog | Pending |
| Maximum oldest unacknowledged message age and corresponding rate | Pending |
| Peak instances and configured maximum | Pending |
| Cloud Run request p50/p99, time range, and measurement source | Pending |
| Invalid tx_id recovered from dead-letter storage and forwarding delay | Pending |
| Actual delivery attempts observed | Pending |
| Terraform and application repositories | [Infrastructure](https://github.com/juliagreene2001/ai-cloud-infra-terraform-team-ghv), [API](https://github.com/juliagreene2001/fraud-api-albertschool-team-ghv) |

## Explanations to complete

1. Why is the push identity separate from the runtime identity? What can each do?
2. What happens to backlog during missing-endpoint failures, and what absorbs load after repair?
3. Why acknowledge only after work, and how does a redelivery affect scoring/counters?
4. What would happen to the invalid message without a dead-letter topic?
5. How did you distinguish a redelivery from a second publication of the same tx_id?
6. Which temporary resources were removed, and which existing team resources were preserved?

Keep private identities, tokens, workstation details, raw state and personal study notes out of this report.
