# Global external HTTP(S) load balancer in front of Cloud Run via a
# serverless NEG. HTTPS resources are created only when a domain is supplied.
# HTTP mode exists so the lab is testable without owning DNS.

resource "google_compute_global_address" "lb_ip" {
  name = "${var.name_prefix}-ip"
}

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

resource "google_compute_url_map" "main" {
  name            = "${var.name_prefix}-urlmap"
  default_service = google_compute_backend_service.backend.id
}

# --- HTTP (lab mode: always on, so the stack is testable without DNS) ---

resource "google_compute_target_http_proxy" "http" {
  name    = "${var.name_prefix}-http-proxy"
  url_map = google_compute_url_map.main.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name_prefix}-http-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.http.id
}

# --- HTTPS (enabled when var.domain is set) ---

resource "google_compute_managed_ssl_certificate" "cert" {
  count = var.domain != "" ? 1 : 0

  name = "${var.name_prefix}-cert"

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_target_https_proxy" "https" {
  count = var.domain != "" ? 1 : 0

  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert[0].id]
}

resource "google_compute_global_forwarding_rule" "https" {
  count = var.domain != "" ? 1 : 0

  name                  = "${var.name_prefix}-https-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.https[0].id
}
