# pubsub topic
resource "google_pubsub_topic" "ingest" {
  name = "sentiment-analysis"
}