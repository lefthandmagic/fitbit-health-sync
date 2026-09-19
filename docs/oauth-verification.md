# Google OAuth verification pack

Status as of **19 Sep 2026**. Fitbit Web API hard sunset: **30 Sep 2026**. Google’s 14 Aug mail is still unanswered. Unverified OAuth is capped at ~100 users; the App Store already had an 11K-download day.

Code on `main` already requests exactly these scopes (do not add more in Cloud Console):

```
https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly
https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly
https://www.googleapis.com/auth/googlehealth.sleep.readonly
```

Client ID (iOS): `547556030049-csoh2cpvu82k3ub8b0gie0gk2k7mhhgc.apps.googleusercontent.com`  
Bundle ID: `com.praveenmurugesan.FitbitHealthSync`

## Cloud Console — paste these

**Application name:** `Fit Health Sync by Praveen Murugesan`  
(Unique brand. Do not leave a generic “Health Sync” / “Fitbit” only name.)

**User support email / developer contact:** `lefthandmagic@gmail.com`

**Authorized domains:** the **top private domain you verify** in Search Console (see `custom-domain.md`). Not `github.io`.

**Homepage / Privacy / Terms** — same host, after the custom domain is live:

- Homepage: `https://<your-domain>/`
- Privacy: `https://<your-domain>/privacy`
- Terms: `https://<your-domain>/terms`

Until DNS is attached, GitHub Pages is still `https://lefthandmagic.github.io/fitbit-health-sync/` — Google already rejected that host.

## Scope justifications (paste per scope)

### `googlehealth.activity_and_fitness.readonly`

The iPhone app’s Home screen lets the user tap Sync Now (or wait for background sync). That action reads Google Health activity-and-fitness data and writes **steps** and **active energy** into Apple Health on the same device. The app is a client-only HealthKit writer. There is no server that stores these samples. A narrower scope does not exist: Google Health does not offer a steps-only or active-energy-only OAuth scope. Write scopes are not requested because the app never writes back to Google Health.

### `googlehealth.health_metrics_and_measurements.readonly`

The same Sync Now / background path reads Google Health measurements and writes **body weight**, **body fat percentage**, and **resting heart rate** into Apple Health. Settings lets the user turn each metric off. No write / ECG / IRN / profile scopes are requested. No narrower read scope covers only these three measurements.

### `googlehealth.sleep.readonly`

The same path reads Google Health sleep sessions and writes them into Apple Health sleep samples. Sleep is a separate Google Health scope; activity-and-fitness does not include sleep. The app does not request `sleep.writeonly`.

## Files in this folder

| File | Use |
| --- | --- |
| `oauth-reply-draft.md` | Paste-reply to the 14 Aug Trust & Safety thread |
| `oauth-reviewer-walkthrough.md` | Click-path + test-account note (no local login) |
| `oauth-demo-script.md` | Reshoot list if the Aug 14 YouTube video is stale |
| `custom-domain.md` | DNS so homepage leaves github.io |
| `casa-al1.md` | CASA AL1 — due **12 Nov 2026** |
| `app-store-ship.md` | Create editable version, then submit |
| `soak-checklist.md` | Issue #1 device soak |

## Order

1. Attach a domain you own + Search Console **domain** verification (same Google account as the Cloud project owner).
2. Update Cloud Console branding + Data Access (exact three scopes) + justifications.
3. Confirm the in-app consent screen lists those three scopes (Show all services).
4. Reply with `oauth-reply-draft.md` + current demo video.
5. Create App Store version and submit the Google Health binary (`app-store-ship.md`).
6. Soak in parallel (`soak-checklist.md`).
7. CASA when T&S already required it — start lab contact now (`casa-al1.md`).
