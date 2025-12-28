# Generate SSH key for VM access
resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Firewall for SSH access
resource "google_compute_firewall" "ssh" {
  name    = "${var.vm_name}-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Firewall for BindPlane UI access
resource "google_compute_firewall" "bindplane_ui" {
  name    = "${var.vm_name}-bindplane-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# VM Instance
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

  tags = ["bindplane", "ssh", "http"]
}

# Remote-exec to setup PostgreSQL and BindPlane
resource "null_resource" "vm_setup" {
  depends_on = [google_compute_instance.bindplane_vm]

  connection {
    type        = "ssh"
    host        = google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip
    user        = "ubuntu"
    private_key = tls_private_key.vm_key.private_key_pem
    timeout     = "20m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",

      # Update system packages
      "echo 'Updating system packages...'",
      "sudo apt update && sudo apt upgrade -y",

      # Install PostgreSQL 14 (works on Ubuntu 22.04)
      "echo 'Installing PostgreSQL 14 and required tools...'",
      "sudo apt install -y postgresql-14 postgresql-client-14 curl",

      # Start PostgreSQL
      "echo 'Starting PostgreSQL service...'",
      "sudo systemctl enable postgresql",
      "sudo systemctl start postgresql",

      # Create database and user
      "echo 'Creating database and user...'",
      "sudo -i -u postgres psql <<EOF",
      "CREATE DATABASE bindplane;",
      "CREATE USER ${var.db_user} WITH PASSWORD '${var.db_pass}';",
      "GRANT ALL PRIVILEGES ON DATABASE bindplane TO ${var.db_user};",
      "\\c bindplane",
      "GRANT USAGE, CREATE ON SCHEMA public TO ${var.db_user};",
      "ALTER SCHEMA public OWNER TO ${var.db_user};",
      "\\q",
      "EOF",

      # BindPlane Server install
      "echo 'Installing BindPlane Server...'",
      "curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh",
      "bash install-linux.sh --version 1.96.7 --init",
      "rm install-linux.sh",
      "sudo systemctl enable bindplane",
      "sudo systemctl start bindplane",

      # BindPlane Agent install
      "echo 'Installing BindPlane Agent...'",
      "curl -fsSL https://packages.bindplane.com/agent/install.sh | sudo bash",
      "sudo systemctl start bindplane-agent",

      "echo 'VM setup completed successfully!'"
    ]
  }
}
