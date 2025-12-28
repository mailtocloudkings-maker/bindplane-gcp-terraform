resource "google_compute_firewall" "bindplane_ui" {
  name    = "${var.vm_name}-bindplane-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }

  source_ranges = ["0.0.0.0/0"]
}

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

  metadata_startup_script = <<EOF
#!/bin/bash
exec > /var/log/bindplane-install.log 2>&1
set -e

echo "=== Updating OS ==="
apt update -y

echo "=== Installing PostgreSQL ==="
apt install -y postgresql postgresql-contrib curl

systemctl start postgresql
systemctl enable postgresql

echo "=== Creating BindPlane Database ==="
sudo -u postgres psql <<DBSQL
CREATE DATABASE bindplane;
CREATE USER ${var.db_user} WITH PASSWORD '${var.db_pass}';
GRANT ALL PRIVILEGES ON DATABASE bindplane TO ${var.db_user};
ALTER SCHEMA public OWNER TO ${var.db_user};
DBSQL

echo "=== Installing BindPlane Server ==="
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install.sh
chmod +x install.sh

./install.sh --version 1.96.7 <<BPSQL
${var.bp_admin_user}
${var.bp_admin_pass}
${var.bp_admin_pass}
BPSQL

systemctl enable bindplane
systemctl start bindplane

echo "=== Installing BindPlane Agent ==="
curl -fsSL https://packages.bindplane.com/agent/install.sh | bash
systemctl enable bindplane-agent
systemctl start bindplane-agent

echo "=== DONE ==="
EOF
}
