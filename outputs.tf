output "vm_external_ip" {
  description = "The external IP of the BindPlane VM"
  value       = google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip
}

output "gcs_bucket_name" {
  description = "The name of the GCS bucket created for logs"
  value       = google_storage_bucket.bindplane_logs.name
}
