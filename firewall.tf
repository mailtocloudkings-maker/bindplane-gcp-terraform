resource "google_compute_firewall" "bindplane" {
  name    = "bindplane-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3001"]
  }
  source_ranges = ["0.0.0.0/0"]
}
