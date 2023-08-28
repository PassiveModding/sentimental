variable "project_id" {
  description = "The project ID to deploy to"
}

variable "datastore_id" {
  description = "The ID of the datastore to post to"
}

variable "region" {
  description = "The region to deploy to"
}

variable "source_archive_bucket" {
  description = "The name of the bucket to store the source archive in"
}

variable "source_archive_name" {
  description = "The name of the source archive"
}

variable "ingest_topic" {
  description = "The name of the input topic"
}

variable "function_name" {
  description = "The name of the function"
}