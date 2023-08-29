terraform {
  required_version = ">= 0.12.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_pubsub_topic" "ingest" {
  name = "ingest"
}

output "producer_endpoint" {
  value = google_cloudfunctions2_function.producer.url
}