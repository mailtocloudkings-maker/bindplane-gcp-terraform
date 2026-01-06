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

  # Upload the installation script
  provisioner "file" {
    source      = "setup_bindplane.sh"
    destination = "/home/ubuntu/setup_bindplane.sh"
  }

  # Run the script remotely
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/setup_bindplane.sh",
      "sudo /home/ubuntu/setup_bindplane.sh"
    ]
  }
}
