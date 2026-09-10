import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';

void main() {
  group(ProfileTabLoadingMoreSliver, () {
    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: const Scaffold(
          body: CustomScrollView(slivers: [ProfileTabLoadingMoreSliver()]),
        ),
      );
    }

    group('renders', () {
      testWidgets('$BrandedLoadingIndicator', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('$SliverToBoxAdapter', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(SliverToBoxAdapter), findsOneWidget);
      });

      testWidgets('centered with padding', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(Center), findsOneWidget);
        expect(find.byType(Padding), findsOneWidget);
      });
    });
  });
}
