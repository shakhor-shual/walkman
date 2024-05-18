provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "project_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = true
}

resource "tls_private_key" "my_vm_access" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "public_key" {
  filename        = var.auto_key_public
  content         = trimspace(tls_private_key.my_vm_access.public_key_openssh)
  file_permission = "0400"
}

resource "local_sensitive_file" "private_key" {
  filename = var.auto_key_private
  # IMPORTANT: Newline is required at end of open SSH private key file
  content         = tls_private_key.my_vm_access.private_key_openssh
  file_permission = "0400"
}


resource "google_compute_firewall" "vm_ssh" {
  name          = "${var.host}-allow-ssh"
  network       = google_compute_network.project_vpc.self_link
  target_tags   = ["${var.host}-ssh"]
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }
}

resource "google_compute_address" "vm_ip_address" {
  name = "external-ip-${var.host}"
}

resource "google_compute_instance" "my_instance" {
  name                      = "${var.host}-node"
  hostname                  = "${var.host}.test.example.com"
  description               = "Linux Node"
  machine_type              = var.machine_type
  zone                      = var.zone
  allow_stopping_for_update = true
  deletion_protection       = false


  boot_disk {
    mode        = "READ_WRITE"
    auto_delete = true
    initialize_params {
      image = var.boot_image
      type  = var.boot_disk_type
      size  = var.boot_disk_size
    }
  }

  network_interface {
    network = google_compute_network.project_vpc.self_link
    access_config {
      network_tier = "PREMIUM"
      nat_ip       = google_compute_address.vm_ip_address.address
    }
  }

  tags = ["${var.host}-ssh"]

  metadata = {
    ssh-keys               = "${var.ssh_user}:${local_file.public_key.content}"
    block-project-ssh-keys = true
  }

  # metadata_startup_script = fileexists(var.startup_script_file) ? file(var.startup_script_file) : ""
}

output "user_info_note" {
  value = "<<<<<<<<<< run SSH command from user_ssh_command for instatnt access to VM >>>>>>>>>>>>>>>"
}

output "user_ssh_command" {
  value = "ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ${abspath(var.auto_key_private)} ${var.ssh_user}@${google_compute_instance.my_instance.network_interface[0].access_config[0].nat_ip}"
}

output "walkman_install" {
  value = "cw4d.sh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ${abspath(var.auto_key_private)} ${var.ssh_user}@${google_compute_instance.my_instance.network_interface[0].access_config[0].nat_ip}"
}

output "ssh_user" {
  value = var.ssh_user
}

output "ssh_user_key" {
  value = abspath(var.auto_key_private)
}

output "access_ip" {
  value = google_compute_instance.my_instance.network_interface[0].access_config[0].nat_ip
}

