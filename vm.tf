# Firewall rule to open BindPlane UI
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
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Remote-exec to install PostgreSQL, BindPlane, and agent
resource "null_resource" "vm_setup" {
  depends_on = [google_compute_instance.bindplane_vm]

  connection {
    type        = "ssh"
    host        = google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")  # Make sure your runner has the private key
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "echo 'Step 1: Update system packages'",
      "sudo apt update && sudo apt upgrade -y",
      
      "echo 'Step 2: Install PostgreSQL'",
      "sudo apt install -y postgresql postgresql-contrib curl",
      "sudo systemctl start postgresql && sudo systemctl enable postgresql",
      
      "echo 'Step 3: Create PostgreSQL database and user'",
      "sudo -u postgres psql -c \"CREATE DATABASE bindplane;\"",
      "sudo -u postgres psql -c \"CREATE USER ${var.db_user} WITH PASSWORD '${var.db_pass}';\"",
      "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE bindplane TO ${var.db_user};\"",
      "sudo -u postgres psql -c \"ALTER SCHEMA public OWNER TO ${var.db_user};\"",

      "echo 'Step 4: Install BindPlane Server'",
      "curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh",
      "bash install-linux.sh --version 1.96.7 --init --accept-license --no-prompt --admin-user ${var.bp_admin_user} --admin-password ${var.bp_admin_pass}",
      "rm install-linux.sh",
      "sudo systemctl enable bindplane && sudo systemctl start bindplane",

      "echo 'Step 5: Install BindPlane Agent'",
      "curl -fsSL https://packages.bindplane.com/agent/install.sh | sudo bash",
      "sudo systemctl start bindplane-agent",

      "echo 'VM setup completed successfully!'"
    ]
  }
}
