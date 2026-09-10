import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/conversation/widgets/conversation_app_bar.dart';

void main() {
  group(ConversationAppBar, () {
    Widget buildSubject({
      String displayName = 'Alice',
      String handle = '@alice',
      VoidCallback? onBack,
      VoidCallback? onOptions,
      bool isResolving = false,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: ConversationAppBar(
            displayName: displayName,
            handle: handle,
            onBack: onBack ?? () {},
            onOptions: onOptions ?? () {},
            isResolving: isResolving,
            loadingDisplayName: 'Generated Name',
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $DiVineAppBar', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(DiVineAppBar), findsOneWidget);
      });

      testWidgets('renders display name', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets('renders handle when non-empty', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('@alice'), findsOneWidget);
      });

      testWidgets('does not render handle when empty', (tester) async {
        await tester.pumpWidget(buildSubject(handle: ''));

        expect(find.text('Alice'), findsOneWidget);
        expect(find.text(''), findsNothing);
      });

      testWidgets('announces loading instead of the placeholder identity', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(buildSubject(isResolving: true));

        expect(find.bySemanticsLabel('Loading'), findsOneWidget);
        expect(find.bySemanticsLabel('Generated Name'), findsNothing);
        semantics.dispose();
      });
    });

    group('interactions', () {
      testWidgets('calls onBack when back button is tapped', (tester) async {
        var onBackCalled = false;

        await tester.pumpWidget(
          buildSubject(onBack: () => onBackCalled = true),
        );

        // Identifier, not label: DiVineAppBar's back label is now
        // MaterialLocalizations.backButtonTooltip and moves per locale.
        final backButton = find.bySemanticsIdentifier('back_button');
        await tester.tap(backButton.first);
        await tester.pump();

        expect(onBackCalled, isTrue);
      });

      /* TODO(meylis1998): Uncomment the test below once it has a function.
      testWidgets('calls onOptions when options button is tapped', (
        tester,
      ) async {
        var onOptionsCalled = false;

        await tester.pumpWidget(
          buildSubject(onOptions: () => onOptionsCalled = true),
        );

        final optionsButton = find.bySemanticsLabel('Options');
        await tester.tap(optionsButton.first);
        await tester.pump();

        expect(onOptionsCalled, isTrue);
      });*/
    });
  });
}
