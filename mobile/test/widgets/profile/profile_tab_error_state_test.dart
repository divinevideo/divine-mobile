import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_tab_error_state.dart';

void main() {
  group(ProfileTabErrorState, () {
    Widget buildSubject({String message = 'Something went wrong'}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(body: ProfileTabErrorState(message: message)),
      );
    }

    group('renders', () {
      testWidgets('error message', (tester) async {
        await tester.pumpWidget(
          buildSubject(message: 'Error loading liked videos'),
        );

        expect(find.text('Error loading liked videos'), findsOneWidget);
      });

      testWidgets('warning $DivineIcon', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(DivineIcon), findsOneWidget);
      });

      testWidgets('$CustomScrollView with $SliverFillRemaining', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SliverFillRemaining), findsOneWidget);
      });
    });
  });
}
