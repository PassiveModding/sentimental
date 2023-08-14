# functions
resource "google_cloudfunctions2_function" "producer" {
  name        = "producer"
  location    = var.region
  description = "Sentiment analysis ingest function"
  # Typically this would be restricted but for the purposes of this demo we allow all traffic

  build_config {
    runtime     = "dotnet6"
    entry_point = "Producer.Function"
    environment_variables = {
      PROJECT_ID   = var.project_id
      OUTPUT_TOPIC = google_pubsub_topic.topic.name
    }
    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.producer_archive.name
      }
    }
  }

  service_config {
    max_instance_count               = 1
    min_instance_count               = 1
    timeout_seconds                  = 60
    max_instance_request_concurrency = 80

    ingress_settings               = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.producer.email
    environment_variables = {
      OUTPUT_TOPIC = google_pubsub_topic.topic.name
      PROJECT_ID   = var.project_id
    }
  }
}

resource "google_cloudfunctions2_function" "consumer" {
  name        = "consumer"
  location    = var.region
  description = "Sentiment analysis function"

  build_config {
    runtime     = "dotnet6"
    entry_point = "Consumer.Function"
    environment_variables = {
      PROJECT_ID = var.project_id
    }
    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.consumer_archive.name
      }
    }
  }

  service_config {
    max_instance_count               = 1
    min_instance_count               = 1
    timeout_seconds                  = 60
    max_instance_request_concurrency = 80

    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.consumer.email
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.topic.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}