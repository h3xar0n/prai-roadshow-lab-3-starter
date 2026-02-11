provider "google" {
  project               = var.project
  region                = var.region
  user_project_override = true
  billing_project       = var.billing_project
}

// Task 1: Add the Sensitive Data Protection templates

// Task 2: Add the Model Armor template
