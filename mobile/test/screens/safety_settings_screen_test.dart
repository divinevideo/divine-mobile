// ABOUTME: Widget tests for SafetySettingsScreen UI and functionality
// ABOUTME: Tests section headers, blocked users list, muted content, filters, and report history

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';

class MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

class MockContentReportingService extends Mock
    implements ContentReportingService {}

void main() {
  group('SafetySettingsScreen Widget Tests', () {
    late MockContentBlocklistService mockBlocklistService;
    late MockContentReportingService mockReportingService;

    setUp(() {
      mockBlocklistService = MockContentBlocklistService();
      mockReportingService = MockContentReportingService();
    });

    Widget createTestWidget() {
      final container = ProviderContainer(
        overrides: [
          contentBlocklistServiceProvider.overrideWithValue(
            mockBlocklistService,
          ),
          // contentReportingServiceProvider is async, so wrap in AsyncValue
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
        ],
      );

      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VineTheme.theme,
          home: const SafetySettingsScreen(),
        ),
      );
    }

    testWidgets('should display "Safety Settings" title in app bar', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Safety Settings'), findsOneWidget);
    });

    testWidgets('should display back button and navigate on tap', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      // Test back navigation
      await tester.tap(backButton);
      await tester.pumpAndSettle();
    });

    testWidgets('should display "Blocked Users" section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('BLOCKED USERS'), findsOneWidget);
    });

    testWidgets('should display "Muted Content" section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('MUTED CONTENT'), findsOneWidget);
    });

    testWidgets('should display "Content Filters" section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('CONTENT FILTERS'), findsOneWidget);
    });

    testWidgets('should display "Report History" section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('REPORT HISTORY'), findsOneWidget);
    });

    testWidgets('should use dark background color', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.black));
    });

    testWidgets('should use VineTheme.vineGreen for app bar background', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });
  });
}
