# Greenlight In-App Parent Approval: Design

**Status:** Draft for review
**Date:** 2026-09-23
**Tracking:** divinevideo/support-trust-safety#230 (decision), #173 (epic)

> **As built (divinevideo/divine-mobile#9451).** Where the code differs from
> this document:
>
> - The whole flow sits behind `FeatureFlag.minorConsentInAppRecording`
>   (`FF_MINOR_CONSENT_IN_APP_RECORDING`), off by default until the
>   relay-manager route and its request-signing contract ship.
> - Submission runs in `MinorConsentSubmitCubit`; the widget only renders its
>   state.
> - The upload sends no body digest. The NIP-98 token signs the URL and method,
>   and its `payload` tag is the hash of an empty body.
> - The only cap is the 60-second length. There is no client size cap. At the
>   camera's default 1080p and 8 Mbps, a full clip is about 60 MB, so
>   "oversize cannot occur" does not hold.

---

## Context

Divine supports 13–15 year olds through a parent-supported path branded
"Divine Greenlight". Today a parent gives consent by sending a short video to
`support@divine.video` as an email attachment or a private link. The video shows
the teen, a parent or guardian speaking on camera, that the teen has permission
to use Divine, and that the parent knows about the account and will supervise it.

Divine's product decision (recorded on
[support-trust-safety#230](https://github.com/divinevideo/support-trust-safety/issues/230))
is that the **in-app path becomes the primary way a parent gives consent**, while
the email / private-link route **stays available as a fallback**. Email
attachments are a known failure point — size limits, the wrong mail app, mobile
quirks — and the in-app path removes those steps for the common case where the
parent and teen are together.

## Current state (mobile)

- A flagged 13–15 account reaches the minor-account-review flow.
- `MinorAccountReviewParentContactScreen` collects the **parent's email** and
  calls `MinorAccountReviewRepository.submitParentContact`, which POSTs
  `{email}` to `/v1/minor-review-cases/{caseId}/parent-contact` on
  relay-manager.
- `MinorAccountReviewParentConsentScreen` explains what the parent must show in
  the video and opens the device mail app pre-filled with a support email
  (`minorAccountReviewParentConsentEmailSubject` / `...Body`).
- The parent then records and emails the video or shares a link; support
  attaches it to the ticket by hand.

## Decision

The in-app path becomes primary. The email / private-link path remains a
fallback and is not removed.

## In-app flow

1. On the parent-consent screen, the primary action becomes **Record consent
   video**. The existing "email support" action is demoted to a secondary
   **Email or send a link instead**.
2. The parent and teen see an intro screen stating exactly what the video must
   show and reassuring them about storage and access.
3. The parent records the video in-app, guided by an on-screen prompt card.
4. The parent reviews the clip and can retake it.
5. The parent confirms their email address (kept for the receipt in #229 and
   the audit link in #232).
6. The parent submits. On success the screen confirms receipt and states when
   to expect a reply.

## Recording

- Guided in-app recording using the front camera.
- Hard cap on length, proposed at **60 seconds**, enforced by the recorder.
- On-screen prompt card the parent reads aloud or shows:
  1. the teen is on camera;
  2. a parent or guardian is on camera;
  3. the teen has permission to use Divine;
  4. the parent knows about the account and will supervise its use.
- The capture is **local only** until the parent submits; the temp file is
  discarded if they exit without submitting.
- No gallery picker. The clip is recorded in the moment on the child's device.

## Data flow

1. Client captures to a temporary local file.
2. Client sends a multipart `POST`
   `/v1/minor-review-cases/{caseId}/parent-consent` carrying the parent email
   and the video, authenticated with the existing NIP-98 service.
3. relay-manager validates the request, creates the Zendesk ticket with the
   video as an attachment, and moves the case to `submittedForReview`.
4. Client invalidates `currentMinorAccountReviewStatusProvider` **and**
   `protectedMinorStatusProvider`, so the approved-teen gating takes effect
   without a relaunch (the #185 fix).
5. Client shows the receipt confirmation.

## Backend (relay-manager)

- One new route under the existing `minor-review-cases` family that accepts
  multipart form data (email + video).
- Validates content type and enforces the same size cap the client applies.
- Creates the support ticket and attaches the video, reusing the programmatic
  ticket-creation mechanism established in divinevideo/divine-web#86.
- Maps the parent email onto the ticket for the receipt and audit trail.
- The existing email-only `parent-contact` route is unchanged and continues to
  serve the fallback path.

## Storage, retention, and access

- The video is stored as a **Zendesk ticket attachment**. No new bucket and no
  new media store are introduced; the clip inherits the support system's
  existing retention.
- Access is restricted to the reviewers on the case, per
  [support-trust-safety#231](https://github.com/divinevideo/support-trust-safety/issues/231).
- The exact retention window must be written down and agreed **before**
  implementation starts. This remains the open blocker recorded on #230: the
  clip is sensitive media of a minor, and "stays in support under its existing
  retention" must be stated explicitly rather than assumed.

## Error handling

- **Camera permission denied or unavailable** — explain why the video is needed
  and route the parent to the email / link fallback.
- **Upload failure** — keep the local file and offer a retry; never make the
  parent re-record because of a network error.
- **Offline** — allow retry; the fallback stays visible throughout.
- **Oversize** — cannot occur, because the recorder enforces the cap.

## Testing

- Abstract a recorder interface so widget tests can drive a fake instead of a
  real camera.
- Widget tests for: permission denied, recording in progress, review and
  retake, successful submit, failed submit.
- Repository test exercising the multipart submission.
- Golden test for the new screen(s).
- Backend route tests live in the relay-manager repository.

## Out of scope

- The parent-own-device link path (a parent completes the recording remotely
  through a link). Deferred.
- The three-choice flagged-kid screen and the plain-language rewrite
  (divinevideo/support-trust-safety#226 and #227). Separate tickets.
- Automated receipts and reminders for the parent (divinevideo/support-trust-safety#229).
  Consumed by this flow but built separately.

## Related tickets

- divinevideo/support-trust-safety#230 — the decision this design implements.
- divinevideo/support-trust-safety#231 — restrict verification-video access.
- divinevideo/support-trust-safety#232 — single account age-review record.
- divinevideo/divine-web#86 — programmatic support-ticket creation.
- divinevideo/divine-mobile#185 — foreground-resume account-state refresh.