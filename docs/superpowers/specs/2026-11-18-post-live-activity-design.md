# New-post Live Activity on iOS

Status: approved by Matt, 2026-11-18. The push-service portion needs Daniel
Cadenas's review before any server work starts.

## For reviewers

We want your feedback, and we want you to check what this design claims.
Everything below was verified against code and config on 2026-11-18. Code
moves, though, and a reviewer who knows a system will catch what reading it
missed. If a fact here is wrong, or right but missing context, say so. A
wrong fact can change the design.

**Feedback we are asking for:**

- **Daniel (push service):**
  - Is a Live Activity delivery class outside the interruption policy
    acceptable?
  - Is extending kind 3079 better than new kinds or an HTTP endpoint?
  - How should Live-Activity-only tokens be kept out of normal delivery?
  - Who can run the staging test send?
  - Would you hold an Apple push key for the direct-to-Apple fallback, if
    it's needed?
- **Sebastian (iOS):**
  - The `WidgetBundle` conversion, the 16.2 guard, and the thumbnail in the
    app group within widget memory limits.
  - A custom plugin versus the `live_activities` package.
  - The `divine://` entry for post stats.
  - Whether the app can get a Firebase token without notification
    permission.
- **Rabble (product, and the creator highlights card this builds on):**
  - On by default.
  - The honest empty states and the 10-minute settle point.
  - The first-run note.
  - How this sits beside the Inbox card.
- **Trust and safety:**
  - "Can't find stats" covers any post the stats service doesn't return,
    whatever the reason. Is truthful, cause-free wording right for now?
  - Lock Screen privacy (counts and the creator's own thumbnail only).

**Please check these facts. The design rests on them:**

| Claim | Where it was read | Who can confirm |
|---|---|---|
| The relay accepts only an allow-list of event kinds, and the push-registration kinds 3079/3080/3083 are on it. | Funnelcake source | Funnelcake maintainers |
| Stats can trail a new post by up to about 8 minutes, because the relay's database writes and the view summary each run on a multi-minute cycle. | Production relay config; Funnelcake | Funnelcake maintainers, Daniel |
| The bulk stats endpoint (`POST /api/videos/stats/bulk`) suits a server polling every few minutes, and leaves out posts it won't return without saying why. | Funnelcake source and production config | Funnelcake maintainers |
| Every push today passes caps (5/h, 20/day), a 6 h gap, quiet hours 21:00–07:00, and an app-active refusal. | `divine-push-service` `notification_delivery.rs` | Daniel |
| Push registration's `TokenPayload` ignores unknown fields, and 3080 removes the device token. | `divine-push-service` `crypto.rs`, `event_handler.rs` | Daniel |
| Firebase HTTP v1 carries a Live Activity token in `apns.live_activity_token`. | Firebase "Get started with Live Activity" docs | Staging test send |
| Live Activities need iOS 16.2+, run up to 8 h, carry at most 4 KB, and should clear 15–30 min after ending. | Apple ActivityKit docs and HIG | Sebastian |
| The app registers for push only after notification permission is granted. | `push_notification_session_coordinator.dart` | Sebastian |
| The post stats screen finds its post by event id in the author list; edited posts take each counter's maximum across versions. | `creator_analytics_screen.dart`; `profile_video_merge.dart` | Sebastian |

## Why

Rabble's creator highlights card (#10594, reworked in #10772) tells creators
how their week is going: one rotating fact at the top of Inbox › All, leading
into their stats. It is a pull surface. It appears only when the creator
opens that tab, it refreshes only on visits and at midnight, and it covers the
calendar week, not the post they just made. From account stats the creator
usually cannot even reach a just-published post's stats, because the
drill-downs there list only standout posts ("Most viewed", "Most discussed",
"Most reposted", top 5).

The moment this design serves is a different one: **someone has just posted
and puts their phone in their pocket.** A Live Activity keeps them connected
to that one post while they're away, in the Dynamic Island and on the Lock
Screen, without reopening Divine. The Inbox card waits to be looked at; this
comes to them.

Success: a creator who taps Post and pockets the phone sees, at a glance, that
the post went live and how its first hour is going, and one tap takes them to
that post's stats.

### Prior art

Alex's spike on Dynamic Island upload progress (#9438) established the iOS
mechanics this design relies on:

- A Live Activity is **not shown in the Dynamic Island while its own app is in
  the foreground**. Upload progress while scrolling Divine cannot be served by
  one. This feature targets the opposite case: the app in the pocket.
- The app **cannot update an activity while suspended**. Apart from a short
  window while a background task assertion is held, only ActivityKit push
  updates keep it current.
- The `ActivityContent`/`staleDate` API is **iOS 16.2+**.
- A Live Activity **fits inside the existing `CameraQuickActionWidget`
  extension**. Converting its single `@main` widget to a `WidgetBundle` was
  the whole structural change, and it built cleanly.
- `staleDate` degradation works with the app suspended, and **orphaned
  activities are real** when nothing ends them.

## Goals

- When a creator taps Post, a Live Activity starts for **that post** and stays
  live for **its first hour**, updated by the server while the app is
  suspended.
- It shows **counts only**: views, likes and comments for that post.
- At the end of the hour it shows a **"First hour" summary**, which clears
  **30 minutes** later.
- **Tapping** it opens that post's stats, with the account stats one step back.
- It is **on by default**, with a **one-line note** on the first one, an
  **in-app toggle**, a **per-post Stop** control, and full respect for Apple's
  system controls.
- **No one who wants it is blocked by their past or current choices**
  (Matt, 2026-11-18). Declining notification permission, turning off
  notification types in Divine, or turning notifications off later never
  prevents or ends it. Only turning Live Activities off does: the in-app
  toggle, Apple's system switch, Stop, or clearing it from the Lock Screen.
  The one group that cannot have it is devices below iOS 16.2, which is
  Apple's floor.

## Non-goals

- **Android.** There is no equivalent surface in this scope.
- **Showing who reacted.** No names, avatars or comment text on the Lock
  Screen in v1. A later version could add people, but it would need
  block/mute and abuse handling on a public surface.
- **Upload percentage.** The activity shows "Posting…" during the upload but
  does not promise a live percentage (see #9438 for why that cannot be kept
  honest while suspended).
- **Changing Funnelcake.** It already serves what we need.
- **Changing the in-app creator highlights card or account stats screen.** The
  post stats screen changes only as far as the activity needs: reachable from
  a link, able to find a just-published or edited post, and carrying the Stop
  control (see *Tap target* below).
- **Fixing count semantics.** Funnelcake's views count plays (including the
  creator's own replays), and reactions include dislikes and are not adjusted
  for deletions. That is what the app's stats show today; the activity
  matches the app rather than defining new numbers.

## Anti-goals

These would make it a failure even if it technically works:

- **Anything other than the truth** (Matt, 2026-11-18: "be honest"). The
  activity and the stats screen always say what is actually known: no "on
  their way" that never resolves, and no quiet ending that hides an empty
  hour.
- **A zero shown by mistake.** A zero appears only once it is confirmed (see
  *Settle point* below). Before that, a zero means "not known yet" and is
  not shown. Kindness comes from the wording ("No views yet · live for 14
  min"), never from withholding a confirmed answer.
- **Numbers that disagree with the app.** Every count comes from the same
  Funnelcake source the app's stats use.
- **A surprise people can't easily turn off.** Apple warns that people who
  cannot control Live Activities from the app turn them off in Settings
  altogether.
- **A stale activity that looks live.** When the server stops checking in,
  the activity says so.
- **Interruptions.** Updates never buzz, alert or produce a banner.

## What the person sees

Everything is about **one post: the one they just published.**

| Part | Shows |
|---|---|
| Which post | Its thumbnail, "Your post", and time since posting ("12m"). No caption: there is no room, and the thumbnail identifies it. |
| Counts | Views, likes and comments **for that post only**: its totals so far, which in the first hour are its first-hour numbers. The same counts the creator highlights card celebrates. No reposts in v1. |
| While uploading | "Posting…" |
| Live, first 10 minutes | Only non-zero counts show (for example "▶ 12 ♥ 3", with comments left off), or "Your post is live" when none are non-zero yet. A zero here is not known yet. |
| Live, nothing yet (from 10 min) | "No views yet · live for 14 min". Funnelcake has the post and its counts are confirmed zero. |
| Live, with counts (from 10 min) | All three counts, with confirmed zeros shown ("▶ 40 ♥ 0 💬 0"). |
| Can't find stats | 10 minutes after publishing, Funnelcake still has no record of the post: "We can't find stats for this post". The activity ends early, and a tap opens the post. |
| Counts older than expected | "Updated 4m ago", driven by `staleDate`. This means the server stopped checking in, not that nothing happened. |
| After the hour | "First hour" with the same three counts, or "No views in the first hour" when that is the truth. It clears 30 minutes later. |
| Edits to the post | Still the same post. It is tracked by the post's address, not the ID of a single version, so an edit does not reset or orphan it. |
| Another post within the hour | The new post **replaces** it. The old activity ends immediately, with no summary. |
| Account switch or sign-out | The activity ends. It belongs to the account that posted. |

**Settle point: 10 minutes after publishing.** In production the relay
writes to the database every 3 minutes, and the view summary rebuilds every
5. So Funnelcake can have the post and still report 0 views while views are
in flight. The worst case is about 8 minutes. Before the settle point a zero
is "not known yet". After it, a zero is a real answer and is shown. The same
point decides "can't find stats". For the Live Activity, the server enforces
this rather than the app (see *Funnelcake client*). The post stats screen
reads Funnelcake itself, so it applies the same rule for a post less than 10
minutes old.

Sketch (layout to be designed; the content is fixed above):

```
Lock Screen
┌──────────────────────────────────────┐
│ [thumb]  Your post is live · 12m     │
│          ▶ 48   ♥ 9   💬 2           │
└──────────────────────────────────────┘
Dynamic Island, compact:  [thumb] ··· ♥ 9
Dynamic Island, minimal:  [thumb]

Lifecycle
Tap Post ─► Posting… ─► Your post is live ─► ▶ 48 ♥ 9 💬 2 ─► First hour: ▶ 212 ♥ 31 💬 6
            (app)       (app, on publish)    (server, ~3 min)   (server, at +60 min; clears +30 min)
```

**Tap** → that post's stats (`PostAnalyticsDetailScreen`, route
`/creator-analytics/<post>`). The route is nested under account stats, so back
lands on `CreatorAnalyticsScreen`. The person lands on the thing they were
watching, and the account-wide picture is one step back.

## Turning it on and off (Apple's rules)

From Apple's Live Activities guidelines and the ActivityKit docs:

- **System switch: Settings › Divine › Live Activities.** Before starting, the
  app checks `ActivityAuthorizationInfo().areActivitiesEnabled` and observes
  `activityEnablementUpdates`. If the system switch is off, the in-app toggle
  shows as unavailable and explains why, rather than looking on while doing
  nothing.
- **Clearing from the Lock Screen.** When a person removes the activity, its
  state becomes `dismissed`. The app tells the server to stop updating it.
- **In-app global toggle**, on by default, in the existing Notification
  settings screen (`notification_settings_screen.dart`): "Show new post
  activity on Lock Screen". Turning it off ends any running activity. Apple:
  *"make it easy for people to turn them off in your app."* Whether it stays
  on by default is for review to decide. It is a single default value on
  this toggle, so changing it needs no redesign.
- **Per-post Stop** on the post stats screen while that post's activity is
  running. It ends the activity immediately and tells the server to stop.
  Apple suggests controls *"in the app view that corresponds to the
  activity."*
- **First-run note**, on the first activity only, shown in the activity before
  any counts arrive. It says what this is and where to control it, for
  example: "Live stats for your first hour · turn off in Settings". Never
  shown again on that device.
- **Independent of notification permission** (Matt, 2026-11-18). Apple
  treats Live Activities as their own permission, with their own switch in
  Settings. Someone who declined notifications still gets the activity, with
  the first-run note telling them what it is and the in-app toggle and the
  system switch giving them control. Today the app stops before registering
  anything with the push service when notifications are denied
  (`push_notification_session_coordinator.dart`). The Live Activity path must
  not depend on that flow, and it **must never enroll someone who declined
  notifications into notification pushes** (see *Token protocol*).
- **No "frequent updates" tier.** We do not declare
  `NSSupportsLiveActivitiesFrequentUpdates`. An hour at a ~3-minute cadence,
  sent mostly at `apns-priority: 5` (which does not count against Apple's
  hourly budget), does not need it, and leaving it out avoids an extra
  Settings switch.
- **Starting.** Apple's model is that Live Activities start as a natural
  follow-on to something the person just did ("after a food order"). Tapping
  Post is that moment. The app is in the foreground then, which is where
  Apple requires `request` to happen. **This is also why the activity must
  start at the Post tap**: once the app is backgrounded it cannot start one.
  Push-to-start (iOS 17.2+) is not needed.
- **Ending.** At +60 minutes the server ends the activity with the summary and
  a dismissal date 30 minutes later. Apple suggests *"a custom dismissal time
  that's proportional to the duration… In most cases, 15 to 30 minutes is
  adequate."*
- **Lock Screen privacy.** Counts and the creator's own public thumbnail only.

Devices on iOS 16.0 and 16.1 (the app's minimum is 16.0) keep today's
behaviour behind an `@available(iOS 16.2, *)` guard. The minimum does not
change.

## Approaches considered

| | Approach | Trade-off | Verdict |
|---|---|---|---|
| A | **App-only.** Update the activity when existing like, comment and repost pushes wake the app (they carry `content-available: 1` via `prefetchContent`), fetching counts from Funnelcake. | Mobile-only, but it goes silent when nobody reacts (views send no push), depends on the creator's notification settings, push-service caps and coalescing, and iOS's rationing of background wakes. Every like also still shows a normal banner. | Rejected as the main path. |
| B | **Server pushes updates.** `divine-push-service` polls Funnelcake on a ~3-minute cycle for each live post and sends ActivityKit updates through Firebase. | Reliable and independent of notification settings, refreshes views on a timer, never produces banners. Needs push-service work and Daniel's buy-in for a delivery path outside the interruption policy. | **Chosen** ("do it the right way"). |
| C | A now, B later. | Ships sooner, with the gaps above. | Not chosen. |

**If B is blocked, shelve it. Do not fall back to A** (Matt, 2026-11-18). Two
gates can block it: the staging test send (Firebase cannot deliver
ActivityKit pushes), or Daniel declining the delivery class. A goes silent on
exactly the quiet posts where a small creator most needs reassurance, so it
is not an acceptable substitute. To find out cheaply, the staging test send
happens **before any mobile work beyond the widget UI**.

## Design

### Mobile (`divine-mobile`)

**Widget extension.** Convert `CameraQuickActionWidget`'s single `@main`
`Widget` into a `WidgetBundle` containing the existing camera widget plus an
`ActivityConfiguration` for the post activity. It needs the Lock Screen /
banner, Dynamic Island expanded, compact and minimal presentations, plus
accessibility labels and dark/light rendering. Add `NSSupportsLiveActivities`
to the Runner `Info.plist`.

**Activity data.** An `ActivityAttributes` type shared by Runner and the
extension:

- *Static:* owner pubkey (full hex), post coordinate, post event id at start,
  thumbnail reference, `postedAt`.
- *Content state:* phase (`posting`, `live`, `notFound`, `summary`), `views`,
  `likes` and `comments` (each nullable, meaning not known yet; zero means a
  confirmed zero), `updatedAt`, and whether to show the first-run note.

The content state carries **numbers and enums only, no display strings**. All
text is localized in the extension's existing `*.lproj/Localizable.strings`
(18 localizations already present; the widget has never shipped `ms`, `te`, `ur`, `vi` or `zh`, which fall back to English), and numbers are formatted compactly on device.
That keeps payloads far under Apple's 4 KB limit and keeps copy out of the
server. "Time since posting" is rendered with SwiftUI's self-updating relative
date text, so it advances without pushes.

**Thumbnail.** The activity's views cannot fetch from the network, so the app
writes a small thumbnail into the shared app group (`group.co.openvine.app`)
at start and the extension reads it from there. It has to stay small enough
for the widget's memory limits.

**Native bridge.** A small Runner plugin, following the existing in-app plugin
pattern, exposes to Dart:

- `isEnabled` and enablement changes
- `start`, which returns the activity id, then the push token asynchronously
- `update` (app-side phase changes)
- `end`
- observing activity state (`dismissed`, `ended`)
- listing running activities

My call: write this plugin rather than add the `live_activities` package. The
needed surface is small, it must use the 16.2 `ActivityContent` API with
`pushType: .token`, and the repo prefers fewer dependencies. The builder may
revisit this if the package covers the push-token flow cleanly.

**Dart side.** A `PostLiveActivityRepository` owns the bridge, the toggle and
the server registration. A cubit or the existing publish flow drives it:

1. On the **Post tap**, if the feature flag, the in-app toggle and the system
   switch all allow it, end any running post activity, then start a new one
   in phase `posting`. This hooks into `BackgroundPublishBloc`
   (`mobile/lib/blocs/background_publish/`), which already holds the
   foreground session across the publish.
2. On **publish success**, update to `live`, then register the activity with
   the push service (see *Token protocol*) with its push token, the post
   coordinate and event id, and the window end (`postedAt` + 60 minutes).
   Push tokens can rotate; send each new token.
3. On **publish failure or cancel**, end the activity immediately.
4. On **Stop, toggle-off, a `dismissed` state, account switch or sign-out**,
   end the activity and tell the server it ended (a 3079 with
   `state: ended`, see *Token protocol*).
5. On **every app foreground**, sweep running activities. End any whose
   window plus the summary period has passed (protection against orphans if
   the server never sent the end), and any that belongs to a different
   account.

**Deep link.** The activity's `widgetURL` uses the `divine://` scheme.
`DeepLinkService` is deny-by-default for that scheme (#11017), and
`customSchemeRoutablePrefixes` deliberately mirrors the web's universal-link
claims, so the post stats route should **not** be added there. Add a dedicated
custom-scheme entry, in the style of `saved-videos` in
`_customSchemeAppRoutes`, that opens `/creator-analytics/<videoId>`, with
account stats beneath it in the navigation stack. The link is
`divine:///post-analytics/<first event id>?coordinate=<post address>`: after an
edit the first event id no longer resolves, and the address still does. This is a security-relevant
change for the reviewer. It only ever shows the signed-in account's own
numbers, and another account's post fails to load.

**Tap target.** Opened from a link, `PostAnalyticsDetailScreen` today finds
its post by matching `video.id == widget.videoId` inside
`fetchCreatorAnalytics` (`creator_analytics_screen.dart`), and shows "Unable
to load" otherwise. That fails exactly where the activity is most likely to
be tapped. In the first few minutes the post is not yet in Funnelcake's
author list (the relay writes to its database on a multi-minute cycle). After an edit,
the stored event id is no longer the surviving version. *My call:* the screen
resolves the post by its address as well as by id. This is the one change to
the stats screen beyond the Stop control, and it tells people what is
actually true (Matt, 2026-11-18):

| State | What we know | What it says |
|---|---|---|
| On their way | Funnelcake has not caught up yet. Normal for the first minutes, while the relay and the view summary catch up. | "Stats are on their way" |
| Nothing yet | Past the 10-minute settle point, Funnelcake has the post and its counts are confirmed zero. Before the settle point, zeros are not shown. | "No views yet · live for 14 min" |
| Can't find stats | **10 minutes** after publishing (past the ~8-minute worst case), Funnelcake still has no record of the post. | "We can't find stats for this post", with a link to the post itself |
| Couldn't load | The request failed. That is an error, not an answer. | The existing "Unable to load" with retry |

Bulk stats leave out any post they don't return without saying why, so "can't
find stats" has more than one possible cause. The wording stays truthful and
claims none. Telling a creator *why* is a
separate trust-and-safety decision, outside this design.

The Live Activity shows the same states (see *What the person sees*), so the
Lock Screen and the stats screen never tell different stories.

**Settings and storage.** The toggle and the "first-run note shown" marker are
**device-scoped** (my call: both concern this device's Lock Screen). Each needs
a `deviceScopedPrefsKeys` classification to satisfy
`check_prefs_key_classification.sh`. New user-facing strings in the Flutter
app (toggle, unavailable explanation, Stop) go through `context.l10n`, with
keys mirrored across locales.

**Feature flag and kill switch.** App feature flags are build-time
(`bool.fromEnvironment` in `build_configuration.dart`), with a per-user
override and no remote config, and the widget extension is native code that
needs a store release anyway. *My call:* the **server's per-environment
enable is the real kill switch**. The app ships with the feature compiled
on, in the first store release after staging delivery is verified. While the
server has it off, an activity simply goes stale, which is the same safe
degradation as any server outage. "On by default" refers to the user setting.

### Push service (`divine-push-service`), subject to Daniel's review

What exists today, verified at `origin/main`:

- Firebase HTTP v1 messages are built as raw JSON (`fcm_sender.rs`, around
  `build_apns_config`). There is no Live Activity support, no `apns-topic`,
  and no `liveactivity` push type.
- Authentication is Google application credentials. The service holds no
  Apple key.
- There is no Funnelcake client. The only outbound HTTP besides Firebase is
  the campaign client in `campaign_delivery.rs`.
- Every send passes the interruption policy in `notification_delivery.rs`: a
  5/hour cap, 20/day, a 6-hour minimum gap, quiet hours from 21:00 to 07:00,
  and a refusal when the app is active.
- Redis-scored delayed jobs exist (`new_post_fanout_jobs`) and are the pattern
  to copy for scheduling.

Proposed additions:

1. **Token protocol.** The push service receives control events only through
   its relay subscription, and Funnelcake's relay accepts only an allow-list
   of kinds, which includes 3079/3080/3083. A new kind pair would therefore need a Funnelcake
   allow-list change in every environment. *My proposal, for Daniel to
   confirm:* **extend kind 3079's encrypted payload** with an optional
   `liveActivity` object
   (`{activityPushToken, postCoordinate, postEventId, windowEndsAt, state}`,
   where `state` is `active` or `ended`), alongside the existing required
   `token`.
   - `TokenPayload` has no `deny_unknown_fields`, so a push service without
     this change treats such an event as an ordinary re-registration of the
     same device token, which is harmless.
   - Ending is a 3079 with `state: ended`, **never a 3080**, because 3080
     deregisters the device token itself.
   - The payload carries whether the device has notification permission. A
     token registered only for Live Activities (permission declined) must
     **never receive alert or background notification pushes**: the service
     stores it as Live-Activity-only and excludes it from normal delivery.
     Because a push service without this change would treat the event as an
     ordinary device registration, **the mobile release that sends these must
     follow the push-service deploy that understands them.**
   - One active activity per owner and device: a new one supersedes the
     previous one.
   - **Live Activity state is stored separately from device registration.** A
     3080 (sent, for example, when someone turns notifications off after
     posting) removes the notification registration only and never ends a
     running activity. An activity ends only on a 3079 with `state: ended`,
     at its window end, or when Firebase reports its token invalid.
   - **Notification preferences never gate it.** The kind 3083 preferences
     (for example, likes or comments turned off), quiet hours, and the caps
     do not apply to Live Activity updates.

   Alternatives, if Daniel prefers: new kinds plus a Funnelcake allow-list
   change, or an authenticated HTTP endpoint (devices cannot reach the
   service over HTTP today, so that is an infrastructure change). Document
   the result in `docs/nip-xx-push-notifications.md`.
2. **Live Activity delivery class, outside the interruption policy.** These
   updates never alert, so they bypass the hourly and daily caps, the minimum
   gap, quiet hours and the app-active refusal. They are still bounded by the
   activity window and the cadence below. The policy in
   `docs/notification-delivery.md` should name this class explicitly.
   **This is the decision Daniel owns.**
3. **Scheduler.** On registration, schedule a job every ~3 minutes until
   `windowEndsAt`, then a final end job. The relay writes to its database and
   the view summary rebuilds on multi-minute cycles, so checking faster gains
   nothing.
4. **Funnelcake client.** Each cycle, one `POST /api/videos/stats/bulk` for up
   to 100 live posts (chunked beyond that). The endpoint's rate limit is well
   above this load; the Funnelcake repo has the details. Map `views` →
   `views`, `reactions` → `likes`, `comments` → `comments`. If counts are
   missing, send unknown (null), never zero. **Before the 10-minute settle
   point, send any zero as unknown (null) too**, because views can still be
   in flight. From the settle point on, a zero is sent as a confirmed zero.
   **Match the app's numbers exactly** (anti-goal: no disagreement). For an
   edited post, the app takes each counter's maximum across all versions of
   the address (`mergeNullableEngagementMax` in
   `videos_repository/lib/src/profile_video_merge.dart`), and falls back to
   `GET /api/videos/{id}/views` when bulk stats have no views. The server does
   the same over every version id it knows for the activity. The app sends a
   new version's id when the creator edits the post on that device (a 3079
   update with the same `liveActivity`). An edit made on another device
   during the hour is not seen, so the counts stay on the known versions.
   That is accepted as rare.
5. **Sending.** Firebase message with `apns.live_activity_token`, `aps.event`
   set to `update` or `end`, `content-state`, `timestamp`, a `stale-date`
   about 10 minutes ahead, and `dismissal-date` = end + 30 minutes on the end
   event. Use `apns-priority: 5` for regular updates. The end event may use 10.
   Send each cycle even when counts are unchanged: that refreshes the stale
   date, so "stale" means *the server stopped checking in*, not *nothing
   happened*.
6. **Can't find stats.** If every id for the post is still absent from bulk
   stats 10 minutes after `postedAt` (listed in `missing`, or not returned),
   send an `end` with phase `notFound` and the usual 30-minute dismissal.
   Before then, "absent" means "not caught up yet" and the counts stay
   unknown (null). A failed request is never treated as absence.
7. **Cleanup.** Drop the activity on a `state: ended` registration, on window
   end, after `notFound`, or when Firebase reports the token invalid.

### Infrastructure (`divine-iac-coreconfig`)

Config only: the push service's Funnelcake base URL, plus a flag to enable the
Live Activity delivery class per environment. No new secrets are expected
for reading stats, and Firebase carries the Apple delivery. The
exception is the direct-to-Apple fallback for people who declined
notifications, if the device check calls for it (see *Verified versus
unverified*).

## Verified versus unverified

**Verified against code and config (2026-11-18):** everything cited under
*What exists today*; the bulk stats endpoint's shape and limits; the relay's
write cadence; the mobile
iOS targets, extension and entitlements; and the deep-link allow-list.

**Unverified.** The staging test send settles the first two, and it gates
mobile work beyond the widget UI. The rest need Daniel or a device check:

- Whether the Firebase project has the Apple configuration that ActivityKit
  pushes need. That requires someone with Firebase console access.
- Whether Firebase accepts `live_activity_token` end to end and sets the topic
  correctly.
- Whether Daniel accepts extending 3079 rather than new kinds (see *Token
  protocol*).
- Whether the app can obtain its Firebase token when notification permission
  was declined. On iOS, remote-notification registration does not itself
  require alert permission, but this needs a device check, because the Live
  Activity registration carries that token. **Named fallback, so this group
  is never quietly excluded:** if the token cannot be obtained, the push
  service delivers to that group directly through Apple, using the
  activity's own push token. That means an Apple push key held by the push
  service, which is a new secret and needs Daniel's agreement.
- Whether the post's Nostr publish completes when the app is suspended
  mid-publish. If it doesn't, the activity stays at "Posting…" until the app
  next runs, and `staleDate` keeps that honest. This needs a device check.
- Whether opening `/creator-analytics/<videoId>` from the custom scheme
  produces account stats beneath it in the stack.

## Delivery

**First, a feature request.** File it as a `divine-mobile` feature issue
that links this document and the *For reviewers* asks, just before the first
pull request below opens, so the issue is where review starts and where each
PR points back to. Matt files it, or approves a draft. A search on 2026-11-18
found no open duplicate. The closest is #9438, closed, which covered upload
progress rather than post stats.

Then independent pull requests, each targeting `main`, not stacked:

1. **Push service:** protocol, delivery class, scheduler, Funnelcake client,
   behind config, off by default. Docs: the NIP file, the notification
   delivery policy, the developer-guide payload section, and the Redis key
   table in `AGENTS.md`.
2. **Infrastructure:** config to enable it on staging, then production.
3. **Mobile:** one pull request, built in two slices on the same branch.
   Slice 1 is the activity's data, display rules, Lock Screen and Dynamic
   Island views and their localizations. Slice 2 adds the bridge, repository,
   toggle, Stop, deep link and the post stats screen change. It shares the
   widget extension with the Apple Watch remote shutter's Live Activity
   (#11134), so whichever lands second joins the other's widget bundle.
   Reviewed by Sebastian. **It does not merge until the push service is
   deployed to production**, so nothing reaches users half-built.

Order: the staging test send, then the push service deployed, then the mobile
release. The mobile release must not reach users before a push service that
handles Live-Activity-only registrations (see *Token protocol*). The mobile
work otherwise degrades safely without the server: the activity goes from
"Posting…" to "Your post is live", then shows as stale.

## Left to the builder

- Visual design of the four presentations, within the content rules above.
- The exact copy, following `brand-guidelines/TONE_OF_VOICE.md`.
- The thumbnail size and format for the app group.
- Whether the end event uses priority 10.
- Test strategy: XCTest in `RunnerTests` for the bridge, Dart unit tests for
  the repository, and push-service tests against its existing stub Firebase
  server.
