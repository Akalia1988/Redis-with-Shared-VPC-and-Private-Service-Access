resource "google_project" "shared-resource" {
  name            = "shared-networking"
  project_id      = "networking"
  org_id          = var.org-id
  billing_account = var.billing_account
}
resource "google_project" "data" {
  name            = "data-tier"
  project_id      = "data"
  org_id          = var.org-id
  billing_account = var.billing_account
}
resource "google_project" "app" {
  name            = "app"
  project_id      = "app"
  org_id          = var.org-id
  billing_account = var.billing_account
}
resource "google_project_service" "compute-shared-networking" {
  project = google_project.shared-networking.project_id
  service = "compute.googleapis.com"
}
resource "google_project_service" "compute-data-tier" {
  project = google_project.data-tier.project_id
  service = "compute.googleapis.com"
}
resource "google_project_service" "redis-data-tier" {
  project = google_project.data-tier.project_id
  service = "redis.googleapis.com"
}
resource "google_project_service" "compute-app-tier" {
  project = google_project.app-tier.project_id
  service = "compute.googleapis.com"
}
resource "google_project_service" "enable-service-networking" {
  project = google_project.shared-networking.project_id
  service = "servicenetworking.googleapis.com"
}
resource "google_project_service" "enable-service-networking-data-tier" {
  project = google_project.data-tier.project_id
  service = "servicenetworking.googleapis.com"
}
resource "google_compute_network" "shared-networking" {
  project                 = google_project.shared-networking.project_id
  name                    = "shared-networking"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "data-us-central1" {
  name          = "data-us-central1"
  ip_cidr_range = "10.0.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.shared-networking.id
  project       = google_project.shared-networking.project_id
}
resource "google_compute_global_address" "managed-data-services" {
  name          = "managed-data-services"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 16
  network       = google_compute_network.shared-networking.self_link
  project       = google_project.shared-networking.project_id
}
resource "google_service_networking_connection" "private-connection" {
  network                 = google_compute_network.shared-networking.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.managed-data-services.name]
}
resource "google_compute_firewall" "ssh" {
  name          = "allow-ingress-tcp-22-shared-networking"
  network       = google_compute_network.shared-networking.name
  project       = google_project.shared-networking.project_id
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
resource "google_compute_shared_vpc_host_project" "host" {
  project = google_project.shared-networking.project_id
}
resource "google_compute_shared_vpc_service_project" "service1" {
  host_project    = google_compute_shared_vpc_host_project.host.project
  service_project = google_project.app-tier.project_id
}
resource "google_compute_shared_vpc_service_project" "service2" {
  host_project    = google_compute_shared_vpc_host_project.host.project
  service_project = google_project.data-tier.project_id
}
resource "google_redis_instance" "cache" {
  name               = "memory-cache"
  memory_size_gb     = 5
  project            = google_project.data-tier.project_id
  region             = "us-central1"
  authorized_network = google_compute_network.shared-networking.self_link
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
}
resource "google_compute_instance" "client" {
  name         = "client"
  machine_type = "f1-micro"
  zone         = "us-central1-a"
  project      = google_project.app-tier.project_id
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
network_interface {
    access_config {
      // Ephemeral public IP
    }
    subnetwork = google_compute_subnetwork.data-tier-us-central1.self_link
  }
}