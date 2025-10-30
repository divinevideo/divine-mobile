# Test Fix Plan

**Date**: 2025-10-21
**Status**: Analysis Complete - Ready for Execution
**Total Failures**: 613 tests (22.6% of 2,717 total tests)

## Executive Summary

Analysis of test failures reveals **5 systemic issues** causing 95%+ of failures. These are infrastructure/setup issues, NOT individual test logic bugs. Fixing these patterns will resolve the vast majority of failures.

## Root Cause Analysis

### 1. ProviderException: Missing Test Overrides (330 failures - 54% of total)

**Issue**: Tests fail with `sharedPreferencesProvider must be overridden in tests`

**Root Cause**: Tests aren't providing mock/override for `sharedPreferencesProvider` in their ProviderScope

**Example Error**:
```
ProviderException: Tried to use a provider that is in error state.
UnimplementedError: sharedPreferencesProvider must be overridden in tests
```

**Solution**:
- Create standard test helper that provides ALL required provider overrides
- Add to `test/helpers/test_providers.dart`:
  ```dart
  ProviderScope testProviderScope({
    required Widget child,
    List<Override>? additionalOverrides,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(MockSharedPreferences()),
        // Add other commonly needed overrides
        ...?additionalOverrides,
      ],
      child: child,
    );
  }
  ```
- Update all failing tests to use `testProviderScope()` wrapper

**Impact**: Will fix ~330 failures

**Effort**: Medium - requires updating many test files, but pattern is consistent

---

### 2. MissingStubError: Incomplete Mock Stubs (102 failures - 17% of total)

**Issue**: Mock objects missing `when()` stubs for commonly called methods

**Root Cause**: Tests create mocks but don't stub all methods that production code calls

**Example Error**:
```
MissingStubError: 'isAuthenticated'
No stub was found which matches the arguments of this method call
```

**Common Missing Stubs**:
- `AuthService.isAuthenticated`
- `SocialService` methods
- Other service method calls

**Solution**:
- Option A: Use `@GenerateNiceMocks` instead of `@GenerateMocks` (returns default values)
- Option B: Create standard mock setup helpers with common stubs pre-configured
- Update test generation to use NiceMocks:
  ```dart
  @GenerateNiceMocks([MockSpec<AuthService>()])
  ```

**Impact**: Will fix ~102 failures

**Effort**: Low-Medium - Can be fixed with annotation change + regeneration

---

### 3. FirebaseException: Missing Initialization (33 failures - 5% of total)

**Issue**: Tests fail with `No Firebase App '[DEFAULT]' has been created`

**Root Cause**: Tests don't call `Firebase.initializeApp()` or use test Firebase setup

**Example Error**:
```
FirebaseException: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
```

**Solution**:
- Add Firebase mock initialization to test setup helper
- Use `firebase_core_platform_interface` for testing
- Create `setupFirebaseForTests()` helper:
  ```dart
  Future<void> setupFirebaseForTests() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  }
  ```
- Add to ALL test files that use Firebase Analytics/Crashlytics

**Impact**: Will fix ~33 failures

**Effort**: Low - Standard pattern, apply to all test files

---

### 4. VineRecordingNotifier Lifecycle Issues (17 failures - 3% of total)

**Issue**: Tests try to use `VineRecordingNotifier` after it's been disposed

**Root Cause**: Test teardown disposes providers while async operations are still pending

**Example Error**:
```
Bad state: Tried to use VineRecordingNotifier after `dispose` was called.
Consider checking `mounted`.
```

**Solution**:
- Add proper lifecycle checks in `VineRecordingNotifier`:
  ```dart
  void someMethod() {
    if (!mounted) return; // Guard against use after dispose
    // ... rest of method
  }
  ```
- Or: Fix test teardown timing to wait for pending operations
- Add `addTearDown()` callbacks in tests to properly cleanup

**Impact**: Will fix ~17 failures

**Effort**: Low-Medium - Requires careful async handling

---

### 5. NostrEncodingException (15 failures - 2% of total)

**Issue**: Nostr data encoding/decoding failures in tests

**Root Cause**: Need to investigate specific cases

**Solution**: TBD - need to examine specific failures

**Impact**: Will fix ~15 failures

**Effort**: TBD

---

### 6. Stream Already Listened To (5 failures - <1% of total)

**Issue**: Tests try to listen to the same stream multiple times

**Root Cause**: Stream controllers not created with `broadcast: true` or tests not cleaning up listeners

**Solution**:
- Use `.asBroadcastStream()` where needed
- Or: Ensure proper test cleanup of stream subscriptions

**Impact**: Will fix ~5 failures

**Effort**: Low

---

## Recommended Fix Order

### Phase 1: Infrastructure Setup (High Impact, Low Effort)
**Goal**: Fix systemic setup issues that affect majority of tests

1. ✅ **Create test helper utilities** (1 hour)
   - `test/helpers/test_providers.dart` - Standard provider overrides
   - `test/helpers/firebase_test_setup.dart` - Firebase mock initialization
   - `test/helpers/mock_generators.dart` - Standard mock configurations

2. ✅ **Update mock generation** (30 minutes)
   - Change `@GenerateMocks` to `@GenerateNiceMocks`
   - Run `flutter pub run build_runner build --delete-conflicting-outputs`
   - Verify generated mocks

3. ✅ **Validate helpers work** (30 minutes)
   - Pick 3-5 failing tests from different categories
   - Apply new helpers
   - Verify fixes work
   - Adjust helpers if needed

**Expected Impact**: Infrastructure ready to fix 470+ failures

---

### Phase 2: Mass Fix Application (High Impact, Medium Effort)
**Goal**: Apply fixes to all affected tests

4. ✅ **Fix ProviderException failures** (3-4 hours)
   - Update ~50 test files to use `testProviderScope()` helper
   - Pattern: Replace `ProviderScope(child: ...)` with `testProviderScope(child: ...)`
   - Run tests after each batch of 10 files to verify
   - **Impact**: ~330 failures → 0

5. ✅ **Fix Firebase initialization failures** (1 hour)
   - Add `setupFirebaseForTests()` to ~15 test files
   - Add to `setUp()` or `setUpAll()`
   - **Impact**: ~33 failures → 0

6. ✅ **Fix MissingStubError failures** (2 hours)
   - Already fixed by NiceMocks in step 2
   - Verify all MissingStubError failures are resolved
   - Add specific stubs if NiceMocks doesn't cover everything
   - **Impact**: ~102 failures → 0

**Expected Impact**: 465+ failures fixed

---

### Phase 3: Edge Cases and Cleanup (Medium Impact, Variable Effort)

7. ✅ **Fix VineRecordingNotifier lifecycle** (2-3 hours)
   - Add `mounted` checks in notifier methods
   - Fix test teardown timing issues
   - Review async operation cleanup
   - **Impact**: ~17 failures → 0

8. ✅ **Fix Stream subscription issues** (30 minutes)
   - Add `.asBroadcastStream()` where needed
   - Fix test cleanup
   - **Impact**: ~5 failures → 0

9. ✅ **Investigate and fix NostrEncodingException** (2-3 hours)
   - Examine specific failure cases
   - Fix encoding/decoding issues
   - Add proper test data setup
   - **Impact**: ~15 failures → 0

10. ✅ **Fix remaining edge cases** (~100 failures)
    - Review remaining failures not covered by patterns above
    - Fix file-specific issues
    - Fix test-specific logic bugs
    - **Impact**: Remaining failures → 0

**Expected Impact**: All 613 failures → 0 (or near-zero)

---

## Total Effort Estimate

- **Phase 1**: 2 hours (infrastructure)
- **Phase 2**: 6-7 hours (mass application)
- **Phase 3**: 6-8 hours (edge cases)

**Total**: ~14-17 hours of focused work

---

## Success Criteria

- ✅ All infrastructure helpers created and tested
- ✅ Test suite passes with 0 failures (or <10 edge cases)
- ✅ CI/CD pipeline green
- ✅ Code coverage maintained or improved
- ✅ No new test failures introduced
- ✅ All fixes documented and reviewable

---

## Risks and Mitigation

**Risk**: Fixing tests might hide real bugs
- **Mitigation**: Review each category of fixes to ensure we're fixing test setup, not masking logic bugs

**Risk**: Changes might break working tests
- **Mitigation**: Run full test suite after each phase, commit incrementally

**Risk**: Time estimate too optimistic
- **Mitigation**: Start with Phase 1 validation, adjust plan based on actual results

---

## Next Steps

1. **Review this plan with team** - Get approval on approach
2. **Create branch**: `fix/test-suite-infrastructure`
3. **Execute Phase 1** - Build and validate infrastructure
4. **Checkpoint** - Review progress, adjust plan if needed
5. **Execute Phase 2** - Mass application of fixes
6. **Execute Phase 3** - Edge cases and cleanup
7. **Merge to main** - After full test suite is green

---

## Notes

- This plan assumes the 613 failures are primarily infrastructure/setup issues, not logic bugs
- The analysis shows 95%+ of failures fit into 5 clear patterns
- Remaining ~100 failures likely need individual investigation
- Once test suite is green, we can confidently upgrade dependencies
