import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_state.dart';

void main() {
  group(ProfileTabLoadingState, () {
    Widget buildSubject({String? message}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(body: ProfileTabLoadingState(message: message)),
      );
    }

    group('renders', () {
      testWidgets('$BrandedLoadingIndicator', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('$CustomScrollView with $SliverFillRemaining', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SliverFillRemaining), findsOneWidget);
      });

      testWidgets('no text when message is null', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(Text), findsNothing);
      });

      testWidgets('message text when provided', (tester) async {
        await tester.pumpWidget(buildSubject(message: 'Loading videos...'));

        expect(find.text('Loading videos...'), findsOneWidget);
      });
    });
  });
}
