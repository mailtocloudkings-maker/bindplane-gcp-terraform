resource "google_storage_bucket" "logs" {
  name     = var.bucket_name
  location = var.region
}
