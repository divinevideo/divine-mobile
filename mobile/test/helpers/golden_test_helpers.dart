// ABOUTME: Helper utilities for golden testing to simplify adding visual regression tests
// ABOUTME: Provides reusable patterns for theme testing, device testing, and common widget scenarios

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'golden_test_devices.dart';

/// Helper to easily add golden tests to existing widget tests
class GoldenTestHelper {
  /// Quickly test a widget with multiple states in a grid layout
  static Future<void> testWidgetStates({
    required WidgetTester tester,
    required String goldenName,
    required Map<String, Widget> scenarios,
    int columns = 3,
    double widthToHeightRatio = 1,
  }) async {
    final builder = GoldenBuilder.grid(
      columns: columns,
      widthToHeightRatio: widthToHeightRatio,
    );

    scenarios.forEach((name, widget) {
      builder.addScenario(name, widget);
    });

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: materialAppWrapper(),
    );
    await screenMatchesGolden(tester, goldenName);
  }

  /// Test a widget across light and dark themes
  static Future<void> testWidgetThemes({
    required WidgetTester tester,
    required String goldenName,
    required Widget Function(ThemeData theme) widgetBuilder,
    Color? lightBackground,
    Color? darkBackground,
  }) async {
    await tester.pumpWidgetBuilder(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Light Theme
          Theme(
            data: ThemeData.light(),
            child: Container(
              color: lightBackground ?? Colors.white,
              padding: const EdgeInsets.all(20),
              child: widgetBuilder(ThemeData.light()),
            ),
          ),
          // Dark Theme
          Theme(
            data: ThemeData.dark(),
            child: Container(
              color: darkBackground ?? Colors.grey[900],
              padding: const EdgeInsets.all(20),
              child: widgetBuilder(ThemeData.dark()),
            ),
          ),
        ],
      ),
      wrapper: materialAppWrapper(),
    );
    await screenMatchesGolden(tester, goldenName);
  }

  /// Test a widget with different size variations
  static Future<void> testWidgetSizes({
    required WidgetTester tester,
    required String goldenName,
    required Widget Function(double size) widgetBuilder,
    List<double> sizes = const [16, 24, 32, 48, 64, 96],
    int columns = 3,
  }) async {
    final builder = GoldenBuilder.grid(columns: columns, widthToHeightRatio: 1);

    for (final size in sizes) {
      builder.addScenario('${size.toInt()}px', widgetBuilder(size));
    }

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: materialAppWrapper(),
    );
    await screenMatchesGolden(tester, goldenName);
  }

  /// Test a widget across multiple device configurations
  static Future<void> testAcrossDevices({
    required WidgetTester tester,
    required String goldenName,
    required Widget widget,
    List<Device>? devices,
    bool useScaffold = true,
  }) async {
    final testWidget = useScaffold
        ? Scaffold(body: Center(child: widget))
        : widget;

    await tester.pumpWidgetBuilder(testWidget, wrapper: materialAppWrapper());

    await multiScreenGolden(
      tester,
      goldenName,
      devices: devices ?? GoldenTestDevices.defaultDevices,
    );
  }

  /// Test loading, success, and error states of a widget
  static Future<void> testAsyncStates({
    required WidgetTester tester,
    required String goldenName,
    required Widget loadingState,
    required Widget successState,
    required Widget errorState,
    Widget? emptyState,
  }) async {
    final builder =
        GoldenBuilder.grid(
            columns: emptyState != null ? 2 : 3,
            widthToHeightRatio: 1,
          )
          ..addScenario('Loading', loadingState)
          ..addScenario('Success', successState)
          ..addScenario('Error', errorState);

    if (emptyState != null) {
      builder.addScenario('Empty', emptyState);
    }

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: materialAppWrapper(),
    );
    await screenMatchesGolden(tester, goldenName);
  }

  /// Test interaction states like normal, hover, pressed, disabled
  static Future<void> testInteractionStates({
    required WidgetTester tester,
    required String goldenName,
    required Widget normalState,
    required Widget pressedState,
    required Widget disabledState,
    Widget? hoverState,
    Widget? focusedState,
  }) async {
    final scenarios = <String, Widget>{
      'Normal': normalState,
      'Pressed': pressedState,
      'Disabled': disabledState,
    };

    if (hoverState != null) {
      scenarios['Hover'] = hoverState;
    }

    if (focusedState != null) {
      scenarios['Focused'] = focusedState;
    }

    await testWidgetStates(
      tester: tester,
      goldenName: goldenName,
      scenarios: scenarios,
      columns: scenarios.length > 3 ? 3 : scenarios.length,
    );
  }
}

/// Extension methods to make golden testing easier in existing tests
extension GoldenTestExtensions on WidgetTester {
  /// Quick method to add a golden test to any existing widget test
  Future<void> expectGolden(String name, {bool update = false}) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/widgets/$name.png'),
    );
  }

  /// Compare the current widget tree to a golden file with automatic wrapping
  Future<void> matchesGolden(
    Widget widget,
    String name, {
    bool useScaffold = true,
    ThemeData? theme,
  }) async {
    await pumpWidgetBuilder(
      widget,
      wrapper: (child) => MaterialApp(
        theme: theme,
        home: useScaffold ? Scaffold(body: Center(child: child)) : child,
      ),
    );
    await screenMatchesGolden(this, name);
  }
}

/// Convenience wrapper for creating themed widgets
class ThemedWidget extends StatelessWidget {
  const ThemedWidget({super.key, required this.child, this.theme});

  final Widget child;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return Theme(data: theme ?? Theme.of(context), child: child);
  }
}

/// Helper for creating test scenarios with labels
class TestScenario {
  const TestScenario(this.label, this.widget);
  final String label;
  final Widget widget;
}

/// Builder pattern for creating complex golden test scenarios
class GoldenScenarioBuilder {
  final List<TestScenario> _scenarios = [];

  GoldenScenarioBuilder add(String label, Widget widget) {
    _scenarios.add(TestScenario(label, widget));
    return this;
  }

  GoldenScenarioBuilder addIf(bool condition, String label, Widget widget) {
    if (condition) {
      _scenarios.add(TestScenario(label, widget));
    }
    return this;
  }

  Future<void> test({
    required WidgetTester tester,
    required String goldenName,
    int columns = 3,
  }) async {
    final builder = GoldenBuilder.grid(columns: columns, widthToHeightRatio: 1);

    for (final scenario in _scenarios) {
      builder.addScenario(scenario.label, scenario.widget);
    }

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: materialAppWrapper(),
    );
    await screenMatchesGolden(tester, goldenName);
  }
}
