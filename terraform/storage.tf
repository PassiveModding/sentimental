resource "random_id" "bucket_id" {
  byte_length = 8
}

resource "google_storage_bucket" "functions" {
  name                     = "sentiment-analysis-${random_id.bucket_id.hex}"
  location                 = var.region
  public_access_prevention = "enforced"
  force_destroy            = true
}

# storage bucket object
# NOTE: Using the hash of the archive file as the object name allows
# functions to automatically update when the archive changes as it forces a build
resource "google_storage_bucket_object" "producer_archive" {
  name   = format("%s#%s", "producer", data.archive_file.producer.output_md5)
  bucket = google_storage_bucket.functions.name
  source = "../build/producer.zip"
}

resource "google_storage_bucket_object" "consumer_archive" {
  name   = format("%s#%s", "consumer", data.archive_file.consumer.output_md5)
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