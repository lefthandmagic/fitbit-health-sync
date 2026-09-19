# Privacy Policy

_Last updated: 2026-09-19_

**Fit Health Sync** (App Store: **Fitbit Health Sync**) is published by **Praveen Murugesan**. This policy covers the iPhone app that copies selected Google Health (and, until sunset, Fitbit) metrics into Apple Health.

## Limited use

We access Google user data only to provide the user-facing sync features described here. We do not sell Google user data. We do not use it for advertising. We do not transfer it to third parties except as required to operate the sync the user requested (Apple Health on the same device) or as required by law. We do not allow humans to read Google user data unless the user gave us the data for support and it is necessary to debug that request, a legal obligation requires it, or we need to handle a security incident — and then only for that purpose.

## Data we access (Google Health)

After you tap Connect Google Health and grant consent, the app requests **only** these three **read-only** scopes:

| Scope | User-facing feature |
| --- | --- |
| `https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly` | Copy **steps** and **active energy** into Apple Health |
| `https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly` | Copy **body weight**, **body fat percentage**, and **resting heart rate** into Apple Health |
| `https://www.googleapis.com/auth/googlehealth.sleep.readonly` | Copy **sleep** sessions into Apple Health |

The app does **not** request write scopes, ECG, GPS/location, nutrition, profile, settings, mindfulness, logged symptoms, or reproductive-health scopes.

You choose which of the six metrics to write in Settings. If you turn a metric off, the app does not write that type to Apple Health.

## How data is used

- The iPhone reads the authorized Google Health API (`health.googleapis.com/v4`) and writes matching samples into Apple HealthKit on **this device**.
- OAuth access and refresh tokens are stored in the iOS Keychain on this device.
- We do not operate a backend that stores your health samples, Google tokens, or Google account contents.
- There is no Fit Health Sync account and no cloud login besides Google’s own OAuth screen.

## Legacy Fitbit Web API

Until Google turns the Fitbit Web API down (September 2026), an existing Fitbit connection may still read weight, heart rate, activity, and sleep via Fitbit OAuth. Those tokens cannot be migrated. You reconnect with Google. Fitbit tokens are also Keychain-only.

## Retention

- Google / Fitbit tokens remain on the device until you disconnect in the app, revoke access in your Google Account, or uninstall the app.
- Apple Health samples stay in Apple Health under your control. Deleting the app does not automatically delete Health samples; remove them in the Health app if you want them gone.
- We do not keep a server-side copy.

## Your choices

- Disconnect in the app (tokens are removed from Keychain).
- Revoke access at [Google Account permissions](https://myaccount.google.com/permissions).
- Uninstall the app at any time.
- You can refuse any scope Google lets you decline; metrics that need a refused scope will not sync.

## Security

Tokens are stored with iOS Keychain. Traffic uses HTTPS to Google. No method of storage is 100% secure.

## Children

The app is not intended for children under 13.

## Changes

We may update this policy. The date at the top is the latest version.

## Contact

Privacy questions: `lefthandmagic@gmail.com`
