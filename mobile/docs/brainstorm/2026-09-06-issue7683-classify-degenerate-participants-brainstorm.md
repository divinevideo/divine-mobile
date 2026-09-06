# Brainstorm: #7683 — degenerate participant sets in `classifyPotentialRequests`

Date: 2026-09-06
Seeded by: investigation of #7683 and the surrounding DM history
Issue: https://github.com/divinevideo/divine-mobile/issues/7683 · Epic: #8229

## Problem Statement

#7683 asks to remove a "redundant" `otherPubkeys.isEmpty` early-return guard in
`DmRepository.classifyPotentialRequests`. **That guard does not exist and never did.** Full git
history shows the empty check was always a disjunct inside one `if` (introduced #2219, unchanged
through #5387) and was **deleted by #6294 — the very PR the issue cites as its context**. The
issue's literal ask is a no-op.

Underneath it sit two real, verified residuals: the empty-participant route to the inbox is now
implicit/undocumented/untested vacuous truth, and the self-filter is case-sensitive against a
documented in-repo convention that it should not be.

## Constraints

- Layered architecture; classification stays in the Repository layer, while the UI/BLoC consumers
  share one pure peer-resolution helper.
- `.claude/rules/testing.md`: a test must be able to fail for a real reason.
- Epic #8229 success criterion: *"a DM docstring is evidence of what the code does."*
- `dm_repository_test.dart` sits at **14** in `mobile/scripts/baseline/shared_setup_stubs.txt` — a
  ceiling that may only shrink, so any new stub must go in a leaf group.
- `tasks/lessons.md` (#5374): do not ship a fix whose premise is an unobservable on-device value.
- Report-only on GitHub until explicitly authorized.

## Prior Art

- `mobile/lib/blocs/dm/minor_dm_approval.dart` — `allParticipantsApprovedForMinor` documents why an
  empty counterparty list must fail closed.
- `_isSelf` (`dm_repository.dart:8961`) + `pubkeysEqual` — the case-insensitive self-compare and the
  dartdoc explaining why exact `==` is wrong.
- #8261 (closed) — Divine does **not** support self-addressed conversations. #8351 shipped the
  send-side refusal.
- `tasks/lessons.md` #5374 — a prior wrong-theory fix on this same function.

## Approaches Explored

### Approach A: Hide self-only rows + case-insensitive self-filter  ← RECOMMENDED
**Description:** Compare self case-insensitively and omit a conversation from both lists when no peer remains.
Document both in the dartdoc, citing #8261 and #6294. Add regression tests.
**Layers affected:** Repository classification and the UI/BLoC peer resolvers that consume it.
**Pros:** Correct whether or not the state is reachable. A degenerate row is logged explicitly but
never exposed through actions that would target the viewer.
**Cons:** Changes behaviour for a malformed state.
**Risks:** If a degenerate row is reachable, its thread disappears from both lists. Under #8261 that
is the correct destination because every available action would target the viewer.
**Complexity:** Low.

### Approach B: Extract a shared `allParticipantsFollowed` predicate
**Description:** Mirror `minor_dm_approval.dart` exactly — a small file with a documented predicate,
called from classify.
**Pros:** Follows the closest structural precedent. Directly unit-testable without constructing
conversations.
**Cons:** **Only one call site exists.** Speculative reuse; YAGNI.
**Complexity:** Low–Medium.

### Approach C: Route self-only rows to Message requests
**Description:** Keep the row visible but move it out of the main inbox.
**Pros:** Most self-documenting.
**Cons:** The row remains unusable, and Report, Block, and Mute still target the viewer.
**Complexity:** Low.

### Approach D: Normalize pubkey case at ingest/storage
**Description:** Lowercase pubkeys in `_extractParticipants` and on write, killing the H4a class.
**Pros:** Root-cause rather than per-site.
**Cons:** **`computeConversationId` is case-sensitive**, so normalizing changes ids for any existing
mixed-case row — splitting or merging threads and requiring a Drift migration. All of it for a
defect scored **0.10 reachable**. This is the #5478 mistake `lessons.md` records: a wide fix on an
unobservable premise.
**Complexity:** High. **Rejected.**

## Recommendation

**Approach A**, adopting C's comment discipline in the dartdoc. Rationale: smallest change that is
correct independent of the reachability question, satisfies epic #8229's docstring criterion, and
keeps a device-side diagnostic without exposing the malformed row. B is deferred until a second
classification caller exists. D is rejected on blast radius vs. evidence.

## Prerequisites

None. No design, protocol, or product decision is blocked — #8261 already ruled.
