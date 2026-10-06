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
