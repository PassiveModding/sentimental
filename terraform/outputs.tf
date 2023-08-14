output "producer_endpoint" {
  value = google_cloudfunctions2_function.producer.url
}

output "producer_invoker_sa_email" {
  value = google_service_account.producer.email
}