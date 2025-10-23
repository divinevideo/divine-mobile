# Dependency Upgrade Plan

**Date**: 2025-10-21
**Branch**: `wip/upgrade-dependencies`
**Status**: Investigation Phase

## Summary

Analysis of current dependencies reveals:
- **47 packages** can be upgraded with `flutter pub upgrade`
- **3 discontinued packages** need replacement or migration
- **CocoaPods (iOS)**: Firebase pods 12.2.0 → 12.4.0 available
- **1 package** requires major version upgrade (manual pubspec.yaml edit)

## Critical Issues

### 1. Discontinued Packages ⚠️

| Package | Current | Status | Impact |
|---------|---------|--------|--------|
| `js` | 0.6.7 | Discontinued | Transitive dependency - need to identify source |
| `build_resolvers` | 3.0.3 | Discontinued | Dev dependency - used by build_runner |
| `build_runner_core` | 9.3.1 | Discontinued | Dev dependency - core build system |

**Action Required**: These are dev dependencies for code generation. May need to update `build_runner` to newer version that uses non-discontinued alternatives.

### 2. Golden Toolkit Discontinued

From earlier analysis:
```
golden_toolkit 0.15.0 (discontinued)
```

**Recommendation**: Migrate to `alchemist` (already in use) or another visual regression testing tool.

## Upgrade Categories

### A. Safe Minor Updates (47 packages)

These can be upgraded with `flutter pub upgrade`:

#### Direct Dependencies
- `animations` 2.0.11 → 2.1.0
- `device_info_plus` 12.1.0 → 12.2.0
- `firebase_analytics` 12.0.2 → 12.0.3
- `firebase_core` 4.1.1 → 4.2.0
- `firebase_crashlytics` 5.0.2 → 5.0.3
- `flutter_local_notifications` 19.4.2 → 19.5.0
- `flutter_riverpod` 3.0.0 → 3.0.3
- `go_router` 16.2.4 → 16.2.5
- `hive_ce` 2.14.0 → 2.15.0
- `media_kit_libs_android_video` 1.3.7 → 1.3.8
- `riverpod_annotation` 3.0.0 → 3.0.3
- `share_plus` 12.0.0 → 12.0.1
- `video_player_media_kit` 1.0.6 → 1.0.7

#### Dev Dependencies
- `riverpod_generator` 3.0.0 → 3.0.3

#### Transitive Dependencies
- All camera, file_selector, image_picker, url_launcher platform implementations
- SQLite, media_kit, video_player updates
- Test framework updates

**Risk**: Low - these are patch/minor version updates

### B. Major Version Updates (Manual)

Require editing `pubspec.yaml` and potentially code changes:

| Package | Current | Latest | Breaking? |
|---------|---------|--------|-----------|
| `dart_pg` | 2.0.0 | 2.1.0 | Possibly - check changelog |
| `alchemist` | 0.12.1 → 0.13.0 | Check for breaking changes |
| `pointycastle` | 3.9.1 | 4.0.0 | YES - major version |
| `shelf_web_socket` | 2.0.1 | 3.0.0 | YES - major version |
| `flutter_secure_storage_*` | Various | 2.0+ to 4.0 | YES - major version |
| `rxdart` | 0.27.7 | 0.28.0 | Possibly |

**Risk**: Medium to High - need to review changelogs for breaking changes

### C. CocoaPods (iOS)

Firebase pods outdated:
```
Firebase 12.2.0 → 12.4.0
FirebaseAnalytics 12.2.0 → 12.4.0
FirebaseCore 12.2.0 → 12.4.0
FirebaseCrashlytics 12.2.0 → 12.4.0
```

**Action**: Run `pod update` in `ios/` directory after Flutter dependency upgrade

## Recommended Upgrade Strategy

### Phase 1: Safe Minor Updates (Low Risk)
1. Run `flutter pub upgrade` to upgrade all 47 compatible packages
2. Run `flutter pub get` to resolve dependencies
3. Run full test suite: `flutter test`
4. Run `flutter analyze` to check for any new warnings
5. Test on iOS and Android devices
6. Commit: "chore: upgrade 47 Flutter dependencies to latest minor versions"

### Phase 2: Discontinued Package Investigation
1. Investigate `js` package usage:
   ```bash
   flutter pub deps | grep js
   ```
2. Check which package depends on discontinued build tools
3. Research migration path for `build_runner` ecosystem
4. Update or replace as needed
5. Commit: "chore: migrate from discontinued packages"

### Phase 3: CocoaPods Update (iOS)
1. `cd ios && pod update`
2. Test iOS build: `./build_native.sh ios debug`
3. Test on iOS device/simulator
4. Commit: "chore: update iOS CocoaPods (Firebase 12.2→12.4)"

### Phase 4: Major Version Updates (High Risk)
**ONLY after Phase 1-3 are stable and committed**

For each major version update:
1. Review package changelog on pub.dev
2. Check for breaking changes
3. Update pubspec.yaml constraints
4. Run `flutter pub upgrade --major-versions <package>`
5. Fix any breaking changes in code
6. Run full test suite
7. Commit each package individually

Example order:
1. `alchemist` (visual testing tool)
2. `dart_pg` (database - check if we actually use it)
3. `rxdart` (reactive programming)
4. `flutter_secure_storage` (major change 3.x → 4.x)
5. `pointycastle` (crypto - major version 3→4)
6. `shelf_web_socket` (if used in backend)

## Testing Requirements

After EACH phase:
- ✅ Run `flutter analyze` - must have 0 new issues
- ✅ Run `flutter test` - all tests must pass
- ✅ Build iOS debug: `./build_native.sh ios debug`
- ✅ Build Android debug: `flutter build apk --debug`
- ✅ Test on real device (iOS and Android)
- ✅ Check hot reload works
- ✅ Check app launches and core features work

## Rollback Plan

If any phase fails:
1. Don't commit broken state
2. `git checkout pubspec.yaml pubspec.lock`
3. `flutter pub get`
4. Document the issue in this file
5. Research solution before retrying

## Notes

- Keep `pubspec.yaml` changes minimal in each commit
- Test thoroughly after EACH phase before moving to next
- Don't mix Flutter dependency updates with code refactoring
- Don't rush - each phase could take 1-2 hours of testing

## Test Results Analysis

**Current State Test Results**:
- ✅ Passed: 2,093 tests
- ⏭️ Skipped: 11 tests
- ❌ Failed: 613 tests
- **Total: 2,717 tests**

**CRITICAL FINDING**: Dependencies are **already at their maximum upgradeable versions** per current pubspec.yaml constraints!
- Running `flutter pub upgrade` results in "No dependencies changed"
- All packages in pubspec.lock are at the max version allowed by pubspec.yaml constraints
- The "47 upgradable packages" from earlier analysis referred to packages that were already upgraded
- No further minor/patch upgrades available without changing pubspec.yaml

**CONCLUSION**: The 613 test failures are pre-existing issues in the codebase, not related to dependencies.

**BLOCKER**: Cannot proceed with dependency upgrades until test suite is fixed. With 22.6% test failure rate, we cannot confidently determine if upgrades break functionality or if failures are pre-existing.

**Required Before Any Upgrades**:
1. Fix the 613 failing tests
2. Achieve green (or near-green) test suite
3. THEN upgrade dependencies with confidence in regression detection

## Current Constraint Issues

From `flutter pub outdated`:
```
47 upgradable dependencies are locked (in pubspec.lock) to older versions.
To update these dependencies, use `flutter pub upgrade`.

1 dependency is constrained to a version that is older than a resolvable version.
To update it, edit pubspec.yaml, or run `flutter pub upgrade --major-versions`.
```

Need to identify which dependency has the constraint issue.

## Questions for Team

1. **Do we actually use `dart_pg`?** (PostgreSQL client)
   - If not, remove it to simplify dependency tree

2. **Visual testing strategy**: Stick with `alchemist` or consider alternatives?
   - `golden_toolkit` is discontinued
   - `alchemist` is actively maintained

3. **Risk tolerance**: How aggressive should major version updates be?
   - Conservative: Wait for community feedback
   - Aggressive: Update ASAP to stay current

## Success Criteria

- ✅ All 47 minor updates applied successfully
- ✅ All tests passing
- ✅ No new flutter analyze warnings
- ✅ App builds and runs on iOS/Android
- ✅ Discontinued packages replaced or dependencies updated
- ✅ CocoaPods updated
- 🎯 OPTIONAL: Major version updates (can be separate effort)
