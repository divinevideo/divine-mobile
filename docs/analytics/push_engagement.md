# Notification opens and engagement

This measures existing notification use. It does not assign users to experiments
or change delivery, preferences, or notification frequency.

The app records `push_notification_opened` when a person taps a notification,
through the existing Firebase analytics sink and consent setting. Background
receipt alone does not record an open. New parameters are:

| Parameter | Values |
| --- | --- |
| `notification_type` | like, comment, follow, mention, repost, campaign, direct_message, new_post, unknown |
| `open_source` | os_cold_start, local_cold_start, os_background, local_tap |

`local_tap` identifies a local-notification callback; it does not assert the app
was in the foreground. No new identity, message text, route, event ID, or FCM
token is sent as a parameter. Transport/source IDs are used only for bounded
in-memory deduplication within a privacy/session boundary. Older campaigns
without either ID cannot reliably deduplicate callbacks. Deduplication does not
promise exactly-once delivery across process restarts.

## Run the report

Use [push_engagement.sql](push_engagement.sql) in BigQuery, or from this repository:

```sh
bq query --project_id=openvine-co --use_legacy_sql=false < docs/analytics/push_engagement.sql
```

The script reads the existing GA4 export and returns aggregate daily rows for
iOS/Android. It uses temporary tables only. The default window is 28 days ending
two UTC days ago, allowing daily export completion. Change `start_date` and
`end_date` at the top for a particular rollout; the window must be under 90 days.
The export property's calendar may differ from UTC, so source table suffixes
include a day on either side and event timestamps determine report dates.

Rows with `notification_type = all` give daily totals. Additional rows group
sessions by the first notification type tapped; `none` means no observed tap.
Use total rows for daily unique users: users can appear in multiple type rows,
so those distinct-user counts must not be added together.

| Column | Meaning |
| --- | --- |
| sessions, users | Sessions and unique GA4 installation identifiers with a session ID |
| returning_sessions, returning_users | Sessions whose GA4 session number is greater than one, and unique installations in those sessions |
| sessions_missing_return_status | Sessions without a session number; their return status is unknown |
| returning_session_share | Returning sessions divided by sessions with known return status |
| notification_opens | Recorded tap events, which can exceed the number of sessions |
| sessions_with_notification_open | Sessions containing at least one tap; this is attribution, not proof the tap started the session |
| engagement_seconds | Total GA4 engagement-time increments observed in the session |
| post_open_engagement_seconds | Observed engagement time after the first tap; intervals spanning the tap are clipped |
| observed_publishes | Existing publish_succeeded events in the session |
| post_open_publishes | Those publish events occurring at or after the first tap |

Sessions are identified by `user_pseudo_id`, `ga_session_id`, and platform. No new
cross-account identity join is used. A returning installation is not necessarily
a returning person across devices, reinstalls, or consent resets. Sessions
crossing midnight belong to their session-start UTC date; this is a session
trend report, not an exact daily-active-user or D1/D7 retention report.

## Reading it

Compare daily total users, returning users, sessions per user, engagement per
session, and publishes before and after the rollout. Watch notification-open
sessions and their subsequent engagement as the instrumented app version reaches
people. Counts before that version have no open instrumentation, and old clients
or disabled analytics remain unobserved. Missing taps do not prove an organic
return; a notification can also remind someone to open the app directly.

This report describes trends and activity following taps. It cannot attribute a
before/after change causally to pushes. It does not calculate an open rate:
existing sender metrics and Firebase reporting are separate, and provider
acceptance is not device display. Verify compatible send/open coverage before
combining denominators.

The Firebase playback helper currently has no app call sites. This report does
not invent video-view, comment, or follow counts from feed loads or screen views.
First-party consumption/engagement collection remains under its existing release
gates; this change does not enable it. GA4 engagement time measures observed
active time, not necessarily watch time. Cold-start consent initialization may
delay the open event slightly, so immediate actions before the event is logged
are not credited as post-open activity.

## Validation

The synthetic check executes the actual report with controlled rows, including
repeated users, unknown session numbers, a direct return, activity before/after
the tap, and an engagement interval spanning it. It never scans production data:

```sh
python3 scripts/analytics/check_push_engagement_report.py
```

A successful result prints 12 passed assertions. BigQuery script dry-runs can
stop before validating later statements; the executable synthetic check is the
check of the aggregation and attribution logic.
