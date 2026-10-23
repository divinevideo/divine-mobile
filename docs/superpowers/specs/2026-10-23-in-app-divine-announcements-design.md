# In-app announcements from Divine

Date: 2026-10-23

Status: Implementation in progress across divine-mobile and divine-engagement.
Production provisioning and deployment have not started.

## Purpose and agreed scope

People should discover useful Divine news inside the Notifications tab and be
able to return to the message later. Staff should compose and publish messages
from a Cloudflare Worker web app under `*.admin.divine.video`.

Rabble selected in-app delivery first and a staff web publisher rather than
posting tagged announcements from an official Nostr account. This design covers
that first version. Device push, post-update popups, campaign automation,
personalized audiences, scheduled publication, and delivery/open analytics are
outside this version.

Success means a staff member can draft, preview, publish, and withdraw an
announcement; an eligible app installation can fetch it, display a clearly
identified **From Divine** entry, open its full text, and retain its local
seen state across app restarts. Social notifications continue to work when the
announcement service is unavailable.

## Existing code and choice of owner

The source audit used:

- `divine-mobile` at `5a9eac06f795a329f2b192ee894d31e0a5c0a3ce`:
  `mobile/packages/models/lib/src/notification_item.dart`,
  `mobile/packages/notification_repository/lib/src/notification_repository.dart`,
  `mobile/lib/notifications/bloc/notification_feed_bloc.dart`, and
  `mobile/lib/notifications/view/notifications_view.dart`.
- `divine-engagement` at `acef6d0f56dca201cfdbe296665f548e22d0b968`:
  `AGENTS.md`, `src/index.ts`, `src/auth/access.ts`,
  `src/campaigns/repository.ts`, and `public/app.js`.

The mobile feed already supports cache hydration, refresh, pagination, filters,
and a badge meaning "new since last seen." Its `system` kind is also used for
unknown notification types; it is not proof that a message came from Divine.
The engagement Worker already owns staff authentication, an internal dashboard,
D1 persistence, and audit events. Its older architecture notes describe roles
that current code and repository rules do not impose: staff access is flat.

Extend the existing engagement Worker with an **Announcements** section at
`https://engagement.admin.divine.video/announcements`. This reuses the staff
identity and audit boundary. A separate Worker would duplicate those controls.
Tagged Nostr posts would reuse relay delivery but do not provide the requested
staff publishing workflow without adding a signing integration.

## Staff publishing

The editor provides these fields:

| Field | Contract |
| --- | --- |
| Title | Required plain text, 1–120 characters after trimming |
| Body | Required plain text, 1–8,000 characters after trimming |
| Learn-more URL | Optional HTTPS URL on `divine.video` or `about.divine.video` |
| Platforms | All supported platforms by default; optional explicit platform selection |
| Minimum app version | Optional marketing version such as `1.0.26`; not a build number |
| Expiry | Required; defaults to 30 days after publication, maximum 90 days |

V1 supports draft editing, an app-shaped preview, **Publish**, and **Withdraw**.
Publishing shows the final copy and eligibility before confirmation. The server
sets the publication time. A published copy is immutable: staff withdraw it and
publish a correction as a new announcement rather than silently changing a
message someone has already read. A stable announcement ID deduplicates retries.

Every draft mutation, publication, and withdrawal records the authenticated
operator and action in the existing audit system. Audit and staff identity data
remain private. Any authenticated staff member may perform these actions;
there is no new author/approver role hierarchy. Publish and withdraw must be
idempotent, and conditional state changes must reject concurrent stale edits.

Announcements have their own D1 records and lifecycle, `draft -> published ->
withdrawn`. Expiry makes a published record ineligible for the public catalog.
They do not enter campaign recipient workflows, delivery queues, push outboxes,
opt-in rosters, or campaign result tracking. Existing campaign controls stay in
force for campaigns. The global visibility of this editorial channel and its
public projection must be explicitly covered by the implementation review.

## Public read contract and access separation

Use the same Worker deployment with a separate public, read-only hostname,
proposed as `https://announcements.divine.video`. This hostname is a design
proposal, not a claim that DNS, a route, or a deployment exists.

The public hostname exposes only `GET /v1/announcements` and its corresponding
`HEAD`, plus an anonymous CORS preflight for conditional reads. All other paths
and methods are rejected; it does not serve admin assets
or admin APIs. The staff hostname retains its current Cloudflare Access JWT
validation. Routing must reject unknown hosts before either app is selected.
The public host must not become an alternate way to reach staff routes.
Anonymous cross-origin reads may be allowed for this public projection without
credentials; that policy must not be applied to the staff app. Learn-more URLs
use exact parsed host matching, forbid userinfo and nonstandard ports, and do
not accept admin subdomains or arbitrary app-navigation strings.

The catalog contains a schema version and the complete active announcement
list. Each item contains only its ID, title, body, optional learn-more URL,
publication and expiry timestamps, platforms, and optional minimum app version.
It contains no operator identities, draft content, audience membership,
account identifiers, campaign data, or device tokens. This is public editorial
copy, so the app sends no account identity or authorization header to fetch it.

Bound active publication to 50 records and the encoded catalog to 512 KiB;
publishing rejects a change that would exceed either bound. This permits an
authoritative complete snapshot without mixing another cursor into the social
feed. Validate both bounds server-side and client-side.

Use an ETag derived from the exact public response body. Cache for at most five
minutes and never beyond the next record expiry. Publish/withdraw and their
audit entries commit atomically; a catalog read must not expose half a publish.
Successful complete responses replace the client catalog; `304` retains it.
Malformed, partial, oversized, timed-out, redirected-to-another-origin, or
otherwise failed responses never erase the last valid cache. Cache expiry and
withdrawal are reevaluated on the next successful refresh; withdrawal cannot
recall copy already read or copied by a user.

## Mobile behavior

An eligible published item appears chronologically in the existing **All**
notifications feed, with Divine branding, **From Divine**, its title, a short
body preview, and publication time. It does not appear in social-type filters
such as Likes or Comments. A tap opens a full-screen announcement detail page
with its full plain text and optional explicit learn-more action. This works
from cache after an announcement has been fetched. The UI supports both themes,
large text, and screen readers. Interface strings use normal localization;
announcement copy is staff-authored content and is not automatically translated.

Preserve the existing badge meaning: announcements contribute to "new since
last seen," and a successful open/refresh of All marks only the announcements
included in that applied snapshot as seen. New arrivals after that snapshot
remain new. Viewing the tab does not imply that the full message was opened,
and no open metric is collected. Refreshes, duplicate responses, and reopening
the tab do not revive a seen announcement. A fresh installation may show the
currently active catalog; there is no historical backfill of expired messages.

Platform, minimum-version, and expiry checks happen before feed merging and
badge calculation. Reuse existing version comparison behavior rather than
inventing lexical comparison. Device notification permission and campaign push
preferences have no effect on these in-app items. This feature never requests
push permission, schedules an OS notification, or opens a popup.

## Mobile ownership and persistence

Add an announcement client/repository with injected HTTP, clock, and storage.
The repository owns schema validation, first-party source provenance, catalog
cache, eligibility, and account-scoped seen state. The app layer supplies the
fixed endpoint, platform, current version, and active owner. Widgets receive
state through BLoC; they do not fetch catalogs or manage storage.

Represent trusted announcement rows with an explicit notification subtype/kind.
An arbitrary social `system` row, profile name, or unknown wire type must never
receive **From Divine** branding. The notification repository composes the
announcement and social snapshots so both feed and badge consume the same
merged result. Announcement refresh failure is independent of social refresh
failure, and neither source's success drops the other's cached rows.

Keep the public catalog separate from account data: cache its opaque validated
envelope once in the device's bounded `cache_sync` store, with a five-minute
freshness TTL. Stale envelopes remain available for repository validation and
offline hydration; repository expiry checks still exclude expired messages.
Seen IDs are small local dismissals stored in account-scoped preferences. They
survive ordinary app restarts and switches between retained accounts; removing
the account or deleting its local data clears that owner's seen state after
draining its writers. Removing an account does not delete public catalog bytes.
Old-owner in-flight requests and storage completions cannot update a new
owner's feed. Cross-device seen synchronization and persistence after local
account cleanup are not part of V1.

Social cursors, per-filter pagination, UUID read writes, and social cache rows
keep their existing contracts. Announcement IDs never go to social mark-read
endpoints, never get grouped with likes or follows, and are not written as
legacy/unowned social cache rows. Catalog refresh runs alongside the existing
notification refresh coordination without blocking app startup or resetting a
paginated social feed. Stable sorting uses publication time and ID as a tie
breaker, with namespaced identities preventing collisions with social IDs.

## Acceptance and verification

Worker tests must establish that anonymous public reads cannot reach drafts,
audit records, private APIs, or admin assets; unknown hosts and public write
methods fail; staff authentication remains required; validation, concurrent
edits, atomic audit writes, idempotent publish/withdraw, expiry, catalog bounds,
and ETags behave as specified. Render preview/copy as text, not executable HTML.

Mobile tests must cover exact DTO contracts, provenance, malformed/oversized
responses, timeout/offline/cache and `304` behavior, eligibility, duplicate IDs,
independent source failures, stable merging and pagination, and per-account
seen state. Exercise mark-seen snapshot races, account switching during fetch
and persistence, logout cleanup, badge agreement, tap routing, cold-start
cache hydration, both themes, large text, accessibility, and localizations.
Assert that no push registration, campaign preference write, or OS-notification
call occurs when fetching or displaying an announcement.

Before rollout, exercise a synthetic announcement through staff preview,
publish, app refresh, detail, restart, seen-state retention, and withdrawal.
Verify the public hostname exposes only the intended projection and the admin
hostname still rejects unauthenticated access. Production campaigns, private
account records, and real audience lists are not test fixtures.

## Delivery boundary

Implementation spans `divine-engagement` (editor, storage, audit, public catalog)
and `divine-mobile` (client, persistence, feed integration, detail UI). Each
repository gets a focused PR targeting main with shared API fixtures. Existing
admin-dashboard navigation can link to the new section without a new admin app.
Do not add duplicate campaign infrastructure or require a Funnelcake inbox
migration for a public editorial feed.

The mobile feature remains release-gated until the public contract is deployed
and checked. Preparing code and tests does not provision the public hostname,
change Access policy, apply remote migrations, publish a real announcement, or
deploy a Worker. Those consequential actions require their own explicit
authorization. No livestream work is part of this feature.

This written design is the review checkpoint before an implementation plan.
