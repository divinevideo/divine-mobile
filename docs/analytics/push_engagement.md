# Notification opens and engagement

This measures existing notification use. It does not assign users to experiments
or change delivery, preferences, or notification frequency.

The app records `push_notification_opened` when a person taps a notification,
through the existing Firebase analytics sink and consent setting. Background
receipt alone does not record an open. New parameters are:

| Parameter | Values |
| --- | --- |
| `notification_type` | like, comment, follow, mention, repost, campaign, direct_message, new_post, list_add, unknown |
| `open_source` | os_cold_start, local_cold_start, os_background, local_tap |

`local_tap` identifies a local-notification callback; it does not assert the app
was in the foreground. No new identity, message text, route, event ID, or FCM
token is sent as a parameter. Transport/source IDs are never exported. The FCM
message ID travels in a locally rendered notification's payload, so it also
appears in the app's local tap log, and otherwise serves only bounded in-memory
deduplication within a privacy/session boundary. Older campaigns
without either ID cannot reliably deduplicate callbacks. Deduplication does not
promise exactly-once delivery across process restarts.

## Run the report

Use [push_engagement.sql](push_engagement.sql) in BigQuery, or from this repository:

```sh
bq query --project_id=openvine-co --use_legacy_sql=false < docs/analytics/push_engagement.sql
```

The script reads the existing GA4 export and returns aggregate daily rows for
iOS/Android. It uses temporary tables only. The default window is 28 days ending
four UTC days ago. Sessions on the final day are observed into the next UTC day.
That observation day can still receive late events, so the final day's
subsequent-activity metrics may change on a later run. This cutoff does not
guarantee that GA4's daily exports are closed. Change `start_date` and
`end_date` at the top for a particular rollout; the window must be under 90 days.
The export property's calendar may differ from UTC, so source table suffixes
include a day before the report and two days after it to cover both the
following observation day and property-calendar differences. Event timestamps
determine report dates.

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
trend report, not an exact daily-active-user or D1/D7 retention report. Events
are observed through the UTC day after end_date so ordinary cross-midnight
sessions keep their later activity. Unusually long sessions continuing beyond
that bounded observation window remain partial.

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
the tap, an engagement interval spanning it, and a final-day session whose tap
and publish happen after midnight. It also applies the real timestamp filter
and checks that activity at the observation window upper boundary is excluded. It never scans production data:

```sh
python3 scripts/analytics/check_push_engagement_report.py
```

A successful result prints 15 passed assertions. BigQuery script dry-runs can
stop before validating later statements; the executable synthetic check is the
check of the aggregation and attribution logic.
