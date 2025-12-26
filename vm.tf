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
sudo apt update && sudo apt upgrade -y
sudo apt install -y postgresql postgresql-contrib curl

sudo systemctl start postgresql
sudo systemctl enable postgresql

sudo -u postgres psql -c "CREATE DATABASE bindplane;"
sudo -u postgres psql -c "CREATE USER ${var.db_user} WITH PASSWORD '${var.db_pass}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE bindplane TO ${var.db_user};"
sudo -u postgres psql -c "ALTER SCHEMA public OWNER TO ${var.db_user};"

curl -fsSlL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
bash install-linux.sh --version 1.96.7 --init
rm install-linux.sh

sudo systemctl enable bindplane
sudo systemctl start bindplane

curl -fsSL https://packages.bindplane.com/agent/install.sh | sudo bash
sudo systemctl start bindplane-agent
EOF
}
