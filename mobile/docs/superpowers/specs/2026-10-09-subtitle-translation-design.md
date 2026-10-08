# Subtitle translation

**Date**: 2026-10-09
**Status**: Draft for implementation planning
**Owner**: rabble
**Repos**: `divine-mobile` (client), `divine-blossom` (server)

## Problem

Videos on Divine carry WebVTT subtitles, but they are shown in the language
their creator spoke. A viewer who does not speak that language sees nothing
useful — for example, an English viewer watching a Japanese clip cannot read
what is being said. Creative work is increasingly cross-language, and the app
currently does nothing to bridge it.

Issue [#4168](https://github.com/divinevideo/divine-mobile/issues/4168) asks for
captions that follow the audience's language. This spec defines the smallest
version that delivers that.

## Goal

A viewer can read any video's subtitles in their own language. The viewer
chooses a target language and a set of source languages they want left in the
original; every other language they encounter is shown translated into their
target language. Translation happens once on the server and is cached, so the
second viewer of any given video and language gets it instantly and for free.

Success: an English speaker opens a Japanese clip and reads English subtitles;
the translation was produced once, server-side, without running new
infrastructure.

## Non-goals

- On-device / offline machine translation. (Researched and rejected for v1: no
  web path, weak Japanese→English without cross-line context, immature Flutter
  bridges. See Background.)
- LLM-based translation. At six seconds a clip has one or two cues, so there is
  almost no cross-line context for an LLM to exploit, while its per-call prompt
  overhead costs roughly 1000x a dedicated NMT API for the same text.
- A new service or repository. Translation is added inside `divine-blossom`.
- The `divine-web` client. It is a second consumer of the same server API and is
  a follow-up.
- Editing a translation, or a creator choosing which languages to publish.
- Changing the kind-39307 video-event schema. The translated track is a derived
  cache addressed by URL, not a signed Nostr event.

## Background: why server-side

Summary of the feasibility research that selected this design.

| Option | Cost / reach | Verdict |
|--------|--------------|---------|
| Apple Translation framework | iOS 18+ only, 20 langs, no web, no mature Flutter bridge | rejected |
| Google ML Kit on-device | Android+iOS only, no web, "casual" quality, English pivot | partial future tier only |
| Chrome Translator API | desktop Chrome only | useless for mobile web |
| **Server NMT API** | all platforms, one call, cacheable, shareable | **chosen** |

On-device NMT runs segment by segment with no cross-line context — the exact
weak spot for subtitles. A six-second clip has almost no context anyway, so the
quality gap that would normally favor an LLM mostly disappears; this makes a
cheap dedicated translation API the right engine rather than an LLM.

Cost: a six-second clip is roughly 60–120 characters of subtitle text. At
Google Cloud Translation v3's $20 / 1M characters, five target languages over
one million videos is roughly $10k, and the on-demand path costs nothing for
the long tail. A static top-set fan-out is therefore cheap enough to keep
simple, with popularity gating available later if volume bites.

## Current state (verified)

Server, `divine-blossom`:

- Blob storage is content-addressed by the video's `sha256`. Derived artifacts
  already hang off that key: `/{sha}.hls`, `/{sha}/720p`, `/{sha}.vtt`.
- Server ASR already runs. The edge dispatches `POST https://<transcoder>/transcribe`
  (`src/main.rs:3019`) to a Cloud Run transcoder that fronts a Parakeet ASR
  sidecar. The source transcript is stored at GCS `{hash}/vtt/main.vtt`
  (`src/main.rs:1783`) and served at `/{sha}.vtt` and `/{sha}/VTT`.
- Language is already tracked: `SubtitleJob.language`, and the detected language
  flows back on the transcript status webhook (`src/main.rs:5497`).
- The subtitle jobs API (`POST /v1/subtitles/jobs`, `GET /v1/subtitles/jobs/<id>`,
  `GET /v1/subtitles/by-hash/<sha>`) models `queued | processing | ready |
  failed` with `Retry-After` polling. The client already polls `202` today
  (`mobile/lib/services/subtitle_fetcher.dart:157`).

Client, `divine-mobile`:

- WebVTT is parsed into `SubtitleCue`s (`mobile/lib/services/subtitle_service.dart`)
  and rendered as text by `CaptionPill` (`mobile/lib/widgets/video_feed_item/subtitle_overlay.dart`).
- Fetching walks an ordered fallback chain ending at Blossom
  `https://media.divine.video/{sha256}/vtt` (`mobile/lib/services/subtitle_fetcher.dart:263`).
- The publish path already writes the subtitle language into the `text-track`
  tag (`mobile/lib/services/video_publish/video_publish_service.dart:541,746`),
  whose wire format is `['text-track', ref, relay, 'captions', '<lang>']`
  (`mobile/packages/models/lib/src/video_event.dart:706`).
- **Gap**: the reader drops that `<lang>` — `video_event.dart:704` keeps only the
  ref, so the client never learns a video's source language.
- Viewer language preferences exist but are unrelated: `LanguagePreferenceService`
  (`contentLanguage`) drives feed content, not subtitles.

## Design

Hybrid: pre-translate a small static set at ASR completion, and translate any
other requested language on demand, caching both. Engine is the Google Cloud
Translation API (NMT). Everything lives in `divine-blossom`.

### Server: storage and URLs

- Translated track is a new derived artifact at GCS `{hash}/vtt/{lang}.vtt`.
  The source stays at `{hash}/vtt/main.vtt`.
- Served at `GET /{sha}.vtt?lang=<bcp47>` and `GET /{sha}/VTT?lang=<bcp47>`.
  With no `lang`, or `lang` equal to the source language, the existing
  `main.vtt` is served unchanged — fully backward compatible.
- Cache key is `(sha256, target_lang)`. Nothing overwrites the hashed blob, so
  the content-addressable immutability rule is untouched.

### Server: generation

- **Fan-out.** When ASR completes for a blob (the status webhook path,
  `src/main.rs:5491`), the source language is known. Enqueue one translation job
  per language in a static config list (`subtitle_translate_targets` in the
  Blossom config store), skipping the source language and skipping any language
  already present.
- **On demand.** A `?lang=` request whose artifact is missing creates the same
  translation job and returns `202` with `Retry-After`, reusing the existing
  polling contract.
- **Job model.** Introduce a translation job record keyed by `(sha256,
  target_lang)` that mirrors `SubtitleJob`'s status machine, retry/backoff, and
  idempotent reuse. `GET /v1/subtitles/jobs` and `/by-hash` gain an optional
  `lang` to select the translation job; absent, they behave as today.
- **Worker.** The Cloud Run subtitle pipeline service already behind
  `CLOUD_RUN_TRANSCODER_HOST` (the one that fronts `/transcribe` and holds the
  webhook contract) gains a translate step: read `main.vtt`, call the
  translation API with the cue texts, write `{lang}.vtt` with identical timing
  and translated text only, then report status on the existing webhook. No new
  repository and no new deployable.
- **Config.** Target-language list and the translation API credential live in
  the existing Blossom config/secret stores (or Cloud Run Secret Manager for the
  worker). Languages are BCP-47, normalized to the bare primary subtag the same
  way publish does (`video_publish_service.dart:784`).

### Protocol consequence

Because the translated track is addressed by a language-parameterized URL,
multi-language no longer collides with the single kind-39307 `d` tag
(`subtitles:<vineId>`, `src/main.rs:943`). No event schema change and no
per-language video republish. The translated artifact is the same trust class as
the ASR transcript it derives from.

### Client

1. **Parse the source language.** Keep the `<lang>` element of the `text-track`
   tag in `VideoEvent` (fix `video_event.dart:704`), exposed as a new field such
   as `textTrackLang`. This is the source language the viewer decides against.
2. **New viewer preference.** Target language (default: app locale) plus a set
   of "keep original" source languages. Stored via a preferences service next to
   `LanguagePreferenceService`, surfaced in Content preferences settings.
3. **Fetch.** If the video's source language is in the keep-original set, or
   equals the target, fetch as today. Otherwise request `?lang=<target>` through
   the existing chain; on any non-`200` (including `202` that never settles),
   fall back to the original track. Overlay code is unchanged — same cues,
   different text.
4. **Availability.** No server dependency is required to ship: an old server
   ignores `?lang=`, and the client already falls back to the original track.

### Consent

Translation is default-on because it is accessibility, not generated content.
A creator opt-out is a documented follow-up, not part of this change.

## Open constraint

Server-side fan-out only knows a language for videos with a **server-generated**
transcript (ASR sets `SubtitleJob.language`). Videos whose creator authored
subtitles by hand and have no server ASR carry a `<lang>` only in the Nostr tag,
which Blossom does not read. Those videos are served by the on-demand path — the
client requests `?lang=<target>` explicitly — and fall back to the original if
the server cannot determine the source. This is acceptable for v1 and is called
out here so it is not mistaken for a bug.

## Components

Server (`divine-blossom`):

- `src/main.rs`: parse `?lang=` on the VTT routes; translation job create/lookup;
  dispatch; fan-out trigger on transcript completion.
- `src/metadata.rs`: translation job record + `(sha, lang)` index.
- `src/storage.rs`: `{hash}/vtt/{lang}.vtt` read/write.
- Cloud Run subtitle pipeline: translate step + translation API client.
- Config/secret: target list + API credential.

Client (`divine-mobile`):

- `mobile/packages/models/lib/src/video_event.dart`: source-language field.
- `mobile/lib/services/subtitle_fetcher.dart` + `mobile/lib/providers/subtitle_providers.dart`:
  language-aware fetch.
- New subtitle-language preference service + cubit, and its settings screen entry.
- l10n keys for the new setting.

## Error handling

- Translation API failure: job follows the existing retry/backoff then terminal
  failure; the viewer silently keeps the original track.
- Unknown/undetectable source language: skip fan-out; on-demand requests still
  attempt translation, and fall back to the original on failure.
- Empty transcript: no translation job is created.
- A translated track with mismatched cue timing must never be served; the worker
  writes timings verbatim from `main.vtt` and a validation check rejects a
  mismatch.

## Testing

Server:

- VTT route parses `?lang=`; unknown language returns `202` then serves once
  written; source language returns `main.vtt`.
- Fan-out enqueues the configured targets, skips the source and existing
  artifacts.
- Translation job reuse/idempotency and backoff behavior.
- Translation API client maps cue text in and preserves timing out (mocked API).

Client:

- `text-track` tag source language is parsed.
- Provider requests `?lang=` only when source differs from target and is not in
  the keep-original set; falls back to original on non-`200`.
- Preference cubit persists and applies.

## Rollout

Server first and fully backward compatible (no `lang` → current behavior). Client
behind the fallback so it can ship before or after the server. Web client is a
follow-up.
