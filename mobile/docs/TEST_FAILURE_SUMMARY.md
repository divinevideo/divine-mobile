# Test Failure Analysis Summary
**Generated**: 2025-10-25
**Total Test Results**: 2182 passed, 28 skipped, 613 failed

## Executive Summary

Out of 613 test failures analyzed, the failures break down into these categories:

### Failure Categories (Actual Test Files Only)

1. **Assertion Mismatch** (284 failures) - Tests expecting different output than actual
   - integration: 70 failures
   - services: 48 failures
   - screens: 35 failures
   - unit: 32 failures
   - widgets: 15 failures
   - providers: 13 failures

2. **Null Safety Violations** (57 failures) - Null check operator failures
   - Most failures in integration tests
   - Core issue: null values where non-null expected

3. **Timeout** (53 failures) - Tests taking >10 minutes
   - screens: 14 failures
   - integration: 10 failures
   - May indicate real performance/async issues

4. **Widget Not Found** (44 failures) - Finder can't locate widgets
   - screens: 12 failures
   - integration: 8 failures
   - widgets: 8 failures

5. **Database** (21 failures) - SQLite/database operation failures
   - integration: 7 failures

6. **Golden Test** (14 failures) - Visual regression test failures
   - goldens: 4 failures
   - integration: 4 failures

7. **Layout/Rendering** (2 failures) - RenderBox size constraint violations
   - screens: 2 failures

8. **Other/Uncategorized** (138 failures remaining)

## Hotspot Directories (Real Test Files)

1. **integration/** - 141 failures
   - Most complex integration scenarios failing
   - Heavy relay/async operations

2. **screens/** - 121 failures
   - UI/widget tree issues
   - Many router-related failures

3. **services/** - 91 failures
   - Core service layer issues
   - Nostr relay, video processing, user profiles

4. **widgets/** - 54 failures
   - Component-level failures

5. **unit/** - 44 failures
   - Unit test assertion mismatches

6. **providers/** - 22 failures
   - Riverpod provider state issues

7. **router/** - 17 failures
   - Navigation and routing failures

## Priority Recommendations

### Immediate (High Impact, Low Effort)

1. **Fix Widget Not Found errors** (44 failures)
   - Quick wins - usually missing `pumpAndSettle()` or wrong finder
   - Example files to start with:
     - `test/unit/error_widget_test.dart`
     - `test/integration/feature_flag_integration_test.dart`

2. **Fix Layout/Rendering errors** (2 failures)
   - Only 2 failures, should be quick
   - `test/screens/feed_screen_scroll_test.dart`

### Medium Priority (High Impact, Medium Effort)

3. **Fix Null Safety errors** (57 failures)
   - Add null checks or provide defaults
   - Most are in integration tests
   - May expose real bugs in production code

4. **Fix Timeout errors** (53 failures)
   - These hide real issues - fix root cause, don't just increase timeout
   - Start with fastest-to-timeout tests
   - Look for missing `await` or infinite loops

### Long-term (High Volume, Requires Investigation)

5. **Fix Assertion Mismatch errors** (284 failures)
   - Largest category - indicates tests out of sync with implementation
   - Prioritize by directory:
     - integration/ (70 failures)
     - services/ (48 failures)
     - screens/ (35 failures)
   - May require updating test expectations or fixing bugs

6. **Fix Database errors** (21 failures)
   - SQLite/drift issues
   - May indicate race conditions or schema mismatches

7. **Fix Golden Test errors** (14 failures)
   - Visual regression failures
   - Run `./scripts/golden.sh update` after verifying visual changes

## Suggested Attack Plan

**Week 1**: Quick Wins (46 failures fixed)
- Day 1-2: Fix all Widget Not Found (44)
- Day 3: Fix Layout/Rendering (2)

**Week 2**: Safety & Performance (110 failures fixed)
- Day 1-3: Fix Null Safety (57)
- Day 4-5: Investigate and fix Timeouts (53)

**Week 3-4**: Core Functionality (305 failures fixed)
- Fix Assertion Mismatches by priority:
  - integration/ tests
  - services/ tests
  - screens/ tests
  - unit/ tests

**Week 5**: Polish
- Fix Database errors (21)
- Update Golden tests (14)

## Common Patterns to Look For

### Widget Not Found Pattern
```dart
// ❌ Common mistake
await tester.pumpWidget(MyWidget());
expect(find.byType(SomeChild), findsOneWidget); // Fails!

// ✅ Correct
await tester.pumpWidget(MyWidget());
await tester.pumpAndSettle(); // Let async operations complete
expect(find.byType(SomeChild), findsOneWidget);
```

### Null Safety Pattern
```dart
// ❌ Failing code
final value = someMap['key']!; // Null check operator fails

// ✅ Fixed
final value = someMap['key'] ?? defaultValue;
// OR
if (someMap.containsKey('key')) {
  final value = someMap['key']!;
}
```

### Timeout Pattern
```dart
// ❌ Test that times out
testWidgets('loads data', (tester) async {
  await tester.pumpWidget(MyApp());
  // Missing await - test never completes!
  service.fetchData();
  expect(find.text('Data'), findsOneWidget);
});

// ✅ Fixed
testWidgets('loads data', (tester) async {
  await tester.pumpWidget(MyApp());
  await service.fetchData(); // Properly awaited
  await tester.pumpAndSettle();
  expect(find.text('Data'), findsOneWidget);
});
```

## Files for Analysis Scripts

- `/tmp/fresh_test_run.txt` - Full test output
- `categorize_failures.py` - Python analysis script
- `analyze_test_failures.dart` - Dart analysis script (less accurate)

## Next Steps

1. Start with Widget Not Found category (highest ROI)
2. Document patterns as you fix them
3. Update this file with progress
4. Consider adding pre-commit hook to prevent regression
