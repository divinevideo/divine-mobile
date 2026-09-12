# Divine Widget Testing Standards

Status: Current
Validated against: current test-writing expectations on 2026-03-19.

## Overview

This document establishes comprehensive widget testing standards for Divine that align with the TDD requirements outlined in the repository guidance. These standards ensure thorough coverage of widget functionality, not just widget existence.

## Testing Philosophy

### Core Principles

1. **Test Behavior, Not Implementation** - Focus on what the widget does, not how it does it
2. **Comprehensive Coverage** - Test all features, edge cases, and error states
3. **Real Interactions** - Test actual user interactions and state changes
4. **Mock External Dependencies** - Use proper mocking for network, navigation, and services
5. **Readable and Maintainable** - Tests should be clear and easy to understand

### Anti-Patterns to Avoid

❌ **Integration Test Cop-Out** - Don't punt core functionality to integration tests
❌ **Happy Path Only** - Don't ignore error states and edge cases
❌ **Surface-Level Assertions** - Don't just check if widgets exist
❌ **Mock Avoidance** - Don't avoid mocking complex dependencies

## Testing Structure

### Required Test Groups

Every widget test file must include these test groups:

```dart
group('WidgetName - Comprehensive Tests', () {
  group('Basic Widget Structure', () {
    // Widget creation, default values, basic rendering
  });

  group('Functionality Tests', () {
    // Core widget behavior, interactions, state changes
  });

  group('Styling and Visual Elements', () {
    // Theming, colors, fonts, layout
  });

  group('User Interactions', () {
    // Tap, scroll, input, gesture handling
  });

  group('Error Handling', () {
    // Error states, null values, invalid inputs
  });

  group('Edge Cases', () {
    // Boundary conditions, unusual inputs, stress scenarios
  });

  group('Accessibility', () {
    // Screen readers, semantic labels, keyboard navigation
  });
});
```

### File Naming Convention

- Test files: `{widget_name}_comprehensive_test.dart`
- Mock files: `{widget_name}_test.mocks.dart`
- Located in: `test/widgets/`

## Core Testing Requirements

### 1. Interaction Testing

**REQUIRED**: Test all user interactions using `tester.tap()`, gesture recognizers, and input simulation.

```dart
testWidgets('handles tap interactions correctly', (tester) async {
  bool tapped = false;

  await tester.pumpWidget(
    MaterialApp(
      home: MyWidget(onTap: () => tapped = true),
    ),
  );

  await tester.tap(find.byType(MyWidget));
  await tester.pumpAndSettle();

  expect(tapped, isTrue);
});
```

### 2. Navigation Testing

**REQUIRED**: Test navigation using `NavigatorObserver` mocks.

```dart
@GenerateNiceMocks([MockSpec<NavigatorObserver>()])
void main() {
  late MockNavigatorObserver mockObserver;

  setUp(() {
    mockObserver = MockNavigatorObserver();
  });

  testWidgets('navigates correctly when action is triggered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [mockObserver],
        home: NavigatingWidget(),
      ),
    );

    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();

    verify(mockObserver.didPush(any, any));
  });
}
```

### 3. State Management Testing

**REQUIRED**: Test Riverpod providers and state changes.

```dart
testWidgets('updates state correctly', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: StatefulWidget(),
      ),
    ),
  );

  final container = ProviderScope.containerOf(
    tester.element(find.byType(StatefulWidget)),
  );

  // Test initial state
  expect(container.read(stateProvider), initialValue);

  // Trigger state change
  await tester.tap(find.text('Change State'));
  await tester.pumpAndSettle();

  // Verify state changed
  expect(container.read(stateProvider), expectedNewValue);
});
```

### 4. Complex Widget Structure Testing

**REQUIRED**: Verify internal widget composition and structure.

```dart
testWidgets('creates correct internal widget structure', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ComplexWidget(config: testConfig),
    ),
  );

  // Verify TextSpan structure for rich text widgets
  final richText = tester.widget<RichText>(find.byType(RichText));
  final spans = richText.text.children?.cast<TextSpan>() ?? [];

  expect(spans.length, expectedSpanCount);
  expect(spans[0].text, expectedFirstSpanText);
  expect(spans[0].recognizer, isA<TapGestureRecognizer>());
});
```

### 5. Error State Testing

**REQUIRED**: Test all error states and fallbacks.

```dart
testWidgets('handles error states gracefully', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NetworkWidget(url: 'invalid-url'),
    ),
  );

  await tester.pumpAndSettle();

  // Should show error UI instead of crashing
  expect(find.byIcon(Icons.error), findsOneWidget);
  expect(find.text('Failed to load'), findsOneWidget);
});
```

### 6. Edge Case Testing

**REQUIRED**: Test boundary conditions and unusual inputs.

```dart
testWidgets('handles edge cases', (tester) async {
  final edgeCases = [
    '', // empty
    '   ', // whitespace only
    'a' * 1000, // very long
    null, // null values
    -1, // negative numbers
    double.infinity, // infinite values
  ];

  for (final testCase in edgeCases) {
    await tester.pumpWidget(
      MaterialApp(
        home: InputWidget(value: testCase),
      ),
    );

    // Should not crash
    expect(find.byType(InputWidget), findsOneWidget);

    await tester.pumpWidget(Container()); // Clear between tests
  }
});
```

## Mocking Standards

### Network Requests

Use `mocktail` or manual mocks for HTTP clients:

```dart
class MockHttpClient extends Mock implements http.Client {}

testWidgets('handles network requests', (tester) async {
  final mockClient = MockHttpClient();
  when(() => mockClient.get(any())).thenAnswer(
    (_) async => http.Response('{"data": "test"}', 200),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: NetworkWidget(client: mockClient),
    ),
  );
});
```

### Services and Providers

Mock complex services using Riverpod overrides:

```dart
testWidgets('mocks service dependencies', (tester) async {
  final mockService = MockDataService();
  when(mockService.fetchData()).thenAnswer((_) async => testData);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dataServiceProvider.overrideWithValue(mockService),
      ],
      child: MaterialApp(
        home: DataWidget(),
      ),
    ),
  );
});
```

### Platform Channels

Mock platform-specific functionality:

```dart
testWidgets('handles platform channel calls', (tester) async {
  const channel = MethodChannel('test_channel');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'testMethod') {
      return 'mocked_response';
    }
    return null;
  });

  // Test widget that uses platform channel
});
```

## Coverage Requirements

### Minimum Coverage Targets

- **Widget Tests**: 90% of all custom widgets must have comprehensive tests
- **Functionality Coverage**: 80% of widget features must be tested
- **User Interactions**: 100% of interactive elements must be tested
- **Error States**: 80% of error conditions must be tested

### Coverage Measurement

Use `flutter test --coverage` to measure coverage:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Testing Utilities

### Common Test Helpers

Create reusable test utilities in `test/test_utils/`:

```dart
// test/test_utils/widget_test_helpers.dart

MaterialApp wrapWidget(Widget widget) {
  return MaterialApp(home: Scaffold(body: widget));
}

ProviderScope wrapWithProviders(
  Widget widget, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: wrapWidget(widget),
  );
}

Future<void> pumpWidgetWithMaterialApp(
  WidgetTester tester,
  Widget widget,
) async {
  await tester.pumpWidget(wrapWidget(widget));
}
```

### Test Data Factories

Create test data in `test/test_data/`:

```dart
// test/test_data/video_test_data.dart

VideoEvent createTestVideoEvent({
  String? id,
  String? title,
  String? videoUrl,
  String? thumbnailUrl,
  String? blurhash,
}) {
  return VideoEvent(
    id: id ?? 'test_video_${DateTime.now().millisecondsSinceEpoch}',
    title: title ?? 'Test Video',
    videoUrl: videoUrl,
    thumbnailUrl: thumbnailUrl,
    blurhash: blurhash,
    pubkey: 'test_pubkey',
    content: 'Test video content',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    timestamp: DateTime.now(),
  );
}
```

## Quality Gates

### Pre-Commit Requirements

1. All new widgets MUST have comprehensive tests
2. `flutter analyze` must pass with zero issues
3. `flutter test` must pass with >90% success rate
4. Mock generation must be up to date (`build_runner`)

### Review Checklist

- [ ] Tests cover all public widget functionality
- [ ] User interactions are tested with actual taps/gestures
- [ ] Error states and edge cases are covered
- [ ] Navigation and routing are properly mocked
- [ ] State management integration is tested
- [ ] Accessibility considerations are addressed
- [ ] Performance considerations are noted
- [ ] Tests are readable and well-documented

## Examples and Templates

### Template for New Widget Tests

```dart
// test/widgets/{widget_name}_comprehensive_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/{widget_name}.dart';

import '../test_utils/widget_test_helpers.dart';
import '../test_data/{relevant_test_data}.dart';

class _MockService extends Mock implements Service {}

void main() {
  group('{WidgetName} - Comprehensive Tests', () {
    late _MockService mockService;

    setUp(() {
      mockService = MockService();
    });

    group('Basic Widget Structure', () {
      testWidgets('creates widget with default values', (tester) async {
        await tester.pumpWidget(wrapWidget(const WidgetName()));

        expect(find.byType(WidgetName), findsOneWidget);
        // Add structure assertions
      });
    });

    group('Functionality Tests', () {
      // Core behavior tests
    });

    group('User Interactions', () {
      // Interaction tests
    });

    group('Error Handling', () {
      // Error state tests
    });

    group('Edge Cases', () {
      // Boundary condition tests
    });

    group('Accessibility', () {
      // Accessibility tests
    });
  });
}
```

## Migration Strategy

### Phase 1: Critical Widgets (Week 1)
- `video_feed_item.dart` - Core video display
- `share_action_button.dart` - Essential social sharing features
- `user_avatar.dart` - Profile display
- `video_overlay_modal.dart` - Video playback UI

### Phase 2: Input/Form Widgets (Week 2)
- `hashtag_input_widget.dart`
- `character_counter_widget.dart`
- `camera_controls_overlay.dart`

### Phase 3: Support/Utility Widgets (Week 3)
- `notification_badge.dart`
- `feed_transition_indicator.dart`
- `content_warning.dart`

### Phase 4: Complex/Integration Widgets (Week 4)
- `filtered_video_grid.dart`
- `vine_recording_controls.dart`
- `app_lifecycle_handler.dart`

## Enforcement

### Automated Checks

1. **Coverage Gate**: CI fails if widget test coverage drops below 80%
2. **Naming Convention**: Lint rule enforces `_comprehensive_test.dart` suffix
3. **Required Groups**: Custom lint rule checks for mandatory test group structure
4. **Mock Generation**: CI ensures mock files are up to date

### Manual Review Requirements

1. All new widgets require comprehensive tests before merge
2. Test coverage must be maintained when modifying existing widgets
3. Performance-sensitive widgets require benchmark tests
4. Accessibility features require specific accessibility test coverage

This document establishes the foundation for professional-grade widget testing that matches the stated TDD requirements in CLAUDE.md while addressing the significant gaps identified in the current test suite.
