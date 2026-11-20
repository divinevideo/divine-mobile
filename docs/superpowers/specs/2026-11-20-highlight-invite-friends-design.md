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

- The highlight card comes from #10594 and #10772; its author should review.
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
2. A separate small card under the highlight. Leaves the existing card code
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
- **Row:** "Bring your friends →" in the card's accent style, on the
  same line as "See your stats →" (it drops to a second line only when
  both don't fit, such as large text or longer translations). Its own
  tap target, so tapping it does not open stats.
- **Tap:** opens a full-screen "Bring your friends" page (revised after
  the first simulator review: people should see and edit the message
  before picking an app, and the share sheet alone only shows a cut-off
  preview). The page has:
  - an editable text box holding the default message:

    > I'm making loops on Divine. You can react and collaborate with me!

  - the download link (`AppConstants.downloadUrl`,
    `https://divine.video/download`) shown below the text box and always
    added on its own line when shared, so editing the message cannot drop
    it;
  - a Share button that opens the system share sheet through
    `showShareSheet`, anchored to the button, with the edited message and
    the link. If the box is cleared, only the link is shared.
- **After sharing (my call):** a completed share returns to Inbox; a
  dismissed share sheet leaves the person on the page to try again.
- **No new dependencies, permissions, or backend changes.** The page is a
  typed route like the rest of the app.

```
┌──────────────────────────────────────┐
│ ✦ Your daily highlight               │
│ You made 2 videos today.             │
│ 2 creative days this week.           │
│                                      │
│ See your stats →   Bring your friends →│
└──────────────────────────────────────┘

┌ ← Bring your friends ────────────────┐
│ ┌──────────────────────────────────┐ │
│ │ I'm making loops on Divine. You  │ │
│ │ can react and collaborate with   │ │
│ │ me!                              │ │
│ └──────────────────────────────────┘ │
│ divine.video/download                │
│                                      │
│            [ Share ]                 │
└──────────────────────────────────────┘
```

## Verification

- The product owner reviews it running in the iOS simulator before the PR is opened
  for peer review.
- Staging is down outside specific windows, and the local stack cannot
  produce a post from the simulator (the app only accepts clips from its
  own camera). So the review uses a throwaway demo build against
  production whose highlight card always reports a post today; the demo
  change is never committed.
- Demo path: open Inbox, see the row, tap it, edit the message, share.
  Also show the row hidden after the weekly limit.

## Left to the builder

- Where the weekly count lives (repository alongside the presentation
  marker is the likely fit) and its key shape.
- Exact widget structure and semantics labels.
- Tests: cubit/repository tests for the posting-day rule and weekly
  limit; widget tests that tapping the row opens the invite page and not
  stats, and that sharing hands the share sheet the edited message plus
  the link (and only the link when the message is cleared).
