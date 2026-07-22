output "direct_url" {
  description = "Default run.app URL, should be UNREACHABLE from the internet (ingress restricted)"
  value       = google_cloud_run_v2_service.backend.uri
}
