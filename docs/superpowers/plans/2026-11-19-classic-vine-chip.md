# Classic Vine chip implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this single task with test-driven development and a final independent review.

**Goal:** Display the localized Classic Vine chip on mobile for archived Vines originally published in 2017 or earlier.

**Architecture:** Add a display-only date/origin predicate to VideoEvent. Render it in the existing metadata badge row and include it in the parent sheet's visibility condition. Preserve server verification requirements for trust decisions and OG Viner recognition.

**Tech stack:** Dart, Flutter, existing localization and metadata widgets.

**Spec:** User instruction: "the vines from 2017 and before should have a classic vine chip".

## Constraints and review focus

- Accept the whole of 2017 in UTC; exclude 2018 and later and unknown/invalid dates.
- Prefer the original `published_at`. A legacy event timestamp is usable only before Vine shut down.
- Require Vine origin metadata or server-verified archive status; an old timestamp alone does not imply Vine origin.
- Display through verification outages and relay loads without granting trust or audio reuse.
- Reuse the existing localized Classic Vine label and theme-aware badge typography.

## Task: Restore the Classic Vine label

- [x] Add failing model tests for origin, original-date precedence, missing dates, and the year boundary.
- [x] Add failing widget tests for the badge and its visibility in the real metadata sheet.
- [x] Implement VideoEvent.isClassicVine, badge rendering, and the sheet visibility condition.
- [x] Run affected widget tests, the models suite, analysis, formatting and localization checks.
- [x] Update the badge guide and verify the chip change in the pull request.
