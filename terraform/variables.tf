variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for Cloud Run and the serverless NEG"
  type        = string
  default     = "europe-west1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "sec-ingress"
}

variable "image" {
  description = "Container image for the demo backend. Default hello image works but lacks the demo routes, push app/ for the full test matrix."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "domain" {
  description = "Custom domain for HTTPS with a managed cert. Empty = HTTP-only lab mode on the LB IP."
  type        = string
  default     = ""
}

variable "rate_limit_threshold" {
  description = "Requests per minute per client IP before throttling"
  type        = number
  default     = 60
}
