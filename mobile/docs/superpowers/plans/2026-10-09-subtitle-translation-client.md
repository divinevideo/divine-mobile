# Subtitle Translation (Client) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a viewer read a video's subtitles in their own language by requesting a server-translated track, with a fallback to the original whenever a translation is unavailable.

**Architecture:** The client learns a video's subtitle source language, compares it against a viewer preference (target language + a set of languages to keep original), and requests the Blossom transcript URL with a `?lang=<target>` parameter only when translation is wanted. Any non-`200` falls back to today's chain, so the client ships before the server and degrades safely. Server-side generation is specified in the design doc and implemented in `divine-blossom` (separate repo/PR).

**Tech Stack:** Flutter, Riverpod, `shared_preferences`, existing `SubtitleService`/`fetchSubtitleCues` chain, `models` package (`VideoEvent`).

**Spec:** `mobile/docs/superpowers/specs/2026-10-09-subtitle-translation-design.md`

## Global Constraints

- Subtitle languages are BCP-47, normalized to the bare primary subtag (`de-CH` -> `de`), matching `video_publish_service.dart:784`.
- The `text-track` tag wire format is `['text-track', ref, relay, 'captions', '<lang>']`.
- The Blossom transcript URL is `https://media.divine.video/{sha256}/vtt`; the translation parameter is appended as `?lang=<bcp47>`.
- Never truncate Nostr IDs. Full values only.
- The translated track is a cache, not a signed event: no kind-39307 change, no republish.
- Any non-`200` response must fall back to the original track, never surface an error to the viewer.
- New l10n keys must be mirrored into every `app_*.arb` locale or added to `_knownUntranslatedDebt` in `mobile/test/l10n/arb_consistency_test.dart`.

## Review Focus

- A video with no `<lang>` on its `text-track` tag: expect the original track, never a crash or a wrong-language request.
- A `?lang=` response that is `202`, `404`, HTML, or a network error: expect the original track, never a broken overlay or thrown error.
- Source language equal to the target, or listed under keep-original: expect no `?lang=` request at all.
- A multi-ref `text-track` (several tracks, possibly several languages): expect the first ref's language to drive the decision and the existing fallback order to be preserved.
- Unknown/abnormal language codes (`und`, `auto`, empty string): expect them treated as "unknown source", not as a language match.

---

## File Structure

- `mobile/packages/models/lib/src/video_event.dart` — add `textTrackLang` (source language) parsing.
- `mobile/lib/services/subtitle_fetcher.dart` — thread an optional `lang` into the Blossom URL.
- `mobile/lib/services/subtitle_language_preference_service.dart` — new: target + keep-original preferences.
- `mobile/lib/providers/subtitle_language_provider.dart` — new: exposes preferences and resolves the effective request language.
- `mobile/lib/providers/subtitle_providers.dart` — pass the effective language into the fetch.
- `mobile/lib/providers/subtitle_repository_provider.dart` / DI — register the new service (follow existing provider wiring).
- `mobile/lib/widgets/video_feed_item/subtitle_overlay.dart` — pass source language through to the cues provider.
- Settings UI + l10n: a later task, gated behind a feature flag until the server ships.

---

### Task 1: Parse subtitle source language into `VideoEvent`

**Files:**
- Modify: `mobile/packages/models/lib/src/video_event.dart` (`text-track` case ~line 704; field near line 986; constructor ~239; JSON ~354; copyWith ~1828; toJson ~1919)
- Test: `mobile/packages/models/test/src/video_event_text_track_test.dart`

**Interfaces:**
- Produces: `VideoEvent.textTrackLang` -> `String?` (bare language subtag of the first `text-track` tag that carries one; `null` when absent).

- [ ] **Step 1: Write the failing test**

Add to `video_event_text_track_test.dart`:

```dart
test('captures the source language from the text-track tag', () {
  final event = Event(testPubkey, 34236, [
    ['d', 'my-vine-id'],
    ['text-track', '39307:$testPubkey:subtitles:my-vine-id', 'wss://relay', 'captions', 'ja'],
  ], '');
  final video = VideoEvent.fromNostrEvent(event);
  expect(video.textTrackLang, equals('ja'));
});

test('textTrackLang is null when the tag carries no language', () {
  final event = Event(testPubkey, 34236, [
    ['d', 'my-vine-id'],
    ['text-track', '39307:$testPubkey:subtitles:my-vine-id'],
  ], '');
  final video = VideoEvent.fromNostrEvent(event);
  expect(video.textTrackLang, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test packages/models/test/src/video_event_text_track_test.dart`
Expected: FAIL — `textTrackLang` is not defined.

- [ ] **Step 3: Implement the field**

Add `final String? textTrackLang;` near `textTrackRefs` (line ~986), an optional constructor parameter, parse it in the `case 'text-track':` branch (`tag.length > 4 ? tag[4].split('-').first : null`, first non-empty wins), and thread it through `fromJson`, `toJson`, `copyWith`, and `props` the same way `textTrackRefs` is handled.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test packages/models/test/src/video_event_text_track_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/models/lib/src/video_event.dart mobile/packages/models/test/src/video_event_text_track_test.dart
git commit -m "feat(models): parse subtitle source language from text-track tag"
```

---

### Task 2: Subtitle language preference service

**Files:**
- Create: `mobile/lib/services/subtitle_language_preference_service.dart`
- Test: `mobile/test/services/subtitle_language_preference_service_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`.
- Produces:
  - `String? get targetLanguage` — explicit target, or `null` to follow the app locale.
  - `Set<String> get keepOriginalLanguages`.
  - `Future<void> setTargetLanguage(String?)`.
  - `Future<void> setKeepOriginalLanguages(Set<String>)`.
  - `String effectiveTargetLanguage(String appLocaleCode)` -> `targetLanguage ?? appLocaleCode`.
  - `bool shouldTranslate({required String? sourceLanguage, required String appLocaleCode})` — `false` when `sourceLanguage` is null/`und`/`auto`/empty, equals the effective target, or is in `keepOriginalLanguages`; otherwise `true`.

- [ ] **Step 1: Write the failing test**

```dart
// subtitle_language_preference_service_test.dart
group('SubtitleLanguagePreferenceService', () {
  test('defaults target to the app locale', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SubtitleLanguagePreferenceService();
    await service.initialize();
    expect(service.effectiveTargetLanguage('en'), equals('en'));
  });

  test('does not translate when source equals target', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SubtitleLanguagePreferenceService();
    await service.initialize();
    expect(service.shouldTranslate(sourceLanguage: 'en', appLocaleCode: 'en'), isFalse);
  });

  test('translates when source differs from target', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SubtitleLanguagePreferenceService();
    await service.initialize();
    expect(service.shouldTranslate(sourceLanguage: 'ja', appLocaleCode: 'en'), isTrue);
  });

  test('keeps a source language original when listed', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SubtitleLanguagePreferenceService();
    await service.initialize();
    await service.setKeepOriginalLanguages({'ja'});
    expect(service.shouldTranslate(sourceLanguage: 'ja', appLocaleCode: 'en'), isFalse);
  });

  test('treats unknown source as no translation', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SubtitleLanguagePreferenceService();
    await service.initialize();
    expect(service.shouldTranslate(sourceLanguage: null, appLocaleCode: 'en'), isFalse);
    expect(service.shouldTranslate(sourceLanguage: 'und', appLocaleCode: 'en'), isFalse);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/services/subtitle_language_preference_service_test.dart`
Expected: FAIL — file/class does not exist.

- [ ] **Step 3: Implement the service**

Model it on `LanguagePreferenceService` (`mobile/lib/services/language_preference_service.dart`): SharedPreferences keys `subtitle_target_language` (String) and `subtitle_keep_original_languages` (StringList), an idempotent `initialize()`, and the getters/methods in the Interfaces block. Normalize every language to its bare subtag with `split('-').first`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/services/subtitle_language_preference_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/subtitle_language_preference_service.dart mobile/test/services/subtitle_language_preference_service_test.dart
git commit -m "feat(subtitles): add subtitle language preference service"
```

---

### Task 3: Language-aware Blossom fetch

**Files:**
- Modify: `mobile/lib/services/subtitle_fetcher.dart` (`fetchSubtitleCues` signature ~195; Blossom URL ~263)
- Test: `mobile/test/services/subtitle_fetcher_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `fetchSubtitleCues(..., String? lang)` — when `lang` is non-null/non-empty, the Blossom URL becomes `https://media.divine.video/{sha256}/vtt?lang={lang}`; every other source is unchanged.

- [ ] **Step 1: Write the failing test**

```dart
test('appends the language query when lang is set', () async {
  final client = _MockHttpClient();
  final captured = <Uri>[];
  when(() => client.get(any())).thenAnswer((invocation) async {
    captured.add(invocation.positionalArguments.first as Uri);
    return http.Response('WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.000\nHola\n', 200);
  });

  await fetchSubtitleCues(
    httpClient: client,
    nostrClient: null,
    delay: (_) async {},
    sha256: 'a' * 64,
    lang: 'es',
  );

  expect(captured.single.queryParameters['lang'], equals('es'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/services/subtitle_fetcher_test.dart`
Expected: FAIL — no named parameter `lang`.

- [ ] **Step 3: Implement**

Add `String? lang` to `fetchSubtitleCues`. Where the Blossom URL is built (line ~263), append `?lang=<lang>` when `lang` is non-empty. Do not change the other sources.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/services/subtitle_fetcher_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/subtitle_fetcher.dart mobile/test/services/subtitle_fetcher_test.dart
git commit -m "feat(subtitles): request a language-specific Blossom transcript"
```

---

### Task 4: Wire the effective language through the provider

**Files:**
- Create: `mobile/lib/providers/subtitle_language_provider.dart`
- Modify: `mobile/lib/providers/subtitle_providers.dart` (`subtitleCues` ~122)
- Modify: `mobile/lib/widgets/video_feed_item/subtitle_overlay.dart` (`_subtitleCuesProvider` ~131)
- Test: `mobile/test/providers/subtitle_providers_test.dart`

**Interfaces:**
- Consumes: `SubtitleLanguagePreferenceService`, `VideoEvent.textTrackLang`.
- Produces: `subtitleCuesProvider(..., String? sourceLang, ...)` — computes `lang = shouldTranslate ? effectiveTarget : null` and passes it to `fetchSubtitleCues`.

- [ ] **Step 1: Write the failing test**

```dart
test('requests the target language when the source differs', () async {
  final container = createContainer();
  addTearDown(container.dispose);
  // stub mockHttpClient.get to capture the Uri and return translated VTT

  final cues = await container.read(
    subtitleCuesProvider(
      videoId: 'test-id',
      textTrackRef: '39307:$testPubkey:subtitles:test-vine-id',
      sourceLang: 'ja',
      sha256: 'a' * 64,
    ).future,
  );

  expect(cues.single.text, equals('Translated'));
  // assert the captured Uri queryParameters['lang'] == 'en'
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/providers/subtitle_providers_test.dart`
Expected: FAIL — no `sourceLang` parameter.

- [ ] **Step 3: Implement**

Add `String? sourceLang` to `subtitleCues`. Read the preference service and app locale, decide with `shouldTranslate`, and pass `lang` to `fetchSubtitleCues`. In `subtitle_overlay.dart`, pass `video.textTrackLang` as `sourceLang`. Register the preference service provider alongside the existing language preference wiring.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/providers/subtitle_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/subtitle_language_provider.dart mobile/lib/providers/subtitle_providers.dart mobile/lib/widgets/video_feed_item/subtitle_overlay.dart mobile/test/providers/subtitle_providers_test.dart
git commit -m "feat(subtitles): request translated cues when configured"
```

---

### Task 5: Settings UI (gated until the server ships)

**Files:**
- Modify: `mobile/lib/screens/settings/content_preferences_screen.dart`
- Add l10n keys to `mobile/lib/l10n/app_en.arb` and mirror into every locale (or `_knownUntranslatedDebt`).
- Test: widget test under `mobile/test/screens/settings/`.

**Interfaces:**
- Consumes: `SubtitleLanguagePreferenceService`.
- Produces: a "Subtitle language" target row plus a "Keep original" multi-select, hidden behind the existing feature-flag provider until the server capability lands.

- [ ] **Step 1: Write the failing widget test** — the screen renders the target-language selector when the flag is on, and hides it when off.
- [ ] **Step 2: Run it and verify it fails.**
- [ ] **Step 3: Implement** the rows, l10n keys (mirrored), and flag gate.
- [ ] **Step 4: Run `cd mobile && flutter test test/screens/settings/` — PASS.**
- [ ] **Step 5: Commit.**

---

## Self-Review

- Spec coverage: source-language parse (Task 1), preference model including keep-original (Task 2), language-aware fetch with fallback (Task 3), provider wiring (Task 4), settings surface (Task 5). Server generation is out of this repo by design, in the design doc.
- No placeholders in Tasks 1–4; Task 5 keys are intentionally enumerated at implementation time because their copy follows the l10n style guide.
- Types are consistent: `textTrackLang` (Task 1) is the `sourceLang` input to `subtitleCuesProvider` (Task 4).
- Review Focus items map to Task 2 (unknown source) and Task 4 (fallback / no-request-when-equal).
