variable "project_id" {
  description = "The project ID to deploy to"
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

variable "output_topic_id" {
  description = "The name of the output topic"
}

variable "function_name" {
  description = "The name of the function"
}