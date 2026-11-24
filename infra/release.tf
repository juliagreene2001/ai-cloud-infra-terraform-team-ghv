# Séance 6, « Après le TD » : l'abonnement d'ombre et la règle d'alerte de votre équipe.
# À copier dans infra/release.tf. Il utilise var.team, var.project_id et var.region de infra/variables.tf.
# Les trois choix de la règle d'alerte (signal, seuil, durée) sont faits ci-dessous et justifiés
# dans docs/seance-6/post-mortem.md, section 4.

variable "shadow_tag" {
  description = "Tag de la révision qui reçoit l'ombre (candidate, degrade...). Vide : pas d'abonnement d'ombre."
  type        = string
  default     = ""
}

data "google_cloud_run_v2_service" "scorer" {
  name     = "${var.team}-scorer"
  location = var.region
}

locals {
  shadow_url = one([
    for t in data.google_cloud_run_v2_service.scorer.traffic_statuses : t.uri if t.tag == var.shadow_tag
  ])
}

# Mêmes réglages que shadow.sh. L'audience est l'adresse du service, pas celle du tag.
resource "google_pubsub_subscription" "shadow" {
  count = var.shadow_tag == "" ? 0 : 1

  name  = "${var.team}-shadow"
  topic = "projects/${var.project_id}/topics/ff-td6"

  ack_deadline_seconds       = 30
  message_retention_duration = "3600s"

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "60s"
  }

  push_config {
    push_endpoint = "${local.shadow_url}/pubsub/shadow"

    oidc_token {
      service_account_email = "${var.team}-scorer-push@${var.project_id}.iam.gserviceaccount.com"
      audience              = data.google_cloud_run_v2_service.scorer.uri
    }
  }

  lifecycle {
    precondition {
      condition     = local.shadow_url != null
      error_message = "Le tag ${var.shadow_tag} n'existe pas sur ${var.team}-scorer."
    }
  }
}

# Le projet n'a pas de canal de notification : la règle ouvre un incident dans Monitoring → Alertes.
resource "google_monitoring_alert_policy" "release" {
  display_name = "${var.team}-scorer-release"
  combiner     = "OR"

  user_labels = {
    team = var.team
  }

  conditions {
    display_name = "${var.team}-scorer, par révision"

    condition_threshold {
      # Signal : distribution des scores td6_score, médiane (ALIGN_PERCENTILE_50) par minute, puis le
      # maximum entre séries (REDUCE_MAX), une série par révision de team-ghv-scorer. Une révision dont
      # l'instantané de features est vide décale ses scores sans échouer : td6_failed ne bouge pas.
      filter = "metric.type=\"logging.googleapis.com/user/td6_score\" AND resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"${var.team}-scorer\""

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_50"
        cross_series_reducer = "REDUCE_MAX"
        group_by_fields      = ["resource.label.revision_name"]
      }

      comparison = "COMPARISON_GT"

      # Seuil : 0,04. La métrique td6_score a des paliers linéaires de 0,05 : tant que plus de la moitié
      # des scores tombe dans le premier palier, la médiane vaut environ 0,025 divisé par la part de
      # scores sous 0,05. Le champion (révision team-ghv-scorer-prep-1119180441, 19-20 novembre, 326
      # minutes avec trafic) est resté entre 0,0250 et 0,0285 ; 0,04 laisse une marge de 0,0115 (+40 %),
      # soit une alerte quand environ 37,5 % des scores dépassent 0,05 (0,6 % chez le champion).
      threshold_value = 0.04

      # Durée : 300 s, cinq minutes consécutives au-dessus du seuil, comme les paliers de la livraison.
      duration = "300s"

      trigger {
        count = 1
      }
    }
  }
}
