# Ship Google Health to the App Store (issue #3)

Live listing is still Fitbit-era. Binary with Google Health is on TestFlight **1.0.33** (14 Aug). Workflow **iOS Release Upload** uploads TestFlight + optional metadata; it **does not create** an App Store version.

## In App Store Connect (you)

1. Fitbit Health Sync → **+ version** (1.0.x, same marketing train).
2. Do **not** run `upload_store_metadata` / `upload_screenshots` against `--use_live_version` until this new version exists (issue #2 / #3).
3. After the version is editable, either:
   - dispatch **iOS Release Upload** with screenshots + metadata, or
   - paste `fastlane/metadata/en-US/*` by hand and attach `fastlane/screenshots`.
4. Privacy URL must match Cloud Console (custom domain once live).
5. Submit for review. What’s new: already in `release_notes.txt` (Google Health + reconnect before Fitbit sunset).

## Luna / CI

- `gh workflow run "iOS Release Upload"` from `main` after you say so (new TestFlight if you want a build newer than 33).
- Creating the ASC version is a browser click. I will not submit the store version without your OK.

## After submit

- Close issue #3 when Apple is Waiting for Review / Ready for Sale.
- Store copy already says Google Health. Swap live only with this binary.
