# Invite friends to Divine (short design)

## Intent

Make it easy for people to get their friends onto Divine. A user taps
"Invite friends," picks how to send it (Messages, Mail, WhatsApp,
whatever their phone offers), and their friend gets a link to download
the app from the App Store or Google Play.

This version is deliberately barebones. It should still feel good to use,
but it does nothing beyond helping someone share the app.

## Goals

- A clear, friendly way to share Divine from inside the app.
- One link that works for every friend, whatever phone they have.
- An honest note in the app about what Divine does not see.

## Non-goals (this version)

- Referral tracking or attribution of any kind ("who signed up from whom").
- Credit, rewards, or invite counts.
- Reading the address book or asking for contacts permission.
- Invite codes or gating. Invite-based onboarding is retired (divine-context
  ARCHITECTURE.md, "Retiring invite infrastructure"); this must not bring it
  back.

## Anti-goals

- Anything that sends Divine information about who was invited, how many,
  through which app, or whether they joined. People will assume the worst,
  so the feature has to be clean by construction, not by policy.

## What Divine does not get

Shown in the app and repeated in the PR:

- Your contacts. The app never reads the address book and never asks for
  contacts permission.
- Who you sent it to, which app you used, or how many people.
- Whether anyone opened the link or joined.

One honest caveat: the link opens divine.video/download, and divine.video
counts page views the way any website does. The visit is anonymous and the
link carries nothing about who sent it.

## Approaches considered

1. **Link to `https://divine.video/download` (picked).** The page already
   exists in divine-web. It shows the right store for the visitor's phone
   (App Store on iPhone, Google Play and Zapstore on Android, both on
   desktop), needs no account, and has a link preview. One short link works
   for every recipient.
2. **Paste both store links into the message.** Avoids divine.video
   entirely, but the message is clunky (two long URLs, two previews) and the
   friend has to pick. Rejected.
3. **Send only the store for the inviter's own platform.** Breaks whenever
   an iPhone user invites an Android friend. Rejected.

## Design

- **Entry point:** an "Invite friends" row on the main Settings screen
  (`mobile/lib/screens/settings/settings_screen.dart`), alongside the
  existing `DivineListTile` rows.
- **Screen:** a simple full-screen page (not a dialog or sheet, per repo
  UI rules) with a short pitch, a primary **Share invite** button, and the
  "what Divine doesn't see" note. Light and dark themes via
  `context.vineColors`.
- **Share:** the button opens the system share sheet through
  `showShareSheet` in `mobile/lib/utils/share_sheet.dart` (the only allowed
  share entry point; it handles the iPad anchor). The shared text is a
  localized message ending with the download link.
- **Link:** a single named constant holding
  `https://divine.video/download`. No query parameters, no fragment, nothing
  identifying the sender. The same link in every build environment.
- **No analytics.** Opening the screen and tapping Share fire no analytics
  events and make no network calls. The share result is not recorded.
- **No new dependencies, permissions, or backend changes.** `share_plus` is
  already in the app; no `Info.plist` or Android manifest changes.

Draft copy (final wording to follow `brand-guidelines/TONE_OF_VOICE.md`):

```
Invite friends

Divine is better with your people. Send them the app.

        [ Share invite ]

Divine doesn't see who you send this to or whether they join.
```

Share message: "I'm on Divine. Six-second loops from real people. Get the
app: https://divine.video/download"

## Left to the builder

- Exact widget structure (Page/View split if wiring warrants it; likely a
  plain stateless screen since there is no state).
- Route path and naming: a `@TypedGoRoute` class with its path in
  `RoutePaths`, per `.claude/rules/routing.md`.
- ARB keys, mirrored to every locale or added to the known-untranslated
  list, each read through `context.l10n` in the same change.
- Tests: a widget test that tapping Share hands the share sheet a message
  containing the exact download link and nothing identifying the user.
  Golden only if the screen warrants it.

## PR framing

The PR description leads with what this is: a barebones way to invite
friends to download Divine, with no tracking, no referral credit, and no
contacts access. It includes the "What Divine does not get" list above.
