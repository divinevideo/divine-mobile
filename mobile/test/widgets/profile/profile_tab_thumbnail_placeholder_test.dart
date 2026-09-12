import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';

void main() {
  group(ProfileTabThumbnailPlaceholder, () {
    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: const Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: ProfileTabThumbnailPlaceholder(),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('$DecoratedBox', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(DecoratedBox), findsOneWidget);
      });

      testWidgets('with border radius of 4', (tester) async {
        await tester.pumpWidget(buildSubject());

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(4)));
      });

      testWidgets('with surfaceContainer color', (tester) async {
        await tester.pumpWidget(buildSubject());

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, equals(VineTheme.surfaceContainer));
      });
    });
  });
}
