# Marketing campaign push contract

Campaigns use the existing encrypted push registration and preference protocols.
Kind 3079 advertises `campaignTargetTypes` with `app_route`, `video_address` and
`creator_profile`. The push backend must support this optional field before the
app advertises it. A device capability never grants account marketing consent:
`campaignsEnabled` remains an explicit, default-off kind-3083 preference.

Supported targets are Following (`app_route` with `/following/new`), a canonical
kind-34236 coordinate with full lowercase creator pubkey and nonempty d-tag
(`video_address`), and a full lowercase creator pubkey (`creator_profile`).
Campaigns reuse normal video/profile navigation. Malformed or unsupported targets
open the inbox. HTTPS destinations remain unsupported.

The `campaignRevisionId` survives FCM, local notification normalization and
foreground/background/cold-start tap handling. The existing
`NotificationAnalyticsTracker` records `push_notification_opened` with the
revision UUID as `campaign_revision_id` only when analytics collection is allowed.
Campaign callbacks deduplicate within the current privacy/session boundary;
identifiers and consent are rechecked across an asynchronous identity change.
No target pubkey, video coordinate or message content is added to analytics.

Observed effective marketing preference changes record `campaign_consent_changed` with
numeric `enabled` (0/1) through that same consented sink. Resetting settings can
record a withdrawal, and choosing an already selected value records nothing. Concurrent preference
callbacks compare one cached observation, so unrelated or duplicate writes do not
produce duplicate marketing changes; persistence ordering remains unchanged.
Analytics failures do not delay navigation or preference persistence.

Existing consented playback and session events supply engagement measurement.
The private report in divine-engagement evaluates distinct completed playback in
24 hours and return activity/opt-outs in seven days against the randomized
holdout. It reports consent coverage; unknown/unconsented accounts are not
counted as measured zero conversions. A provider-accepted send is not proof of
notification display or opening.

Release order: compatible push backend, this app, then campaign dashboard
video/profile choices. Physical iOS/Android verification must cover one alert,
correct destination, campaign revision preservation, foreground/background/cold
starts, account changes and analytics opt-out. Older devices retain Following
support and are filtered out of unsupported video/profile sends server-side.
