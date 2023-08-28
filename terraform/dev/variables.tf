variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
}

variable "datastore_id" {
  description = "The ID of the datastore to save processed text scores to"
  type        = string
}