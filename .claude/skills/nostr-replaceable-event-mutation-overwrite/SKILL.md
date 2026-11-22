---
name: nostr-replaceable-event-mutation-overwrite
description: |
  Fix silent data loss when mutating Nostr replaceable events (Kind 0 profile, Kind 3 contact/follow
  list, Kind 10002 relay list, etc.) in client apps. Use when: (1) Following someone wipes the user's
  entire follow list, (2) Updating profile metadata loses existing fields, (3) Fresh browser session
  or mobile login causes data loss on first action, (4) Replaceable event mutation uses stale or null
  cached state, (5) A republish is built from a relay read that did not finish (in divine-mobile:
  `queryEvents`, or `queryEventsDetailed` without `requireAllRelaysSettled`). Root cause: Nostr
  replaceable events are full-replace (no partial update), so publishing based on stale/unloaded
  cache, or on a read some relay never answered, overwrites the canonical version. Applies to any
  Nostr client using React, Flutter, or similar reactive frameworks where query state may not be
  loaded when a mutation fires.
author: Claude Code
version: 1.2.0
date: 2026-11-22
---

# Nostr Replaceable Event Mutation Overwrite

## Problem

Nostr replaceable events (Kind 0, 3, 10002, etc.) use a full-replace model: publishing a new
event completely replaces the previous one. If a client publishes a mutation based on stale,
incomplete, or null cached state, it silently overwrites the canonical version on relays, causing
data loss. The most common case is follow list (Kind 3) wipes when a user follows someone before
the client has loaded their existing contact list.

## Context / Trigger Conditions

- User reports "I followed someone and lost all my other follows"
- Follow/unfollow action on a fresh browser session or mobile login
- Profile update loses existing metadata fields
- Relay list update drops existing relays
- Any mutation on a replaceable event where the UI passes cached state to the mutation function
- React Query / TanStack Query `data` is `undefined` when mutation fires (query still loading)
- The mutation function accepts the current event as a parameter from the UI layer

## Solution

### 1. Always Fetch Fresh State Inside the Mutation

Never rely solely on the UI's cached/query state. Fetch the latest version of the replaceable
event directly from the relay inside the mutation function, before publishing:

```typescript
// BAD: Relies on UI cache which may be null/stale
mutationFn: async ({ targetPubkey, currentContactList }) => {
  const currentTags = currentContactList?.tags || []; // null -> [] -> data loss!
  // ... publish with only the new follow
}

// GOOD: Fetches fresh from relay before mutating
mutationFn: async ({ targetPubkey, currentContactList }) => {
  let bestContactList = currentContactList;

  try {
    const relayEvents = await nostr.query([
      { kinds: [3], authors: [userPubkey], limit: 1 },
    ], { signal: AbortSignal.timeout(5000) });

    const relayContactList = relayEvents
      .sort((a, b) => b.created_at - a.created_at)[0] || null;

    if (relayContactList) {
      // NIP-01 already fixes which copy of a replaceable event wins:
      // the higher created_at, and on an exact tie the lower event id.
      // Never compare tag counts — a shorter list is what a legitimate
      // unfollow produces.
      const passed = currentContactList;
      const isNewer =
        !passed ||
        relayContactList.created_at > passed.created_at ||
        (relayContactList.created_at === passed.created_at &&
          relayContactList.id < passed.id);
      if (isNewer) {
        bestContactList = relayContactList;
      }
    }
  } catch {
    // The read failed. It cannot be told apart from "the relay holds
    // nothing", so refuse to publish rather than replacing from a guess.
    throw new Error('Could not confirm the current list. Please try again.');
  }

  if (!bestContactList) {
    // Only safe once the read is known to have finished (section 3): then
    // no list exists yet, and this publish creates the first one.
    bestContactList = { tags: [], content: '' };
  }

  // Now mutate bestContactList...
}
```

### 2. Newest Wins, Per NIP-01

Order the relay's version against the cached one by `created_at`, and on an exact tie by
the lower event id. That is the rule relays themselves apply, so it is the only choice
that converges.

**Do not compare tag counts.** "Use whichever has MORE data" looks safe and is not: the
newer, authoritative list is *shorter* whenever the user removed someone, so preferring
the longer copy silently resurrects every unfollow, unmuted account, or deleted relay —
and republishes it. The heuristic cannot tell "this copy is stale" from "the user removed
something", because those two produce the identical shape.

A source that carries no timestamp at all — a bare cached array, a derived REST index —
has unknowable freshness, not old freshness. It may seed an empty state, but it must lose
to any copy that can name a `created_at`.

Worked example, including the persistence migration that gives the local cache a
timestamp to be ordered by: divinevideo/divine-mobile#8266.

### 3. Refuse to Publish When the Read Did Not Finish

A read for the current version has three outcomes, not two:

- **found**: replace the newest copy, ordered as in section 2.
- **absent**: every relay asked answered, and none holds a list. Publishing the first one
  is safe.
- **failed**: the read threw, or a relay timed out, refused the request, dropped the
  connection, or was never asked. Do not publish, even when the read returned an event or
  a cached copy exists: a partial answer can carry an older version than the relay that
  stayed silent. Keep the edit local and retry later. A user-facing error is always better
  than silent data loss.

Many clients do not throw on an unfinished read. They return whatever arrived, so a
`catch` block never sees the failure. Find out how your client reports an unfinished read
before trusting one. Section 4 covers divine-mobile.

### 4. In divine-mobile, Ask NostrClient Whether the Read Finished

`NostrClient` never throws on a timeout or a relay `CLOSED`. Read the base of a
replacement like this:

```dart
final read = await nostrClient.queryEventsDetailed(
  [Filter(authors: [pubkey], kinds: const [EventKind.contactList])],
  requireAllRelaysSettled: true,
);
if (read.timedOut || read.noRelays) {
  // failed: a relay that stayed silent, refused, or was never asked may
  // hold a newer list than anything this read returned. Do not publish.
  return false;
}
// found or absent: the relays that were asked all answered.
final newest = pickNewest(read.events); // created_at, then lowest id
```

- `queryEvents` returns only the events and drops both flags. Never use it to read a base
  you are about to replace.
- Without `requireAllRelaysSettled: true`, `timedOut` is set only when the deadline fires.
  A relay that sends `CLOSED`, drops its socket, or stays silent past the one-second settle
  window comes back as `timedOut: false` with whatever the other relays sent.
- `readEvents` returns a `QueryResult` instead. Act only when `isComplete` is true, and for
  a list read also when `possiblyCapped` is false.
- A settled read waits for a silent relay until its timeout. A shorter timeout errs toward
  not publishing, which is the safe direction: the DM inbox read uses 3 seconds.
- Worked examples: `_refreshCurrentUserContactList` in `follow_repository.dart`,
  `_readAuthoritative` in `profile_pins_repository.dart`, and `_publishForPubkey` in
  `relay_list_repository.dart`. divinevideo/divine-mobile#8258 lists every fixed site with
  the tests that fail if its refusal is removed.

### 5. Apply to Both Directions

Apply this pattern to ALL mutation directions (follow AND unfollow, add AND remove relay,
update AND clear profile fields). The unfollow path is just as dangerous as follow.

## Verification

Cold-start overwrite:

1. Open the app in a private/incognito browser window
2. Log in with an account that has multiple follows
3. Navigate to a profile and tap Follow IMMEDIATELY (before the page fully loads)
4. Check that the follow count increased by 1 (not reset to 1)

Cross-device removal — the case a tag-count heuristic passes and still corrupts:

5. On a second client, unfollow two of several accounts
6. Cold-start the first client and confirm the removals are still gone
7. Follow one new account there, then read the relay's kind 3 back and confirm
   the two removed accounts did not reappear in its `p` tags

Partial read — the case a check that only catches thrown errors passes and still corrupts:

8. Point the client at two relays and make one of them refuse the read (`CLOSED`) or
   never answer it. In divine-mobile, a unit test does this with a scripted relay; see the
   tests listed on divinevideo/divine-mobile#8258
9. Follow someone and confirm that nothing is published until both relays answer

## Example

A follow mutation that follows sections 1-3. It assumes a `nostr.query` that rejects when a
relay does not finish; if yours resolves with a partial list instead, check its completion
flag where the comment says so.

```typescript
const newest = (events) =>
  events
    .filter(Boolean)
    .sort((a, b) => b.created_at - a.created_at || (a.id < b.id ? -1 : 1))[0];

export function useFollowUser() {
  const { nostr } = useNostr();

  return useMutation({
    mutationFn: async ({ targetPubkey, currentContactList }) => {
      // Step 1: read the relays' current list. A read that did not finish
      // is a failure, never an empty answer.
      let relayList;
      try {
        const events = await nostr.query(
          [{ kinds: [3], authors: [user.pubkey], limit: 1 }],
          { signal: AbortSignal.timeout(5000) },
        );
        // A client that resolves on a partial answer: check completion here.
        relayList = newest(events);
      } catch {
        throw new Error('Could not confirm your follow list. Please try again.');
      }

      // Step 2: newest wins per NIP-01, never the longer list. With neither
      // copy, the finished read proved there is no list yet.
      const base = newest([relayList, currentContactList]) ?? { tags: [], content: '' };

      // Step 3: mutate the newest copy and publish it.
      const tags = [...base.tags, ['p', targetPubkey]];
      return publishEvent({ kind: 3, tags, content: base.content });
    },
  });
}
```

## Notes

- This pattern applies to ALL Nostr replaceable event kinds: Kind 0 (profile), Kind 3
  (contacts), Kind 10002 (relay list), Kind 10000 (mute list), Kind 30000+ (addressable)
- The race condition is most common on mobile browsers where network is slower and users
  tap quickly
- Safety check dialogs (like "are you sure?") don't help because they check the same
  stale cache - the fix must be inside the mutation itself
- A read that waits for every relay costs up to its whole timeout when one relay stays
  silent. Erring short is safe: an expired read is a failed read, and a failed read
  publishes nothing
- Consider also disabling the mutation button while the initial query is loading, as a
  belt-and-suspenders approach
