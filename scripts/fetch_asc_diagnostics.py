#!/usr/bin/env python3
"""Pull App Store Connect crash signatures + analytics access check.

Auth: APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, APPSTORE_PRIVATE_KEY
Does not print the key or JWT. Full diagnostic logs stay off stdout.
"""
from __future__ import annotations

import csv
import gzip
import io
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


def is_priority_report(name: str) -> bool:
    n = (name or "").lower()
    if n.startswith("app crashes"):
        return True
    return any(
        key in n
        for key in (
            "app downloads standard",
            "app downloads detailed",
            "app sessions standard",
            "app store installation and deletion",
            "app store discovery and engagement",
        )
    )


def download_presigned(url: str) -> bytes:
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()


def csv_preview(raw_gz: bytes) -> dict[str, Any]:
    try:
        text = gzip.decompress(raw_gz).decode("utf-8", errors="replace")
    except OSError:
        text = raw_gz.decode("utf-8", errors="replace")
    sample = text[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",\t")
    except csv.Error:
        dialect = csv.excel
    reader = csv.DictReader(io.StringIO(text), dialect=dialect)
    headers = reader.fieldnames or []
    rows = list(reader)
    numeric: dict[str, float] = {}
    for col in headers:
        total = 0.0
        ok = 0
        for row in rows:
            val = (row.get(col) or "").replace(",", "").strip()
            try:
                total += float(val)
                ok += 1
            except ValueError:
                pass
        if ok and ok >= max(1, len(rows) // 4):
            numeric[col] = total
    return {
        "headers": headers[:24],
        "rowCount": len(rows),
        "numericSums": {k: round(v, 2) for k, v in list(numeric.items())[:12]},
    }


def instance_preview(token: str, instance_id: str) -> dict[str, Any]:
    segs = paged(token, f"/v1/analyticsReportInstances/{instance_id}/segments?limit=20")
    previews = []
    for seg in segs[:3]:
        url = (seg.get("attributes") or {}).get("url")
        if not url:
            continue
        blob = download_presigned(url)
        previews.append(csv_preview(blob))
    return {"segmentCount": len(segs), "previews": previews}


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
        ("builds", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10"),
        ("betaFeedbackCrashSubmissions", f"/v1/apps/{app_id}/betaFeedbackCrashSubmissions?limit=1"),
    ]
    st, body = request_json(
        token,
        f"/v1/apps/{app_id}/perfPowerMetrics?filter[platform]=IOS",
        accept=ACCEPT_DIAG,
    )
    extra = f" · {errors_summary(body)}" if st != 200 else f" · {len(body.get('data') or [])} items"
    print(f"PROBE perfPowerMetrics → {st}{extra}")
    for name, path in probes:
        st, body = request_json(token, path)
        extra = ""
        if st == 200:
            extra = f" · {len(body.get('data') or [])} items"
        else:
            extra = f" · {errors_summary(body)}"
        print(f"PROBE {name} → {st}{extra}")

    # Analytics snapshot: create once. Reports usually populate in 24–48h.
    st, existing = request_json(token, f"/v1/apps/{app_id}/analyticsReportRequests?limit=10")
    has_snapshot = False
    if st == 200:
        for item in existing.get("data") or []:
            if (item.get("attributes") or {}).get("accessType") == "ONE_TIME_SNAPSHOT":
                has_snapshot = True
                break
    if not has_snapshot:
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
        st, existing = request_json(token, f"/v1/apps/{app_id}/analyticsReportRequests?limit=10")
    else:
        print("ONE_TIME_SNAPSHOT already exists — not creating another")

    report_summaries: list[dict[str, Any]] = []
    if st == 200:
        for item in existing.get("data") or []:
            a = item.get("attributes") or {}
            print(
                f"  existing request {item.get('id')} access={a.get('accessType')} "
                f"stopped={a.get('stoppedDueToInactivity')}"
            )
            try:
                reports = paged(token, f"/v1/analyticsReportRequests/{item.get('id')}/reports?limit=200")
            except RuntimeError as exc:
                print(f"    reports → {exc}")
                continue
            interesting = []
            for report in reports:
                ra = report.get("attributes") or {}
                name = ra.get("name") or ""
                if is_priority_report(name):
                    interesting.append((report.get("id"), name, ra.get("category") or ""))
            print(f"    {len(reports)} reports · {len(interesting)} priority")
            for rid, name, cat in interesting:
                print(f"    • {name} [{cat}]")
                try:
                    instances = paged(
                        token,
                        f"/v1/analyticsReports/{rid}/instances?limit=10",
                    )
                except RuntimeError as exc:
                    print(f"      instances → {exc}")
                    continue
                print(f"      {len(instances)} instances")
                entry: dict[str, Any] = {
                    "name": name,
                    "category": cat,
                    "instanceCount": len(instances),
                }
                for inst in instances[:1]:
                    ia = inst.get("attributes") or {}
                    print(
                        f"      instance {inst.get('id')} granularity={ia.get('granularity')} "
                        f"processing={ia.get('processingDate')}"
                    )
                    try:
                        entry["csv"] = instance_preview(token, inst.get("id"))
                        for prev in (entry["csv"].get("previews") or []):
                            print(
                                f"      csv rows={prev.get('rowCount')} "
                                f"headers={','.join(prev.get('headers') or [])[:180]}"
                            )
                            if prev.get("numericSums"):
                                print(f"      sums={prev.get('numericSums')}")
                    except Exception as exc:  # noqa: BLE001
                        print(f"      csv → {exc}")
                report_summaries.append(entry)

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
        for dtype in ("LAUNCHES", "HANGS", "DISK_WRITES"):
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

    instance_total = sum(int(r.get("instanceCount") or 0) for r in report_summaries)
    ready = instance_total > 0
    summary_path = os.environ.get("ASC_SUMMARY_PATH", "asc-diagnostics-summary.json")
    payload = {
        "appId": app_id,
        "bundleId": BUNDLE_ID,
        "ready": ready,
        "instanceTotal": instance_total,
        "reports": report_summaries,
        "signatureCount": len(crash_rows),
        "signatures": crash_rows,
    }
    with open(summary_path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
        fh.write("\n")
    print(f"ASC_READY={'1' if ready else '0'} instances={instance_total}")
    print(f"Wrote {summary_path} ({len(crash_rows)} signatures, {len(report_summaries)} reports)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
