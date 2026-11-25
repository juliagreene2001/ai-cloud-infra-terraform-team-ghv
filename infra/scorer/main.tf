# Séance 6, « Après le TD » : décrire team-ghv-scorer tel qu'il est, sans jamais l'appliquer.
# Le service appartient au socle. Dossier à part, état local (pas de bloc backend, git-ignoré).
# Ici : terraform init, terraform plan seulement. Jamais terraform apply ni terraform destroy.

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}

provider "google" {
  project = "advanced-cloud-ai"
  region  = "europe-west1"

  add_terraform_attribution_label = false
}

import {
  to = google_cloud_run_v2_service.scorer
  id = "projects/advanced-cloud-ai/locations/europe-west1/services/team-ghv-scorer"
}
