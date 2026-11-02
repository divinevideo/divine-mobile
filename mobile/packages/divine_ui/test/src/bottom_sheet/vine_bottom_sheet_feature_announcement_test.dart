// ABOUTME: Tests for VineBottomSheetFeatureAnnouncement component
// ABOUTME: Verifies rendering, button interactions, semantics, and modal show

import 'dart:ui' show SemanticsFlag;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _illustrationKey = Key('illustration');

const _features = [
  VineFeatureAnnouncementItem(
    icon: DivineIconName.closedCaptioning,
    title: 'Turn them on anytime',
    description: 'Tap CC on any video that has captions.',
  ),
  VineFeatureAnnouncementItem(
    icon: DivineIconName.gear,
    title: 'Your choice sticks',
    description: 'Keep captions on for every video in Settings.',
  ),
];

void main() {
  Widget buildSubject({
    Widget illustration = const SizedBox.square(
      key: _illustrationKey,
      dimension: 100,
    ),
    String? badgeLabel,
    String? subtitle,
    List<VineFeatureAnnouncementItem> features = const [],
    VoidCallback? onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
  }) {
    return MaterialApp(
      theme: VineTheme.theme,
      home: Scaffold(
        body: VineBottomSheetFeatureAnnouncement(
          illustration: illustration,
          badgeLabel: badgeLabel,
          title: 'Captions',
          subtitle: subtitle,
          features: features,
          primaryButtonText: 'Got it',
          onPrimaryPressed: onPrimaryPressed ?? () {},
          secondaryButtonText: secondaryButtonText,
          onSecondaryPressed: onSecondaryPressed,
        ),
      ),
    );
  }

  group(VineBottomSheetFeatureAnnouncement, () {
    group('constructor', () {
      test('asserts when secondaryButtonText has no onSecondaryPressed', () {
        expect(
          () => VineBottomSheetFeatureAnnouncement(
            illustration: const SizedBox.shrink(),
            title: 'Captions',
            primaryButtonText: 'Got it',
            onPrimaryPressed: () {},
            secondaryButtonText: 'Turn on captions',
          ),
          throwsAssertionError,
        );
      });

      test('asserts when onSecondaryPressed has no secondaryButtonText', () {
        expect(
          () => VineBottomSheetFeatureAnnouncement(
            illustration: const SizedBox.shrink(),
            title: 'Captions',
            primaryButtonText: 'Got it',
            onPrimaryPressed: () {},
            onSecondaryPressed: () {},
          ),
          throwsAssertionError,
        );
      });
    });

    group('renders', () {
      testWidgets('illustration, title and primary button', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byKey(_illustrationKey), findsOneWidget);
        expect(find.text('Captions'), findsOneWidget);
        expect(find.text('Got it'), findsOneWidget);
        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('badge with sparkle icon when badgeLabel is set', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(badgeLabel: 'New'));

        expect(find.text('New'), findsOneWidget);
        final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(icon.icon, equals(DivineIconName.sparkle));
      });

      testWidgets('no badge when badgeLabel is null', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(DivineIcon), findsNothing);
      });

      testWidgets('subtitle when provided', (tester) async {
        await tester.pumpWidget(
          buildSubject(subtitle: 'Read along, even with the sound off.'),
        );

        expect(
          find.text('Read along, even with the sound off.'),
          findsOneWidget,
        );
      });

      testWidgets('one row per feature with icon, title and description', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(features: _features));

        for (final feature in _features) {
          expect(find.text(feature.title), findsOneWidget);
          expect(find.text(feature.description), findsOneWidget);
        }
        final icons = tester
            .widgetList<DivineIcon>(find.byType(DivineIcon))
            .map((icon) => icon.icon);
        expect(
          icons,
          equals([DivineIconName.closedCaptioning, DivineIconName.gear]),
        );
      });

      testWidgets('secondary button when provided', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            secondaryButtonText: 'Turn on captions',
            onSecondaryPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsNWidgets(2));
        final secondary = tester.widget<DivineButton>(
          find.byType(DivineButton).last,
        );
        expect(secondary.label, equals('Turn on captions'));
        expect(secondary.type, equals(DivineButtonType.secondary));
      });
    });

    group('semantics', () {
      testWidgets('marks the title as a header', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildSubject());

        expect(
          tester.getSemantics(find.text('Captions')),
          isSemantics(label: 'Captions', isHeader: true),
        );
        handle.dispose();
      });

      testWidgets('reads each feature row as one node', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildSubject(
            features: [
              VineFeatureAnnouncementItem(
                icon: _features.first.icon,
                title: _features.first.title,
                description: _features.first.description,
              ),
            ],
          ),
        );

        // matchesSemantics, unlike isSemantics, also fails on unexpected
        // flags, such as the image flag an unexcluded row icon would add.
        expect(
          tester.getSemantics(find.text('Turn them on anytime')),
          matchesSemantics(
            label:
                'Turn them on anytime\n'
                'Tap CC on any video that has captions.',
          ),
        );
        handle.dispose();
      });

      testWidgets('hides the illustration from screen readers', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(illustration: const Text('Sparkle art')),
        );

        expect(find.text('Sparkle art'), findsOneWidget);
        expect(find.bySemanticsLabel('Sparkle art'), findsNothing);
      });

      testWidgets('hides the badge sparkle icon from screen readers', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(badgeLabel: 'New'));

        expect(find.bySemanticsLabel('New'), findsOneWidget);
        expect(find.semantics.byFlag(SemanticsFlag.isImage), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('calls onPrimaryPressed when primary button tapped', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          buildSubject(onPrimaryPressed: () => tapped = true),
        );

        await tester.tap(find.text('Got it'));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('calls onSecondaryPressed when secondary button tapped', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          buildSubject(
            secondaryButtonText: 'Turn on captions',
            onSecondaryPressed: () => tapped = true,
          ),
        );

        await tester.tap(find.text('Turn on captions'));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });

    group('show', () {
      testWidgets('opens as a modal and returns the popped value', (
        tester,
      ) async {
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result =
                        await VineBottomSheetFeatureAnnouncement.show<String>(
                          context: context,
                          illustration: const SizedBox.square(
                            key: _illustrationKey,
                            dimension: 100,
                          ),
                          badgeLabel: 'New',
                          title: 'Captions',
                          subtitle: 'Read along, even with the sound off.',
                          features: _features,
                          primaryButtonText: 'Got it',
                          onPrimaryPressed: () =>
                              Navigator.of(context).pop('dismissed'),
                          secondaryButtonText: 'Turn on captions',
                          onSecondaryPressed: () {},
                        );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(find.byKey(_illustrationKey), findsOneWidget);
        expect(find.text('New'), findsOneWidget);
        expect(find.text('Captions'), findsOneWidget);
        expect(
          find.text('Read along, even with the sound off.'),
          findsOneWidget,
        );
        for (final feature in _features) {
          expect(find.text(feature.title), findsOneWidget);
        }
        expect(find.text('Turn on captions'), findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        expect(result, equals('dismissed'));
        expect(find.text('Captions'), findsNothing);
      });

      testWidgets('forwards onSecondaryPressed to the secondary button', (
        tester,
      ) async {
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    result =
                        await VineBottomSheetFeatureAnnouncement.show<String>(
                          context: context,
                          illustration: const SizedBox.square(dimension: 100),
                          title: 'Captions',
                          primaryButtonText: 'Got it',
                          onPrimaryPressed: () => navigator.pop('dismissed'),
                          secondaryButtonText: 'Turn on captions',
                          onSecondaryPressed: () => navigator.pop('tried'),
                        );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Turn on captions'));
        await tester.pumpAndSettle();

        expect(result, equals('tried'));
      });
    });
  });
}
