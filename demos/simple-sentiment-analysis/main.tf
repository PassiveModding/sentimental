provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_pubsub_topic" "sentiment" {
  name = "sentiment"
}

resource "random_id" "bucket_id" {
  byte_length = 8
}

resource "google_storage_bucket" "functions" {
  name                     = "sentiment-functions-${random_id.bucket_id.hex}"
  location                 = var.region
  public_access_prevention = "enforced"
  force_destroy            = true
}

resource "google_firestore_database" "datastore_mode_database" {
  name        = "(default)"
  location_id = var.region
  type        = "DATASTORE_MODE"
}

resource "google_cloudfunctions2_function" "producer" {
  name     = "producer-function"
  location = var.region

  build_config {
    runtime     = "dotnet6"
    entry_point = "Producer.Function"
    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.producer.name
      }
    }
  }

  service_config {
    environment_variables = {
      OUTPUT_TOPIC_ID = google_pubsub_topic.sentiment.id
      PROJECT_ID      = var.project_id
    }
  }
}

resource "google_storage_bucket_object" "producer" {
  name   = format("%s#%s.zip", "producer", data.archive_file.producer.output_md5)
  bucket = google_storage_bucket.functions.name
  source = "./producer.zip"
}

data "archive_file" "producer" {
  type        = "zip"
  source_dir  = "./producer"
  output_path = "./producer.zip"
}

resource "google_cloudfunctions2_function" "consumer" {
  name     = "consumer-function"
  location = var.region

  build_config {
    runtime     = "dotnet6"
    entry_point = "Consumer.Function"
    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.consumer.name
      }
    }
  }

  service_config {
    environment_variables = {
      PROJECT_ID = var.project_id
    }
  }

  event_trigger {
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.sentiment.id
    trigger_region = var.region
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
  }
}

resource "google_storage_bucket_object" "consumer" {
  name   = format("%s#%s.zip", "consumer", data.archive_file.consumer.output_md5)
  bucket = google_storage_bucket.functions.name
  source = "./consumer.zip"
}

data "archive_file" "consumer" {
  type        = "zip"
  source_dir  = "./consumer"
  output_path = "./consumer.zip"
}

output "producer_endpoint" {
  value = google_cloudfunctions2_function.producer.url
}
output "consumer_endpoint" {
  value = google_cloudfunctions2_function.consumer.url
}