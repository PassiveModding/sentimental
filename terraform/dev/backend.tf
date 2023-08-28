terraform {
  backend "gcs" {
    bucket = "sentimental-dev-1-tfstate"
    prefix = "terraform/state"
  }
}
