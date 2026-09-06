# Analytics Observability

Status: Current contract with semantic route screen views, comments sheet
surface load instrumentation, authenticated identity, and creator funnel
instrumentation live.
Baseline validated against: `mobile/lib/services/screen_analytics_service.dart`,
`mobile/lib/services/page_load_observer.dart`,
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
and Crashlytics; logout clears both and clears account-scoped invite
attribution. This is owned by `analyticsIdentitySync` in
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

## Comments Sheet

The comments sheet measures:

- tap/open intent to first rendered sheet frame
- tap/open intent to comments success, empty state, or failure
- count loaded
- whether video replies were enabled
- whether the user dismissed before data loaded

## Creator Funnel

Every creator-funnel event includes `mode`, using the stable
`VideoRecorderMode.name` values `capture`, `stopMotion`, `lipSync`, `classic`,
or `upload`.

| Event | Additional parameters | Boundary |
| --- | --- | --- |
| `camera_opened` | `entry_point` | Recorder session opens |
| `recording_started` | — | Native recording succeeds, or the first stop-motion frame lands |
| `recording_completed` | `clip_count`, `duration_ms` | Creator continues from the recorder |
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

## Invite Attribution

After the invite service confirms redemption, the normalized code is set as
the Firebase Analytics user property `invite_code`. Failed redemptions do not
set it. Any change of authenticated identity clears it, so a second account on
the device cannot inherit the first account's attribution. Logout is not the
only such change: an in-place account switch never passes through an
unauthenticated state.

## Required Firebase Admin Setup

Complete this before campaign traffic. GA4 stores unregistered parameters but
does not make them queryable as dimensions retroactively.

1. Create an event-scoped custom dimension named `mode` for event parameter
   `mode`.
2. Create a user-scoped custom dimension named `invite_code` for user property
   `invite_code`.

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
- custom traces only when the span represents a real user wait; for
  `feed_load_*`, filter by `completion` and follow the
  [feed-load trace semantics](../mobile/docs/FEED_LOAD_TRACES.md)

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
