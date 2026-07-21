# Threat / access model

## Assets

- The backend service and its non-public routes (`/api/admin/*`)
- Availability of the public routes (`/api/public/*`, `/healthz`)

## Exposure map

| Path | Intended audience | Enforced by |
|------|-------------------|-------------|
| `/api/public/*` | internet | Cloud Armor allow rule (priority 1000) |
| `/healthz` | internet (uptime checks) | Cloud Armor allow rule |
| `/api/admin/*` | nobody, externally | Cloud Armor default deny (403) |
| any path via `*.run.app` | nobody | Cloud Run ingress = `INTERNAL_LOAD_BALANCER` |

## The bypass question (the one that matters)

**"If Cloud Armor is on the load balancer, why restrict Cloud Run ingress at
all?"** Because Cloud Armor policies attach to the LB's backend service, so they
see only traffic that comes *through the LB*. The default `*.run.app` URL is a
separate Google frontend that never touches your LB. Leave ingress open and an
attacker who discovers the run.app hostname (they're guessable and they leak
in logs, error messages and certificate transparency) talks straight to the
container, past the allowlist, past the rate limit. The ingress setting is
what makes the edge policy *the only door*.

## Network controls vs application auth (different layers, different jobs)

- **This lab (network layer):** who can reach a route at all. Cheap to
  enforce, impossible for app bugs to undo, but coarse (paths and IPs, not
  identities).
- **Application auth (not in scope):** who may *do* something once connected,
  handled by OAuth/IAP/JWTs. A real service has both. Route allowlisting is not a
  substitute for authenticating admin actions. In production the admin routes
  would additionally sit behind IAP or service-to-service IAM, and
  `allUsers` invoker would be replaced by the LB's identity where the
  architecture allows it.

## Failure modes considered

| Threat | Mitigation here | Residual risk |
|--------|-----------------|---------------|
| Direct run.app access | ingress restriction | none known |
| Route probing / scraping | default deny 403 | allowed routes still enumerable |
| Simple volumetric abuse | per-IP throttle (60 rpm) | distributed sources, tune or add reCAPTCHA/adaptive protection |
| OWASP-class payloads on allowed routes | **not mitigated**, production would add Cloud Armor preconfigured WAF rules (SQLi/XSS) | acknowledged gap |
| DNS pointing elsewhere / cert issues | managed cert when domain set | HTTP lab mode is deliberately insecure in transit |
