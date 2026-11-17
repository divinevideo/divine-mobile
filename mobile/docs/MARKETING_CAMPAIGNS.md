# Marketing campaign push contract

Campaigns use the existing encrypted push registration and preference protocols.
Kind 3079 advertises `campaignTargetTypes` with `app_route`, `video_address`,
`creator_profile`, `announcement` and `featured_feed`. The push backend must support this optional field before the
app advertises it. A device capability never grants account marketing consent:
`campaignsEnabled` remains an explicit, default-off kind-3083 preference.

Supported targets are Following (`app_route` with `/following/new`), a canonical
kind-34236 coordinate with a 64-character lowercase hex creator pubkey and a
nonempty d-tag (`video_address`), and a 64-character lowercase hex creator pubkey
(`creator_profile`). Registration advertises
`NotificationWireValues.campaignTargetTypes`, and a test checks that every type
in that list routes a valid value.
Announcement and featured-feed targets carry their exact catalog UUID.
Announcements resolve through the trusted catalog. Featured feeds preserve the
requested identity through repository selection and caching, and show an
unavailable state when the feed is ineligible or withdrawn.
Campaigns reuse normal video/profile navigation. Malformed or unsupported targets
open the inbox. HTTPS push destinations remain unsupported. Validated
announcement actions can open canonical store links or approved contest details.

Encrypted registration also includes the known platform, install channel and
canonical marketing version for release targeting. Unknown install channels or
versions are omitted. Marketing consent remains independent of this metadata.

The `campaignRevisionId` survives FCM, local notification normalization and
foreground/background/cold-start tap handling. The existing
`NotificationAnalyticsTracker` records `push_notification_opened` with the
revision as `campaign_revision_id` only when analytics collection is allowed and
the revision is a lowercase UUID; any other value is dropped with a warning and
the open is recorded without it. Campaign opens deduplicate by revision within the
current privacy/session boundary, so separate deliveries of one revision count
once; an open whose boundary changes while consent is being read is dropped.
No target pubkey, video coordinate or message content is added to analytics.

Observed effective marketing preference changes record `campaign_consent_changed`
with numeric `enabled` (0/1) through that same consented sink. They are observed
only while the Notification settings screen is open. Resetting settings can
record a withdrawal; choosing an already selected value, and unrelated or
duplicate writes, including concurrent ones, record nothing. Analytics failures
do not delay navigation or preference persistence. Both events are listed in
[`docs/ANALYTICS_OBSERVABILITY.md`](../../docs/ANALYTICS_OBSERVABILITY.md).

Existing consented playback and session events supply engagement measurement.
The private report in divine-engagement evaluates distinct completed playback in
24 hours and return activity/opt-outs in seven days against the randomized
holdout. It reports consent coverage; unknown/unconsented accounts are not
counted as measured zero conversions. A provider-accepted send is not proof of
notification display or opening.

Release order: compatible push backend, this app, then campaign dashboard
video, profile, announcement and featured-feed choices. Physical iOS/Android
verification must cover one alert,
correct destination, campaign revision preservation, foreground/background/cold
starts, account changes and analytics opt-out. Older devices that advertise no
`campaignTargetTypes` keep Following support. The server filters those devices
from sends for other target types.
