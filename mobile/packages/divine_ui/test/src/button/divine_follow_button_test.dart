import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineFollowButton', () {
    Widget buildTestWidget({
      DivineFollowButtonVariant variant = DivineFollowButtonVariant.follow,
      VoidCallback? onPressed,
      String? semanticLabel,
      String? semanticIdentifier,
      double tapTargetSize = DivineFollowButton.defaultTapTargetSize,
      bool disableAnimations = false,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: disableAnimations,
            textScaler: textScaler,
          ),
          child: Scaffold(
            body: Center(
              child: DivineFollowButton(
                variant: variant,
                onPressed: onPressed,
                semanticLabel: semanticLabel,
                semanticIdentifier: semanticIdentifier,
                tapTargetSize: tapTargetSize,
              ),
            ),
          ),
        ),
      );
    }

    Finder disc() => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    );

    Color discColor(WidgetTester tester, {bool last = false}) {
      final containers = tester.widgetList<Container>(disc());
      final container = last ? containers.last : containers.single;
      return (container.decoration! as BoxDecoration).color!;
    }

    DivineIcon glyph(WidgetTester tester) =>
        tester.widget<DivineIcon>(find.byType(DivineIcon));

    /// Pumps until the cross-fade has completed and the switcher has dropped
    /// the outgoing disc. Frame-counting is brittle here: the change is built
    /// on one frame, the ticker records its start time on the next, and the
    /// outgoing disc is dropped one frame after the animation ends.
    Future<void> settleFade(WidgetTester tester) => tester.pumpAndSettle();

    group('rendering', () {
      testWidgets('follow: green disc with the exported white plus', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        expect(discColor(tester), VineTheme.vineGreen);
        expect(glyph(tester).icon, DivineIconName.followPlus);
        expect(glyph(tester).size, DivineFollowButton.badgeSize);
        expect(glyph(tester).color, VineTheme.whiteText);
      });

      testWidgets('selected: dark green disc with the exported green check', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(variant: DivineFollowButtonVariant.selected),
        );

        expect(discColor(tester), VineTheme.onPrimaryButton);
        expect(glyph(tester).icon, DivineIconName.followCheck);
        expect(glyph(tester).size, DivineFollowButton.badgeSize);
        expect(glyph(tester).color, VineTheme.vineGreen);
      });

      testWidgets('paints a 20dp disc centred in a 44dp target', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        final button = tester.getRect(find.byType(DivineFollowButton));
        final badge = tester.getRect(disc());
        expect(button.size, const Size(44, 44));
        expect(badge.size, const Size(20, 20));
        expect(badge.topLeft - button.topLeft, const Offset(12, 12));
      });

      testWidgets('centres the disc in a custom tap target', (tester) async {
        await tester.pumpWidget(buildTestWidget(tapTargetSize: 48));

        final button = tester.getRect(find.byType(DivineFollowButton));
        final badge = tester.getRect(disc());
        expect(button.size, const Size(48, 48));
        expect(badge.topLeft - button.topLeft, const Offset(14, 14));
      });

      testWidgets('rejects a tap target smaller than the disc', (
        tester,
      ) async {
        expect(
          () => DivineFollowButton(
            variant: DivineFollowButtonVariant.follow,
            tapTargetSize: DivineFollowButton.badgeSize - 1,
          ),
          throwsAssertionError,
        );
      });

      testWidgets('ignores the system text scale', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(textScaler: const TextScaler.linear(3)),
        );

        expect(tester.getRect(disc()).size, const Size(20, 20));
        expect(tester.widget<SvgPicture>(find.byType(SvgPicture)).width, 20);
      });
    });

    group('semantics', () {
      testWidgets('is a labelled button when tappable', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
            semanticLabel: 'Follow',
            semanticIdentifier: 'follow_button',
          ),
        );

        final node = tester.getSemantics(find.byType(DivineFollowButton));
        expect(node.label, 'Follow');
        expect(node.identifier, 'follow_button');
        expect(node.flagsCollection.isButton, isTrue);
        expect(find.bySemanticsIdentifier('follow_button'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('is labelled but not a button when inert', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildTestWidget(
            variant: DivineFollowButtonVariant.selected,
            semanticLabel: 'Following',
          ),
        );

        final node = tester.getSemantics(find.byType(DivineFollowButton));
        expect(node.label, 'Following');
        expect(node.flagsCollection.isButton, isFalse);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
        handle.dispose();
      });

      testWidgets('meets the iOS tap target guideline', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildTestWidget(onPressed: () {}, semanticLabel: 'Follow'),
        );

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    });

    group('interaction', () {
      testWidgets('calls onPressed when tapped anywhere in the target', (
        tester,
      ) async {
        var pressed = 0;
        await tester.pumpWidget(buildTestWidget(onPressed: () => pressed++));

        final corner = tester.getTopLeft(find.byType(DivineFollowButton));
        await tester.tapAt(corner + const Offset(2, 2));
        await settleFade(tester);

        expect(pressed, 1);
      });

      testWidgets('lets taps fall through when inert', (tester) async {
        var reachedBehind = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => reachedBehind = true,
                      ),
                    ),
                    const DivineFollowButton(
                      variant: DivineFollowButtonVariant.selected,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DivineFollowButton));
        await tester.pump();

        expect(reachedBehind, isTrue);
      });

      testWidgets('shows the selected disc while held, then releases', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(DivineFollowButton)),
        );
        await settleFade(tester);
        expect(discColor(tester), VineTheme.onPrimaryButton);

        await gesture.up();
        await settleFade(tester);
        expect(discColor(tester), VineTheme.vineGreen);
      });

      testWidgets('releases the selected disc when the tap is cancelled', (
        tester,
      ) async {
        var pressed = 0;
        await tester.pumpWidget(buildTestWidget(onPressed: () => pressed++));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(DivineFollowButton)),
        );
        await settleFade(tester);
        expect(discColor(tester), VineTheme.onPrimaryButton);

        await gesture.moveBy(const Offset(40, 40));
        await settleFade(tester);
        await gesture.up();
        await settleFade(tester);

        expect(discColor(tester), VineTheme.vineGreen);
        expect(pressed, 0);
      });
    });

    group('cross-fade', () {
      testWidgets('cross-fades when a tappable badge becomes inert', (
        tester,
      ) async {
        // The follow-to-selected flip in the app also drops onPressed; the
        // switcher must survive that rather than being rebuilt.
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));
        await tester.pumpWidget(
          buildTestWidget(variant: DivineFollowButtonVariant.selected),
        );

        await tester.pump(const Duration(milliseconds: 50));
        expect(disc(), findsNWidgets(2));

        await settleFade(tester);
        expect(disc(), findsOneWidget);
        expect(discColor(tester), VineTheme.onPrimaryButton);
      });

      testWidgets('cross-fades from follow to selected in 100ms', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpWidget(
          buildTestWidget(variant: DivineFollowButtonVariant.selected),
        );

        // Mid-transition both discs are on screen, the old fading out under
        // the new one fading in.
        await tester.pump(const Duration(milliseconds: 50));
        expect(disc(), findsNWidgets(2));
        expect(discColor(tester, last: true), VineTheme.onPrimaryButton);

        await settleFade(tester);
        expect(disc(), findsOneWidget);
        expect(discColor(tester), VineTheme.onPrimaryButton);
      });

      testWidgets('switches instantly under reduced motion', (tester) async {
        await tester.pumpWidget(buildTestWidget(disableAnimations: true));
        await tester.pumpWidget(
          buildTestWidget(
            variant: DivineFollowButtonVariant.selected,
            disableAnimations: true,
          ),
        );
        await tester.pump();

        expect(disc(), findsOneWidget);
        expect(discColor(tester), VineTheme.onPrimaryButton);
      });
    });
  });
}
