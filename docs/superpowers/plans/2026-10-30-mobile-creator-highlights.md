# Mobile creator highlights implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show actual creators daily personal celebration cards in the Divine app.
**Architecture:** A bounded Funnelcake-backed repository selects truthful facts. An account-keyed Cubit owns loading and presentation. The existing Inbox All list renders the card with actionable routes.
**Tech stack:** Flutter, BLoC, existing Funnelcake API client, SharedPreferences, gen-l10n.
**Spec:** docs/superpowers/specs/2026-10-30-mobile-creator-highlights-design.md

## Global constraints
No fabricated activity or ranks, no push changes, full Nostr identifiers, adaptive colors, reduced-motion support, account isolation, no notification loading regression.

## Review focus
Account swap during an in-flight load must never show the previous owner's card. Sparse view metrics must not imply a complete daily total. Edited and archived videos must not create false publication days. Long translations and narrow devices must scroll without overflow. Hidden tabs must not cause background API polling or consume celebrations.

## Task 1: Load and select real highlights
- [x] Write failing repository tests using real Funnelcake HTTP parsing for zero-view creation, known totals, absent metrics, archive/foreign/future/deletion filtering, edit collapse, truncation, day rollover and account-scoped presentation.
- [x] Implement CreatorHighlight and CreatorHighlightsRepository using bounded author pages and fresh bulk stats; preserve unknown counts.
- [x] Run repository tests; expect pass.

## Task 2: Own mobile state and presentation
- [x] Write failing Cubit tests for successful/empty/failure loads, concurrent refresh and disposed/account-bound work, and once-per-day presentation.
- [x] Implement account-bound Cubit, canonical provider wiring and local preference cleanup.
- [x] Run Cubit and repository tests; expect pass.

## Task 3: Integrate the actual Inbox
- [x] Write failing widget tests proving a real card appears in Inbox All, survives an empty feed, refreshes on visibility/pull, routes correctly, supports large text/reduced motion, and stays absent from reaction filters and signed-out accounts.
- [x] Add native card and localized copy to the notification scroll flow, with video/analytics/create actions.
- [x] Run affected tests, flutter analyze, localization and guards, and required golden verification. Capture real Flutter UI before/after using synthetic API responses. Review whole diff independently, fix verified blockers.

Delivery: publish a ready mobile PR with evidence and inspect CI. The pull request records the live delivery and approval state.

## Verification record

Repository and Cubit missing-feature failures were observed before implementation. Review regressions reproduced typed video navigation, incomplete statistics, deletion/edit history, covered presentation, and midnight races before their fixes. Final local verification passed 197 affected tests and CI-scoped Flutter analysis; commands are recorded in the pull request. Running-browser before/after captures use synthetic data at 390 × 844; the widget integration test separately checks video, camera, and analytics routes.
