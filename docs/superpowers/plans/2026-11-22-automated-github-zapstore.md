# Approved Android distribution implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically publish the exact Play-published Android candidate to GitHub and then Zapstore without rebuilding it.

**Architecture:** Retain direct-download APK identities during the original native build. The existing main-only coordinator journals a separate distribution operation after verified Play production availability; the existing Codemagic publication workflow reuses the GitHub publisher and Zapstore signer, recording completion privately.

**Tech Stack:** Python unittest, existing Python release tooling, Codemagic YAML and its existing pinned Zapstore CLI.

**Spec:** `docs/superpowers/specs/2026-11-22-automated-github-zapstore-design.md` (approved by Rabble in session).

## Global constraints

- Exact version, build number, source, completed provenance, original APK hashes and retained notes must agree.
- Only actual published Play production availability qualifies; no native rebuild or store resubmission.
- GitHub stable verification precedes signing that exact release for Zapstore.
- Preserve existing store holds, native cadence, manual publication and all other worktrees.
- Credentials stay in existing protected workflows/groups. No new IAM or secrets.
- Publication intent precedes dispatch; unknown acceptance is reconciled rather than retried blindly.
- Flutter setup and analysis use `/Users/rabble/.local/share/mise/installs/flutter/3.47.9/bin/flutter`.

## Review focus

- A higher pending/rejected Play candidate must not qualify merely because an older release remains available.
- A publication retry after GitHub succeeded must preserve its exact tag, notes and APK bytes.
- Lost Codemagic dispatch responses must not launch duplicate signing jobs.
- Missing historical APK evidence must produce an honest hold, never a rebuilt substitute.
- A newer checkout or concurrent GitHub release must not change the selected version or sign another release.

### Task 1: Retain original APK evidence

**Files:** `codemagic.yaml`, `mobile/scripts/publish_play_bundle.py`, new `mobile/scripts/release_train/android_distribution.py`, and `.github/scripts/tests/test_android_distribution.py`.

**Interface:** `retain_downloads(env, ledger, source, version, number)` creates an immutable `artifacts/android-downloads/<number>.json` binding the two ARM APK filenames/digests, original Codemagic build and validated native notes.

- [ ] Write and observe failing tests for scheduled APK production, allocated APK build number, retained hashes/notes, missing APKs and conflicting retries.
- [ ] Remove the scheduled APK skip, use the allocated build number, retain the manifest before Play upload and preserve existing manual behavior.
- [ ] Pass the new tests and existing Play/publisher/configuration tests; commit this delivery slice.

### Task 2: Publish the approved candidate in order

**Files:** new `mobile/scripts/publish_approved_android.py`, `mobile/scripts/release_train/android_distribution.py`, `codemagic.yaml`, and `.github/scripts/tests/test_android_distribution.py`.

**Interfaces:** `validate_downloads(record, build)` validates manifest identity; `publish_approved(env, ledger, cm, github)` validates approval/provenance, downloads original APKs from the recorded build, checks hashes, and calls the existing stable publisher with retained notes. `record_published(env, ledger, github)` verifies the resulting release and writes a completion receipt only after the Zapstore step succeeded.

- [ ] Write and observe failing tests for mismatched identities/hashes, artifact origin/redirect safety, absent evidence, retained notes, already-uploaded matching assets, and GitHub failure before Zapstore.
- [ ] Extend the existing manual Zapstore workflow with explicit approved-candidate preparation/receipt steps. Retain its legacy manual mode and pinned signer. Pass the selected version explicitly instead of assuming pubspec.
- [ ] Verify exact release/source/assets before and after signing; pass focused tests and commit.

### Task 3: Connect and reconcile the existing coordinator

**Files:** `mobile/scripts/release_train/{runner,coordinator,android_distribution}.py`, `.github/scripts/tests/test_android_distribution.py`, `release-notes/README.md`, and the existing release-train runbook.

**Interfaces:** `plan_distribution(snapshot, state, levels)` returns a distribution action for the newest published, CI-verified production candidate with retained evidence; `reconcile_distribution(operation, snapshot)` uses the durable dispatch label and exact completion receipt. The journal tracks publication separately from native attempts and store submission budgets.

- [ ] Write and observe failing tests for published/pending/rejected/partial Play reads, missing manifests, unrelated holds, durable intent, unknown acceptance, terminal retry and dry runs.
- [ ] Add the action to the existing plan, securely refresh its existing scoped ledger credential, dispatch the existing publication workflow and reconcile provider completion without rebuilding.
- [ ] Update operator documentation, run the full CI configuration suite and pinned Flutter CI-scope analysis, and inspect the full diff.
- [ ] Obtain fresh independent whole-branch review; fix findings, rebase on current main, commit/push a focused PR, request mapped reviewers once and inspect all required checks. Do not bypass real merge/release gates.
