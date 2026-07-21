"""Demo backend with deliberately mixed route sensitivity.

The point of the lab is that only /api/public/* and /healthz should be
reachable from the internet; /api/admin/* exists to prove the edge denies it.
"""

import os

from fastapi import FastAPI

app = FastAPI(title="secure-ingress-demo")


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/api/public/info")
def public_info() -> dict:
    return {"service": "secure-ingress-demo", "visibility": "public"}


@app.get("/api/admin/config")
def admin_config() -> dict:
    # Reachable only if edge controls fail. Its appearance in a browser
    # means the test matrix has caught a regression.
    return {
        "visibility": "should-never-be-public",
        "note": os.getenv("ADMIN_NOTE", "if you can read this from the internet, the edge is broken"),
    }
