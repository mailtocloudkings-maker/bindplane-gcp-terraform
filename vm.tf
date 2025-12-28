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

# Upload and execute setup_bindplane.sh script
resource "null_resource" "vm_setup" {
  depends_on = [google_compute_instance.bindplane_vm]

  connection {
    type        = "ssh"
    host        = google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip
    user        = "ubuntu"
    private_key = tls_private_key.vm_key.private_key_pem
    timeout     = "30m"
  }

  # Copy the script to the VM
  provisioner "file" {
    source      = "setup_bindplane.sh"
    destination = "/home/ubuntu/setup_bindplane.sh"
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    environment = {
      DB_USER       = var.db_user
      DB_PASS       = var.db_pass
      BP_ADMIN_USER = var.bp_admin_user
      BP_ADMIN_PASS = var.bp_admin_pass
    }

    inline = [
      "chmod +x /home/ubuntu/setup_bindplane.sh",
      "echo 'Starting VM setup via setup_bindplane.sh...'",
      "sudo /home/ubuntu/setup_bindplane.sh"
    ]
  }
}
