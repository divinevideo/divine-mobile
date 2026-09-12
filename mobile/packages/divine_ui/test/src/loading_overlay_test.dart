import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group(LoadingOverlay, () {
    Widget buildSubject({
      required bool isLoading,
      Widget child = const SizedBox(),
      EdgeInsets padding = EdgeInsets.zero,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: LoadingOverlay(
            isLoading: isLoading,
            padding: padding,
            child: child,
          ),
        ),
      );
    }

    testWidgets(
      'renders child',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(isLoading: false, child: const Text('content')),
        );

        expect(find.text('content'), findsOneWidget);
      },
    );

    testWidgets(
      'shows $LinearProgressIndicator when isLoading is true',
      (tester) async {
        await tester.pumpWidget(buildSubject(isLoading: true));

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'hides $LinearProgressIndicator when isLoading is false',
      (tester) async {
        await tester.pumpWidget(buildSubject(isLoading: false));

        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'aligns $LinearProgressIndicator to top center',
      (tester) async {
        await tester.pumpWidget(buildSubject(isLoading: true));

        final align = tester.widget<Align>(
          find.ancestor(
            of: find.byType(LinearProgressIndicator),
            matching: find.byType(Align),
          ),
        );
        expect(align.alignment, Alignment.topCenter);
      },
    );

    testWidgets(
      'applies the provided padding around the indicator',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(isLoading: true, padding: const EdgeInsets.only(top: 4)),
        );

        final padding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byType(LinearProgressIndicator),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(padding.padding, const EdgeInsets.only(top: 4));
      },
    );
  });
}
