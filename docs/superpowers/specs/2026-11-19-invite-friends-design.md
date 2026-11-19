# Invite friends to Divine (short design)

## Intent

Make it easy for people to get their friends onto Divine. A user taps
"Invite friends," picks how to send it (Messages, Mail, WhatsApp,
whatever their phone offers), and their friend gets a link to download
the app from the App Store or Google Play.

This is a first version: get it available, keep it simple, make it feel
good to use, and enhance it as we learn what people need.

## Goals

- A clear, friendly way to share Divine from inside the app.
- One link that works for every friend, whatever phone they have.
- Small enough to ship quickly and build on.

## Scope of this version

In:
- A share flow that sends a download link through the system share sheet.

Not in this version (candidates for later iterations):
- Picking friends from device contacts inside the app.
- Knowing which signups came from an invite.
- Rewards or invite counts.

Constraint: invite-based onboarding is retired (divine-context
ARCHITECTURE.md, "Retiring invite infrastructure"), so this must not add
invite codes or gate signup.

## Approaches considered

1. **Link to `https://divine.video/download` (picked).** The page already
   exists in divine-web. It shows the right store for the visitor's phone
   (App Store on iPhone, Google Play and Zapstore on Android, both on
   desktop), needs no account, and has a link preview. One short link works
   for every recipient.
2. **Paste both store links into the message.** The message is clunky (two
   long URLs, two previews) and the friend has to pick. Rejected.
3. **Send only the store for the inviter's own platform.** Breaks whenever
   an iPhone user invites an Android friend. Rejected.

## Design

- **Entry point:** an "Invite friends" row on the main Settings screen
  (`mobile/lib/screens/settings/settings_screen.dart`), alongside the
  existing `DivineListTile` rows.
- **Screen:** a simple full-screen page (not a dialog or sheet, per repo
  UI rules) with a short pitch and a primary **Share invite** button. Light
  and dark themes via `context.vineColors`.
- **Share:** the button opens the system share sheet through
  `showShareSheet` in `mobile/lib/utils/share_sheet.dart` (the only allowed
  share entry point; it handles the iPad anchor). The shared text is a
  localized message ending with the download link.
- **Link:** a single named constant holding `https://divine.video/download`,
  the same in every build environment.
- **No new dependencies, permissions, or backend changes.** `share_plus` is
  already in the app; no `Info.plist` or Android manifest changes.

Draft copy (final wording to follow `brand-guidelines/TONE_OF_VOICE.md`):

```
Invite friends

Divine is better with your people. Send them the app.

        [ Share invite ]
```

Share message: "I'm on Divine. Six-second loops from real people. Get the
app: https://divine.video/download"

## Left to the builder

- Exact widget structure (likely a plain stateless screen, since there is
  no state).
- Route path and naming: a `@TypedGoRoute` class with its path in
  `RoutePaths`, per `.claude/rules/routing.md`.
- ARB keys, mirrored to every locale or added to the known-untranslated
  list, each read through `context.l10n` in the same change.
- Tests: a widget test that tapping Share hands the share sheet a message
  containing the download link. Golden only if the screen warrants it.

## PR framing

Lead with what this is: a simple, first-version way for people to invite
friends to download Divine from the App Store or Google Play, built to
ship now and improve as we go.
