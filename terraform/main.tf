#test
terraform {
  backend "gcs" {
    # must be pre-created
    bucket = "sentimental-analysis-1-0-tfstate"
  }
}

provider "google" {
  project_id = var.project_id
region            = var.region
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
  name                     = "sentiment-analysis-${random_id.bucket_id.hex}"
  location                 = var.region
  public_access_prevention = true
}

# service account with write access to storage bucket
resource "google_service_account" "service_account" {
  account_id   = "sa-bucket-writer"
  display_name = "Sentiment Analysis Bucket Writer"
}

resource "google_service_account_iam_member" "storage_bucket_writer" {
  service_account_id = google_service_account.service_account.name
  role               = "roles/storage.objectCreator"
  member             = "serviceAccount:${google_service_account.service_account.email}"
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
