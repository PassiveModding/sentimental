# required permissions - post to pubsub topic
resource "google_project_iam_binding" "producer" {
  project = var.project_id
  role    = "roles/producer-function-role"

  members = [
    "serviceAccount:${google_service_account.producer.email}",
  ]
}

resource "google_service_account" "producer" {
  account_id   = "sentiment-analysis-producer"
  display_name = "Sentiment analysis producer account"
}

# required permisisons - invoke from pubsub topic, call natural language api, write to datastore
resource "google_project_iam_binding" "consumer" {
  project = var.project_id
  role    = "roles/consumer-function-role"

  members = [
    "serviceAccount:${google_service_account.consumer.email}",
  ]
}

resource "google_service_account" "consumer" {
  account_id   = "sentiment-analysis-consumer"
  display_name = "Sentiment analysis consumer account"
}
