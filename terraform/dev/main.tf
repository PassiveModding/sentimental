module "common" {
  source = "../modules/common"

  project_id   = var.project_id
  region       = var.region
  pubsub_topic = "ingest-topic"
}

module "producer_function" {
  source = "../modules/producer_function"

  project_id = var.project_id
  region     = var.region

  source_archive_bucket = module.common.source_archive_bucket
  source_archive_name   = module.common.producer_archive_name
  output_topic          = module.common.ingest_topic_name
  function_name         = "producer-function"

  depends_on = [module.common]
}

module "consumer_function" {
  source = "../modules/consumer_function"

  project_id   = var.project_id
  region       = var.region
  datastore_id = var.datastore_id

  source_archive_bucket = module.common.source_archive_bucket
  source_archive_name   = module.common.consumer_archive_name
  ingest_topic          = module.common.ingest_topic_id
  function_name         = "consumer-function"

  depends_on = [module.common]
}