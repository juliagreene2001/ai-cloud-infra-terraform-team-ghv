mock_provider "google" {
  mock_data "google_storage_bucket" {
    defaults = { name = "advanced-cloud-ai-models" }
  }
}

variables {
  team     = "team-ghv"
  image    = "europe-west1-docker.pkg.dev/advanced-cloud-ai/cloud-ai/team-ghv-fraud-api:policy-test"
  invokers = ["user:reviewer@example.com"]
}

run "private_bounded_course_service" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.api.invoker_iam_disabled == false
    error_message = "Cloud Run must enforce IAM authentication."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.template[0].service_account == "cloudai-runner@advanced-cloud-ai.iam.gserviceaccount.com"
    error_message = "The course-mandated runtime identity must be used."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.scaling[0].max_instance_count <= 3 && google_cloud_run_v2_service.api.template[0].scaling[0].max_instance_count <= 3
    error_message = "Both service-level and revision-level scaling must be capped at three."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.template[0].volumes[0].gcs[0].read_only
    error_message = "Historical data must be mounted read-only."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.template[0].containers[0].ports[0].container_port == 8000
    error_message = "The container must use the application's port 8000."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.deletion_protection
    error_message = "The pre-existing GHV service must be protected from accidental deletion."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.name == "team-ghv-fraud-api"
    error_message = "The service must use the actual GHV namespace."
  }
  assert {
    condition     = length(google_service_account.runtime) == 0
    error_message = "Default course-identity mode must not create an unused team account."
  }
  assert {
    condition     = google_cloud_run_v2_service_iam_binding.invokers.members == toset(var.invokers)
    error_message = "The service's invoker role must match the explicit private allowlist."
  }
}

run "reject_public_invoker" {
  command = plan
  variables {
    invokers = ["allUsers"]
  }
  expect_failures = [var.invokers]
}

run "reject_excess_scaling" {
  command = plan
  variables {
    max_instances = 4
  }
  expect_failures = [var.max_instances]
}

run "reject_other_team_image" {
  command = plan
  variables {
    image = "europe-west1-docker.pkg.dev/advanced-cloud-ai/cloud-ai/team2-fraud-api:v1"
  }
  expect_failures = [var.image]
}

run "reject_invalid_team_name" {
  command = plan
  variables {
    team  = "ghv"
    image = "europe-west1-docker.pkg.dev/advanced-cloud-ai/cloud-ai/ghv-fraud-api:v1"
  }
  expect_failures = [var.team]
}

run "accept_upstream_named_team_format" {
  command = plan
  variables {
    team  = "team-really-cool"
    image = "europe-west1-docker.pkg.dev/advanced-cloud-ai/cloud-ai/team-really-cool-fraud-api:v1"
  }
  assert {
    condition     = google_cloud_run_v2_service.api.name == "team-really-cool-fraud-api"
    error_message = "The upstream named-team validation must remain supported."
  }
}

run "optional_account_exercise_is_explicit" {
  command = plan
  variables {
    create_team_account = true
  }
  assert {
    condition     = google_service_account.runtime[0].account_id == "team-ghv-run"
    error_message = "The optional exercise must also use the actual GHV namespace."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.template[0].service_account == "cloudai-runner@advanced-cloud-ai.iam.gserviceaccount.com"
    error_message = "The exercise must not silently change the mandated runtime account."
  }
}
