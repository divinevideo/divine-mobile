# Store release notes

Goal: automatically write useful, on-brand TestFlight, App Store and Google Play
notes since the actual previous numbered production release.

The user requested KISS. One Lunaroute request rewrites the complete first-parent
app changelog. A single shortening retry is allowed if validation fails. Code
checks exact source/platform, required locales, blank text, copied English and
store limits, then retains the completed bundle in the private ledger.

Google Play gets all 23 shipped languages, at most 500 Unicode characters each.
Apple gets its configured languages, at most 4000 characters each. TestFlight
asks ordinary people to try ordinary actions. Store copy describes benefits.
No model credential goes to Codemagic; it stays in protected GitHub Actions.

Native builds and later promotions consume the same source-bound bundle.
Android deferred uploads keep their original notes. Generation and identity
failures occur before store-operation journaling; real ambiguous store failures
keep the existing hold/reconciliation behavior.

Do not submit iOS 1.0.30+916 to the App Store. The existing TestFlight-only mode
and explicit build exclusion remain until a corrected replacement is verified.

Validation: source binding, complete language coverage, store limits, original
baseline retention, retry identity, preparation failures and actual store errors.
Run the full configuration suite and affected analysis, inspect normal CI, and
complete independent code review before delivery. Existing release cadence,
exposure, approval, rejection and livestream/patch holds remain.
