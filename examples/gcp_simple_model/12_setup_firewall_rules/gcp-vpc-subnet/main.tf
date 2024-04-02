provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

resource "google_compute_firewall" "allow_ssh" {
  name          = "${var.namespace}-allow-ssh"
  network       = var.network
  target_tags   = ["${var.tag_allow_ssh}"] // this targets our tagged VM
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_web" {
  name          = "${var.namespace}-allow-web"
  network       = var.network
  target_tags   = ["${var.tag_allow_web}"] // this targets our tagged VM
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "1000-2000"]
  }
}
