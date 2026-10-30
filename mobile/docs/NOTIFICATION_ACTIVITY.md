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
Heartbeats replace the pending state without restarting a failing request's
backoff. Failed sends wait 5, 15, 30, then 60 seconds; foreground retries stay
at 60 seconds until a send succeeds. A real visibility transition sends its new
state immediately. Background retries stop after four retries. Failure logs
record only the error type and retry delay, without request bodies or account
identifiers.
Backgrounding and disposal stop heartbeats. Server receipt time is authoritative;
presence expires after 180 seconds if the app crashes or the OS suspends it.
Logging out or switching accounts retires the old account's signing callbacks;
it does not send a final background update for that account. Its server presence
can therefore remain until that same 180-second lease expires.

## Remote off switch

The activity endpoint can return HTTP 410 to stop reporting without an app
release. A 410 cancels pending retries and heartbeats and suppresses further
report signing across visibility and account changes for this provider's
lifetime. App restart or a server-environment change creates a new provider and
allows reporting again. Operators must return 410 at the activity route to use
the switch; a 204 means the report was accepted. This is an off switch, not a
remotely re-enabled configuration feed. Ordinary 404/429/503 responses keep the
bounded backoff behavior and do not activate the switch.

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
signing to fifteen seconds. A new Amber connection asks for standing kind 27235
permission. Once granted, user-initiated NIP-98 requests also try the content
resolver before opening the signer, so those HTTP-auth requests no longer prompt
individually when the resolver succeeds. The permission is scoped to the event
kind; each signed token still binds one exact URL, method and body for its short
validity window. Existing Amber connections keep their prior grants until the
user explicitly reconnects.

NIP-46 bunker and NIP-07 extension identities currently offer no explicit silent
signing capability, so autonomous activity reports fail closed for those signers.
Their foreground presence and visit resets cannot be reported until such a
capability exists. If the proposed server allowance policy ships without its
signer fallback, those accounts receive the initial absence allowance but cannot
reset it by opening the app, and later eligible pushes can be suppressed.
Deploy the compatible server fallback before activating that policy. This PR
does not add silent signing support to those identities.

An `activityDigest` push displays the supplied aggregate title and body through
the existing Android data-message and iOS alert paths. Its real triggering
`eventId` is for identity and deduplication; tapping opens Notifications rather
than a single video. No synthetic Nostr event kind or actor is introduced.

Roll out the push-service policy and Funnelcake gateway before releasing mobile.
Foreground visits reset only the absence allowance; the server retains the
six-hour cooldown, delivery identities, consent, expiry, and quiet-hour rules.

## Privacy disclosure before release

The published privacy policy lives in the web repository, outside this mobile
change. Its activity disclosure must be published before releasing reporting.
Proposed text for the policy owner to reconcile with the deployed retention
settings:

> When you're signed in, the app tells Divine when you open and close it, and
> checks in once a minute while it's open. We use this only to time notifications.
> Current status is kept for three minutes, and visit counts for up to 90 days.
> It isn't shown to anyone.

Retries can add reports while a send is failing; the one-minute cadence describes
successful foreground check-ins. The remote off switch does not publish this
disclosure or establish that the backend rollout has completed.

## Optional simulator evidence

Digest tap routing changes an interaction. Before/after screenshots can provide
useful supporting evidence; missing captures are not a draft or readiness gate.
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
   coordinating PR workflow. Record any missing evidence and the actual device
   validation limits in the PR description.
