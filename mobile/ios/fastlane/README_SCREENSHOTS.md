# App Store screenshot pipeline

Automated, caption-overlaid App Store screenshots for Divine. One command
captures the required iPhone screenshot sizes and composites the marketing
captions on top.

## How to run

```bash
# 1. Generate the Xcode config with SCREENSHOT_MODE (from mobile/, normal shell —
#    running flutter from inside fastlane breaks SPM resolution).
cd mobile
flutter build ios --simulator --debug --config-only --dart-define=SCREENSHOT_MODE=true

# 2. Capture + frame.
cd ios
bundle install          # first time only
bundle exec fastlane screenshots
```

Framing (brand canvas + caption + rounded screenshot) is done by
`fastlane/frame_screenshots.py`, run via `fastlane/frame.sh`, which
bootstraps a local Python venv with Pillow on first run — **no manual
ImageMagick / pip step**. To re-frame existing captures without
recapturing (e.g. after editing caption copy), run
`bundle exec fastlane frame`.

The `screenshots` lane verifies step 1 ran (it checks `Generated.xcconfig`
for the `SCREENSHOT_MODE` define) and fails fast with instructions if not.
The `DivineUITests` scheme uses the `Debug-DivineUITests` build configuration,
which is also the Flutter asset flavor that bundles the screenshot-only videos
and thumbnails.

A flavorless `flutter run --dart-define=SCREENSHOT_MODE=true` does not bundle
those fixtures. For manual screenshot-mode debugging, select the
`DivineUITests` scheme in Xcode so the app is built with its fixture flavor.

Output lands in `mobile/ios/fastlane/screenshots/<locale>/` - raw captures
as `<device>-<name>.png`, framed + captioned versions as
`*_framed.png`. The exported framed set is controlled by `SLIDES` in
`frame_screenshots.py`: eight captured screens plus the generated
`09_endcard` brand card. Nothing is ever uploaded; the `upload_screenshots`
lane is deliberately disabled.

Partial runs while iterating:

```bash
bundle exec fastlane capture   # capture only, skip framing
bundle exec fastlane frame     # re-frame existing captures (fast)
```

## How it works

- Before running fastlane, generate the Flutter Xcode config with
  `--dart-define=SCREENSHOT_MODE=true`. That flag (see
  `lib/config/screenshot_mode.dart`) is compile-time false outside debug
  builds; the Fastfile verifies the define is present before capture, and
  no screenshot affordance ships in Release.
- The `Debug-DivineUITests` configuration lets Flutter infer the
  `DivineUITests` asset flavor from the scheme build. Production and ordinary
  debug builds therefore omit the screenshot-only videos and thumbnails.
- On launch, screenshot mode creates a **throwaway Nostr account**
  (fresh key, terms auto-accepted) and follows a fixed set of well-known
  creators (see `ScreenshotModeService.creatorPubkeysHex`) so the share
  sheet and feeds have real content. The account persists on the
  simulator between runs.
- Screenshot mode also overrides `topClassicVinersProvider` and
  `discoveredListsProvider` with deterministic fixtures so the classics row
  and list-discovery capture do not depend on live relay ordering or
  avatar-less public profiles.
- `ios/DivineUITests/DivineScreenshots.swift` launches the app once per
  screen with `SCREENSHOT_INITIAL_ROUTE` in the launch environment; the
  screenshot startup hook reads that value from `SharedPreferences` and
  drives the router after first-frame startup. Each screen has an
  accessibility identifier from `lib/constants/semantic_ids.dart`; a few
  captures also use bounded sleeps where native media/image loading has no
  reliable accessibility signal.
- The camera preview is a bundled still (simulators have no camera); the
  editor timeline is seeded from bundled clips when
  `SCREENSHOT_SEED_CLIPS=1` is in the launch environment.
- `snapshot` overrides the status bar (9:41, full signal/battery) via
  `override_status_bar` in the `Snapfile`. The same scheme contains
  recording-only `testRec*` methods for App Store preview video B-roll; those
  are skipped by the scheme during regular `snapshot` runs and should be run
  one at a time with Xcode's `-only-testing` while `simctl io recordVideo`
  records the simulator.
- `frame_screenshots.py` composites the dark-green brand canvas
  (`#00150D`), the caption in Bricolage Grotesque - headline in brand
  green `#27C58B` (from `<locale>/keyword.strings`), subhead in white
  (from `<locale>/title.strings`) — and the rounded device capture below.
  `03_creator_post` intentionally has no subhead entry; the creator's
  on-video caption carries extra context. The generated `09_endcard` uses the
  official white wordmark from `fastlane/endcard_assets/`.

## How to change caption copy

Edit `fastlane/screenshots/<locale>/keyword.strings` (headline) and
`title.strings` (subhead), keyed by screenshot name:

```
"04_capture" = "Press record. Make something weird";
```

Then re-run `bundle exec fastlane frame`. Check legibility at thumbnail
size: `sips -Z 200 <framed>.png --out /tmp/thumb.png` and eyeball it.

## How to add a locale

1. Add the locale to `languages([...])` in `fastlane/Snapfile`
   (e.g. `"fr-FR"`, `"de-DE"`, `"pl"`, `"fil"`).
2. Create `fastlane/screenshots/<locale>/keyword.strings` and
   `title.strings` with translated captions.
3. Re-run `bundle exec fastlane screenshots`. snapshot passes the locale
   to the app, which already ships these translations.

## How to add a new screen

1. Give the target widget a stable identifier: add a constant to
   `lib/constants/semantic_ids.dart` and wrap the widget in
   `Semantics(identifier: SemanticIds.yourThing, ...)`.
2. Add a `testNN...` method to
   `ios/DivineUITests/DivineScreenshots.swift`: launch with the route,
   `waitFor(...)` the identifier, then `snapshot("NN_name")`.
3. Add the export entry to `SLIDES` in `frame_screenshots.py`.
4. Add caption entries to `keyword.strings` / `title.strings` in every
   locale directory. Every exported slide must have a headline; framing fails
   if a required capture or headline is missing.

## Pinned content (change when needed)

Constants at the top of `DivineScreenshots.swift`:

- `creatorPostVideoId` — Lele Pons' "VINE IS BACK!" event id (03).
- `verifiedVideoId` — a video whose About sheet shows the Human-Made
  badge and all four verification checks (02).
- `profileNpub` — the profile captured for 07.

## Environment / credentials

None required for capture. The throwaway account is generated at runtime
and never leaves the simulator; no nsec or App Store Connect key is read
or stored. If `upload_screenshots` is ever enabled, provide an App Store
Connect API key via `APP_STORE_CONNECT_API_KEY_*` env vars — never commit
credentials.

## Notes

- Content screens (02, 03, 07) render live production data -
  loop counts and thumbnails will differ between runs; the framing is
  deterministic.
- Both simulators (`iPhone 16 Pro Max`, `iPhone 11 Pro Max`) must exist;
  create them with `xcrun simctl create` if `snapshot` reports a missing
  device.
