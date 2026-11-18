resource "google_cloud_run_v2_service" "vectors" {
  project             = var.project_id
  name                = "${var.team}-vectors"
  location            = var.region
  deletion_protection = false

  template {
    service_account = local.runtime_service_account

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    containers {
      image = "docker.io/qdrant/qdrant:v1.12.4"

      ports {
        container_port = 6333
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }

        cpu_idle = false
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "vectors_invokers" {
  for_each = toset(var.invokers)

  project  = var.project_id
  name     = google_cloud_run_v2_service.vectors.name
  location = var.region
  role     = "roles/run.invoker"
  member   = each.value
}

output "vectors_url" {
  value = google_cloud_run_v2_service.vectors.uri
}