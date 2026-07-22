resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  name                  = "${var.name_prefix}-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.backend.name
  }
}

resource "google_compute_backend_service" "backend" {
  name                  = "${var.name_prefix}-backend-svc"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = google_compute_security_policy.edge.id

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}
