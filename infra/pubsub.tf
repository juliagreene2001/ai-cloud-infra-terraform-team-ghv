# Session 3 resources for the existing team-ghv service.
# The unfilled teaching copy remains in docs/seance-3/pubsub.tf.

resource "google_service_account" "push" {
  account_id   = "${var.team}-push"
  display_name = "Pub/Sub delivery to the ${var.team} scoring service"
}

# Integrate this account into the existing authoritative invokers binding in main.tf.
# Do not also create a google_cloud_run_v2_service_iam_member for the same invoker role.
# Keep the full approved human invoker list and add the push account's member identity.
# Verify token-minting and dead-letter service-agent IAM prerequisites separately.

resource "google_pubsub_topic" "dead" {
  name = "${var.team}-tx-dead"
}

resource "google_pubsub_subscription" "dead_pull" {
  name  = "${var.team}-tx-dead-pull"
  topic = google_pubsub_topic.dead.id
}

resource "google_pubsub_subscription" "tx" {
  name                       = "${var.team}-tx-push"
  topic                      = var.tx_topic
  ack_deadline_seconds       = 30
  message_retention_duration = "3600s"

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.api.uri}/pubsub"

    oidc_token {
      service_account_email = google_service_account.push.email
      audience              = google_cloud_run_v2_service.api.uri
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "60s"
  }

  # Forwarding after the configured count is best effort, not an exact attempt guarantee.
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead.id
    max_delivery_attempts = 5
  }

  labels     = { team = var.team }
  depends_on = [google_cloud_run_v2_service_iam_binding.invokers]
}

output "push_subscription" {
  value = google_pubsub_subscription.tx.name
}

output "dead_letter_subscription" {
  value = google_pubsub_subscription.dead_pull.name
}
