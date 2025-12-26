resource "null_resource" "pipeline" {
  provisioner "local-exec" {
    command = <<EOF
curl -X POST http://${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}:3001/api/v1/pipelines \
-H "Authorization: Bearer ${var.bindplane_token}" \
-H "Content-Type: application/json" \
-d '{
 "name":"${var.pipeline_name}",
 "source":{"type":"google_cloud_storage","config":{"bucket":"${var.bucket_name}"}},
 "destination":{"type":"google_cloud_observability"}
}'
EOF
  }
}
