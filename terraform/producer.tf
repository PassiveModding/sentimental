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