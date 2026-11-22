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

Fetch the current revision inside the mutation, before publishing. Filter by author and
kind, and include the `d` tag for an addressable event. Only compare cached or locally
accepted revisions of that same event. See the [follow example](#example) below.

### 2. Newest Wins, Per NIP-01

Order the relay's version against the cached one by `created_at`, and on an exact tie by
the lower event id. That is the rule relays themselves apply, so it is the only choice
that converges. Use the publisher's timestamp policy to give the replacement a later
`created_at` than the selected base.

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
- **absent**: the required network read completed without truncation or a matching event,
  and there is no locally accepted revision to preserve. The mutation can create the first event.
- **failed**: the read threw, a required relay did not answer, or the answer may have
  omitted the newest revision. Keep the edit local and retry later, even if the read returned
  an older revision or a cached copy exists.

Many clients do not throw on an unfinished read. They return whatever arrived, so a
`catch` block never sees the failure. Find out how your client reports an unfinished read
before trusting one. Section 4 covers divine-mobile.

### 4. In divine-mobile, Ask NostrClient Whether the Read Finished

`NostrClient` never throws on a timeout or a relay `CLOSED`. Read the base of a
replacement like this:

```dart
final read = await nostrClient.readEvents(
  [Filter(authors: [pubkey], kinds: const [EventKind.contactList])],
  relayTypes: RelayType.network,
  useCache: false,
  requireAllRelaysSettled: true,
);
if (!read.isComplete || read.possiblyCapped) {
  return false;
}
// Select the newest matching revision, then apply the pending edit.
```

- `queryEvents` returns only the events and drops both flags. Never use it to read a base
  you are about to replace.
- With `queryEventsDetailed`, check `timedOut || noRelays` and set `requireAllRelaysSettled`.
  A default read can return `timedOut: false` after `CLOSED`, a dropped socket, or the
  one-second settle window. Leave `acceptRelayClosedWhenOthersAnswered` disabled when the
  mutation needs the refusing relay's answer.
- Both `queryEventsDetailed` and `queryEventsOnFreshConnections` drop `possiblyCapped`.
  When a relay finishes with a `more` hint and no usable event, it can be complete and still
  have withheld the only matching revision. This example rejects potentially capped reads.
  Use the cap flag or other evidence that the newest revision was included before publishing.
- `useCache: false` excludes the database cache. `RelayType.network` also excludes cache
  relays, which can otherwise complete a query without any network relay answering.
- Full settlement covers relays that took the request. A disconnected relay can be skipped
  during dispatch while another relay returns a complete answer. For specific required relays,
  run `readEvents` against each URL using `tempRelays: [url]` and `relayTypes: RelayType.onlyTemp`.
  Require a complete, usable answer from each. `queryEventsOnFreshConnections` also checks
  required relay participation when called with `requiredRelays`, but only reports settlement.
- Keep a global `limit` off the replacement read unless the client applies the same ordering
  before truncating. `NostrClient` merges with a timestamp-only sort when a limit trims the
  result, so it can drop the lowest ID among events tied for newest.
- A settled read can spend the whole timeout waiting for a silent relay. The follow
  repository uses three seconds and withholds the publish if the read expires.
- Examples of checking the settlement flags: `_refreshCurrentUserContactList` in
  `follow_repository.dart`, `_readAuthoritative` in `profile_pins_repository.dart`, and
  `_publishForPubkey` in `relay_list_repository.dart`. These callers use their existing relay
  scopes. divinevideo/divine-mobile#8258 lists the tests that fail if the checks are removed.

### 5. Apply to Both Directions

Apply this pattern to ALL mutation directions (follow AND unfollow, add AND remove relay,
update AND clear profile fields). The unfollow path is just as dangerous as follow.

Within a client, serialize edits to the same event from the read through the publish
acknowledgement. Remember the accepted revision before the next edit starts because a relay
can acknowledge a publish before serving the revision on a read.

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

Partial read:

8. Have one relay return an older contact list and finish the read. Have the other relay
   refuse the read (`CLOSED`) or accept the request and stay silent.
9. Follow someone and confirm the failed read leaves the publish count at zero. Retry with
   the second relay returning a newer list. Check that the publish preserves it and adds the follow.
   Also verify that a cache-only answer, a missed required relay, or an empty answer with a
   `more` hint cannot authorize a publish.

## Example

A follow mutation that assumes `nostr.query` rejects when a required relay fails to finish
or the newest revision may have been omitted. If the client returns partial answers, check
settlement and truncation before using the events. The illustrative `publishEvent` helper
returns the signed revision after relay acceptance and rejects if it cannot assign a valid
timestamp later than `newerThan`.
The client shares a store of last accepted revisions by account. Follow and unfollow use
the same TanStack Query v5 scope in the same query client. [Mutation scopes](https://tanstack.com/query/latest/docs/framework/react/guides/mutations#mutation-scopes)

```typescript
type ContactList = {
  id: string;
  created_at: number;
  tags: string[][];
  content: string;
};

function newest(events: (ContactList | null | undefined)[]) {
  return events.filter((event) => event != null).sort((a, b) => {
    if (a.created_at !== b.created_at) return b.created_at - a.created_at;
    if (a.id === b.id) return 0;
    return a.id < b.id ? -1 : 1;
  })[0];
}

export function useFollowUser(pubkey: string) {
  const { nostr } = useNostr();

  return useMutation({
    scope: { id: `contact-list:${pubkey}` },
    mutationFn: async (targetPubkey: string) => {
      let events: ContactList[];
      try {
        events = await nostr.query(
          [{ kinds: [3], authors: [pubkey] }],
          { signal: AbortSignal.timeout(5000) },
        );
      } catch {
        throw new Error('Could not confirm your follow list. Please try again.');
      }

      const base = newest([...events, lastAcceptedContactList(pubkey)]);
      const tags = [...(base?.tags ?? [])];
      if (tags.some(([kind, value]) => kind === 'p' && value === targetPubkey)) return;
      tags.push(['p', targetPubkey]);
      const accepted = await publishEvent(
        { pubkey, kind: 3, tags, content: base?.content ?? '' },
        { newerThan: base?.created_at },
      );
      rememberAcceptedContactList(pubkey, accepted);
      return accepted;
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
