output "vm_external_ip" {
  description = "External IP of BindPlane VM"
  value       = google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip
}

output "gcs_bucket_name" {
  description = "GCS bucket for BindPlane logs"
  value       = google_storage_bucket.bindplane_logs.name
}

output "postgres_status" {
  description = "PostgreSQL service status on VM"
  value       = "Use null_resource logs in GitHub Actions for live status"
}

output "bindplane_status" {
  description = "BindPlane server service status on VM"
  value       = "Use null_resource logs in GitHub Actions for live status"
}
