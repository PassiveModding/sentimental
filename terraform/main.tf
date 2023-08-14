terraform {
  backend "gcs" {
    # must be pre-created
    bucket = "sentimental-analysis-1-0-tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# pubsub topic
resource "google_pubsub_topic" "ingest" {
  name = "sentiment-analysis"
}

resource "random_id" "bucket_id" {
  byte_length = 8
}

# storage bucket
resource "google_storage_bucket" "functions" {
  name                     = "sentiment-analysis-${random_id.bucket_id.hex}"
  location                 = var.region
  public_access_prevention = "enforced"
}

# storage bucket object
resource "google_storage_bucket_object" "producer_archive" {
  name   = "producer.zip"
  bucket = google_storage_bucket.functions.name
  source = "../build/producer.zip"
}

resource "google_storage_bucket_object" "consumer_archive" {
  name   = "consumer.zip"
  bucket = google_storage_bucket.functions.name
  source = "../build/consumer.zip"
}

data "archive_file" "producer" {
  type        = "zip"
  source_dir  = "../functions/producer"
  output_path = "../build/producer.zip"
}

data "archive_file" "consumer" {
  type        = "zip"
  source_dir  = "../functions/consumer"
  output_path = "../build/consumer.zip"
}