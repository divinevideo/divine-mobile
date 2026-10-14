// ABOUTME: Tests the "Back up recordings to your gallery" toggle (#10067).
// ABOUTME: Covers turning it on and the message when access is denied.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/recording_gallery_backup_setting.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/recording_gallery_backup_preference_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  group(RecordingGalleryBackupSetting, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late SharedPreferences sharedPreferences;
    late _MockPermissionsService permissions;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      permissions = _MockPermissionsService();
    });

    Widget buildWidget() => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        permissionsServiceProvider.overrideWithValue(permissions),
      ],
      child: MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: RecordingGalleryBackupSetting()),
      ),
    );

    bool switchValue(WidgetTester tester) =>
        tester.widget<DivineSwitchTile>(find.byType(DivineSwitchTile)).value;

    group('interactions', () {
      testWidgets('turns on once gallery access is granted', (tester) async {
        when(
          permissions.checkGalleryStatus,
        ).thenAnswer((_) async => PermissionStatus.granted);
        await tester.pumpWidget(buildWidget());

        await tester.tap(find.text(l10n.settingsBackUpRecordings));
        await tester.pumpAndSettle();

        expect(switchValue(tester), isTrue);
        expect(
          sharedPreferences.getBool(
            RecordingGalleryBackupPreferenceService.prefsKey,
          ),
          isTrue,
        );
      });

      testWidgets('stays off and says why when gallery access is denied', (
        tester,
      ) async {
        when(
          permissions.checkGalleryStatus,
        ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        await tester.pumpWidget(buildWidget());

        await tester.tap(find.text(l10n.settingsBackUpRecordings));
        await tester.pumpAndSettle();

        expect(switchValue(tester), isFalse);
        expect(
          find.text(
            l10n.libraryGalleryPermissionDenied(
              GallerySaveService.destinationName,
            ),
          ),
          findsOneWidget,
        );
      });
    });
  });
}
