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


resource "google_compute_firewall" "walkman_ssh" {
  name          = "walkman-allow-ssh"
  network       = google_compute_network.project_vpc.self_link
  target_tags   = ["walkman-ssh"]
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_address" "walkman_ip_address" {
  name = "external-ip-walkman"
}

resource "google_compute_instance" "my_instance" {
  name                      = "walkman-devops-node"
  hostname                  = "devops.walkman.example.com"
  description               = "Walkman Node"
  machine_type              = var.machine_type
  zone                      = var.zone
  allow_stopping_for_update = true
  deletion_protection       = false


  boot_disk {
    mode        = "READ_WRITE"
    auto_delete = true
    initialize_params {
      image = var.image
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.project_vpc.self_link
    access_config {
      network_tier = "PREMIUM"
      nat_ip       = google_compute_address.walkman_ip_address.address
    }
  }

  tags = ["walkman-ssh"]

  metadata = {
    ssh-keys               = "${var.ssh_user}:${local_file.public_key.content}"
    block-project-ssh-keys = true
  }

  metadata_startup_script = <<-EOT
sudo apt update;sudo apt install -y git mc 
git clone https://github.com/shakhor-shual/walkman ~/walkman
chown -R ${var.ssh_user}:${var.ssh_user} ~/walkman
mv ~/walkman /home/${var.ssh_user}/walkman
/home/${var.ssh_user}/walkman/bin/cw4d.sh ${var.ssh_user}
EOT
}

output "user_info_note" {
  value = "<<<<<<<<< run SSH command from walkman_ssh for instatnt access to VM  >>>>>>>>>>>"
}

output "walkman_ssh" {
  value = "ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ${abspath(var.auto_key_private)} ${var.ssh_user}@${google_compute_instance.my_instance.network_interface[0].access_config[0].nat_ip}"
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
