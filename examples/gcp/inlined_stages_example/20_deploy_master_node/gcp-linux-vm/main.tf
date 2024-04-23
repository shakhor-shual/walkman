provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

resource "tls_private_key" "my_vm_access" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "public_key" {
  filename        = var.ssh_key_public
  content         = trimspace(tls_private_key.my_vm_access.public_key_openssh)
  file_permission = "0400"
}

resource "local_sensitive_file" "private_key" {
  filename = var.ssh_key_private
  # IMPORTANT: Newline is required at end of open SSH private key file
  content         = tls_private_key.my_vm_access.private_key_openssh
  file_permission = "0400"
}

resource "google_compute_instance" "my_instance" {
  name                      = var.instance_name
  hostname                  = "${var.host}.${var.domain}"
  description               = "Linux Server"
  machine_type              = var.machine_type
  zone                      = var.zone
  allow_stopping_for_update = true
  deletion_protection       = false

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    provisioning_model  = "STANDARD"
    on_host_maintenance = "TERMINATE"
    automatic_restart   = true
  }

  boot_disk {
    mode        = "READ_WRITE"
    auto_delete = true
    initialize_params {
      image = var.image
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnetwork_self_link
    access_config {
      network_tier = "PREMIUM"
    }
  }

  tags = var.tags

  metadata = {
    ssh-keys               = "${var.ssh_user}:${local_file.public_key.content}"
    block-project-ssh-keys = true
  }

  metadata_startup_script = var.startup_script
}



output "nat_ip" {
  value = google_compute_instance.my_instance.network_interface[0].access_config[0].nat_ip
}
