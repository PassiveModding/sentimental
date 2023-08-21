terraform {
  backend "gcs" {
    # must be pre-created
    bucket = "sentimental-analysis-3-0-tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}