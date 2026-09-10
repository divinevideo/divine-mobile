import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

// English labels matching app_en.arb values.
String _expirationLabel(VideoMetadataExpiration exp) {
  return switch (exp) {
    VideoMetadataExpiration.notExpire => 'Does not expire',
    VideoMetadataExpiration.oneDay => '1 day',
    VideoMetadataExpiration.oneWeek => '1 week',
    VideoMetadataExpiration.oneMonth => '1 month',
    VideoMetadataExpiration.oneYear => '1 year',
    VideoMetadataExpiration.oneDecade => '1 decade',
  };
}

void main() {
  group('VideoMetadataExpirationSelector', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('displays default expiration option', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      // Default is "Never expire"
      expect(
        find.text(_expirationLabel(VideoMetadataExpiration.notExpire)),
        findsOneWidget,
      );
      expect(find.text('Expiration'), findsOneWidget);
    });

    testWidgets('displays currently selected expiration', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = VideoEditorProviderState(expiration: .oneDay);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      expect(
        find.text(_expirationLabel(VideoMetadataExpiration.oneDay)),
        findsOneWidget,
      );
    });

    testWidgets('opens bottom sheet when tapped', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(_l10n.videoMetadataSelectExpirationSemanticLabel),
      );
      await tester.pumpAndSettle();

      // Bottom sheet should be visible with all options
      expect(find.text('Expiration'), findsNWidgets(2)); // Label + sheet title

      // Check that all expiration options are displayed
      for (final option in VideoMetadataExpiration.values) {
        expect(find.text(_expirationLabel(option)), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('shows checkmark on selected option in bottom sheet', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = VideoEditorProviderState(expiration: .oneDay);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(_l10n.videoMetadataSelectExpirationSemanticLabel),
      );
      await tester.pumpAndSettle();

      // Selected option uses DivineIconName.check in the selection menu.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon && widget.icon == DivineIconName.check,
        ),
        findsOneWidget,
      );
    });

    testWidgets('updates expiration when option is selected', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      VideoMetadataExpiration? selectedExpiration;
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(),
        onSetExpiration: (exp) => selectedExpiration = exp,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(
        find.bySemanticsLabel(_l10n.videoMetadataSelectExpirationSemanticLabel),
      );
      await tester.pumpAndSettle();

      // Select a different option from bottom sheet.
      await tester.tap(
        find.text(_expirationLabel(VideoMetadataExpiration.oneWeek)),
      );
      await tester.pumpAndSettle();

      expect(selectedExpiration, equals(VideoMetadataExpiration.oneWeek));
    });
  });
}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state, {this.onSetExpiration});

  final VideoEditorProviderState _state;
  final void Function(VideoMetadataExpiration)? onSetExpiration;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void setExpiration(VideoMetadataExpiration expiration) {
    onSetExpiration?.call(expiration);
    state = state.copyWith(expiration: expiration);
  }
}
