# Mock Setup Issues

**Generated**: 2025-10-20
**Total Test Files**: 508
**Mock Files**: 93
**Tests Analyzed**: Full test suite

---

## CRITICAL: Compilation Failures (7+ tests)

### Missing Method: `_runAutoDiagnostics`
**Error**: `The method '_runAutoDiagnostics' isn't defined for the type 'VideoEventService'`
**Location**: `lib/services/video_event_service.dart:671:15`
**Impact**: Blocks compilation of multiple test files

**Affected Tests**:
- [ ] `test/unit/providers/comments_provider_test.dart` - BLOCKS LOADING
- [ ] `test/unit/screens/video_metadata_screen_wiring_test.dart` - BLOCKS LOADING
- [ ] `test/unit/services/video_event_service_pagination_test.dart` - BLOCKS LOADING
- [ ] `test/unit/services/video_event_service_subscription_test.dart` - BLOCKS LOADING
- [ ] `test/unit/services/video_event_service_deduplication_test.dart` - BLOCKS LOADING
- [ ] `test/unit/services/video_event_service_search_test.dart` - BLOCKS LOADING

**Fix**:
```bash
# Either add the missing method to VideoEventService or remove the call
# Check lib/services/video_event_service.dart line 671
```
**Priority**: CRITICAL - Blocks 8+ tests from even loading

---

## Missing Plugin Mocks (50+ test failures)

### 1. path_provider Plugin
**Error**: `MissingPluginException(No implementation found for method getApplicationSupportDirectory on channel plugins.flutter.io/path_provider)`

**Already Mocked In**: `test/test_setup.dart` lines 104-120
**Issue**: Tests not calling `setupTestEnvironment()` before running

**Affected Services**:
- Log initialization failures across many tests
- Database initialization for embedded relay
- File system access in upload/cache tests

**Fix**: Add to beginning of each failing test:
```dart
setUpAll(() {
  setupTestEnvironment(); // Already defined in test/test_setup.dart
});
```

**Tests Needing Fix** (Sample - affects 50+):
- [ ] All tests with "Failed to initialize log files" error
- [ ] All tests with "Database initialization failed ERROR"
- [ ] `test/unit/services/embedded_relay_service_unit_test.dart`
- [ ] Video cache tests
- [ ] Upload manager tests

**Priority**: HIGH - Causes widespread test noise and potential false failures

---

### 2. flutter_secure_storage Plugin
**Error**:
- `MissingPluginException(No implementation found for method read on channel plugins.it_nomads.com/flutter_secure_storage)`
- `MissingPluginException(No implementation found for method write...)`
- `MissingPluginException(No implementation found for method delete...)`

**Already Mocked In**: `test/test_setup.dart` lines 20-61
**Issue**: Tests not calling `setupTestEnvironment()` OR test runs in isolation without setup

**Affected Areas**:
- Nostr key management tests
- Authentication tests
- Secure storage tests

**Specific Failures**:
- [ ] Key generation fails with secure storage errors
- [ ] Import/export key operations fail
- [ ] Tests expecting secure storage to work but get MissingPluginException

**Fix**: Same as path_provider - ensure `setupTestEnvironment()` called in `setUpAll()`

**Priority**: HIGH - Blocks authentication and key management tests

---

### 3. shared_preferences Plugin
**Error**: `MissingPluginException(No implementation found for method getAll on channel plugins.flutter.io/shared_preferences)`

**Already Mocked In**: `test/test_setup.dart` line 13
**Issue**: Mock is set up but some tests still fail - likely race condition or test isolation issue

**Affected Tests**:
- [ ] Feature flag tests
- [ ] Settings tests
- [ ] Preference-based tests

**Fix**: Verify `SharedPreferences.setMockInitialValues({})` is called before tests use it

**Priority**: MEDIUM - Affects feature flag and settings tests

---

### 4. Custom Secure Storage Channel
**Error**: `MissingPluginException(No implementation found for method getCapabilities on channel openvine.secure_storage)`

**Already Mocked In**: `test/test_setup.dart` lines 62-79
**Issue**: Mock exists but tests may not initialize properly

**Fix**: Ensure test setup runs before service initialization

**Priority**: MEDIUM - Affects custom security capability checks

---

## Outdated Mock Interfaces (0 found)

**Status**: All mocks appear to be up-to-date with current service signatures.

**Note**: No "Unexpected method call" errors detected in test output, suggesting mocks match current interfaces.

---

## Test Logic Failures (NOT Mock Issues)

### 1. VideoEvent Kind Validation
**Error**: `Invalid argument(s): Event must be a NIP-71 video kind (22, 21, 34236, 34235)`

**Affected Tests**:
- [ ] `test/unit/video_event_real_parsing_test.dart` - Tests using kind 32222 (WRONG)
- [ ] `test/unit/models/video_event_blurhash_parsing_test.dart` - Tests using kind 32222

**Issue**: Tests are using invalid event kind (32222) instead of valid NIP-71 kinds
**Fix**: Update test data to use kind 34236 (addressable videos) or 22 (legacy)
**Priority**: MEDIUM - Test data issue, not mock issue

---

### 2. Subscription Filter Limit Validation
**Test**: `test/unit/services/subscription_manager_filter_test.dart`
**Error**: `Expected: a value less than or equal to <100>, Actual: <200>`

**Issue**: Test expects limit optimization but service is not applying it
**Fix**: Review SubscriptionManager filter optimization logic
**Priority**: LOW - Test assertion issue, not mock setup

---

### 3. NostrService Initialization State
**Test**: `test/unit/services/embedded_relay_service_unit_test.dart`
**Error**: `Expected: <1>, Actual: <0>` (checking relay count)

**Issue**: Test expects 1 relay initialized but service shows 0
**Fix**: Verify test initialization sequence or update assertion
**Priority**: LOW - Test expectation mismatch

---

### 4. Bad State Errors
**Errors**:
- `Bad state: NostrService not initialized`
- `Bad state: Embedded relay not initialized`
- `Bad state: Tried to use VineRecordingNotifier after dispose was called`

**Issue**: Tests running before services fully initialized OR tests not cleaning up properly
**Fix**: Add proper async initialization and teardown
**Priority**: MEDIUM - Service lifecycle issues in tests

---

## Mock Regeneration Needed

Run this to regenerate all mocks (in case of future interface changes):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**When to regenerate**:
- After adding new methods to services that are mocked
- After changing method signatures on mocked classes
- After adding new services that need mocking

**Mock files that may need regeneration** (if services change):
```
test/unit/providers/comments_provider_test.mocks.dart
test/unit/services/nip17_message_service_test.mocks.dart
test/integration/upload_publish_e2e_comprehensive_test.mocks.dart
test/unit/subscription_manager_tdd_test.mocks.dart
test/integration/video_event_service_simple_test.mocks.dart
... (88 more - see test/**/*.mocks.dart)
```

---

## Quick Wins (Top 10 Priority Fixes)

### 1. Fix VideoEventService compilation error (2 min)
**Impact**: Unblocks 8+ test files
```bash
# Check lib/services/video_event_service.dart:671
# Either add missing _runAutoDiagnostics method or remove call
```

### 2. Add setupTestEnvironment() to all test files (10 min)
**Impact**: Fixes 50+ plugin mock errors
```dart
void main() {
  setUpAll(() {
    setupTestEnvironment();
  });
  // ... rest of tests
}
```

### 3. Fix kind 32222 to 34236 in video event tests (3 min)
**Impact**: Fixes 4 parsing tests
```dart
// Change:
kind: 32222
// To:
kind: 34236
```

### 4. Search for tests NOT using setupTestEnvironment() (5 min)
```bash
# Find tests that might be missing setup
grep -L "setupTestEnvironment" test/**/*_test.dart
```

### 5. Fix global error handler test (5 min)
**File**: `test/unit/global_error_handler_test.dart`
**Issue**: Test expects error boundary behavior but fails
**Fix**: Review test expectations vs implementation

### 6. Fix npub parsing test (3 min)
**File**: `test/unit/models/user_profile_npub_test.dart`
**Issue**: Fails during loading
**Fix**: Check for compilation errors or missing dependencies

### 7. Fix hashtag filter test (2 min)
**File**: `test/unit/nostr_sdk/filter_hashtag_test.dart`
**Issue**: Fails during loading
**Fix**: Check for compilation errors

### 8. Fix user avatar test (2 min)
**File**: `test/unit/user_avatar_tdd_test.dart`
**Issue**: Fails during loading
**Fix**: Check for compilation errors

### 9. Review embedded relay initialization (10 min)
**Issue**: Many tests show "Embedded relay not initialized"
**Fix**: Add proper async initialization in test setup

### 10. Clean up test output noise (5 min)
**Issue**: "Failed to initialize log files" appears 50+ times
**Fix**: Mock path_provider properly OR suppress log initialization in tests

---

## Tests Using Mocks Effectively (Examples to Follow)

**Good Examples**:
- ✅ `test/unit/subscription_manager_tdd_test.dart` - Clean mock setup with `@GenerateNiceMocks`
- ✅ `test/unit/curated_list_relay_sync_test.dart` - Well-structured mock service tests
- ✅ `test/unit/nostr_key_manager_test.dart` - Proper setup/teardown with mocks

**Patterns**:
```dart
@GenerateNiceMocks([MockSpec<INostrService>()])
import 'your_test.mocks.dart';

void main() {
  late MockINostrService mockNostrService;

  setUp(() {
    mockNostrService = MockINostrService();
  });

  test('example', () {
    when(mockNostrService.someMethod()).thenAnswer((_) async => result);
    // ... test code
  });
}
```

---

## Overcomplicated Mocks (None Found)

**Status**: No evidence of tests using mocks where real implementations would be simpler.

**Reasoning**: Most mocked services (NostrService, INostrService, AuthService, etc.) involve network I/O, state management, or complex dependencies that genuinely require mocking.

---

## Test Setup Best Practices

### Current Status
- ✅ `test/test_setup.dart` exists with comprehensive plugin mocks
- ❌ NOT consistently called across all test files
- ⚠️ Some tests work because they run in batch, but fail in isolation

### Recommendations

**1. Make setupTestEnvironment() automatic**
```dart
// Option A: Create test/flutter_test_config.dart
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setupTestEnvironment();
  await testMain();
}
```

**2. OR enforce in each test file**
```dart
void main() {
  setUpAll(setupTestEnvironment);

  // tests...
}
```

**3. Add to test template/guidelines**
Document that ALL new tests must call `setupTestEnvironment()` in `setUpAll()`.

---

## Summary Statistics

| Category | Count | Priority |
|----------|-------|----------|
| **Compilation Failures** | 8 | CRITICAL |
| **Missing Plugin Mocks** | 50+ | HIGH |
| **Test Logic Failures** | 6 | MEDIUM |
| **Mock Regeneration Needed** | 0 | LOW |
| **Overcomplicated Mocks** | 0 | N/A |

**Total Passing Tests**: 339
**Total Failing Tests**: 169
**Success Rate**: ~67%

**Primary Issue**: Missing `setupTestEnvironment()` calls and compilation error in `VideoEventService`

**Estimated Fix Time**:
- Critical fixes: 30 minutes
- High priority fixes: 2 hours
- All fixes: 4-6 hours

---

## Action Plan

**Phase 1: Unblock Compilation (15 min)**
1. Fix `_runAutoDiagnostics` in `lib/services/video_event_service.dart`
2. Verify tests can load

**Phase 2: Fix Plugin Mocks (1 hour)**
1. Add automatic test setup OR
2. Add `setupTestEnvironment()` to all test files
3. Verify plugin errors disappear

**Phase 3: Fix Test Data (30 min)**
1. Update kind 32222 → 34236 in video event tests
2. Fix other test data issues

**Phase 4: Fix Service Initialization (1-2 hours)**
1. Review embedded relay initialization
2. Fix NostrService initialization tests
3. Add proper async setup/teardown

**Phase 5: Polish (1 hour)**
1. Fix remaining test assertion failures
2. Clean up test output
3. Document test setup requirements

---

## Notes

- `test/test_setup.dart` is well-designed and comprehensive
- Main issue is **adoption/enforcement**, not mock quality
- No evidence of outdated mocks or interface mismatches
- Most failures are plugin initialization, not mock logic
- Consider making `setupTestEnvironment()` automatic via `flutter_test_config.dart`
