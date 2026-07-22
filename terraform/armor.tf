# Cloud Armor deny-by-default. Allow exactly the intended routes, and
# rate-limit what is allowed. Rule priorities, lower number wins.

resource "google_compute_security_policy" "edge" {
  name        = "${var.name_prefix}-edge-policy"
  description = "Route allowlist + rate limiting for the demo backend"

  # 1000: allow the public API routes and the health endpoint
  rule {
    action   = "allow"
    priority = 1000
    match {
      expr {
        expression = "request.path.startsWith('/api/public/') || request.path == '/healthz'"
      }
    }
    description = "allow public routes"
  }

  # 1100: throttle clients that hammer the allowed routes
  rule {
    action   = "throttle"
    priority = 1100
    match {
      expr {
        expression = "request.path.startsWith('/api/public/')"
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_threshold
        interval_sec = 60
      }
    }
    description = "per-IP rate limit on public routes"
  }

  # 2147483647: default rule (required), deny everything else
  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default deny"
  }
}
