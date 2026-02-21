# Fitbit Health Sync

Minimal iPhone app to sync Fitbit data into Apple Health.

## What this version includes

- Fitbit OAuth 2.0 (Authorization Code + PKCE)
- Keychain token persistence + refresh flow
- HealthKit write pipeline with de-dup metadata
- Manual sync and best-effort background sync scheduling
- Metrics implemented in sync engine:
  - Body weight
  - Body fat percentage
  - Steps
  - Resting heart rate
  - Active energy
  - Sleep

## 1) Create a Fitbit app

In Fitbit developer settings:

- Create an app of type `Personal` + `Client`
- Redirect URI: `fitbithealthsync://oauth-callback`
- Scopes:
  - `weight`
  - `heartrate`
  - `activity`
  - `sleep`

Copy the Fitbit Client ID.

## 2) Generate Xcode project

This repo uses `xcodegen`.

```bash
brew install xcodegen
xcodegen generate
open FitbitHealthSync.xcodeproj
```

## 3) Xcode signing and capabilities

- Set your Apple Team in Signing.
- Ensure capabilities include:
  - HealthKit
  - Background Modes (Background fetch + Background processing)

## 4) Run on physical iPhone

The Health app + background scheduling behavior should be tested on a real iPhone.

Open app -> Settings tab:

- Enter Fitbit Client ID
- Choose sync interval
- Select metrics

Then Connect tab:

- Connect Fitbit account

Then Sync tab:

- Tap `Sync Now`
- Verify data appears in Apple Health.

## Notes

- iOS background tasks are best effort. The app schedules periodic refresh, but exact execution time is not guaranteed by iOS.
- If OAuth fails, verify redirect URI and client app settings in Fitbit developer console.
