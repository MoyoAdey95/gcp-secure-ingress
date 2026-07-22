# Cloud Armor deny-by-default. Allow exactly the intended routes, and
# rate-limit what is allowed. Rule priorities, lower number wins.

resource "google_compute_security_policy" "edge" {
  name        = "${var.name_prefix}-edge-policy"
  description = "Route allowlist + rate limiting for the demo backend"

  # 900: rate-limited allow for the public API routes. This has to run
  # before any unconditional allow for the same path. Cloud Armor stops at
  # the first matching rule, so a plain allow at a lower priority number
  # would win first and this throttle would never run. The first version
  # failed this way. It had a separate allow rule at priority 1000, and
  # every request matching /api/public/* was already resolved by that
  # earlier rule, so the throttle rule below never got evaluated.
  rule {
    action   = "throttle"
    priority = 900
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
    description = "rate-limited allow for public routes"
  }

  # 1000: plain allow for the health endpoint. Not rate-limited on purpose,
  # uptime checks shouldn't get throttled.
  rule {
    action   = "allow"
    priority = 1000
    match {
      expr {
        expression = "request.path == '/healthz'"
      }
    }
    description = "allow health check"
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
