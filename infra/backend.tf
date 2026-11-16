terraform {
  backend "gcs" {
    bucket = "advanced-cloud-ai-tfstate"
    prefix = "team-ghv" # This team's existing shared state.
  }
}
