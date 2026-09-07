# Divine Documentation Map

Status: Current
Validated against: active repo structure and current mobile launch scope on 2026-03-19.

This directory is the index for current repository documentation. Use it to find the source-of-truth docs first and the historical archive second.

## Start Here

- [docs/P1_LAUNCH_HUB.md](P1_LAUNCH_HUB.md) - launch-critical docs for P1 submission
- [CONTRIBUTING.md](../CONTRIBUTING.md) - setup, workflow, tests, and PR expectations
- [docs/ARCHITECTURE.md](ARCHITECTURE.md) - app layers and dependency direction (UI → BLoC → Repository → Client)
- [docs/STATE_MANAGEMENT.md](STATE_MANAGEMENT.md) - current architecture direction
- [docs/BLOC_UI_MIGRATION_PRD.md](BLOC_UI_MIGRATION_PRD.md) - migration policy and rationale
- [docs/DOCUMENTATION_GUIDELINES.md](DOCUMENTATION_GUIDELINES.md) - how to keep docs current

## Launch-Critical Docs

- [docs/RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)
- [docs/APP_STORE_REVIEW_DOSSIER.md](APP_STORE_REVIEW_DOSSIER.md)
- [mobile/docs/APPLE_REVIEW_RESPONSE.md](../mobile/docs/APPLE_REVIEW_RESPONSE.md)
- [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](../mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md)
- [mobile/docs/ANDROID_DEPLOYMENT.md](../mobile/docs/ANDROID_DEPLOYMENT.md)
- [mobile/docs/AI_TRAINING_POLICY.md](../mobile/docs/AI_TRAINING_POLICY.md)

## Current Engineering Docs

- [docs/ARCHITECTURE.md](ARCHITECTURE.md) - app layers and dependency direction
- [docs/STATE_MANAGEMENT.md](STATE_MANAGEMENT.md)
- [docs/BLOC_UI_MIGRATION_PRD.md](BLOC_UI_MIGRATION_PRD.md)
- [docs/NOSTR_SDK_ARCHITECTURE.md](NOSTR_SDK_ARCHITECTURE.md) - Nostr SDK internals
- [docs/BUILD_SCRIPTS_README.md](BUILD_SCRIPTS_README.md)
- [docs/BUILD_SPEED_CHECKLIST.md](BUILD_SPEED_CHECKLIST.md)
- [mobile/docs/settings_screen_structure.md](../mobile/docs/settings_screen_structure.md)
- [mobile/docs/ZENDESK_INTEGRATION.md](../mobile/docs/ZENDESK_INTEGRATION.md)
- [mobile/docs/NOSTR_VIDEO_EVENTS.md](../mobile/docs/NOSTR_VIDEO_EVENTS.md)
- [mobile/docs/FEED_LOAD_TRACES.md](../mobile/docs/FEED_LOAD_TRACES.md) - what the `feed_load_*` Firebase Performance traces measure and how to compare them
- [mobile/docs/LOCALIZATION_STYLE_GUIDE.md](../mobile/docs/LOCALIZATION_STYLE_GUIDE.md) - per-locale tone, dialect, terminology, and translation review

## Historical Docs

Older plans, investigations, migration notes, and postmortems are still useful, but they are not the current source of truth. Start at [docs/archive/README.md](archive/README.md) before using anything under `docs/plans`, `docs/superpowers`, or `mobile/docs/plans`.

## Source-Of-Truth Rule

When docs disagree:

1. Trust current code and targeted tests.
2. Trust focused current docs over older broad docs.
3. Treat archived or historical docs as context only.
