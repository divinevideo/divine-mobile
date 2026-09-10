import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_limit_warning_banner.dart';

void main() {
  group(VideoMetadataLimitWarningBanner, () {
    Widget buildWidget({bool metadataLimitReached = false}) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(
              VideoEditorProviderState(
                metadataLimitReached: metadataLimitReached,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoMetadataLimitWarningBanner(),
        ),
      );
    }

    testWidgets('renders $SizedBox when limit not reached', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders warning when limit is reached', (tester) async {
      await tester.pumpWidget(buildWidget(metadataLimitReached: true));

      expect(
        find.text('64KB limit reached. Remove some content to continue.'),
        findsOneWidget,
      );
    });

    testWidgets('renders warning icon when limit is reached', (tester) async {
      await tester.pumpWidget(buildWidget(metadataLimitReached: true));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.warning,
        ),
        findsOneWidget,
      );
    });

    testWidgets('warning has correct background color', (tester) async {
      await tester.pumpWidget(buildWidget(metadataLimitReached: true));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(VideoMetadataLimitWarningBanner),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, equals(VineTheme.contentWarningBackground));
    });

    testWidgets('warning has rounded corners', (tester) async {
      await tester.pumpWidget(buildWidget(metadataLimitReached: true));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(VideoMetadataLimitWarningBanner),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(16)));
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
