# Publishing suggestions

A local system-model client and validated suggestion repository for Divine's
publishing form. Apple uses Vision classifications with Foundation Models;
Android uses ML Kit Prompt image inputs. Unsupported devices use the app's
localized, human-written deck. No cloud generation or bundled model.

The caller supplies frames from the current rendered video and corrected
transcript text. `capabilities` never sends media or downloads anything.
`prepare` is an explicit user action. `cancel` invalidates native work and
repository retries. Model errors and private inputs are never logged.

Text options and hashtags are separate. Suggested wording contains no hashtags
or mentions; callers apply tags only when selected. Validation rejects empty,
malformed, duplicate, and over-limit output.

Run `flutter test --coverage` and `dart analyze` here. The app integration is
behind the internal `publishingIdeas` flag (default off), also configurable with
`--dart-define=FF_PUBLISHING_IDEAS=true`.

## Language and rollout policy

Android generation is restricted to English (including regional English locales)
for this opt-in experiment. ML Kit's device-wide status does not establish
language support; other languages return unavailable before opening the model
and use the app's localized premade deck. Apple checks both device readiness and
`SystemLanguageModel.supportsLocale`. Neither policy substitutes for evaluating
actual output on representative devices before enabling the feature.

The flag gates the UI, not plugin registration or dependency packaging. Android
builds include `com.google.mlkit:genai-prompt:1.0.0-beta4` and its transitive
libraries even when the flag is off. No model weights are bundled. A release-app
size comparison and physical-device inference evaluation remain rollout checks.

## Native verification

Android: with Java 17, Android SDK 36 and `FLUTTER_ROOT` set, run
`gradle testDebugUnitTest assembleRelease` from `android/` (Gradle 8.14.3).
The tests use a device-model seam while exercising real method handling,
status/language policy, cancellation/replies, and Android bitmap decoding.

Apple: with Xcode 26 and a Flutter SDK precached for iOS/macOS, run
`FLUTTER_ROOT=/path/to/flutter bash darwin/test_suggestions.sh`.
The executable exercises the plugin's method handling with an injected model,
plus real Vision frame decoding; the script also typechecks iOS wiring.
These tests do not claim to evaluate model output quality.
