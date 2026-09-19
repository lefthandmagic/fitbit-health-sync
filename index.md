# Fit Health Sync

**Fit Health Sync** (App Store: **Fitbit Health Sync**) is an iPhone app by **Praveen Murugesan** (Left Hand Magic). It copies selected Google Health metrics into Apple Health on this device.

This page is the public homepage for the app. There is no account with us and no login wall.

## What the app does

1. You tap **Connect Google Health** in the app.
2. Google’s consent screen asks for three **read-only** Google Health scopes (activity, measurements, sleep).
3. The app reads only the metrics you enabled: body weight, body fat percentage, steps, sleep, resting heart rate, and active energy.
4. It writes those samples into **Apple Health** on the same iPhone, with de-dup metadata.
5. You can tap **Sync Now**, or leave best-effort background sync on. Tokens stay in the iOS Keychain. Health samples are not uploaded to our servers — we do not operate a health-data backend.

Existing Fitbit Web API logins still work until Google turns that API down (**30 September 2026**). Those tokens cannot be transferred. Reconnect with Google before then.

## Why these Google permissions

The app only requests the three read-only scopes that cover those six metrics. It does not request write, ECG, location, nutrition, profile, or reproductive-health scopes. See the [privacy policy](./privacy) for the exact scope strings and limited-use commitments.

## Links

- [Privacy Policy](./privacy)
- [Terms of Service](./terms)
- [Organization](./organization)
- App Store: search **Fitbit Health Sync**

## Contact

Developer: **Praveen Murugesan**  
Email: `lefthandmagic@gmail.com`
