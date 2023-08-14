# permission for producer function to post to pubsub
resource "google_service_account" "producer" {
  account_id   = "producer"
  display_name = "producer"
}

resource "google_service_account" "consumer" {
  account_id   = "consumer"
  display_name = "consumer"
}

# permission for producer function to post to pubsub
resource "google_pubsub_topic_iam_member" "pubsub_topic_iam_member" {
  topic = google_pubsub_topic.ingest.name
  role  = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.producer.email}"
}

# permission for consumer function to post to datastore
resource "google_project_iam_member" "project_iam_member" {
  project = var.project_id
  role    = "roles/datastore.owner"
  member  = "serviceAccount:${google_service_account.consumer.email}"
}

# add invoker for producer 
resource "google_service_account" "producer_invoker" {
  account_id   = "producer-invoker"
  display_name = "producer invoker"
}

resource "google_cloudfunctions2_function_iam_member" "producer_invoker" {
  project = var.project_id
  location = var.region
  cloud_function = regex(google_cloudfunctions2_function.producer.name, google_cloudfunctions2_function.producer.id)
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.producer_invoker.email}"
}