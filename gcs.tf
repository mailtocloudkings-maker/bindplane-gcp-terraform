resource "google_storage_bucket" "bindplane_logs" {
  name     = var.bucket_name
  location = var.region
  force_destroy = true
}
