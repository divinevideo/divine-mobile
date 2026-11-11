# Apple Review Response Reference

Status: Launch-critical
Validated against: current settings/support flows, `mobile/ios/Runner/Info.plist`, and launch docs on 2026-03-19.

This document captures the current reviewer-response posture for Divine. It is not a transcript to paste blindly into App Store Connect; it is the maintained source used to prepare reviewer notes and follow-up responses.

## App Identity

- App name: `Divine`
- Bundle identifier: `co.openvine.app`
- Current legal/support links:
  - `https://divine.video/terms`
  - `https://divine.video/privacy`
  - `https://divine.video/safety`
  - `https://divine.video/faq`
  - `https://divine.video/proofmode`

## Current Reviewer Talking Points

### 1. User-Generated Content Safeguards

Divine includes visible, in-app safeguards for user-generated content:

- users can report content
- users can block and mute abusive accounts
- users can manage moderation providers and safety preferences under `Safety & Privacy`
- policy and safety links are reachable from the welcome flow and Support Center

Primary in-app surfaces:

- `Settings -> Support Center`
- `Settings -> Moderation Controls`

### 2. Support And Escalation

The Support Center gives reviewers a visible route to:

- contact support or report a bug
- export logs
- view support messages when Zendesk is configured
- open FAQ, ProofMode, Privacy Policy, and Safety Standards

### 3. Permissions Clarification

Current iOS permission strings cover:

- camera
- microphone
- photo library access
- Bluetooth usage descriptions
- Bonjour service discovery
- location usage descriptions

These must stay aligned with the actual app behavior and the submission answers in App Store Connect.

### 4. Export Compliance

Divine sets `ITSAppUsesNonExemptEncryption` to `false`.

Reference:

- [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](ENCRYPTION_EXPORT_COMPLIANCE.md)

## Reviewer Notes Template Inputs

Use these facts when writing reviewer notes:

- where moderation/reporting/blocking live in the UI
- where legal/policy pages are linked in the app
- any staged or disabled features that could confuse review
- support contacts and escalation routes

## Do Not Use

Do not reuse older wording that references removed screens, old domains, or unsupported background modes without rechecking current code first.

---

## Appendix A: Historical Review Resolutions

These are past Apple review rejections and how they were resolved. Keep this record so future submissions do not regress.

### Issue 1: iPad Screenshots (Guideline 2.3.3)

**Problem:** Submitted iPad screenshots were scaled-up iPhone captures, which Apple flagged as misleading.

**Resolution:** Replaced with authentic iPad captures taken on actual iPad hardware/simulator at native resolution.

### Issue 2: Background Audio (Guideline 2.5.4)

**Problem:** The app declared the `audio` background mode in `Info.plist` but did not use background audio playback.

**Resolution:** Removed the `audio` background mode declaration from `UIBackgroundModes`. The app does not play audio in the background.

### Issue 3: Bluetooth Background Modes (Guideline 2.5.4)

**Problem:** Reviewer asked about Bluetooth background mode declarations.

**Resolution:** Clarified that the app does not declare Bluetooth background modes (`bluetooth-central`, `bluetooth-peripheral`). Bluetooth usage description keys are present for BLE-related libraries but no background execution is requested.

### Issue 4: UGC Moderation (Guideline 1.2)

**Problem:** Apple required evidence of a complete content moderation system for user-generated content.

**Resolution:** Full moderation system implemented. See Appendix B for implementation details.

---

## Appendix B: Moderation Implementation Details

### Reporting Protocol

Divine uses NIP-56 (kind 1984) report events on the Nostr protocol for content reporting. Reports are signed by the reporting user and relayed to moderation infrastructure. A report made from a direct message is sent privately instead, as an encrypted message to Divine's moderation account, so it is never published.

### Report Categories

The reporting system supports 9 categories:

1. Spam
2. Harassment
3. Hate speech
4. Violence
5. Nudity / sexual content
6. Misinformation
7. Impersonation
8. Illegal content
9. Other

### Response SLA

- **Critical** (illegal content, imminent harm): response within 1 hour
- **High** (harassment, hate speech, violence): response within 4 hours
- **Standard** (spam, misinformation, other): response within 24 hours

All reports are acknowledged and resolved within 24 hours maximum.

### Code References

| File | Purpose |
|------|---------|
| `lib/services/content_reporting_service.dart` | NIP-56 report event creation and submission |
| `lib/services/content_moderation_service.dart` | Moderation policy enforcement and queue processing |
| `lib/services/content_blocklist_service.dart` | Local and global blocklist management |

### Contact Emails

| Purpose | Address |
|---------|---------|
| General support | support@divine.video |
| Security reports | security@divine.video |
| Legal inquiries | legal@divine.video |

---

## Appendix C: New User Onboarding and TOS Acceptance Flow

The welcome flow includes a mandatory terms-of-service acceptance gate before account creation completes:

1. **Age check** — user must confirm they meet the minimum age requirement.
2. **TOS / Privacy Policy / Safety Standards agreement** — user is presented with all three documents. Each document title is a clickable link that opens the full text (`divine.video/terms`, `divine.video/privacy`, `divine.video/safety`).
3. **Disabled continue button** — the continue/create-account button remains disabled until the user has checked the acceptance checkbox.
4. **No bypass** — the flow cannot be skipped; the app does not proceed to the main experience without explicit acceptance.

This ensures Apple reviewers can verify that users agree to content policies before participating in the platform.
