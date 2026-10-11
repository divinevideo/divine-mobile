# Go Live Prefill Design

**Date:** 2026-04-09
**Branch:** `codex/live-spaces-v1`

## Problem

The current `Go live` form opens completely blank. That makes the host do unnecessary setup work for every stream, and the cover field looks unfinished even when the app already knows who the host is.

## Decision

Use the current host's cached profile to prefill the `Go live` form once on first render.

## UX

- If a cached profile exists for the current host pubkey:
  - prefill the title with `"<display name> is live"`
  - prefill the summary with `"Come hang out with <display name> live on Divine."`
  - prefill the cover image URL with the profile `picture`
- Show the current cover image as a visible preview so the host can see that their avatar is being used.
- Only seed the form once. After the host edits a field, later rebuilds must not overwrite their changes.
- If no cached profile exists, keep the current blank form behavior.

## Implementation Notes

- Resolve cached profile data in the page-level dependency wiring, not inside the text-field widget tree.
- Keep the defaults editable and store them in `GoLiveState` so the view can initialize its controllers from state once.
- Reuse existing Divine UI components and theme values. The preview should stay lightweight and feel like part of the form, not a new media picker flow.

## Success Criteria

- `Go live` opens with host-based defaults when cached profile data is available.
- The host avatar is visible as the default cover preview.
- User edits are preserved across rebuilds.
- Blank-state behavior remains unchanged when no cached profile exists.
