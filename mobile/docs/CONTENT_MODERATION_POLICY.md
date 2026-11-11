# Content Moderation Policy

## Overview

Divine is committed to maintaining a safe and welcoming environment for all users. This document outlines our content moderation processes and compliance with Apple App Store requirements for user-generated content applications.

## Apple App Store Compliance

Divine fully complies with Apple's requirements for user-generated content apps (App Store Review Guideline 1.2):

### ✅ Method for Filtering Objectionable Content

**Implementation:**
- Client-side content filtering via `ContentPolicyEngine` — a pure-Dart rules engine (SelfReference, PubkeyMute, PubkeyBlock, MutualMute) that gates every feed/search/profile/comment/notification ingress seam
- User-managed block/mute state via `ContentBlocklistRepository`, which exposes an immutable `ContentPolicyState` snapshot to the engine and a `shouldFilterFromFeeds` predicate covering own blocks (kind 30000 `d=block`), own mutes (kind 10000), and mutual block/mute
- Multiple report categories: spam, harassment, violence, sexual content, copyright violations, misinformation, CSAM, and AI-generated content

**Location:**
- `packages/content_policy/` (ContentPolicyEngine and rules)
- `packages/content_blocklist_repository/lib/src/content_blocklist_repository.dart` (ContentPolicyState + shouldFilterFromFeeds)

### ✅ Mechanism to Report Offensive Content

**Implementation:**
- NIP-56 compliant reporting system (kind 1984 events)
- Report dialog accessible from the video action rail and user profile more menu
- Reports published to `wss://relay.divine.video` (Divine moderation relay)
- 9 distinct report categories

**Location:**
- `lib/services/content_reporting_service.dart`
- `lib/widgets/video_feed_item/actions/report_action_button.dart` (video report entry point)
- `lib/widgets/report_content_dialog.dart` (ReportContentDialog)
- `lib/screens/other_profile_screen.dart` (user report entry point)

### ✅ Ability to Block Abusive Users

**Implementation:**
- Block/Unblock functionality in the user profile more menu
- Blocked users filtered from all feeds (home, explore, hashtag)
- Users can still explicitly visit blocked profiles (maintaining Nostr decentralization principles)

**Location:**
- `packages/content_blocklist_repository/lib/src/content_blocklist_repository.dart`
- `lib/screens/other_profile_screen.dart` (block/unblock action handling)
- `lib/widgets/profile/more_sheet/` (block/unblock menu and confirmation views)

### ✅ Timely Response to Reports (24-Hour SLA)

**Implementation:**
Divine monitors all content reports published to `wss://relay.divine.video` and commits to the following response times:

**Response Time Commitment:**
> Divine will act on content reports within 24 hours by removing the content and ejecting the user who provided the offending content.

This policy is displayed to users in the report dialog.

**Moderation Process:**

1. **Report Submission**
   - User reports content via ReportContentDialog
   - Report published as kind 1984 event to `wss://relay.divine.video`
   - Report includes: event ID, author pubkey, reason, details, timestamp
   - A report made from a direct message (a message, or the account from a
     conversation or the inbox) is not published: it goes to the moderation
     account as an encrypted NIP-17 message, optionally with the reported
     message as an unverified excerpt (#7340). The message names the
     reported account in a `reported_pubkey` tag, which the moderation
     service turns into a review item for that account

2. **Report Monitoring**
   - Divine moderation team monitors `wss://relay.divine.video` for kind 1984 events
   - New reports trigger alerts to moderation team
   - Reports reviewed within 24 hours

3. **Content Review**
   - Moderation team reviews reported content
   - Determines if content violates community guidelines
   - Takes appropriate action based on severity

4. **Action Taken**
   - **Content Removal:** Offending event deleted from Divine relays
   - **User Ejection:** Offending user's pubkey banned from Divine relays
   - **Reporter Notification:** (Future enhancement) Notify reporter of action taken

5. **Appeals Process**
   - Users can appeal moderation decisions via `contact@divine.video`
   - Appeals reviewed by separate team member
   - Response provided within 48 hours

### ✅ Published Contact Information

**Support Email:** contact@divine.video

**Bug Reports:**
- In-app bug report system (`lib/services/bug_report_service.dart`)
- API endpoint: `https://bug-reports.protestnet.workers.dev/api/bug-reports`

**Location:**
- Settings > Support > Report a Bug
- Settings > Safety & Privacy

## Content Categories

Divine recognizes the following violation categories:

1. **Spam or Unwanted Content** - Repetitive, commercial, or off-topic content
2. **Harassment, Bullying, or Threats** - Targeted abuse, intimidation, or threatening behavior
3. **Violent or Extremist Content** - Graphic violence, terrorism, or hate speech
4. **Sexual or Adult Content** - Pornography, nudity, or sexually explicit material
5. **Copyright Violation** - Unauthorized use of copyrighted material
6. **Misinformation** - Deliberately false or misleading information
7. **Child Safety Concern (CSAM)** - Any content exploiting minors (immediate escalation to law enforcement)
8. **Suspected AI-Generated Content** - Content that may violate authenticity requirements
9. **Other Violation** - Any other community guideline violations

## Severity Levels

Divine uses a four-tier severity system:

- **Info** - Informational only, no action required
- **Warning** - Show warning but allow viewing
- **Hide** - Hide by default, show if user requests
- **Block** - Completely block content, remove from all feeds

## Decentralization Principles

While Divine maintains strict content moderation policies, we respect the decentralized nature of the Nostr protocol:

- **Client-Side Filtering:** Users maintain control over their own blocklists and mute lists via NIP-51
- **Relay Independence:** Users can connect to other relays for uncensored access
- **Profile Visibility:** Blocked users' profiles remain accessible if explicitly visited
- **Data Sovereignty:** User reports and moderation actions are published as Nostr events

## Moderation Team

**Responsible Party:** Divine moderation team
**Contact:** contact@divine.video
**Response Time:** 24 hours for content reports, 48 hours for appeals

## Legal Compliance

Divine complies with:
- Apple App Store Review Guidelines (1.2 User-Generated Content)
- U.S. federal law (COPPA, DMCA, etc.)
- International content moderation standards

**CSAM Policy:** Any reports of child sexual abuse material (CSAM) are immediately escalated to the National Center for Missing & Exploited Children (NCMEC) and law enforcement as required by law.

## Updates to This Policy

This policy may be updated periodically. Users will be notified of material changes via in-app notifications.

**Last Updated:** November 10, 2025
**Version:** 1.0
