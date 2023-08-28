# pubsub topic
resource "google_pubsub_topic" "ingest" {
  name = var.pubsub_topic
}