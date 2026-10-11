# Live Explore Tab Design

**Date:** 2026-04-09
**Branch:** `codex/live-spaces-v1`

## Problem

The current livestream beta is surfaced in Explore as a standalone promo card above the tab strip. That makes Live feel like an ad, hides the actual discovery surface behind an extra tap, and leaves the rest of Explore visually empty when the feature is enabled.

## Decision

When `FeatureFlag.livestreamingBeta` is enabled, `Live` should appear as a first-class Explore tab, similar to `Integrated Apps`.

## UX

- Remove the standalone `LiveExploreEntryCard` from the Explore column.
- Add a `Live` tab to the Explore `TabBar` when livestreaming is enabled.
- Render the live discovery experience inline in the `TabBarView` instead of forcing users through a separate promo-card route.
- Keep the dedicated live routes for deep links and direct navigation, but make the Explore tab the primary entry point.

## Implementation Notes

- Update `ExploreScreen` tab bookkeeping so `live` participates in `_tabCount`, `_tabNames`, tab labels, and `TabBarView`.
- Keep the change focused on Explore and reuse the existing embedded discovery surface if available.
- Preserve the existing livestream feature flag gate.

## Success Criteria

- Enabling `FeatureFlag.livestreamingBeta` shows `Live` in the Explore tab strip.
- The promo card no longer appears above the tabs.
- Selecting `Live` shows live discovery content inline in Explore.
