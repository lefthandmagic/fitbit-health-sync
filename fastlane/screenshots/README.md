Store App Store screenshot assets here.

Expected structure:

- `fastlane/screenshots/en-US/*.png`
- `fastlane/screenshots/<other-locale>/*.png`

Current `en-US` set (Google Health shipping screens):

- `01-launch` — launch card
- `02-home-connected` — Google Health connected after a sync
- `03-home-reconnect` — Fitbit legacy user with Reconnect with Google
- `04-settings` — interval (2h/4h/8h/12h) and metrics
- `05-activity` — background status and sync log

Sizes: iPhone 6.5"/6.7"/6.9" (`1242x2688`, `1284x2778`, `1290x2796`, `1320x2868`) and iPad 12.9"/13" (`2048x2732`, `2064x2752`).

Regenerate with:

```bash
python3 scripts/generate_store_screenshots.py
```

Notes:

- Use locale folder names supported by App Store Connect (for example `en-US`).
- The release workflow uploads all PNG files from this directory.
- Upload uses `overwrite_screenshots`, so the uploaded set replaces existing screenshots for matching locales/device families.
