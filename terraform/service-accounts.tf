# permission for producer function to post to pubsub
resource "google_service_account" "producer" {
  account_id   = "producer"
  display_name = "producer"

  depends_on = [
    google_project_service.gcp_services
  ]
}

resource "google_service_account" "consumer" {
  account_id   = "consumer"
  display_name = "consumer"

  depends_on = [
    google_project_service.gcp_services
  ]
}



# custom role for producer function
resource "google_project_iam_custom_role" "producer_pubsub_publisher" {
  role_id     = "producer-pubsub-publisher"
  title       = "Producer PubSub Publisher"
  description = "Custom role for producer function to publish to pubsub"

  permissions = [
    "pubsub.topics.publish"
  ]
}

resource "google_pubsub_topic_iam_member" "producer_pubsub_publisher" {
  topic  = google_pubsub_topic.ingest.name
  role   = google_project_iam_custom_role.producer_pubsub_publisher.id
  member = "serviceAccount:${google_service_account.producer.email}"
}

# custom role for consumer function
resource "google_project_iam_custom_role" "consumer_pubsub_subscriber" {
  role_id     = "consumer-pubsub-subscriber"
  title       = "Consumer PubSub Subscriber"
  description = "Custom role for consumer function to subscribe to pubsub"

  permissions = [
    "datastore.entities.create"
  ]
}

# permission for consumer function to post to datastore
resource "google_project_iam_member" "consumer_datastore_owner" {
  project = var.project_id
  role    = google_project_iam_custom_role.consumer_pubsub_subscriber.id
  member  = "serviceAccount:${google_service_account.consumer.email}"
}


# custom role to be given to services which need to invoke the producer function
resource "google_project_iam_custom_role" "producer_invoker" {
  role_id     = "producer-invoker"
  title       = "Producer Invoker"
  description = "Custom role for services which need to invoke the producer function"

  permissions = [
    "cloudfunctions.functions.invoke"
  ]
}


resource "google_service_account" "producer_invoker" {
  account_id   = "producer-invoker"
  display_name = "producer invoker"

  depends_on = [
    google_project_service.gcp_services
  ]
}

resource "google_cloudfunctions2_function_iam_member" "producer_invoker" {
  project        = var.project_id
  location       = var.region
  cloud_function = regex(google_cloudfunctions2_function.producer.name, google_cloudfunctions2_function.producer.id)
  role           = google_project_iam_custom_role.producer_invoker.id
  member         = "serviceAccount:${google_service_account.producer_invoker.email}"
}