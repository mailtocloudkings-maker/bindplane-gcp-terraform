resource "google_storage_bucket" "bindplane_logs" {
  name                        = var.bucket_name
  location                    = "US-CENTRAL1"
  force_destroy               = true
  uniform_bucket_level_access = true
  lifecycle {
    prevent_destroy = false
  }
}
