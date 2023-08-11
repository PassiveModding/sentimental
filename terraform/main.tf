#test
terraform {
  backend "gcs" {
    # must be pre-created
    bucket = "jaques_tfstate"
    prefix = "sentimental/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "project" {
  project_id = var.project_id
}

# pubsub topic
resource "google_pubsub_topic" "topic" {
  name = "sentiment-analysis"
}

resource "random_id" "bucket_id" {
  byte_length = 8
}

# storage bucket
resource "google_storage_bucket" "bucket" {
  name     = "sentiment-analysis-${random_id.bucket_id.hex}"
  location = var.region
  public_access_prevention = true
}

# storage bucket object
# ---------------------
# NOTE: Archives are created in the ci steps
# ---------------------
resource "google_storage_bucket_object" "producer_archive" {
  name   = "producer.zip"
  bucket = google_storage_bucket.bucket.name
  source = "../build/producer.zip"
}

resource "google_storage_bucket_object" "consumer_archive" {
  name   = "consumer.zip"
  bucket = google_storage_bucket.bucket.name
  source = "../build/consumer.zip"
}
