# Request a video's sound through DMs

Status: Approved for implementation on 2026-10-16.

## Intent and agreed behavior

A viewer wants to remix with a video's original audio, but the creator has not
enabled sound reuse. Let the viewer request it through a direct message. The
creator can enable public reuse from that message. After publication succeeds,
reply to each pending requester with actions to use the sound or save it to
their library.

Approval enables reuse for everyone under the existing audio permission model.
There is no permission limited to one person or one use. Saving to a requester's
library is explicit; receiving the reply does not save anything automatically.

Success means the requester can discover, request, receive, save, and use the
sound, and the creator can fulfill requests without uploading a second video.

## Product flow

### Request

In the existing video metadata Sounds section, offer **Request this sound** for
another creator's original sound when reuse is explicitly disabled and the video
has a supported addressable identity. Retain the attribution row. Offer the
existing use-sound flow when reuse is already allowed.

An unresolved audio reference or a failed consent lookup does not establish that
sharing is disabled. Show a retryable unavailable state in those cases instead
of requesting the reusing video's creator to grant rights to someone else's
sound. Preserve the existing classic-audio eligibility policy. Do not offer a
request for deleted or suppressed videos or where current policy prohibits the
action. Creators viewing their own videos do not send requests to themselves.

The viewer must be signed in. Send through the existing one-to-one DM path and
its blocking, recipient, and send-budget rules. A repeated tap while the same
request is queued or pending opens its conversation rather than sending another
message. Use the existing queued/delivered/failed distinctions; a durable queued
message is not confirmed delivery.

### Creator card

Render a structured request as a card with the video preview, requester identity,
and this localized copy:

> Someone wants to use your sound
>
> Enable sound reuse on this video so anyone can remix with it.
>
> Enable sound reuse · Dismiss

The card itself explains the public effect, allowing a single approval action.
Dismiss is local to the creator's request state; it does not send a rejection or
alter the video's permissions. An explicit incoming request may be dismissed
without blocking the requester. Replayed copies of a dismissed request remain
dismissed. No automatic reminders are sent.

Only the video's actual signing owner can enable reuse. A collaborator invite,
preview, message body, or other user's signature does not confer ownership.

### Publication

Approval loads the latest signed source video, verifies ownership and current
eligibility, publishes a reusable audio event, and replaces the video metadata
at the same logical address with public reuse enabled and the audio reference.

The source may exist only remotely: download the published video through the
existing media path when the local original is absent. Extract the published
audio, upload it, and retain creator attribution and source-video linkage. Do
not require the creator to locate an old draft. If acquisition or extraction is
unsupported on the current platform, show a clear failure without claiming that
reuse has been enabled.

Keep the original video kind, author, d-tag, content, media references, captions,
collaborators, and unrelated tags. Change only audio-sharing metadata and the
replacement timestamp. Resolve the latest source again before signing so an
earlier request cannot roll metadata back. Serialize local operations for the
same video. Another device can still race a replacement; reconcile against the
current video before reporting completion rather than claiming atomic updates.

Reuse an already valid linked audio event where appropriate. Never relabel a
reused or licensed provider sound as the requesting creator's original audio.
The operation succeeds only when the required audio publication and video
replacement are acknowledged and the current reuse policy permits reuse. If
policy indexing is pending, retain a pending state and recheck through explicit
retry or the existing background work mechanism.

### Requester reply

Once the sound is ready, send a reply to each pending requester:

> Your requested sound is ready
>
> Use it in your next video or save it to your sound library.
>
> Use this sound · Save to My Sounds

**Use this sound** resolves the published audio and enters the existing creation
flow with it selected. **Save to My Sounds** uses the existing saved-sound flow,
then displays **Saved**. It does not start a recording. Saving an already saved
sound is idempotent, and the saved indicator follows library state if the sound
is subsequently removed.

Both actions recheck current eligibility through the existing consent rules.
A historical approval message does not override a later creator takedown or
permission change. If the sound is unavailable, show that state and preserve
the conversation. A pending request arriving after the creator has enabled the
sound can be fulfilled from the existing published sound without republishing.

## Architecture and existing building blocks

New presentation state uses Cubits and constructor injection. Follow
`UI -> BLoC/Cubit -> Repository -> Client`; widgets do not orchestrate publishing,
DM delivery, consent lookups, or storage. Repository contracts and models remain
free of Flutter UI types. Dependency adapters belong in the app composition
layer; do not introduce dependencies between repository packages.

Relevant existing code:

- `mobile/lib/widgets/video_feed_item/metadata/metadata_sounds_section.dart`:
  attribution and original/shared sound eligibility.
- `mobile/lib/models/collaborator_invite.dart`,
  `mobile/lib/services/collaborator_invite_parser.dart`, and
  `mobile/lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart`:
  structured DM parsing and actionable cards.
- `mobile/packages/dm_repository/lib/src/dm_repository.dart`:
  message transport, persistence, send policies, and retries.
- `mobile/lib/services/video_publish/video_audio_publisher.dart` and
  `mobile/lib/services/local_audio_event_publisher.dart`: audio extraction,
  publication, attribution, and source references. Extract narrowly reusable
  operations rather than duplicating publishing logic.
- `mobile/lib/services/video_event_publisher.dart`: confirmed metadata
  replacement precedent in `republishWithSubtitles`.
- `mobile/lib/services/audio_reuse_consent_resolver.dart`: current consent
  verification; the DM is never the source of reuse authority.
- `mobile/lib/screens/sound_detail_screen.dart` and
  `mobile/lib/blocs/saved_sounds/saved_sounds_bloc.dart`: use and save actions.

Place reusable wire parsing and value models in the owning packages. Keep
feature-specific cards and their Cubits in the app. Compose durable request
state, publication, and fulfillment delivery through injected contracts, with
all domain transitions owned below the presentation layer.

## Message contract

Use the existing encrypted NIP-17 text-message transport and readable fallback
content. Do not introduce a new public event kind or reuse collaboration invite
markers. The request/ready distinction is a versioned Divine application message
extension, not an existing Nostr permission standard.

The request carries its type/version and the full source video coordinate with
an optional relay hint. Its rumor ID identifies the request; the authenticated
message sender identifies the requester. The ready reply carries its type/version,
the original request reference, source video coordinate, and full published
audio-event ID with a relay hint. Following the existing collaborator message's
`divine` marker convention, propose these new application tags:

- Request discriminator: `['divine', 'sound-request', '1']`.
- Ready discriminator: `['divine', 'sound-ready', '1']`.
- Source video: `['a', videoCoordinate, relayHint, 'root']` in both messages.
- Request being fulfilled: `['e', requestRumorId, '', 'reply']` in the ready reply.
- Published sound: `['e', audioEventId, audioRelayHint, 'audio']` in the ready reply.

These discriminators are new feature design, not claims about existing protocol
support. Reject duplicate/conflicting required tags and unsupported versions.
Keep tag constants and parsers shared with queue recovery, as collaboration
invites already do. Avoid encoding application authority in human-readable text
or parsing translated sentences.

Only render an actionable creator approval for a valid one-to-one request
addressed to the video's signing owner. Only render a ready message as a
fulfillment when the authenticated sender owns the source video and its request,
video, audio linkage, and current policy validate. Reject malformed, conflicting,
or unsupported metadata without hiding its readable message body. No message
in a group conversation triggers approval or automatic fulfillment.

## Durable state and recovery

Index received and sent requests from persisted DM history, independent of
whether a particular conversation screen is open. Key records by signed-in
account, video coordinate, requester, and canonical request ID. Preserve dismissed
and fulfilled state across restart; account switching cannot reuse another
account's state or signer. History replay rebuilds the request index without
issuing new messages merely because a card was rendered.

Track publication separately from delivery. Persist the published audio ID and
video replacement result before enqueueing requester replies. Once both publish,
mark all known pending requests for that video fulfilled and create a durable
reply job per requester. Requests discovered later are reconciled with current
public reuse state. Dismissed requests are not pending and receive no automatic
reply unless the creator explicitly reopens them.

Retry extraction/upload, video replacement, and replies at their own boundaries.
A video replacement failure must not send a ready reply. A reply failure must
not extract, upload, or publish the sound again. Persist stable reply jobs and
use the DM outbox's existing idempotency and retry semantics; do not promise
distributed exactly-once delivery. Collapse repeated ready cards referencing
the same canonical request when history arrives from multiple devices.

The app performs this reconciliation while signed in using its existing DM
lifecycle. This feature does not add an always-running server that sends on
behalf of offline creators. Pending work resumes on the next eligible session.

## UI and localization

Reuse Divine buttons, preview components, adaptive theme tokens, and existing
conversation layout. Keep new UI state in Cubits even where integration points
still use Riverpod. All labels, fallback message copy, pending states, and errors
are localized under the repository's localization workflow. Buttons disable while
their operation is in flight; accessibility labels explain the public effect and
the distinction between using and saving.

## Validation and acceptance

Use synthetic full-length identifiers in fixtures. Validate:

1. Request/ready parsing, fallback rendering, unsupported versions, malformed
   coordinates, wrong sender, unrelated sound, and group-message rejection.
2. Eligibility at the Sounds entry point: sharing off, sharing on, owner,
   classic-audio policy, unresolved reference, blocked recipient, unavailable
   video, and unknown consent.
3. Approval from a remotely available video without a local original; exact
   preservation of kind, coordinate, content, and unrelated metadata.
4. Extraction/upload, relay rejection, metadata replacement, pending policy,
   restart recovery, repeated taps, account switching, and concurrent approval.
5. Several pending requesters, late history, dismissed requests, and sound
   already enabled; reply failure retries without another sound publication.
6. Reply use/save actions, already saved state, save failure, creation routing,
   library removal, and consent revocation between reply and action.
7. Widget states and accessibility in light/dark appearances and localized copy.

Run affected package, Cubit, and widget tests, the repository's required analyzer
and localization checks, and inspect relevant CI before publishing completed
implementation. This design stage does not claim app behavior is implemented.
