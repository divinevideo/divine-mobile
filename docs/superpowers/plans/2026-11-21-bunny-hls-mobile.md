# Bunny HLS playback test flag

Approved cross-repo design: divine-blossom docs/superpowers/specs/2026-11-21-bunny-hls-delivery-design.md.

1. Extend the existing exact public-path canary to 480p MP4 and HLS master at their current ladder positions. Reject signed URLs and child paths. Test first.
2. Add a bounded server selection client for GET /api/bunny-playback/<parent>. Require version 1, fixed Bunny host and same-parent exact paths. Deduplicate requests, bound memory and body size, cache at most 30 seconds. Transport/config failures retain canonical playback; policy denial stays terminal. Test first.
3. Add default-off internal bunnyPlayback flag and stable provider-owned selector. Resolve before choosing disk bytes. Disable disk prefetch under server selection. Rollback disposes sources and ignores late results. Keep authenticated retries canonical. Test first.
4. Run package suite/coverage/analysis and focused app tests, independent whole-diff review, rebase, commit, push and request mapped reviewers. Upload and signed event URLs remain canonical. No visual change.
