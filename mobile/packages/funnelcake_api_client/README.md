# funnelcake_api_client

Status: Current
Validated against: `pubspec.yaml` on 2026-03-19.

Purpose: HTTP client for Funnelcake REST APIs used by search, profile, and feed-adjacent features.

Used by: repository packages that need server-backed data in addition to Nostr data.

Test locally:

```bash
cd mobile/packages/funnelcake_api_client
flutter test --no-pub
```

`getVideosByAuthors` uses `POST /api/v2/videos/by-authors` with a JSON author
array and the existing sort and pagination fields. Each call still accepts up
to 200 authors; repository chunking is unchanged. Deploy backend POST support
before releasing this caller. The response shape is unchanged, the POST
response is not cached, and the client does not fall back to GET.


The idempotent author-feed POST retries transient 429/5xx and transport failures
using the same total timeout budget as GET reads. Other POST calls retain their
existing behavior.
