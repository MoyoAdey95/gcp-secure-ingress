# gcp-secure-ingress

A case study in exposing a Cloud Run service *properly*. Only selected routes
reachable from the internet, everything else denied at the edge, and the
service's default URL closed so the controls can't be bypassed.

Personal lab, not client or production work. The pattern is one I've worked
with professionally, and this repo packages the architecture as an
independent, inspectable implementation. Built with AI-assisted tooling,
deployed and tested by me.

## The problem this demonstrates

Deploying a container to Cloud Run gives you a public `*.run.app` URL. Many
teams then put a load balancer and WAF "in front" and forget the default URL
still answers, bypassing every control they just built. Real ingress security
means:

1. Traffic **must** enter through the load balancer (Cloud Run ingress
   restricted to `internal-and-cloud-load-balancing`).
2. The edge enforces policy (Cloud Armor, route allowlist + rate limiting).
3. Network-layer controls and application auth are understood as different
   layers doing different jobs.

## Architecture

```
 internet
    │
    ▼
 Global external HTTPS LB  ── Cloud Armor policy
    │                          ├─ allow /api/public/* and /healthz
    │                          ├─ rate-limit rule
    ▼                          └─ default: deny 403
 Serverless NEG
    │
    ▼
 Cloud Run (ingress: internal-and-cloud-load-balancing)
    └─ direct *.run.app access → blocked by ingress setting
```

- [docs/threat-model.md](docs/threat-model.md), what is exposed, to whom,
  and which control stops what
- [docs/test-matrix.md](docs/test-matrix.md), permitted/denied traffic,
  verified with curl evidence

## Deploy

Prerequisites. Terraform >= 1.9, gcloud authenticated, a dedicated project
with billing + budget alert.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit
terraform init && terraform apply
```

By default the stack is **HTTP-only on the LB IP** so it can be tested without
owning a domain. Set `domain = "lab.example.com"` in tfvars to add a managed
certificate + HTTPS (point an A record at the LB IP first, cert provisioning
can take 15-60 minutes).

Run the test matrix:

```bash
LB_IP=$(terraform output -raw lb_ip)
curl -i "http://${LB_IP}/api/public/info"     # 200
curl -i "http://${LB_IP}/api/admin/config"    # 403 (Cloud Armor)
curl -i "$(terraform output -raw direct_url)/api/public/info"  # 404/403 (ingress blocked)
```

## Teardown

Global LB components are the priciest part of this lab (~$18/month if left
running), so run `terraform destroy` between sessions.

## Honest limitations

- HTTP mode exists for testability. A real deployment is HTTPS-only.
- Cloud Armor here does route allowlisting + basic rate limiting, not tuned
  WAF rules (preconfigured OWASP rules are noted in the threat model).
- Single region, single backend. This demonstrates the pattern, not the scale.
