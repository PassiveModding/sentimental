# pubsub topic
resource "google_pubsub_topic" "ingest" {
  name = "sentiment-analysis"

  depends_on = [
    google_project_service.gcp_services
  ]
}