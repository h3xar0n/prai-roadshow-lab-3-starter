provider "google" {
  project               = var.project
  region                = var.region
  user_project_override = true
  billing_project       = var.billing_project
}

// Task 1: Add the Sensitive Data Protection templates
// add SDP templates here

// Task 2: Add the Model Armor template
// add Model Armor template here

// leave this part:
resource "google_artifact_registry_repository" "cloud_run_source_deploy" {
  location      = var.region
  repository_id = "cloud-run-source-deploy"
  description   = "Repository for Cloud Run Source Deploy"
  format        = "DOCKER"

  labels = {
    "dev-tutorial" = "prod-ready-3"
  }
}
