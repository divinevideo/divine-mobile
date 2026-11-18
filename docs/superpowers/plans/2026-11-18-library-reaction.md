# Library Reaction Implementation Plan

> Execute inline with superpowers:executing-plans; obtain fresh independent branch review before publication.

**Goal:** Select saved Classics in an existing editor and record side-by-side reactions from the library.
**Architecture:** Reuse the clip picker crop guide, recorder and split-screen builder; keep library reaction coordination in a focused widget file.
**Tech stack:** Flutter 3.47.9, Dart, BLoC, existing clip manager.
**Spec:** docs/superpowers/specs/2026-11-18-library-reaction-design.md

## Global constraints
Preserve source files, source credits, current session drafts and unrelated worktrees. Existing layout presets remain available. No new dependencies.

## Review focus
Cancel at camera/layout; account or route change during async work; unfinished session preservation; attribution of both cells; square/vertical geometry and library originals.

## Task 1: Classic selection
- [x] Add regression for a square imported clip in a vertical composition, including unchanged source and retained credits. Run red.
- [x] Pass the composition crop guide to the editor picker; use clipsWithAspectRatio for incoming clips, preserving each mask's original frame. Run library and import tests green.

## Task 2: Library reaction
- [x] Test preview action, camera cancellation and seeded layout handoff before code.
- [x] Add a focused reaction coordinator with injectable recorder/layout callbacks for tests. Extract completed camera takes through existing clip-manager ownership; keep autosave before clearing for final editor handoff.
- [x] Add initial clips to VideoEditorSplitScreenLayoutScreen; seed source left and reaction right using existing cubit clipsPicked.
- [x] Connect localized Record reaction button in library clip preview; reuse camera crop guide and layout pickers.
- [x] Verify widget flows, cancellation, credits and session preservation. Generate l10n and verify consistency.

## Delivery
- [ ] Run affected tests, full analysis, applicable guards and goldens; independent review, address findings, rebase onto origin/main, commit, push, open PR against main, request mapped reviewers, inspect completed CI.

Implementation notes: independent review found and verified fixes for multiple camera cuts (merge in capture order), merged media dimensions/poster consistency, and generated-file cleanup. The layout supports the existing picture-in-picture presets. New copy uses the exact English fallback key libraryRecordReaction until translated.
