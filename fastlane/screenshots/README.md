Store App Store screenshot assets here.

Expected structure:

- `fastlane/screenshots/en-US/*.png`
- `fastlane/screenshots/<other-locale>/*.png`

Notes:

- Use locale folder names supported by App Store Connect (for example `en-US`).
- The release workflow uploads all PNG files from this directory.
- Upload uses `overwrite_screenshots`, so the uploaded set replaces existing screenshots for matching locales/device families.
