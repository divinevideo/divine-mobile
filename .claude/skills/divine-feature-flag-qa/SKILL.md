---
name: divine-feature-flag-qa
description: Prepare or conduct a Divine mobile/web feature-flag QA audit to decide what to release, fix, keep controlled, or retire. Use for flag inventories and release-readiness reviews, not for enabling or deploying features.
---

# Divine feature-flag QA

Read [the QA review prompt](references/QA_FEATURE_FLAG_REVIEW.md) when preparing an assignment or conducting an audit. It supplies the review scope, evidence requirements, feature-specific checks, and report format.

The reference is a dated starting snapshot, not a current release verdict. Before using its inventory, reconcile the actual target commit's flag definitions, build configuration, runtime overrides, call sites, additional gates, and deployed service availability. Recheck linked PR and issue states; do not repeat old states as current facts. Preserve the original source and date when reporting historical evidence.

Load the target repository's agent instructions and shared Divine context, and apply current maintainer instructions and holds. This skill authorizes no merge, deployment, global default change, contacts collection, permission expansion, or unrelated implementation. Livestream/LiveKit work stays excluded while its maintainer hold applies. An instruction to prepare a QA prompt does not authorize executing account-writing tests.

If asked for a prompt, produce a copy-ready assignment with the refreshed inventory and explicit unknowns. If asked to execute QA, test within the authorized accounts, environments, and actions, and report untested paths honestly. Do not fabricate a release verdict from code inspection alone.

Evaluate real user flows and service boundaries. Distinguish fixture screenshots from real-media rendering and full integration. HTTP success, merged code, an enabled flag, and green unit tests individually do not establish that a deployed feature works. For visual flows collect actual app screenshots with real permitted content where possible, and identify staged data and backend responses.

Return a decision for every flag: **Release**, **Fix then release**, **Keep controlled**, **Retire**, or **Not verified**. Separately recommend whether to remove the gate, enable by default, keep rollback control, or retain consent/expert/canary controls. Include exact build/platform/effective settings, tested behavior, blockers, evidence, and owner/acceptance criteria where a fix is needed. Separate nonblocking polish from release blockers. Favor shipping verified features and removing obsolete flags without bypassing existing safety or consent gates.
