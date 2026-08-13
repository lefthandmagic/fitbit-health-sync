# Fitbit Health Sync

Minimal iPhone app to sync Fitbit / Google Health data into Apple Health.

**Continuity:** Google turns down the legacy Fitbit Web API in **September 2026**. This app now has a dual stack: existing Fitbit OAuth still works, then users reconnect with Google OAuth and the [Google Health API](https://developers.google.com/health). Tokens do **not** transfer — every user must re-consent.

## What this version includes

- Fitbit OAuth 2.0 (Authorization Code + PKCE) — legacy, until Sept 2026
- Google OAuth 2.0 + Google Health API (`health.googleapis.com/v4`) — new path
- Keychain token persistence + refresh flow
- HealthKit write pipeline with de-dup metadata
- Manual sync and best-effort background sync scheduling
- Metrics:
  - Body weight
  - Body fat percentage
  - Steps
  - Resting heart rate
  - Active energy
  - Sleep

## 1) Google Health API (required before September 2026)

1. Create / open a Google Cloud project: https://console.cloud.google.com
2. Enable **Google Health API**.
3. Configure the OAuth consent screen. Scopes (read-only, restricted):
   - `https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly`
   - `https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly`
   - `https://www.googleapis.com/auth/googlehealth.sleep.readonly`
4. Create an **iOS** OAuth client ID. Bundle ID: `com.praveenmurugesan.FitbitHealthSync`
5. Paste the client ID into `FitbitHealthSync/Services/GoogleHealth/GoogleHealthConfig.swift` (`clientID`).
6. Add a URL scheme in `Info.plist` equal to the **reversed** client ID  
   (`123-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123-abc`).
7. Privacy / terms are already hosted at https://lefthandmagic.github.io/fitbit-health-sync/ (GitHub Pages from `main`). Merge updates there automatically.
8. Unverified apps are capped at **100 users**. Submit OAuth verification if you need more. Google Health scopes are Restricted.

Until step 5 is done, the app keeps using the existing Fitbit client ID `239Z9K`.

## 2) Legacy Fitbit app (still used until reconnect)

In Fitbit developer settings (no new apps after deprecation):

- Redirect URI: `fitbithealthsync://oauth-callback`
- Scopes: `weight` `heartrate` `activity` `sleep`

## 3) Generate Xcode project

This repo uses `xcodegen`.

```bash
brew install xcodegen
xcodegen generate
open FitbitHealthSync.xcodeproj
```

## 4) Xcode signing and capabilities

- Set your Apple Team in Signing.
- Ensure capabilities include:
  - HealthKit
  - Background Modes (Background fetch + Background processing)

## 5) Run on physical iPhone

The Health app + background scheduling behavior should be tested on a real iPhone.

Open app -> Settings tab:

- Choose sync interval
- Select metrics

Then Home tab:

- Connect Google Health (or Fitbit until the client ID is configured)
- Existing Fitbit users see **Reconnect with Google** once the Google client ID is set

Then:

- Tap `Sync Now`
- Verify data appears in Apple Health.

## Notes

- iOS background tasks are best effort. The app schedules periodic refresh, but exact execution time is not guaranteed by iOS.
- If OAuth fails, verify the Google iOS client ID, reversed URL scheme, and (legacy) Fitbit redirect URI.

## App Store screenshots (no manual re-upload)

Keep your screenshots in this repo so they are versioned and never lost:

- `fastlane/screenshots/<locale>/...png`
- Example locale folder: `fastlane/screenshots/en-US/`

The release GitHub Action now supports screenshot upload directly to App Store Connect:

- Run workflow `iOS Release Upload`
- Keep `upload_screenshots = true`
- It will upload all PNG files under `fastlane/screenshots` and replace the current screenshots in App Store Connect

App Store metadata is also now managed in-repo:

- Promotion text is stored in `fastlane/metadata/en-US/promotional_text.txt`
- Keep `upload_store_metadata = true` in the workflow to auto-apply this text on future releases
