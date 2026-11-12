variable "project_id" {
  type    = string
  default = "advanced-cloud-ai"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "team" {
  description = "Team ID: prefix for all your resources and value of the team label."
  type        = string

  validation {
    condition     = var.team == "team-ghv"
    error_message = "This repository belongs to team-ghv. Numeric team IDs are not this team's namespace."
  }
}

variable "image" {
  description = "Image to deploy, including its tag: europe-west1-docker.pkg.dev/advanced-cloud-ai/cloud-ai/<team>-fraud-api:<tag>."
  type        = string

  validation {
    condition = can(regex(
      "^${var.region}-docker[.]pkg[.]dev/${var.project_id}/cloud-ai/${var.team}-fraud-api(:[A-Za-z0-9_.-]+|@sha256:[a-f0-9]{64})$",
      var.image
    ))
    error_message = "Use this team's versioned fraud-api image in the course's regional Artifact Registry."
  }
}

variable "invokers" {
  description = "Identities allowed to invoke the service, for example user:firstname@albertschool.com."
  type        = list(string)

  validation {
    condition = length(var.invokers) > 0 && alltrue([
      for identity in var.invokers : can(regex("^(user|group|serviceAccount):[^ ]+@[^ ]+$", identity))
    ])
    error_message = "Specify explicit user, group, or service-account emails; public invokers are forbidden."
  }
}

variable "memory" {
  description = "Memory per instance; change this to compare revisions during the lab."
  type        = string
  default     = "1Gi"

  validation {
    condition     = contains(["512Mi", "1Gi", "2Gi"], var.memory)
    error_message = "Use 512Mi, 1Gi, or 2Gi for this 1-vCPU course service."
  }
}

variable "max_instances" {
  description = "Hard course scaling limit, between one and three instances."
  type        = number
  default     = 3

  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 3 && floor(var.max_instances) == var.max_instances
    error_message = "The maximum instance count must be an integer from 1 through 3."
  }
}

variable "concurrency" {
  description = "Requests allowed per instance; one avoids overlapping in-memory event updates."
  type        = number
  default     = 1

  validation {
    condition     = var.concurrency >= 1 && var.concurrency <= 80 && floor(var.concurrency) == var.concurrency
    error_message = "Concurrency must be an integer from 1 through 80."
  }
}

variable "create_team_account" {
  description = "Opt into the separate account/IAM exercise; the mandated course account remains the runtime identity."
  type        = bool
  default     = false
}
