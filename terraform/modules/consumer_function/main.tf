resource "google_cloudfunctions2_function" "consumer" {
  name        = "consumer"
  location    = var.region
  description = "Sentiment analysis function"

  build_config {
    runtime     = "dotnet6"
    entry_point = "Consumer.Function"
    source {
      storage_source {
        bucket = var.source_archive_bucket
        object = var.source_archive_name
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
      PROJECT_ID   = var.project_id
      #DATASTORE_ID = var.datastore_id
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = var.ingest_topic_id
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
