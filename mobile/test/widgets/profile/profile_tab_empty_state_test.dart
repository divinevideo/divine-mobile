import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';

void main() {
  group(ProfileTabEmptyState, () {
    Widget buildSubject({
      String title = 'No Items',
      String subtitle = 'Nothing here yet',
      Widget? action,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: ProfileTabEmptyState(
            title: title,
            subtitle: subtitle,
            action: action,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('title text', (tester) async {
        await tester.pumpWidget(buildSubject(title: 'No Videos Yet'));

        expect(find.text('No Videos Yet'), findsOneWidget);
      });

      testWidgets('subtitle text', (tester) async {
        await tester.pumpWidget(
          buildSubject(subtitle: 'Videos you like will appear here'),
        );

        expect(find.text('Videos you like will appear here'), findsOneWidget);
      });

      testWidgets('action under the subtitle', (tester) async {
        await tester.pumpWidget(
          buildSubject(action: const Text('Try again')),
        );

        expect(
          tester.getTopLeft(find.text('Try again')).dy,
          greaterThan(tester.getBottomLeft(find.text('Nothing here yet')).dy),
        );
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
