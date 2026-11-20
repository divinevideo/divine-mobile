# Invite friends from the daily highlight (short design)

## Intent

When a creator has just made something, ask them to bring their friends
onto Divine. The daily highlight card in Inbox already appears only for
creators who posted this week and celebrates what they made, so it is the
moment to ask. The pitch is about more than watching: friends on Divine
can react, comment, and collab with you.

This is a first version. We expect to iterate on the copy, timing, and
what gets shared.

## Goals

- A friendly, low-pressure invite at a moment of pride.
- Tied to new content: it shows only on days the creator posted.
- Uses the same download link and share flow as Settings.

Non-goals for this version: sharing the creator's video instead of the
download link, invite rewards or counts, knowing which signups came from
an invite.

Anti-goals: it must not read as an ad, interrupt the Inbox, or appear so
often it becomes wallpaper.

## Constraints

- The highlight card is rabble's (#10594, #10772); he should review.
- Invite codes and signup gating are retired; this adds neither.
- Eligibility logic lives below the widget (cubit/repository), per the
  repo's layering rules.
- New ARB keys are read in the same change and mirrored to every locale
  or recorded as known untranslated debt.
- Any new preference key is account-scoped and classified for
  account-switch cleanup.

## Approaches

1. **An invite line inside the highlight card (picked).** One more row
   under "See your stats →". Smallest change, and it reads as part of
   the celebration.
2. A separate small card under the highlight. Leaves rabble's code
   alone, but two stacked cards read more like an ad and re-derive
   "posted today."
3. Option 1, sharing today's video instead of the download link. Shows
   the friend the actual loop, but depends on how the web video page
   treats someone without the app, which is unverified. Candidate for a
   later iteration.

## Design

- **When:** the row shows when the day's highlight has
  `createdToday > 0`, whichever fact the card is rotating through that
  day.
- **How often (my call, adjustable):** at most 3 posting days per week
  per account, counted when the row is actually seen (the card already
  records visible presentation; the invite count rides the same moment).
- **Row:** "Bring your friends in →" in the card's accent style, under
  "See your stats →". Its own tap target, so tapping it does not open
  stats.
- **Tap:** opens the system share sheet through `showShareSheet` with a
  localized message ending in `AppConstants.downloadUrl`
  (`https://divine.video/download`). Draft message, final wording per
  `brand-guidelines/TONE_OF_VOICE.md`:

  > Come make loops with me on Divine. React, comment, and collab with
  > me in the app: https://divine.video/download

- **No new dependencies, permissions, or backend changes.**

```
┌──────────────────────────────────────┐
│ ✦ Your daily highlight               │
│ You made 2 videos today.             │
│ 2 creative days this week.           │
│                                      │
│ See your stats →                     │
│ Bring your friends in →              │
└──────────────────────────────────────┘
```

## Verification

- Matt reviews it running in the iOS simulator before the PR is opened
  for peer review.
- Run against the local stack (`local_stack/`), not staging, which is
  down outside specific windows. For the iOS simulator, export
  `BLOSSOM_PUBLIC_URL=http://localhost:43003` before `local_stack/up.sh`.
- Demo path: sign in to a local account, post a loop, open Inbox, see
  the row, tap it to open the share sheet. Also show the row hidden on a
  day with no post and after the weekly limit.

## Left to the builder

- Where the weekly count lives (repository alongside the presentation
  marker is the likely fit) and its key shape.
- Exact widget structure and semantics labels.
- Tests: cubit/repository tests for the posting-day rule and weekly
  limit; a widget test that tapping the row hands the share sheet a
  message containing the download link and does not open stats.
