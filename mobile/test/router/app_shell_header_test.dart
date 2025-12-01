// ABOUTME: Tests for app shell header with dynamic titles
// ABOUTME: Verifies header shows correct title and camera button for each route

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';

void main() {
  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: ProviderScope(
      child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
    ),
  );

  testWidgets('Header shows Divine on home', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go('/home/0');
    await tester.pump();
    expect(find.text('Divine'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });

  testWidgets('Header shows Explore on explore', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go('/explore/0');
    await tester.pump();
    await tester.pump(); // Extra pump for provider updates
    // Find specifically in AppBar (not bottom nav)
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Explore')),
      findsOneWidget,
    );
  });

  testWidgets('Header shows #tag on hashtag', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go('/hashtag/rust%20lang/0');
    await tester.pump();
    expect(find.text('#rust lang'), findsOneWidget);
  });

  testWidgets('Header shows Profile on profile', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go('/profile/npubXYZ/0');
    await tester.pump();
    // Find specifically in AppBar (not bottom nav)
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Profile')),
      findsOneWidget,
    );
  });

  group('Back button visibility', () {
    testWidgets('Back button shown on hashtag route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go('/hashtag/comedy/0');
      await tester.pumpAndSettle();

      // Should find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsOneWidget);
    });

    testWidgets('Back button shown on search route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go('/search');
      await tester.pumpAndSettle();

      // Should find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsOneWidget);
    });

    testWidgets('No back button on home route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go('/home/0');
      await tester.pumpAndSettle();

      // Should NOT find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsNothing);
    });

    testWidgets('No back button on explore route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go('/explore/0');
      await tester.pumpAndSettle();

      // Should NOT find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsNothing);
    });

    testWidgets('No back button on profile route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go('/profile/npubXYZ/0');
      await tester.pumpAndSettle();

      // Should NOT find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsNothing);
    });

    testWidgets('No back button on notifications route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go('/notifications/0');
      await tester.pumpAndSettle();

      // Should NOT find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsNothing);
    });
  });
}
