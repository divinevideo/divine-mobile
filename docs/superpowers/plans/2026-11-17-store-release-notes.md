# User-friendly store release notes implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement and verify each task.

**Goal:** Automatically publish truthful, on-brand notes since the previous numbered production release, in the languages each store needs.

**Architecture:** A protected GitHub workflow generates one immutable source-and-baseline-bound note bundle. Standard-library Python validates and retains it in the private release ledger. Native uploads and later promotions consume the bundle rather than assembling commit titles or English fallbacks.

**Tech stack:** Python unittest, LunaRoute Responses structured outputs, existing protected store-release environment and store clients.

**Spec:** This document records the user's requirements and chosen implementation interfaces.

## Global constraints

- Never submit iOS 1.0.30+916 to the App Store. Keep iOS testflight-only pending a fixed replacement and its own public exposure.
- Notes cover changes since the actual previous numbered production release per platform, never merely the previous beta.
- Divine voice: candid, human, inviting and slightly playful. Describe benefits; TestFlight asks people to try ordinary actions. No commit titles, internal implementation detail, hype or unsupported promises.
- No livestream claims or held features. Source data is untrusted; it never supplies executable instructions.
- Play requires all 23 shipped locales, each at most 500 Unicode characters. Apple locales match configured storefront/beta languages, each at most 4000 characters.
- Model credential stays in protected GitHub; no model credential enters Codemagic, artifacts or logs.
- No generic fallback, silent truncation, partial translation or notes from a different source. Existing source, CI, review, cadence and rejection controls remain.

## Interfaces

`release_train.release_notes` owns:
- `ensure_bundle(platform, source_sha, data=None, *, env, ledger) -> dict`: resolve live production baseline (normalized snapshot optional), load immutable matching bundle or generate/validate/save it.
- `notes_for(bundle, channel) -> list[dict]`: validated language/text list for `testflight`, `app_store` or `google_play`.
- `bundle_from_env(env, source_sha, platform) -> dict`: parse `RELEASE_NOTES_BUNDLE`, require exact platform/source and validated bundle.
- `validate_localizations(notes, *, limit, required=()) -> list[dict]`: reject duplicates, missing languages, blank or excessive text.
- Bundle fields: `schema=1`, `platform`, `source_sha`, `baseline={version,sha}`, `locales` (Apple configured locales, empty for Android), `testflight`, `app_store`, `google_play` (lists; irrelevant channels empty), `changes` (grounded facts, separate from public copy), `policy_sha256`.

## Review focus

- A beta retry must retain its original source/baseline notes even after a newer production version appears.
- Empty or unsupported localizations must fail before a store mutation rather than replace translated text with English.
- A model refusal, network error or oversized source inventory must never cause generic notes or consume a native build attempt.
- Production source must be mapped from real provider build identity to retained provenance, not guessed from a tag.
- Store updates cannot advertise reverted or held changes; editorial verification must inspect the final diff and reject unsupported claims.

### Task 1: Source-bound generation and validation

Files: new mobile/scripts/release_train/release_notes.py, release-notes/BRAND_VOICE.md and .github/scripts/tests/test_release_notes.py.

- [ ] Write failing tests for exact-source validation, all Play languages/limits, locale duplication, real production baseline, immutable-cache reuse and model failure.
- [ ] Run tests and verify expected failures.
- [ ] Implement inventory, structured fact extraction and editorial/localization with independent semantic verification, bounded input sizes, safe errors and create-only cache.
- [ ] Run tests and commit.

### Task 2: Provider and coordinator consumers

Files: providers.py, runner.py and their existing Python tests.

- [ ] Write failing tests showing localized notes survive beta submission, App Store submission, Play promotion and retained AAB retry.
- [ ] Replace raw commit-title/generic copy with shared bundle consumption. Prepare bundle before build attempt journaling, forward non-secret JSON only. Support beta-note updates without resubmitting beta review.
- [ ] Validate notes before mutations; preserve normal review and publication behavior.
- [ ] Run affected tests and commit through coordinating owner.

### Task 3: Manual/native consumers and workflow setup

Files: start_ios_release.py, prepare_testflight_notes.py, publish_play_bundle.py, release workflows, focused tests.

- [ ] Write failing tests for exact-source bundle forwarding/native validation, complete locales and retained artifact note identity.
- [ ] Generate in protected manual drivers before dispatch; add protected model/store environment only to GitHub; native steps validate/use JSON, never regenerate with a model.
- [ ] Preserve original bundle on deferred Android uploads and all manual input behavior.
- [ ] Run affected tests and commit through coordinating owner.

### Task 4: Delivery and live verification

- [ ] Run full configuration suite, scope analysis/checks and independent fresh-context complete-diff review. Fix findings before publishing.
- [ ] Rebase fresh main, push/open PR, ensure mapped review routing once, inspect completed CI, integrate through normal approval gates.
- [ ] Configure existing authorized credential securely in protected environment, run actual generation and inspect all locales and human-facing copy.
- [ ] Verify storefront readbacks on appropriate replacement builds. Keep 916 App Store prohibition and normal exposure rules in effect.
