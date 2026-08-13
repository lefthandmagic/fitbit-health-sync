#!/usr/bin/env python3
"""Pull App Store Connect crash signatures + analytics access check.

Auth: APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, APPSTORE_PRIVATE_KEY
Does not print the key or JWT. Full diagnostic logs stay off stdout.
"""
from __future__ import annotations

import json
import os
import sys
import textwrap
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

APP_ID_FALLBACK = "6759504137"
BUNDLE_ID = "com.praveenmurugesan.FitbitHealthSync"
API = "https://api.appstoreconnect.apple.com"
ACCEPT_DIAG = "application/vnd.apple.xcode-metrics+json,application/json"


def normalize_pem(raw: str) -> str:
    raw = raw.strip().strip('"').strip("'")
    raw = raw.replace("\\n", "\n").replace("\r\n", "\n")
    if "BEGIN" not in raw:
        compact = "".join(raw.split())
        raw = (
            "-----BEGIN PRIVATE KEY-----\n"
            + "\n".join(textwrap.wrap(compact, 64))
            + "\n-----END PRIVATE KEY-----\n"
        )
    if not raw.endswith("\n"):
        raw += "\n"
    return raw


def make_token(key_id: str, issuer_id: str, pem: str) -> str:
    import jwt  # PyJWT

    now = int(time.time())
    return jwt.encode(
        {
            "iss": issuer_id,
            "iat": now,
            "exp": now + 19 * 60,
            "aud": "appstoreconnect-v1",
        },
        pem,
        algorithm="ES256",
        headers={"alg": "ES256", "kid": key_id, "typ": "JWT"},
    )


def request_json(
    token: str,
    path: str,
    method: str = "GET",
    body: dict[str, Any] | None = None,
    accept: str = "application/json",
) -> tuple[int, Any]:
    url = path if path.startswith("http") else f"{API}{path}"
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": accept,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            payload = json.loads(raw) if raw.strip() else {}
            return resp.status, payload
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw) if raw.strip() else {"raw": raw}
        except json.JSONDecodeError:
            payload = {"raw": raw[:2000]}
        return exc.code, payload


def errors_summary(payload: Any) -> str:
    if not isinstance(payload, dict):
        return str(payload)[:400]
    errs = payload.get("errors") or []
    if not errs:
        return json.dumps(payload)[:400]
    parts = []
    for err in errs[:4]:
        parts.append(
            f"{err.get('status')} {err.get('code')}: {err.get('title')} — {err.get('detail')}"
        )
    return " | ".join(parts)


def paged(token: str, path: str, accept: str = "application/json") -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    next_path: str | None = path
    while next_path:
        status, payload = request_json(token, next_path, accept=accept)
        if status != 200:
            raise RuntimeError(f"{next_path} -> {status} {errors_summary(payload)}")
        out.extend(payload.get("data") or [])
        next_path = (payload.get("links") or {}).get("next")
    return out


def main() -> int:
    key_id = os.environ.get("APPSTORE_KEY_ID", "").strip()
    issuer_id = os.environ.get("APPSTORE_ISSUER_ID", "").strip()
    private_key = os.environ.get("APPSTORE_PRIVATE_KEY", "").strip()
    if not (key_id and issuer_id and private_key):
        print("Missing APPSTORE_KEY_ID / APPSTORE_ISSUER_ID / APPSTORE_PRIVATE_KEY", file=sys.stderr)
        return 2

    token = make_token(key_id, issuer_id, normalize_pem(private_key))
    print(f"JWT ok · key {key_id[:4]}… · issuer {issuer_id[:8]}…")

    status, payload = request_json(
        token,
        f"/v1/apps?filter[bundleId]={urllib.parse.quote(BUNDLE_ID)}&limit=5",
    )
    print(f"GET apps?bundleId → {status}")
    if status != 200:
        print(errors_summary(payload))
        return 1

    apps = payload.get("data") or []
    if not apps:
        print(f"No app for {BUNDLE_ID}; trying id {APP_ID_FALLBACK}")
        status, payload = request_json(token, f"/v1/apps/{APP_ID_FALLBACK}")
        print(f"GET apps/{APP_ID_FALLBACK} → {status}")
        if status != 200:
            print(errors_summary(payload))
            return 1
        app = payload.get("data") or {}
    else:
        app = apps[0]

    app_id = app.get("id")
    attrs = app.get("attributes") or {}
    print(f"App {attrs.get('name')} · id {app_id} · bundle {attrs.get('bundleId')}")

    # Permission probes
    probes = [
        ("analyticsReportRequests", f"/v1/apps/{app_id}/analyticsReportRequests?limit=5"),
        ("perfPowerMetrics", f"/v1/apps/{app_id}/perfPowerMetrics?filter[platform]=IOS"),
        ("builds", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10"),
        ("betaFeedbackCrashSubmissions", f"/v1/apps/{app_id}/betaFeedbackCrashSubmissions?limit=1"),
    ]
    for name, path in probes:
        st, body = request_json(token, path)
        extra = ""
        if st == 200:
            extra = f" · {len(body.get('data') or [])} items"
        else:
            extra = f" · {errors_summary(body)}"
        print(f"PROBE {name} → {st}{extra}")

    # Analytics: request a snapshot if we can (first time needs Admin; then 24–48h)
    st, body = request_json(
        token,
        "/v1/analyticsReportRequests",
        method="POST",
        body={
            "data": {
                "type": "analyticsReportRequests",
                "attributes": {"accessType": "ONE_TIME_SNAPSHOT"},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}}
                },
            }
        },
    )
    print(f"POST analyticsReportRequests ONE_TIME_SNAPSHOT → {st}")
    if st not in (200, 201):
        print(f"  {errors_summary(body)}")
    else:
        req_id = (body.get("data") or {}).get("id")
        print(f"  request id {req_id} (reports usually appear in 24–48h)")

    st, body = request_json(token, f"/v1/apps/{app_id}/analyticsReportRequests?limit=10")
    if st == 200:
        for item in body.get("data") or []:
            a = item.get("attributes") or {}
            print(
                f"  existing request {item.get('id')} access={a.get('accessType')} "
                f"stopped={a.get('stoppedDueToInactivity')}"
            )
            rel = f"/v1/analyticsReportRequests/{item.get('id')}/reports?limit=50"
            rst, rbody = request_json(token, rel)
            if rst != 200:
                print(f"    reports → {rst} {errors_summary(rbody)}")
                continue
            for report in rbody.get("data") or []:
                ra = report.get("attributes") or {}
                print(f"    report {ra.get('name')} category={ra.get('category')}")

    builds = []
    try:
        builds = paged(
            token,
            f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=20",
        )
    except RuntimeError as exc:
        print(f"builds list failed: {exc}")

    print(f"Recent builds: {len(builds)}")
    crash_rows: list[dict[str, Any]] = []
    for build in builds[:12]:
        battrs = build.get("attributes") or {}
        bid = build.get("id")
        version = battrs.get("version")
        expired = battrs.get("expired")
        print(
            f"Build {version} id={bid} processing={battrs.get('processingState')} "
            f"expired={expired} uploaded={battrs.get('uploadedDate')}"
        )
        for dtype in ("CRASHES", "HANGS"):
            path = (
                f"/v1/builds/{bid}/diagnosticSignatures"
                f"?filter[diagnosticType]={dtype}&limit=20"
            )
            st, body = request_json(token, path, accept=ACCEPT_DIAG)
            if st == 404:
                print(f"  {dtype} → 404 (none / not ready)")
                continue
            if st != 200:
                print(f"  {dtype} → {st} {errors_summary(body)}")
                continue
            sigs = body.get("data") or []
            print(f"  {dtype}: {len(sigs)} signatures")
            for sig in sigs:
                sa = sig.get("attributes") or {}
                row = {
                    "build": version,
                    "buildId": bid,
                    "type": sa.get("diagnosticType") or dtype,
                    "signature": sa.get("signature"),
                    "weight": sa.get("weight"),
                    "id": sig.get("id"),
                }
                crash_rows.append(row)
                print(
                    f"    w={sa.get('weight')}  {sa.get('signature')}"
                )

    summary_path = os.environ.get("ASC_SUMMARY_PATH", "asc-diagnostics-summary.json")
    with open(summary_path, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "appId": app_id,
                "bundleId": BUNDLE_ID,
                "signatureCount": len(crash_rows),
                "signatures": crash_rows,
            },
            fh,
            indent=2,
        )
        fh.write("\n")
    print(f"Wrote {summary_path} ({len(crash_rows)} signatures, no stack traces)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
