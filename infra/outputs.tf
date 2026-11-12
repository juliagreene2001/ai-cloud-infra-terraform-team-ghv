output "service_url" {
  description = "HTTPS endpoint of the private Cloud Run service."
  value       = google_cloud_run_v2_service.api.uri
}

output "service_name" {
  description = "Team-prefixed Cloud Run service name."
  value       = google_cloud_run_v2_service.api.name
}

output "runtime_service_account_email" {
  description = "Actual deployed runtime identity, as required by the course administrator."
  value       = local.runtime_service_account
}

output "team_service_account_email" {
  description = "Separate team account and scoped grants created for the Terraform exercise."
  value       = try(google_service_account.runtime[0].email, null)
}

output "artifact_registry_repository" {
  description = "Existing instructor-managed container registry."
  value       = data.google_artifact_registry_repository.images.id
}
