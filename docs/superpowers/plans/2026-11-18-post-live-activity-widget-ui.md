# Post Live Activity: Widget UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the iOS Live Activity's data shape and its Lock Screen and Dynamic Island presentations to the existing widget extension, fully localized and tested, with nothing that starts an activity yet.

**Architecture:** A small shared Swift module (compiled into both the Runner app and the `CameraQuickActionWidget` extension) holds the activity's `ActivityAttributes`, a pure `PostActivityDisplay` mapping from content state to what is shown, and plain SwiftUI presentation views. The extension's single `@main` widget becomes a `WidgetBundle` that adds an `ActivityConfiguration` using those views. Compiling the shared code into Runner is what lets `RunnerTests` test the mapping, render the views and check every translation.

**Tech Stack:** Swift 5, SwiftUI, WidgetKit, ActivityKit (iOS 16.2+), XCTest in `mobile/ios/RunnerTests`.

**Spec:** `docs/superpowers/specs/2026-11-18-post-live-activity-design.md`, the sections *What the person sees*, *Settle point*, *Turning it on and off*, and *Design › Mobile* (the widget extension, activity data and thumbnail parts only).

**Scope boundary:** This is the work the design allows before the staging test send. It does **not** include the native bridge that starts activities, Dart code, registration with the push service, the deep-link handler, the toggle, Stop, or the stats screen. Those are part 2. Nothing in this plan can make an activity appear for a user.

## Global Constraints

- App and extension minimum stays **iOS 16.0**. All Live Activity code is `@available(iOS 16.2, *)`, and ActivityKit is **weak-linked** (Optional) in both Runner and the extension, so 16.0 and 16.1 devices launch normally.
- The content state carries **numbers and enums only, no display strings**. It must stay well under Apple's 4 KB.
- A count of `nil` means **not known yet** and is never rendered, least of all as 0. A count of `0` is a **confirmed zero** and is shown. (The server sends `nil` for zeros before the 10-minute settle point; this UI just obeys the values.)
- Nostr identifiers (owner pubkey, event id, coordinate) are stored and used **whole**: full 64-character hex, never truncated.
- Do **not** declare `NSSupportsLiveActivitiesFrequentUpdates`. Do add `NSSupportsLiveActivities` = `YES` to `Runner/Info.plist`.
- Every new string exists in **all 18 widget localizations** (`en` plus `am ar bg de es fil fr id it ja ko nl pl pt ro sv tr`). Copy follows `brand-guidelines/TONE_OF_VOICE.md`, and translations follow `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`. The PR description flags the non-English strings for fluent review.
- Colours reuse the existing widget's brand values: `divineGreen` = rgb(39, 197, 139) and `divineDeepGreen` = rgb(0, 21, 13). The presentations must read correctly in both dark and light.
- The extension does no networking. The thumbnail is read from the app group `group.co.openvine.app` only.
- Commit messages carry no `Co-Authored-By` or session trailers. Create the review stamp before each commit (see `review-before-commit`).

## English copy (fixed by the spec)

| Key | English |
|---|---|
| `divine_post_activity_your_post` | Your post |
| `divine_post_activity_posting` | Posting… |
| `divine_post_activity_live` | Your post is live |
| `divine_post_activity_no_views_yet %@` | No views yet · live for %@ |
| `divine_post_activity_cant_find` | We can't find stats for this post |
| `divine_post_activity_first_hour` | First hour |
| `divine_post_activity_no_views_first_hour` | No views in the first hour |
| `divine_post_activity_updated %@` | Updated %@ ago |
| `divine_post_activity_first_run_note` | Live stats for your first hour · turn off in Settings |

The `%@` takes SwiftUI's self-updating relative date text. Plural accessibility labels live in `Localizable.stringsdict`: `divine_post_activity_views_count` ("%lld view" / "%lld views"), plus `divine_post_activity_likes_count` and `divine_post_activity_comments_count` in the same shape.

## Review Focus

1. **Huge counts and long translations in the compact Dynamic Island.** 1,234,567 views in German should show as a compact, locale-formatted number, not clipped digits. Pinned in Task 1 (formatting) and Task 2 (render at size).
2. **The thumbnail file is missing or not an image.** The activity shows the brand placeholder and never crashes. Pinned in Task 1.
3. **Right-to-left (Arabic).** The counts row mirrors correctly and renders without layout failure. Pinned in Task 2.
4. **Largest accessibility text size, and VoiceOver.** The presentation renders, and VoiceOver reads one combined label with correct plurals ("1 view", "2 views"). Pinned in Tasks 1 and 3.
5. **A stuck upload.** "Posting…" past its stale date shows "Updated … ago" rather than looking live. Pinned in Task 1.

---

### Task 1: Shared activity model and display mapping

**Files:**
- Create: `mobile/ios/Shared/PostLiveActivity/PostActivityAttributes.swift` (members of Runner and CameraQuickActionWidget)
- Create: `mobile/ios/Shared/PostLiveActivity/PostActivityDisplay.swift` (members of Runner and CameraQuickActionWidget)
- Create: `mobile/ios/RunnerTests/PostActivityDisplayTests.swift` (member of RunnerTests)
- Modify: `mobile/ios/Runner.xcodeproj/project.pbxproj`. Add a `Shared/PostLiveActivity` group, add target memberships, and add `ActivityKit.framework` to the Frameworks phase of Runner and CameraQuickActionWidget with `ATTRIBUTES = (Weak, )`. Edit with Xcode or the `xcodeproj` gem that CocoaPods bundles. Do not commit any helper script.

**Interfaces:**
- Produces:
  - `enum PostActivityPhase: String, Codable, Hashable { case posting, live, notFound, summary }`
  - `struct PostActivityContentState: Codable, Hashable`, a top-level type with no availability guard so tests and display logic don't need one, with `phase: PostActivityPhase`, `views: Int?`, `likes: Int?`, `comments: Int?`, `updatedAt: Date` and `showFirstRunNote: Bool`
  - `@available(iOS 16.2, *) struct PostActivityAttributes: ActivityAttributes`, with `typealias ContentState = PostActivityContentState` and stored `ownerPubkey: String`, `thumbnailFileName: String?` and `startedAt: Date`; the post's `postCoordinate` and `postEventId` are optional content-state fields, because the activity starts before the post has either
  - `enum PostActivityHeadline: Equatable { case posting, live, noViewsYet, cantFind, firstHour, noViewsFirstHour }`
  - `enum PostActivityMetric: CaseIterable { case views, likes, comments }`
  - `struct PostActivityCount: Equatable { let metric: PostActivityMetric; let value: Int }`
  - `struct PostActivityDisplay: Equatable`, with `headline`, `counts: [PostActivityCount]` (order views, likes, comments; only non-nil values), `showsFirstRunNote: Bool`, `showsUpdatedAt: Bool`, `compactCount: PostActivityCount?`, and `static func make(state: PostActivityContentState, isStale: Bool) -> PostActivityDisplay`
  - `enum PostActivityFormat { static func compact(_ value: Int, locale: Locale) -> String }`, using `value.formatted(.number.notation(.compactName).locale(locale))`
  - `enum PostActivityThumbnail { static let appGroup = "group.co.openvine.app"; static let directory = "LiveActivityThumbnails"; static func load(fileName: String?, containerURL: URL?) -> UIImage? }`, which reads `containerURL/LiveActivityThumbnails/<fileName>` and returns `nil` for a nil name or container, a missing file, or undecodable bytes. Part 2's bridge writes the file to that same path.
  - `enum PostActivityLink { static func url(postEventId: String?, postCoordinate: String?) -> URL? }`, which returns nil unless both are non-empty and otherwise returns `divine:///post-analytics/<postEventId>?coordinate=<percent-encoded coordinate>` (the handler arrives in part 2). The address rides along because an edited post's first event id no longer resolves

Mapping rules for `make` (the spec's state table):

| Phase | Counts | Headline | Shown counts |
|---|---|---|---|
| posting | any | posting | none |
| live | all nil | live | none |
| live | views, likes and comments all `0` | noViewsYet | none |
| live | otherwise | live | the non-nil ones |
| notFound | any | cantFind | none |
| summary | all three `0` | noViewsFirstHour | none |
| summary | otherwise | firstHour | the non-nil ones |

- `showsFirstRunNote` = `state.showFirstRunNote && counts.isEmpty && phase ∈ {posting, live} && headline != .noViewsYet`
- `showsUpdatedAt` = `isStale && phase ∈ {posting, live}`
- `compactCount` = the likes entry if present, else views, else comments, else `nil`

- [x] **Step 1: Write the failing tests** in `PostActivityDisplayTests`, one per row of the table plus:
  - `testLiveWithSomeNilCountsShowsOnlyKnownCounts`: views 12, likes 3, comments nil → counts `[views 12, likes 3]`, headline `.live`
  - `testConfirmedZerosAreShownAlongsideOtherCounts`: views 40, likes 0, comments 0 → all three counts, with zeros present
  - `testNilIsNeverRenderedAsZero`: views nil, likes 0, comments 0 → counts `[likes 0, comments 0]`, headline `.live` (not `.noViewsYet`)
  - `testStalePostingShowsUpdatedAt` (Review Focus 5): phase posting, `isStale: true` → `showsUpdatedAt == true`
  - `testStaleSummaryDoesNotShowUpdatedAt`
  - `testFirstRunNoteHiddenOnceCountsArrive`
  - `testCompactCountPrefersLikesThenViews`
  - `testCompactFormatsLargeCountsPerLocale` (Review Focus 1): 1_234_567 in `en_US` → "1.2M", and in `de_DE` → the locale's compact form (assert it equals `formatted(.number.notation(.compactName).locale(...))` and contains no "1234567")
  - `testThumbnailLoadReturnsNilForMissingNameFileOrBadBytes` (Review Focus 2): use a temp directory as `containerURL`, write a non-image file, and assert `nil` for all three cases, then non-nil for a real 1×1 PNG
  - `testLinkCarriesFullEventIdAndCoordinate` and `testLinkEncodesACoordinateWithAnyDTag`: the full 64-hex id is the path, and the coordinate round-trips whatever its d-tag holds
  - `testContentStateRoundTripsAndStaysSmall`: JSON-encode a state with every field set, decode it equal, and assert the encoded size is under 4096 bytes

- [x] **Step 2: Run the tests and confirm they fail** (the symbols don't exist yet)

  From `mobile/`: `flutter build ios --config-only --simulator`, then `ruby scripts/ensure_ios_swift_package_floor.rb 'ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift'`, then from `mobile/ios`: `xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=<an iPhone from xcrun simctl list>' -only-testing:RunnerTests/PostActivityDisplayTests`

  Expected: build failure naming `PostActivityDisplay`.

- [x] **Step 3: Implement the two shared files and the project changes** per the Interfaces block and the mapping table.

- [x] **Step 4: Run the same command and confirm it passes.** Then run the whole `RunnerTests` (drop the class filter) and confirm nothing else regressed.

- [x] **Step 5: Commit**

  ```bash
  git add mobile/ios/Shared mobile/ios/RunnerTests/PostActivityDisplayTests.swift mobile/ios/Runner.xcodeproj/project.pbxproj
  git commit -m "feat(ios): add the post Live Activity model and display rules"
  ```

### Task 2: Widget bundle and the four presentations (English)

**Files:**
- Create: `mobile/ios/Shared/PostLiveActivity/PostActivityViews.swift` (Runner and CameraQuickActionWidget)
- Create: `mobile/ios/CameraQuickActionWidget/PostLiveActivityWidget.swift` (CameraQuickActionWidget only)
- Create: `mobile/ios/CameraQuickActionWidget/DivineWidgetBundle.swift` (CameraQuickActionWidget only)
- Modify: `mobile/ios/CameraQuickActionWidget/CameraQuickActionWidget.swift` (remove `@main` only)
- Modify: `mobile/ios/CameraQuickActionWidget/en.lproj/Localizable.strings` (add the English copy above)
- Create: `mobile/ios/CameraQuickActionWidget/en.lproj/Localizable.stringsdict` (the three plural keys), registered as a variant group in the extension's Resources
- Modify: `mobile/ios/Runner/Info.plist` (`NSSupportsLiveActivities` = `YES`)
- Modify: `mobile/ios/Runner.xcodeproj/project.pbxproj`
- Create: `mobile/ios/RunnerTests/PostActivityViewsTests.swift`

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces:
  - `@available(iOS 16.2, *) struct PostActivityLockScreenView: View`, init `(attributes: PostActivityAttributes, display: PostActivityDisplay, state: PostActivityContentState, thumbnail: UIImage?, bundle: Bundle)`
  - `PostActivityCompactLeadingView`, `PostActivityCompactTrailingView`, `PostActivityMinimalView` and `PostActivityExpandedBottomView`, taking the same inputs, each limited to what it needs
  - `enum PostActivityStrings { static let keys: [String]; static let pluralKeys: [String] }`, the single list of every key above
  - `@available(iOS 16.2, *) struct PostLiveActivityWidget: Widget`, an `ActivityConfiguration(for: PostActivityAttributes.self)` that builds the display with `PostActivityDisplay.make(state: context.state, isStale: context.isStale)`, loads the thumbnail with `PostActivityThumbnail.load` from `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`, sets `.widgetURL(PostActivityLink.url(postEventId:postCoordinate:))` from the content state (none while the post has no identity), and passes `Bundle.main` as `bundle`
  - `@main struct DivineWidgetBundle: WidgetBundle`, whose body is `CameraQuickActionWidget()` then `if #available(iOS 16.2, *) { PostLiveActivityWidget() }`

Layout rules (the visual design itself is left to the builder, within these):
- **Lock Screen:** thumbnail at left; headline on top, the counts row or note beneath, and relative "time since posting" via `Text(attributes.startedAt, style: .relative)`. When `showsUpdatedAt`, replace the time with the "Updated %@ ago" line, using `Text(state.updatedAt, style: .relative)`.
- **Dynamic Island compact:** thumbnail leading; `compactCount` trailing, or nothing when it is nil. **Minimal:** thumbnail only. **Expanded:** thumbnail leading, headline centre, counts row bottom.
- Counts render as SF Symbol and compact number pairs (`play.fill` for views, `heart.fill` for likes, `bubble.right.fill` for comments). Text uses `lineLimit(1)` and `minimumScaleFactor`.
- Each presentation exposes **one combined VoiceOver label**: the headline, then the counts read with the plural keys. Icons are hidden from accessibility.
- A missing thumbnail shows a `divineGreen` rounded square with `play.rectangle.fill`.

- [x] **Step 1: Write the failing tests** in `PostActivityViewsTests`. Render each view with `ImageRenderer`, using the **embedded extension bundle** as `bundle`: `Bundle(url: Bundle.main.builtInPlugInsURL!.appendingPathComponent("CameraQuickActionWidget.appex"))`.
  - `testLockScreenRendersEveryHeadlineInDarkAndLight`: for each `PostActivityHeadline`, in both colour schemes, `ImageRenderer(...).uiImage` is non-nil with a non-zero size
  - `testCompactTrailingFitsWithLargeGermanCount` (Review Focus 1): locale `de_DE`, likes 1_234_567, rendered width ≤ 64 pt
  - `testLockScreenRendersRightToLeft` (Review Focus 3): `\.layoutDirection = .rightToLeft` with `ar` resolves a non-nil image
  - `testLockScreenRendersAtAccessibilityTextSize` (Review Focus 4, layout half): `\.dynamicTypeSize = .accessibility3` resolves a non-nil image
  - `testEveryKeyResolvesInEnglish`: each of `PostActivityStrings.keys` resolves in the extension bundle's `en` table to a value that is not the key itself
  - `testBundleRegistersLiveActivityWidget`: `Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool == true`

- [x] **Step 2: Run** `-only-testing:RunnerTests/PostActivityViewsTests` (same command as Task 1) **and confirm it fails.**

- [x] **Step 3: Implement the files and the project edits.** Then build the extension on its own: `xcodebuild build -workspace Runner.xcworkspace -scheme Runner -destination 'generic/platform=iOS Simulator'`. Expected: `** BUILD SUCCEEDED **`, and the camera widget is still listed in the widget gallery on the simulator.

- [x] **Step 4: Run the class, then the full `RunnerTests`, and confirm both pass.**

- [x] **Step 5: Commit**

  ```bash
  git add mobile/ios/Shared mobile/ios/CameraQuickActionWidget mobile/ios/Runner/Info.plist mobile/ios/RunnerTests/PostActivityViewsTests.swift mobile/ios/Runner.xcodeproj/project.pbxproj
  git commit -m "feat(ios): add the post Live Activity Lock Screen and Dynamic Island views"
  ```

### Task 3: Translations for the 17 other widget locales

**Files:**
- Modify: `mobile/ios/CameraQuickActionWidget/<locale>.lproj/Localizable.strings` for `am ar bg de es fil fr id it ja ko nl pl pt ro sv tr`
- Create: `mobile/ios/CameraQuickActionWidget/<locale>.lproj/Localizable.stringsdict` for the same 17, with each language's real plural categories (for example `zero/one/two/few/many/other` in Arabic, `one/few/many/other` in Polish, `other` only in Japanese and Korean)
- Modify: `mobile/ios/Runner.xcodeproj/project.pbxproj` (add the 17 stringsdict variants)
- Modify: `mobile/ios/RunnerTests/PostActivityViewsTests.swift`

**Interfaces:**
- Consumes: `PostActivityStrings.keys` and `pluralKeys` from Task 2.

- [x] **Step 1: Write the failing tests**
  - `testEveryKeyExistsInEveryWidgetLocale`: for each `.lproj` in the extension bundle, its `Localizable.strings` contains every `PostActivityStrings.keys` entry, and its `Localizable.stringsdict` contains every `pluralKeys` entry. Fail with the locale and the missing key. The widget's text files have no other guard; this test becomes it.
  - `testPluralsReadCorrectlyInEnglish` (Review Focus 4, VoiceOver half): with `en`, the views key formats 1 as "1 view" and 2 as "2 views"
  - `testPlaceholdersSurviveTranslation`: in every locale, each `%@` key's value still contains exactly one `%@`

- [x] **Step 2: Run** `-only-testing:RunnerTests/PostActivityViewsTests` **and confirm the parity test fails**, listing the 17 locales.

- [x] **Step 3: Write the translations** in each locale's register per `LOCALIZATION_STYLE_GUIDE.md`. Keep "Divine" untranslated, keep "·" separators, and keep `%@` and `%lld` intact.

- [x] **Step 4: Run the class, then the full `RunnerTests`, and confirm both pass.**

- [x] **Step 5: Commit**

  ```bash
  git add mobile/ios/CameraQuickActionWidget mobile/ios/RunnerTests/PostActivityViewsTests.swift mobile/ios/Runner.xcodeproj/project.pbxproj
  git commit -m "feat(ios): translate the post Live Activity into the widget's 17 other languages"
  ```

## Handoff (after Task 3, not a task)

1. Rename the branch from `docs/post-live-activity-design` to `feat/post-live-activity-widget-ui`. The design doc commits stay on it, so the first PR carries the design and its first slice.
2. Rebase onto fresh `origin/main` and run the full `RunnerTests` once more.
3. Capture screenshots of each presentation in dark and light from the render tests, for the PR description.
4. Run a full review (`superpowers:requesting-code-review`) and resolve its findings.
5. **Stop and ask Matt:** draft or ready, with the review verdict, plus the **feature request draft** to file just before the PR goes up. The feature request links the design doc, carries Daniel's four questions from *For reviewers*, and states that this PR starts nothing for users. The PR description flags the non-English strings for fluent review and names Sebastian as iOS reviewer.
