# Reviewer walkthrough (no local login)

The app does **not** have its own username/password. Reviewers sign in with Google.

## Install

1. TestFlight: **Fitbit Health Sync** (latest, currently **1.0.33** until a newer `iOS Release Upload` lands).
2. Or a store build once the Google Health version is submitted.

## First launch

1. Allow Health access when iOS asks (write: weight, body fat, steps, sleep, heart rate, active energy).
2. Home tab: **Connect Google Health** (Fitbit users see **Reconnect with Google**).
3. Safari/ASWebAuthenticationSession: Google account picker.
4. Consent screen: expand **Show all services**. Confirm exactly:
   - See your Google Health activity and fitness data
   - See your Google Health health metrics and measurement data
   - See your Google Health sleep data
5. Allow.
6. Back in the app, tap **Sync Now**.
7. Open **Apple Health** → Browse → confirm samples for any metric enabled in Settings.

## Settings

- Interval (background attempt; iOS decides when it runs)
- Toggles for the six metrics

## If a metric is empty

That usually means the Google account has no samples for that type, or the toggle is off — not an OAuth failure. Check the in-app Activity log.

## Test account

Preferred: reviewer uses their own Google account that already has Fitbit / Pixel Watch / Google Health data.

If T&S insists on credentials, create a Google account with some Health history, turn off extra 2-Step for the review week, and put email/password only in the reply email (not in this repo).
