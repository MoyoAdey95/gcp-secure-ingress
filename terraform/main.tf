locals {
  required_apis = [
    "run.googleapis.com",
    "compute.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  service            = each.value
  disable_on_destroy = false
}

# The backend service. The single most important line in this file is the
# ingress setting. Without it, the default *.run.app URL would bypass the
# load balancer, and therefore Cloud Armor, entirely.
resource "google_cloud_run_v2_service" "backend" {
  name                = "${var.name_prefix}-backend"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  deletion_protection = false

  template {
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  depends_on = [google_project_service.required]
}

# Unauthenticated invocation is required for LB traffic in this pattern.
# Network-layer restriction (ingress + Cloud Armor) is doing the gatekeeping,
# not IAM. The trade-off is documented in docs/threat-model.md.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  name     = google_cloud_run_v2_service.backend.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
