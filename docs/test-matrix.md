# Test matrix

Every claim in the threat model, verified. `LB` = `http://$(terraform output
-raw lb_ip)`, and `DIRECT` = the `direct_url` output. Fill the *observed* column
from real curl runs and commit the evidence.

| # | Request | Expected | Observed | Evidence |
|---|---------|----------|----------|----------|
| 1 | `curl -i $LB/api/public/info` | 200, public payload | 200, public payload | evidence/01-08-test-matrix-run.txt |
| 2 | `curl -i $LB/healthz` | 200 | 200 | evidence/01-08-test-matrix-run.txt |
| 3 | `curl -i $LB/api/admin/config` | **403** from Cloud Armor | 403 | evidence/01-08-test-matrix-run.txt |
| 4 | `curl -i $LB/` | **403** (not allowlisted) | 403 | evidence/01-08-test-matrix-run.txt |
| 5 | `curl -i $LB/api/publicX/info` | **403** (prefix must match exactly) | 403 | evidence/01-08-test-matrix-run.txt |
| 6 | `curl -i $DIRECT/api/public/info` | **404/403** (ingress blocks LB bypass) | 404 | evidence/01-08-test-matrix-run.txt |
| 7 | `curl -i $DIRECT/healthz` | **404/403** (same) | 404 | evidence/01-08-test-matrix-run.txt |
| 8 | `for i in $(seq 1 100); do curl -s -o /dev/null -w "%{http_code}\n" $LB/api/public/info; done` | 200s then **429**s once throttle kicks in | 200s then 429s once past 60/min | evidence/01-08-test-matrix-run.txt |

Capture format for evidence. Paste the status line + relevant headers into
`docs/evidence/NN-description.txt`, or screenshot the terminal.

## Notes

- Test 5 guards against a lazy `startsWith('/api/public')` (no trailing
  slash) which would also match `/api/publicX`. The rule uses
  `'/api/public/'` deliberately.
- If test 6 returns 200, the single most important control has regressed.
  Check the service's ingress setting first.
- Tests 6 and 7 both return 404, but from two different sources. Test 6
  gets Cloud Run's own plain "Page not found" page, the ingress restriction
  rejecting the request before it reaches the container. Test 7 gets
  Google's generic frontend 404 (the "That's an error" page with the robot
  logo), the same interception that made repo `gcp-terraform-lab` rename its
  health path to `/health`. That interception happens on the default
  `*.run.app` hostname regardless of ingress settings, so it fires here too,
  even though this service's ingress is already blocking the path for an
  unrelated reason. `/healthz` stayed as-is in this repo because it's only
  ever hit through the LB, where the interception doesn't apply.
- Test 8 needed a real Cloud Armor bug fixed first. The original policy had
  a plain allow rule for `/api/public/*` at priority 1000, and a separate
  throttle rule for the same path at priority 1100. Cloud Armor evaluates
  rules in priority order and stops at the first match, so the allow rule
  always won and the throttle rule never ran. Fixed by moving the throttle
  to priority 900, ahead of the allow, since `conform_action = "allow"`
  already covers normal traffic on its own.
- After that fix, several retests still came back all 200s. Cloud Armor's
  propagation for rate-limit rules took noticeably longer than the plain
  allow/deny rule changes elsewhere in this policy, which took effect in
  under a minute. Confirmed via `gcloud compute security-policies rules
  describe` that the live rule matched the Terraform config exactly
  (`preview: false`, correct threshold) before concluding it was a
  propagation delay and not a config problem. Budget extra time for this
  if you're testing it yourself.
