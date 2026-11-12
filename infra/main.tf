# Shared foundation, managed by the instructor: read only.

data "google_artifact_registry_repository" "images" {
  repository_id = "cloud-ai"
  location      = var.region
}

data "google_storage_bucket" "models" {
  name = "${var.project_id}-models"
}

locals {
  # The course administrator's email requires this identity for actual deployments.
  # The optional separate account is an explicit teaching exercise, not a
  # prerequisite for the already-provisioned course runtime identity.
  runtime_service_account = "cloudai-runner@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_service_account" "runtime" {
  count        = var.create_team_account ? 1 : 0
  project      = var.project_id
  account_id   = "${var.team}-run"
  display_name = "${var.team} fraud scoring account"
  description  = "Team account from the Terraform exercise; course policy controls runtime identity."
}

resource "google_storage_bucket_iam_member" "runtime_models" {
  count  = var.create_team_account ? 1 : 0
  bucket = data.google_storage_bucket.models.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.runtime[0].email}"
}

resource "google_project_iam_member" "runtime_logs" {
  count   = var.create_team_account ? 1 : 0
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.runtime[0].email}"
}

resource "google_cloud_run_v2_service" "api" {
  project              = var.project_id
  name                 = "${var.team}-fraud-api"
  location             = var.region
  description          = "Private course fraud-scoring service managed by Terraform."
  deletion_protection  = true
  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = false

  # Cap the service as well as individual revisions during a rollout.
  scaling {
    min_instance_count = 0
    max_instance_count = var.max_instances
  }

  template {
    service_account                  = local.runtime_service_account
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN2"
    max_instance_request_concurrency = var.concurrency
    timeout                          = "60s"

    labels = { team = var.team }

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }

    volumes {
      name = "models"
      gcs {
        bucket    = data.google_storage_bucket.models.name
        read_only = true
      }
    }

    containers {
      name  = "${var.team}-api"
      image = var.image

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = var.memory
        }
        cpu_idle = true
      }

      volume_mounts {
        name       = "models"
        mount_path = "/mnt/models"
      }

      env {
        name  = "DATA_DIR"
        value = "/mnt/models/data"
      }
      env {
        name  = "WEB_CONCURRENCY"
        value = "1"
      }
      env {
        name  = "XGB_NTHREAD"
        value = "1"
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 1
        period_seconds        = 5
        failure_threshold     = 48
        http_get {
          path = "/health"
          port = 8000
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # This is the group's pre-existing service. Import it before applying.
  # Terraform owns image updates while optional CD remains disabled.
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_cloud_run_v2_service_iam_binding" "invokers" {
  project  = var.project_id
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  members  = toset(var.invokers)
}
