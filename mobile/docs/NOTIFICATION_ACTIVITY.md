# Notification activity and digests

The app reports authenticated visibility to Funnelcake through
`POST /api/v2/notifications/activity`. This controls interruption allowance and
presence; it never acknowledges or deletes inbox activity. It is independent of
analytics consent, FCM registration, and background fetch.

The strict JSON body contains:

| Field | Value |
| --- | --- |
| `sessionId` | Random UUID for one account/provider/process lifetime |
| `sequence` | Increasing integer from 1 through 2147483647 |
| `visit` | Integer from 1 through 2147483647, at most `sequence` |
| `state` | `foreground` or `background` |

NIP-98 signs the exact URL, POST method, and serialized body. An empty 204
acknowledges applied, duplicate, and stale updates. Uncertain requests retry
with the same body and a fresh signature, unless a newer lifecycle update
supersedes them. Account changes retire pending work and create a new UUID.
The server rejects bodies larger than 4096 bytes.

The first foreground uses visit 1. Each real background-to-foreground transition
increments `visit`, even while signing or transport is unavailable. This lets
the server recognize a return when the previous background request was lost.
Transient `inactive` transitions retain visibility and do not create visits.
Foreground heartbeats run every 60 seconds and preserve the visit number.
Backgrounding and disposal stop heartbeats. Server receipt time is authoritative;
presence expires after 180 seconds if the app crashes or the OS suspends it.

The provider waits for the matching signer-backed Nostr session and uses the
current Flutter lifecycle state at activation. A hidden background launch cannot
report a foreground visit. Delayed signing rechecks both the owner and current
update before transmission. The request retains this validity check through
clock-skew recovery, so retirement before or during corrected signing prevents
the retry from sending an obsolete foreground lease.

Passive activity signing never opens signer approval UI, including a clock-skew
retry. Local keys and noninteractive Keycast RPC are supported. Amber uses only
its content resolver after HTTP-auth kind 27235 permission has been granted;
the explicit signer connection requests that permission alongside relay auth.
Existing Amber users may need to reconnect and grant it. Missing permission or
an unavailable resolver suppresses the activity report without an intent fallback.
Silent resolver calls are bounded to six seconds, and noninteractive Keycast
signing to fifteen seconds. User-initiated signing retains its existing behavior.

NIP-46 bunker and NIP-07 extension identities currently offer no explicit silent
signing capability, so autonomous activity reports fail closed for those signers.
Their foreground presence and visit resets cannot be reported until such a
capability exists; normal notification and signing flows are unchanged.

An `activityDigest` push displays the supplied aggregate title and body through
the existing Android data-message and iOS alert paths. Its real triggering
`eventId` is for identity and deduplication; tapping opens Notifications rather
than a single video. No synthetic Nostr event kind or actor is introduced.

Roll out the push-service policy and Funnelcake gateway before releasing mobile.
Foreground visits reset only the absence allowance; the server retains the
six-hour cooldown, delivery identities, consent, expiry, and quiet-hour rules.

## Pending simulator evidence

Digest tap routing changes an interaction. Before/after screenshots are still
required by the shared PR review policy; automated tests do not satisfy it.
At implementation handoff the booted iOS simulator had no Divine installation,
and no authenticated synthetic digest/inbox capture fixture was prepared.

For safe capture:

1. Use separate isolated checkouts for the PR base and current head, and a fresh
   simulator rather than an existing account-bearing simulator. Record both full
   SHAs, simulator model/runtime, theme, and capture commands.
2. Prepare the local stack after checking its documented fixed ports are free.
   Create a synthetic account, video, and like/repost events. Keep generated
   private keys out of source control and captures. Use the same seeded data for
   both builds; the trigger event must resolve to the synthetic video so the
   base behavior can be observed.
3. Build each revision from `mobile/` using
   `flutter build ios --simulator --debug --dart-define=DEFAULT_ENV=LOCAL`.
   Install `build/ios/iphonesimulator/Runner.app` on the capture simulator, sign
   into the synthetic account, and enable notification permission.
4. Background the app and inject an alert with `xcrun simctl push` using the
   installed bundle identifier. The payload needs `aps.alert.title` =
   `New activity`, an aggregate body, `type` = `activityDigest`, the synthetic
   triggering `eventId`, and the synthetic account's `receiverPubkey`. Use full
   IDs and no fabricated actor or Nostr kind. `aps.mutable-content` may be 1.
5. Tap the notification. Capture the base's single-video destination and the
   head's Notifications inbox with `xcrun simctl io <device> screenshot <file>`.
   Inspect both images, then publish comparable Before/After pairs through the
   coordinating PR workflow. Keep the PR draft until that evidence is available.
