terraform {
  required_version = ">= 0.12.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

###########
# Variables
###########
variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
}

###########
# PubSub
###########
resource "google_pubsub_topic" "ingest" {
  name = "ingest"
}

###########
# Storage
###########
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
  source = "./build/producer.zip"
}

resource "google_storage_bucket_object" "consumer_archive" {
  name   = format("%s#%s", "consumer", data.archive_file.consumer.output_md5)
  bucket = google_storage_bucket.functions.name
  source = "./build/consumer.zip"
}

# Using zip we can avoid doing this manually
data "archive_file" "producer" {
  type        = "zip"
  source_dir  = "./functions/producer"
  output_path = "./build/producer.zip"
}

data "archive_file" "consumer" {
  type        = "zip"
  source_dir  = "./functions/consumer"
  output_path = "./build/consumer.zip"
}

###########
# Functions
###########
resource "google_cloudfunctions2_function" "producer" {
  name        = "producer-function"
  location    = var.region
  description = "Sentiment analysis ingest function"
  # Typically this would be restricted but for the purposes of this demo we allow all traffic

  build_config {
    runtime     = "dotnet6"
    entry_point = "Producer.Function"
    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.producer_archive.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    min_instance_count = 1
    timeout_seconds    = 60

    ingress_settings               = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.producer.email
    environment_variables = {
      OUTPUT_TOPIC_ID = google_pubsub_topic.ingest.id
      PROJECT_ID      = var.project_id
    }
  }
}

# service account for producer function
resource "google_service_account" "producer" {
  account_id   = "producer"
  display_name = "producer"
}

# custom role for producer function
resource "google_project_iam_custom_role" "producer_pubsub_publisher" {
  role_id     = "producer_pubsub_publisher"
  title       = "Producer PubSub Publisher"
  description = "Custom role for producer function to publish to pubsub"

  permissions = [
    "pubsub.topics.publish"
  ]
}

resource "google_pubsub_topic_iam_member" "producer_pubsub_publisher" {
  topic  = google_pubsub_topic.ingest.id
  role   = google_project_iam_custom_role.producer_pubsub_publisher.id
  member = "serviceAccount:${google_service_account.producer.email}"
}


resource "google_cloudfunctions2_function" "consumer" {
  name        = "consumer-function"
  location    = var.region
  description = "Sentiment analysis function"

  build_config {
    runtime     = "dotnet6"
    entry_point = "Consumer.Function"
    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.consumer_archive.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    min_instance_count = 1
    timeout_seconds    = 60

    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.consumer.email

    environment_variables = {
      PROJECT_ID = var.project_id
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.ingest.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

# service account for consumer function
resource "google_service_account" "consumer" {
  account_id   = "consumer"
  display_name = "consumer"
}

resource "google_cloudfunctions2_function" "consumer" {
  name        = "consumer-function"
  location    = var.region
  description = "Sentiment analysis function"

  build_config {
    runtime     = "dotnet6"
    entry_point = "Consumer.Function"
    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.consumer_archive.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    min_instance_count = 1
    timeout_seconds    = 60

    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.consumer.email

    environment_variables = {
      PROJECT_ID = var.project_id
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.ingest.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

# service account for consumer function
resource "google_service_account" "consumer" {
  account_id   = "consumer"
  display_name = "consumer"
}


# permission for consumer function to post to datastore
resource "google_project_iam_member" "consumer_datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.consumer.email}"
}

###########
# Output
###########
output "producer_endpoint" {
  value = google_cloudfunctions2_function.producer.url
}