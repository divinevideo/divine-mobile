import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group(AnimatedReveal, () {
    Widget buildSubject({
      Widget? child,
      Duration? duration,
      bool disableAnimations = false,
    }) {
      return MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: AnimatedReveal(
                  duration: duration ?? const Duration(milliseconds: 220),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder subject() => find.byType(AnimatedReveal);

    testWidgets('renders the child once it is settled', (tester) async {
      await tester.pumpWidget(
        buildSubject(child: const SizedBox(height: 40, child: Text('badge'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('badge'), findsOneWidget);
      expect(tester.getSize(subject()).height, 40);
    });

    testWidgets('takes no height while the child is null', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(tester.getSize(subject()).height, 0);
    });

    testWidgets('grows into place when the child arrives', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildSubject(child: const SizedBox(height: 40, child: Text('badge'))),
      );
      await tester.pump();
      final revealingHeight = tester.getSize(subject()).height;

      await tester.pumpAndSettle();

      expect(revealingHeight, lessThan(40));
      expect(tester.getSize(subject()).height, 40);
    });

    testWidgets('lays the child out under the parent constraints', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: AnimatedReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('leading')],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Stacking the child (as an AnimatedSwitcher does) would hand it loose
      // constraints, shrink-wrapping the column and centring it instead.
      expect(tester.getSize(find.byType(Column)).width, 300);
      expect(tester.getTopLeft(find.text('leading')).dx, 0);
    });

    testWidgets('lands at full height when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(disableAnimations: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildSubject(
          disableAnimations: true,
          child: const SizedBox(height: 40, child: Text('badge')),
        ),
      );
      await tester.pump();

      expect(tester.getSize(subject()).height, 40);
    });
  });
}
