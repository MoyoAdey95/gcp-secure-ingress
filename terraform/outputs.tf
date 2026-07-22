output "lb_ip" {
  description = "Public IP of the load balancer (entry point for all traffic)"
  value       = google_compute_global_address.lb_ip.address
}

output "direct_url" {
  description = "Default run.app URL: should be UNREACHABLE from the internet (ingress restricted)"
  value       = google_cloud_run_v2_service.backend.uri
}

output "https_enabled" {
  description = "Whether HTTPS + managed cert is provisioned"
  value       = var.domain != ""
}
