#############################
# SSH KEY
#############################
resource "tls_private_key" "vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

#############################
# FIREWALLS
#############################
resource "google_compute_firewall" "ssh" {
  name    = "${var.vm_name}-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "bindplane_ui" {
  name    = "${var.vm_name}-bindplane-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }
  source_ranges = ["0.0.0.0/0"]
}

#############################
# VM INSTANCE
#############################
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

#############################
# PROVISION
#############################
resource "null_resource" "vm_setup" {
  depends_on = [google_compute_instance.bindplane_vm]

  connection {
    type        = "ssh"
    host        = google_compute_instance.bindplane_vm.network_interface[0].access_config[0].nat_ip
    user        = "ubuntu"
    private_key = tls_private_key.vm_key.private_key_pem
    timeout     = "45m"
  }

  provisioner "file" {
    source      = "setup_bindplane.sh"
    destination = "/home/ubuntu/setup_bindplane.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'DB_USER=${var.db_user}' | sudo tee /etc/bindplane.env",
      "echo 'DB_PASS=${var.db_pass}' | sudo tee -a /etc/bindplane.env",
      "echo 'BP_ADMIN_USER=${var.bp_admin_user}' | sudo tee -a /etc/bindplane.env",
      "echo 'BP_ADMIN_PASS=${var.bp_admin_pass}' | sudo tee -a /etc/bindplane.env",

      "sudo chmod 600 /etc/bindplane.env",
      "sudo chmod +x /home/ubuntu/setup_bindplane.sh",
      "sudo /bin/bash -c 'set -a && source /etc/bindplane.env && /home/ubuntu/setup_bindplane.sh'"
    ]
  }
}
