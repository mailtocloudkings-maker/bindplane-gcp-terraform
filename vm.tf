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

  # ------------------------------
  # Startup script automates Postgres + BindPlane
  # ------------------------------
  metadata_startup_script = templatefile("${path.module}/setup_bindplane.sh", {
    db_user       = var.db_user
    db_pass       = var.db_pass
    bp_admin_user = var.bp_admin_user
    bp_admin_pass = var.bp_admin_pass
  })

  tags = ["ssh", "bindplane"]
}
