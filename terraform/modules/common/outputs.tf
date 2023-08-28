output "ingest_topic_id" {
  value = google_pubsub_topic.ingest.id
}

output "ingest_topic_name" {
  value = google_pubsub_topic.ingest.name
}

output "source_archive_bucket" {
  value = google_storage_bucket.functions.name
}

output "producer_archive_name" {
  value = google_storage_bucket_object.producer_archive.name
}

output "consumer_archive_name" {
  value = google_storage_bucket_object.consumer_archive.name
}