import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_help_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoMetadataHelpButton, () {
    testWidgets('renders info icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoMetadataHelpButton(
                onTap: () {},
                tooltip: 'Test tooltip',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('has correct tooltip message', (tester) async {
      const tooltipText = 'Test help tooltip';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoMetadataHelpButton(onTap: () {}, tooltip: tooltipText),
            ),
          ),
        ),
      );

      // Tooltip widget should have the correct message
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, tooltipText);
    });

    testWidgets('has correct accessibility semantics', (tester) async {
      const tooltipText = 'Test accessibility label';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoMetadataHelpButton(onTap: () {}, tooltip: tooltipText),
            ),
          ),
        ),
      );

      // Find semantics widget with button=true and the tooltip as label
      final semanticsWidgets = find.byType(Semantics);
      expect(semanticsWidgets, findsWidgets);

      var foundButtonSemantics = false;
      for (final element in semanticsWidgets.evaluate()) {
        final widget = element.widget as Semantics;
        if (widget.properties.button == true &&
            widget.properties.label == tooltipText) {
          foundButtonSemantics = true;
          break;
        }
      }
      expect(foundButtonSemantics, isTrue);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoMetadataHelpButton(
                onTap: () => tapCount++,
                tooltip: 'Test tooltip',
              ),
            ),
          ),
        ),
      );

      expect(tapCount, 0);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('can be tapped multiple times', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoMetadataHelpButton(
                onTap: () => tapCount++,
                tooltip: 'Test tooltip',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, 2);
    });

    testWidgets('renders with correct icon size', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoMetadataHelpButton(
                onTap: () {},
                tooltip: 'Test tooltip',
              ),
            ),
          ),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.width, 16);
      expect(svgPicture.height, 16);
    });
  });
}
