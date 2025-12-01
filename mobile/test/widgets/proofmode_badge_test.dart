// ABOUTME: Tests for ProofMode verification badge widgets
// ABOUTME: Validates badge rendering, colors, and display logic for all verification levels

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/proofmode_badge.dart';

void main() {
  group('ProofModeBadge Widget', () {
    testWidgets('renders Verified Mobile badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.verifiedMobile,
              size: BadgeSize.small,
            ),
          ),
        ),
      );

      // Should display verified icon
      expect(find.byIcon(Icons.verified), findsOneWidget);

      // Should display correct text
      expect(find.text('Fully Verified'), findsOneWidget);

      // Check the badge container exists
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders Verified Web badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.verifiedWeb,
              size: BadgeSize.small,
            ),
          ),
        ),
      );

      // Should display shield icon
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Should display correct text
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('renders Basic Proof badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.basicProof,
              size: BadgeSize.small,
            ),
          ),
        ),
      );

      // Should display info icon
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      // Should display correct text
      expect(find.text('Basic Proof'), findsOneWidget);
    });

    testWidgets('renders Unverified badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.unverified,
              size: BadgeSize.small,
            ),
          ),
        ),
      );

      // Should display shield icon
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Should display correct text
      expect(find.text('Unverified'), findsOneWidget);
    });

    testWidgets('renders different badge sizes correctly', (tester) async {
      // Test small size
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.verifiedMobile,
              size: BadgeSize.small,
            ),
          ),
        ),
      );

      var badge = tester.widget<ProofModeBadge>(find.byType(ProofModeBadge));
      expect(badge.size, BadgeSize.small);

      // Test medium size
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.verifiedMobile,
              size: BadgeSize.medium,
            ),
          ),
        ),
      );

      badge = tester.widget<ProofModeBadge>(find.byType(ProofModeBadge));
      expect(badge.size, BadgeSize.medium);

      // Test large size
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.verifiedMobile,
              size: BadgeSize.large,
            ),
          ),
        ),
      );

      badge = tester.widget<ProofModeBadge>(find.byType(ProofModeBadge));
      expect(badge.size, BadgeSize.large);
    });

    testWidgets('badge has proper visual structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofModeBadge(
              level: VerificationLevel.verifiedMobile,
              size: BadgeSize.small,
            ),
          ),
        ),
      );

      // Should have Container for styling
      expect(find.byType(Container), findsWidgets);

      // Should have Row for icon + text layout
      expect(find.byType(Row), findsOneWidget);

      // Should have Icon and Text widgets
      expect(find.byType(Icon), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('OriginalVineBadge Widget', () {
    testWidgets('renders Original Vine badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OriginalVineBadge(size: BadgeSize.small)),
        ),
      );

      // Should display 'V' text
      expect(find.text('V'), findsOneWidget);

      // Should display 'Original Vine' text
      expect(find.text('Original Vine'), findsOneWidget);

      // Check the badge container exists
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders different Vine badge sizes correctly', (tester) async {
      // Test small size
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OriginalVineBadge(size: BadgeSize.small)),
        ),
      );

      var badge = tester.widget<OriginalVineBadge>(
        find.byType(OriginalVineBadge),
      );
      expect(badge.size, BadgeSize.small);

      // Test medium size
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OriginalVineBadge(size: BadgeSize.medium)),
        ),
      );

      badge = tester.widget<OriginalVineBadge>(find.byType(OriginalVineBadge));
      expect(badge.size, BadgeSize.medium);

      // Test large size
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OriginalVineBadge(size: BadgeSize.large)),
        ),
      );

      badge = tester.widget<OriginalVineBadge>(find.byType(OriginalVineBadge));
      expect(badge.size, BadgeSize.large);
    });

    testWidgets('Vine badge has proper visual structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OriginalVineBadge(size: BadgeSize.small)),
        ),
      );

      // Should have Container for styling
      expect(find.byType(Container), findsWidgets);

      // Should have Row for V + text layout
      expect(find.byType(Row), findsOneWidget);

      // Should have two Text widgets (V and Original Vine)
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('Vine badge has teal background color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OriginalVineBadge(size: BadgeSize.small)),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OriginalVineBadge),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF00BF8F)); // Vine teal
    });
  });

  group('Badge Enum Values', () {
    test('VerificationLevel has all expected values', () {
      expect(VerificationLevel.values, hasLength(4));
      expect(
        VerificationLevel.values,
        contains(VerificationLevel.verifiedMobile),
      );
      expect(VerificationLevel.values, contains(VerificationLevel.verifiedWeb));
      expect(VerificationLevel.values, contains(VerificationLevel.basicProof));
      expect(VerificationLevel.values, contains(VerificationLevel.unverified));
    });

    test('BadgeSize has all expected values', () {
      expect(BadgeSize.values, hasLength(3));
      expect(BadgeSize.values, contains(BadgeSize.small));
      expect(BadgeSize.values, contains(BadgeSize.medium));
      expect(BadgeSize.values, contains(BadgeSize.large));
    });
  });
}
