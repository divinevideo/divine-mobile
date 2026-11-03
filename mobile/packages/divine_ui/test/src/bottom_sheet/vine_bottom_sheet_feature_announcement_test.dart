// ABOUTME: Tests for VineBottomSheetFeatureAnnouncement component
// ABOUTME: Verifies rendering, button interactions, semantics, and modal show

import 'dart:ui' show SemanticsFlag;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _illustrationKey = Key('illustration');

final Finder _sparkleIcon = find.byWidgetPredicate(
  (widget) => widget is DivineIcon && widget.icon == DivineIconName.sparkle,
);

const _features = [
  VineBottomSheetFeatureData(
    icon: DivineIconName.closedCaptioning,
    title: 'Turn them on anytime',
    description: 'Tap CC on any video that has captions.',
  ),
  VineBottomSheetFeatureData(
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
    List<VineBottomSheetFeatureData> features = const [],
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
        expect(_sparkleIcon, findsOneWidget);
      });

      testWidgets('wraps a badge label too long for one line', (tester) async {
        final label = List.filled(40, 'New').join(' ');
        await tester.pumpWidget(buildSubject(badgeLabel: label));

        expect(tester.takeException(), isNull);
        expect(find.text(label), findsOneWidget);
      });

      testWidgets('no badge when badgeLabel is null', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(_sparkleIcon, findsNothing);
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
        final rowIcons = find.descendant(
          of: find.byType(MergeSemantics),
          matching: find.byType(DivineIcon),
        );
        final icons = tester
            .widgetList<DivineIcon>(rowIcons)
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
        await tester.pumpWidget(buildSubject());

        expect(
          tester.getSemantics(find.text('Captions')),
          isSemantics(label: 'Captions', isHeader: true),
        );
      });

      testWidgets('reads each feature row as one node', (tester) async {
        // Built at runtime, not reused from the const list, so the item's
        // constructor stays covered.
        await tester.pumpWidget(
          buildSubject(
            features: [
              VineBottomSheetFeatureData(
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
      for (final useSecondary in [false, true]) {
        testWidgets(
          '${useSecondary ? 'secondary' : 'primary'} action closes the root '
          'sheet from a tab and returns its value',
          (tester) async {
            final rootKey = GlobalKey<NavigatorState>();
            final tabKey = GlobalKey<NavigatorState>();
            String? result;
            var primaryCalls = 0;
            var secondaryCalls = 0;
            await tester.pumpWidget(
              MaterialApp(
                navigatorKey: rootKey,
                theme: VineTheme.theme,
                home: Navigator(
                  key: tabKey,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(
                            context,
                            rootNavigator: true,
                          );
                          result =
                              await VineBottomSheetFeatureAnnouncement.show<
                                String
                              >(
                                context: context,
                                illustration: const SizedBox.shrink(),
                                title: 'Captions',
                                primaryButtonText: 'Got it',
                                onPrimaryPressed: () {
                                  primaryCalls++;
                                  navigator.pop('dismissed');
                                },
                                secondaryButtonText: 'Try captions',
                                onSecondaryPressed: () {
                                  secondaryCalls++;
                                  navigator.pop('tried');
                                },
                              );
                        },
                        child: const Text('Show from tab'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Show from tab'));
            await tester.pumpAndSettle();

            // The sheet covers the tab shell and the captured root navigator
            // must be the navigator that can dismiss it.
            expect(
              Navigator.of(
                tester.element(find.byType(VineBottomSheetFeatureAnnouncement)),
              ),
              same(rootKey.currentState),
            );
            expect(primaryCalls, isZero);
            expect(secondaryCalls, isZero);
            expect(result, isNull);

            await tester.tap(
              find.text(useSecondary ? 'Try captions' : 'Got it'),
            );
            await tester.pumpAndSettle();

            expect(result, equals(useSecondary ? 'tried' : 'dismissed'));
            expect(primaryCalls, equals(useSecondary ? 0 : 1));
            expect(secondaryCalls, equals(useSecondary ? 1 : 0));
            expect(
              find.byType(VineBottomSheetFeatureAnnouncement),
              findsNothing,
            );
            expect(find.text('Show from tab'), findsOneWidget);
            expect(tabKey.currentState!.canPop(), isFalse);
            expect(tester.takeException(), isNull);
          },
        );
      }

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
                    final navigator = Navigator.of(
                      context,
                      rootNavigator: true,
                    );
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
                          onPrimaryPressed: () => navigator.pop('dismissed'),
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
        expect(find.byType(Divider), findsNothing);

        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        expect(result, equals('dismissed'));
        expect(find.text('Captions'), findsNothing);
      });
    });
  });
}
