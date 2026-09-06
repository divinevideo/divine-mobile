# Network performance monitoring

What the Firebase console's **Network Requests** tab covers, what it deliberately
does not, and how to keep it that way. Issue: #7122.

Feed-load timing that includes relay WebSocket milestones is reported
separately through custom traces. See
[Feed-load performance traces](FEED_LOAD_TRACES.md) before interpreting those
durations or their `event_count` metric.

## Why anything had to be built

Firebase Performance auto-instruments network traffic by swizzling the *native*
HTTP stacks. Requests the app issues from Dart never touch those, so they were
invisible: the export had **zero** `NETWORK_REQUEST` events on Android, and on
iOS 24,843 events of which essentially all were Apple and Google SDK telemetry
(`app-analytics-services.com`, `app-ads-services.com`,
`firebase-settings.crashlytics.com`, …). The only Divine host present was
`media.divine.video` with 414 events — native video-player traffic, not
anything Dart sent. Relay latency, feed query latency, CDN behaviour and upload
transport were all absent from a tab that looked like it covered them.

`HttpMetric` is the API that fixes this, and it has to be driven explicitly.

## How it works

One decorator at the client boundary, not per call site:

| Piece | File |
|---|---|
| `PerformanceHttpClient` — `http.BaseClient` that opens one metric per request | `lib/observability/network/performance_http_client.dart` |
| `HttpMetricRecorder` / `HttpMetricSpan` — backend-agnostic port | `lib/observability/network/http_metric_recorder.dart` |
| `FirebaseHttpMetricRecorder` — the Firebase implementation | `lib/observability/network/firebase_http_metric_recorder.dart` |
| `httpMetricUrlPattern` / `isInstrumentedHost` — reported-URL policy | `lib/observability/network/http_url_pattern.dart` |
| `instrumentedHttpClientFactoryProvider` — the wiring entry point | `lib/providers/service_providers.dart` |

Each request reports method, URL pattern, response code, request and response
payload sizes, and response content type. The span covers the whole transfer:
it ends when the response body completes, fails, or its subscription is
cancelled — not at time-to-first-byte.

Nothing is recorded until `PerformanceMonitoringService.initialize()` has
succeeded (`isEnabled`), which is sampled per request rather than captured,
because clients are built with the provider graph before startup finishes.

### Instrumenting a new client

Use the factory instead of `http.Client()`:

```dart
final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
ref.onDispose(httpClient.close);
return SomeApiClient(baseUrl: ..., httpClient: httpClient);
```

It is a factory, not a shared client, so each call site keeps owning and
closing its own client — one consumer's `close()` cannot cancel another's
in-flight requests. Injecting a client often flips the callee from owner to
borrower, so check whether its own `dispose()` still closes anything; if not,
close it from the provider as above.

## What is instrumented

Everything below routes through `instrumentedHttpClientFactoryProvider`.

| Traffic | Host | Wired in |
|---|---|---|
| Funnelcake REST API — feeds, search, profiles, notifications, video stats | `api.divine.video` | `curation_providers.dart` |
| Event publish (REST-first kind 34236) | relay HTTP origin | `video_providers.dart` |
| Product analytics ingest | `api.divine.video` | `social_providers.dart` |
| Username claim / release / check | `names.divine.video` | `repository_providers.dart` |
| Keycast OAuth (login/register/token/poll/reset) | `login.divine.video` | `auth_providers.dart` |
| Relay-manager (minor-account review) | `api-relay-*.divine.video` | `upload_media_providers.dart` |
| Invite server | `invite.divine.video` | `main.dart` |
| Apps-directory listing + audit | `apps.divine.video` | `nostr_apps_providers.dart` |
| NIP-39 identity verification | `verifier.divine.video` | `auth_providers.dart` |
| CAWG identity verification | `verifyer.divine.video` | `auth_providers.dart` |
| Crossposting (settings, manual crossposts) | `crossposter.divine.video` | `upload_media_providers.dart`, `crossposting_providers.dart` |
| Supporter worker (build-gated) | build-supplied | `supporter_providers.dart` |
| Subtitle / VTT fetch | `media.divine.video` | `subtitle_providers.dart` |
| Moderation check-result (playback UX) | `moderation-api.divine.video` | `video_moderation_status_service.dart` |
| NIP-11 relay capability probe | relay HTTP origin | `relay_providers.dart` |

## What is deliberately not instrumented

| Traffic | Why not |
|---|---|
| **Relay WebSockets** — every Nostr subscription and publish over `wss://` | Not HTTP requests; `HttpMetric` cannot express them. Relay latency needs its own custom trace, which is a separate piece of work. |
| **Blossom uploads** (`media.divine.video`) | Goes through Dio, and through the OS background transport (URLSession / Android foreground service) on the shipped path — which Firebase *does* auto-instrument natively. Upload timing is already reported as custom traces via `BlossomPerformanceMonitor`, which measures the whole chunked/resumable operation rather than fragmenting it into per-chunk events. |
| **Video and image byte traffic** — `media_cache`, `divine_video_player`, `cached_network_image` | High volume (one or more events per feed item) for little diagnostic value beyond the native `media.divine.video` events already reported. Download throughput is what matters here and `BandwidthTrackerService` already tracks it. |
| **Third-party hosts** — GitHub releases, Zendesk, the geo-blocker worker on `workers.dev`, NIP-05 resolution, remote avatar SVGs, user-configured relays and Blossom servers | Not ours to measure, and Firebase drops URL patterns past a per-app cap — spending it on hosts we cannot act on is a straight loss. Enforced at runtime by `isInstrumentedHost`, so wrapping a client that *may* be pointed at a third-party host stays safe. |
| **`nostr_sdk` Dio uploaders** (nostr.build, void.cat, …) | Third-party media hosts on a legacy path the app does not use. |

If any of these becomes worth measuring, the decision to add it belongs in this
file next to the reason it was left out.

## URL patterns

Firebase aggregates by URL and drops high-cardinality patterns, so an
identifier in a path would give one pattern per request and blow the cap.
`httpMetricUrlPattern` reports the route instead:

```
https://api.divine.video/api/users/<64-hex pubkey>/videos?limit=20
  -> https://api.divine.video/api/users/:id/videos
https://media.divine.video/<sha256>.mp4
  -> https://media.divine.video/:id.mp4
https://names.divine.video/api/username/by-pubkey/npub1…
  -> https://names.divine.video/api/username/by-pubkey/:npub
```

Collapsed automatically: long hex ids (pubkeys, event ids, sha256 hashes),
NIP-19 bech32 entities (reported as `:npub`, `:nevent`, … so the type stays
readable), UUIDs, all-digit segments, and opaque base64url-ish tokens. Query
strings, fragments and userinfo are dropped entirely.

**Placeholders are `:name`, not `{name}`.** Both SDKs parse the reported URL
before they will record it, and braces are excluded characters in RFC
2396/3986. Android's `FirebasePerfNetworkValidator` calls
`java.net.URI.create` on it and drops the metric at dispatch when that throws
("URL cannot be parsed"); iOS 16's `NSURL(string:)` returns nil and the plugin
fails the call with `invalid-url`. A braced pattern therefore reports nothing,
with no error surfaced to the app. A colon is a legal `pchar`. The character
set is pinned by `http_url_pattern_test.dart`.

Identifiers are replaced **whole**, never shortened. A truncated Nostr id is
still a Nostr id, and emitting one is banned repo-wide (AGENTS.md, "Nostr And
Async Rules") — aggregating by route pattern is the sanctioned answer.

**Free-text path segments need an explicit entry.** No generic rule can tell
`/api/username/check/alice` from a route word, so routes that interpolate a
username, slug or search term into the *path* are listed in
`_freeTextRoutePatterns` in `http_url_pattern.dart`. Add an entry when you add
such an endpoint. Query parameters need nothing.

## Verifying a change

Firebase surfaces network data in the console within ~12 hours, so the loop is
slow; check the cheap things first.

1. Unit level: `flutter test test/observability/network`.
2. Local stack: loopback hosts are instrumented on purpose, so a LOCAL run
   against `local_stack/` exercises the same path end to end. Nothing reaches
   the console from it by default, though — developer builds are deactivated
   natively and gated in Dart (#7123), so this step only proves the client
   builds a metric, not that Firebase accepted it. To take it all the way,
   opt that one run back in: undo the native deactivation for your platform
   (`android/app/src/debug/AndroidManifest.xml`, or
   `FIREBASE_PERFORMANCE_COLLECTION_DEACTIVATED=NO` in `ios/Flutter/Debug.xcconfig`)
   **and** flip `PerformanceMonitoringService.collectionEnabled` to `true` —
   either alone leaves collection off. Revert both before committing; a debug
   run that reports lands `http://localhost:<port>/…` patterns in the
   production project under a build number no store build uses — exactly the
   contamination that skewed #7123.
3. Console: **Performance → Network Requests**, filtered to `divine.video` /
   `dvines.org`. Confirm requests appear from **both** platforms and that each
   endpoint shows as one aggregated pattern with placeholders — a list of
   near-identical URLs differing by one segment means a missing rule.
