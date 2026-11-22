# Analytics Observability

Status: Current contract with semantic route screen views, comments sheet
surface load instrumentation, authenticated identity, and creator funnel
instrumentation live.
Baseline validated against:
`mobile/packages/analytics/lib/src/screen_analytics_service.dart`,
`mobile/packages/analytics/lib/src/page_load_observer.dart`,
`mobile/lib/screens/comments/comments_screen.dart`.

Current code still contains legacy `screen_load` and `screen_data_loaded`
analytics paths for compatibility. The required semantic `screen_view`
parameters are implemented for routes, and `surface_load` is live for
`comments_sheet`. Additional user-visible surfaces should use the same
`surface_load` contract as they are instrumented.

## Purpose

Analytics must answer operational questions:

- Which user-visible screens or surfaces are slow?
- How slow are they at p50, p75, p95, and p99?
- Did the user see real content, an empty state, or an error?
- Is slowness isolated to an entry point, platform, app version, network type,
  or feature flag?

## Naming

Use semantic snake_case names, never Flutter/native class names.

Examples:

- `home_feed`
- `explore`
- `profile`
- `video_detail`
- `comments_sheet`
- `settings`
- `notifications`

Do not log Nostr event IDs, pubkeys, npubs, nsecs, user-entered search text,
comment text, or raw URLs in analytics parameters.

The reserved Firebase Analytics `user_id` field is the deliberate exception to
the pubkey rule above. It is the authenticated account's exact 64-character hex
pubkey, never an npub and never a hash. It is identity metadata, not a custom
event parameter. Login and restored identity set the same value in Analytics
and Crashlytics; logout clears both. This is owned by `analyticsIdentitySync` in
`mobile/lib/providers/auth_providers.dart`, kept deliberately independent of
the Zendesk identity sync so the campaign's BigQuery/ClickHouse join cannot be
broken by a change to the support-desk integration.

## Core Events

### `screen_view`

Logged when the user navigates to a full-screen route.

Required parameters:

- `screen_name`
- `entry_point`
- `route_name`

#### Bottom-navigation shell

The root navigation observers see the shell as one full-screen route. On a
cold start they receive one push named for the initial branch, such as `home`,
and emit one corresponding `screen_view`. A route pushed above the shell, such
as settings or video detail, is also observed normally.

Branch navigators do not notify the root observers. Switching tabs, returning
to an already-mounted tab, and replacing one route with another inside a tab
therefore emit no root `screen_view` or page-load lifecycle events. Analytics
owned by an individual surface remains independent of this observer contract.

This isolation is deliberate. A stateful shell keeps branch navigators alive,
so their events describe navigator lifecycle rather than user arrival:

- the initial branch and shell both push at startup, duplicating the event;
- another branch pushes only on its first mount, not on later visits;
- a sibling route change produces a push plus a remove, while
  `PageLoadObserver` ends sessions only on pop.

For that reason the shell permanently sets `notifyRootObserver: false`.
`mobile/test/router/shell_route_analytics_test.dart` pins both the production
setting and the representative observer sequences.

### `surface_load`

Logged once when a user-visible surface reaches a terminal load state.

Required parameters:

- `surface_name`
- `entry_point`
- `result`: `success`, `empty`, `failure`, or `dismissed`
- `visible_ms`
- `data_ms`
- `total_ms`
- `slow_bucket`: `under_1s`, `1_3s`, `3_5s`, `5_10s`, or `over_10s`

Optional safe parameters:

- `item_count`
- `initial_count`
- `has_more`
- `sort_mode`
- `feature_flag`
- `tab`: which tab of a tabbed surface loaded, from that surface's own fixed
  vocabulary

## Comments Sheet

The comments sheet measures:

- tap/open intent to first rendered sheet frame
- tap/open intent to comments success, empty state, or failure
- count loaded
- `feature_flag`, which is always `video_replies_enabled` now that video
  replies are always on
- whether the user dismissed before data loaded

## Sound Picker

The video editor's sound picker is a modal sheet, so it gets no
`screen_view`. Most of what it loads arrives over relay WebSockets, which the
HTTP metrics cannot see, so it reports its own loads, searches and picks. The
search is a Firebase Performance trace, `sound_search`, described in
[UX performance monitoring](../mobile/docs/UX_PERFORMANCE_MONITORING.md).

### Tab loads

`surface_load` with `surface_name = sound_picker`, once for each tab whose
list shows in an opened picker. The time runs from the tab opening until its
list first shows.

- `tab`: `for_you`, `popular`, `newest`, or `my_sounds`
- `entry_point`: `sheet_open` for the tab the picker opens on, `tab_switch`
  for a tab the user switches to
- `result`: `success`, `empty`, `failure`, or `dismissed` when the user left
  the tab, or closed the picker, before its list showed. A dismissed tab is
  timed again when the user returns to it.
- `item_count`: the sounds the tab's list loaded. For you counts the sounds of
  followed creators; Divine's own sounds are added to that list either way.
- `initial_count`: equal to `item_count` when the list was loaded before the
  tab opened — preloaded by the editor, or loaded behind the open tab — and
  `0` when the user waited for it. Such a list shows at once, so split on this
  before reading `total_ms`.
- `has_more`: for the paged tabs, whether the list has another page

### Picks

| Event | Parameters | Boundary |
| --- | --- | --- |
| `sound_selected` | `source`, `outcome`, `searched` | A pick is attached, refused, or fails |

- `source`: `for_you`, `popular`, `newest`, `my_sounds`, or `import` for a file
  the user imported. A sound attached from another tab than the open one keeps
  the tab it was picked from.
- `outcome`:
  - `attached`: the user confirmed the sound and the picker handed it to the
    editor.
  - `reuse_blocked`: the reuse check refused it. The check fails closed, so
    this includes a failed `POST /api/videos/audio-reuse/bulk`: an outage of
    that endpoint shows as a jump in the `reuse_blocked` share of `popular` and
    `newest` picks, not as errors.
  - `download_failed`: the sound's file could not be downloaded for the
    preview.
  - `failed`: an import the app could not read, or a preview that would not
    play.
- `searched`: `1` when a search narrowed the list the sound was picked from,
  otherwise `0`.

A sound the user only previews before picking another is not reported. A
failed download is reported once per pick; if the user confirms that sound
anyway, `attached` follows it.

## Creator Funnel

Every creator-funnel event includes `mode`, using the stable
`VideoRecorderMode.name` values `capture`, `stopMotion`, `classic`, or `upload`.
Events logged before lip sync and the color mask moved into Capture can also
carry `lipSync` or `chromaKey`; `recording_completed` now records both as
`has_sound` and `has_color_mask` instead.

| Event | Additional parameters | Boundary |
| --- | --- | --- |
| `camera_opened` | `entry_point` | Recorder session opens |
| `recording_started` | — | Native recording succeeds, or the first stop-motion frame lands |
| `recording_completed` | `clip_count`, `duration_ms`, `has_sound`, `has_color_mask` (each `1` or `0`) | Creator continues from the recorder |
| `editor_opened` | — | Editor or metadata route opens |
| `publish_started` | `time_since_camera_open_ms` | Creator taps publish, before render/upload |
| `publish_succeeded` | `time_since_camera_open_ms` | Publish service confirms success |
| `publish_failed` | `reason` | Render, preparation, or publish fails |
| `creation_abandoned` | `last_stage` | The creation flow closes before publish starts |

The tracker is app-scoped so recorder, editor, metadata, and publish routes
contribute to one session. Creation metadata remains local analytics state and
is not written into Nostr video events. `time_since_camera_open_ms` is
**omitted entirely** — not sent as `0` — for an editor-only restored draft
that did not open the camera in the active session, so those publishes cannot
drag the timing distribution toward zero. Query it with `IS NOT NULL` rather
than treating a missing value as instant.

## Notification Opens and Campaign Consent

| Event | Parameters | Boundary |
| --- | --- | --- |
| `push_notification_opened` | `notification_type`, `open_source`, `campaign_revision_id` (campaign opens only) | A person taps a push or local notification; receipt alone is not an open |
| `campaign_consent_changed` | `enabled` (0 or 1) | The campaign opt-in changes while the Notification settings screen is open |

The parameter values, deduplication, and the BigQuery engagement report are in
[analytics/push_engagement.md](analytics/push_engagement.md). The campaign
contract, including how revisions and consent changes are measured, is in
[mobile/docs/MARKETING_CAMPAIGNS.md](../mobile/docs/MARKETING_CAMPAIGNS.md).

## Post-Publish Experiment

The existing profile destination and published-video confirmation remain the
payoff. A deterministic 50/50 assignment from the authenticated hex pubkey
gives the `view_share` variant a confirmation sheet offering **View** and
**Share** instead of the bare snackbar. The control variant is unchanged.
Assignment is local in the app; there is no remote kill switch or Firebase
Admin setup for this experiment.

The sheet requires a single video, a resolvable `d` tag, and the creator
still standing on their own profile. Everything else in the treatment arm
falls back to the control snackbar, so `post_publish_screen_shown` counts
assignments rather than sheets.

- Baseline second-post rate: 44.1%

Events:

- `post_publish_screen_shown`: `destination`, `variant`
- `post_publish_view_tapped`: `seconds_since_publish`
- `post_publish_share_tapped`: `seconds_since_publish`

Arm B was previously a "Record a Video" action under the variant name
`create_again`, logging `post_publish_create_again_tapped`. Those names were
retired rather than reused so the two treatments never share a bucket — data
before and after the swap is not comparable within one variant name.

## Required Firebase Admin Setup

Complete this before campaign traffic. GA4 stores unregistered parameters but
does not make them queryable as dimensions retroactively.

1. Create an event-scoped custom dimension named `mode` for event parameter
   `mode`.
2. Create event-scoped custom dimensions `notification_type`, `open_source`
   and `campaign_revision_id`, and `enabled` for `campaign_consent_changed`,
   before the instrumented release if notification opens and campaign consent
   changes should break down in GA4 reports. The BigQuery report reads raw
   event parameters and does not need them.
3. Create event-scoped custom dimensions `tab` (for `surface_load`) and
   `source`, `outcome` and `searched` (for `sound_selected`) if the sound
   picker should break down in GA4 reports. BigQuery reads the raw event
   parameters without them.

The GA4 reporting identity setting does not gate the BigQuery `user_id` field;
use BigQuery as the campaign source of truth.

## Pre-Release-Candidate End-To-End Check

Publish from a test account and query the streaming export within minutes:

```sql
SELECT
  event_timestamp,
  event_name,
  user_id,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'mode')
    AS mode
FROM `openvine-co.analytics_<property_id>.events_intraday_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  AND user_id = @pubkey_hex
ORDER BY event_timestamp;
```

Verify that `user_id` is the exact 64-character hex pubkey, matches the same
account in ClickHouse `nostr.events_local.pubkey`, and accompanies the complete
creation funnel with non-null `mode`. A null or bech32 `user_id` is a release
blocker for the campaign build.

## Firebase Console Checks

Use Firebase Analytics events to inspect:

- `surface_load` filtered by `surface_name = comments_sheet`
- `slow_bucket` distribution
- p95/p99 in BigQuery export when available
- app version and platform breakdowns

Use Firebase Performance to inspect:

- network request traces for media/API domains
- custom traces when the span represents a real user wait

The iOS `NETWORK_REQUEST` export also carries the Google SDKs' own traffic —
`app-analytics-services.com` is the upload path for every event above, at
roughly 3.5 requests and 4 KB per app start. Its expected volume, host by
host, is recorded in
[Google SDK traffic in the export](../mobile/docs/NETWORK_PERFORMANCE_MONITORING.md#google-sdk-traffic-in-the-export)
so it is read as SDK cost rather than as a finding; the same section says why
the `*.app-ads-services.com` rows stop at the first store release after #7303.

The existing `feed_load_*` traces are an exception: they measure subscription
attempts, including background retries and re-subscriptions, rather than a
user-visible surface load. Filter them by `completion` and follow the
[feed-load trace semantics](../mobile/docs/FEED_LOAD_TRACES.md). New
user-visible feed instrumentation should use the `surface_load` contract above.

## First Dashboard To Build

Create a Firebase/GA4 exploration or BigQuery query for:

- event name: `surface_load`
- dimension: `surface_name`
- dimension: `slow_bucket`
- dimension: `result`
- metric: event count
- metric: p95/p99 of `total_ms`

First target filter:

```text
surface_name = comments_sheet
```

## Divine Brain Check

Divine Brain is read-only from agent tooling. To make this contract discoverable
there, keep this document and the implementation PR detailed enough for the
GitHub ingest pipeline.

Before changing analytics behavior, search Divine Brain for recent context:

```text
Firebase Analytics mobile screen_view surface_load observability divine-mobile
```

After this PR merges and Brain's hourly ingest has run, verify that Brain can
find this contract by searching:

```text
analytics observability comments_sheet surface_load divine-mobile
```
