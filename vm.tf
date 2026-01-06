# -------- TLS Key for SSH --------
resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# -------- Firewall for SSH --------
resource "google_compute_firewall" "ssh" {
  name    = "${var.vm_name}-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

# -------- Firewall for BindPlane UI --------
resource "google_compute_firewall" "bindplane_ui" {
  name    = "${var.vm_name}-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bindplane"]
}

# -------- BindPlane VM --------
resource "google_compute_instance" "bindplane_vm" {
  name         = var.vm_name
  zone         = var.zone
  machine_type = "e2-medium"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.vm_key.public_key_openssh}"
  }

  tags = ["ssh", "bindplane"]
}

# -------- Install PostgreSQL + BindPlane --------
resource "null_resource" "install_bindplane" {
  depends_on = [
    google_compute_instance.bindplane_vm,
    google_storage_bucket.bindplane_logs
  ]

  connection {
    type        = "ssh"
    host        = google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip
    user        = "ubuntu"
    private_key = tls_private_key.vm_key.private_key_pem
    timeout     = "60m"
  }

  provisioner "remote-exec" {
    script = <<-EOT
      set -euxo pipefail

      echo "===== UPDATING SYSTEM ====="
      sudo apt-get update -y
      sudo apt-get install -y postgresql postgresql-contrib curl jq

      echo "===== STARTING POSTGRESQL ====="
      sudo systemctl enable postgresql
      sudo systemctl start postgresql

      echo "===== CREATING DATABASE AND USER ====="
      sudo -u postgres psql -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${var.db_user}') THEN CREATE ROLE ${var.db_user} LOGIN PASSWORD '${var.db_pass}'; END IF; END \$\$;"
      sudo -u postgres psql -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bindplane') THEN CREATE DATABASE bindplane OWNER ${var.db_user}; END IF; END \$\$;"

      echo "===== INSTALLING BINDPLANE SERVER ====="
      curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
      bash install-linux.sh --version 1.96.7 --init --accept-license --no-prompt --admin-user ${var.bp_admin_user} --admin-password ${var.bp_admin_pass}
      rm install-linux.sh

      echo "===== STARTING SERVICES ====="
      sudo systemctl enable bindplane-server
      sudo systemctl restart bindplane-server
      sudo systemctl enable bindplane-agent
      sudo systemctl restart bindplane-agent

      echo "===== CHECKING SERVICES ====="
      PG_STATUS=$(systemctl is-active postgresql || echo 'inactive')
      BP_STATUS=$(systemctl is-active bindplane-server || echo 'inactive')
      echo "PostgreSQL: $PG_STATUS"
      echo "BindPlane: $BP_STATUS"
    EOT
  }
}
