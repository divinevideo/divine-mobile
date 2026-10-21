// ABOUTME: Tests the "Mirror front camera" toggle in Create & Share.
// ABOUTME: Covers showing the saved choice and persisting a tap.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/mirror_front_camera_setting.dart';
import 'package:openvine/services/front_camera_mirror_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(MirrorFrontCameraSetting, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<SharedPreferences> pumpSetting(
      WidgetTester tester, {
      Map<String, Object> initialValues = const {},
    }) async {
      SharedPreferences.setMockInitialValues(initialValues);
      final sharedPreferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          ],
          child: MaterialApp(
            theme: VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: MirrorFrontCameraSetting()),
          ),
        ),
      );
      return sharedPreferences;
    }

    bool switchValue(WidgetTester tester) =>
        tester.widget<DivineSwitchTile>(find.byType(DivineSwitchTile)).value;

    group('renders', () {
      testWidgets('the saved choice', (tester) async {
        await pumpSetting(
          tester,
          initialValues: {FrontCameraMirrorPreferenceService.prefsKey: true},
        );

        expect(switchValue(tester), isTrue);
        expect(
          find.text(l10n.settingsMirrorFrontCameraSubtitle),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('turns on and saves the choice when tapped', (tester) async {
        final sharedPreferences = await pumpSetting(tester);
        expect(switchValue(tester), isFalse);

        await tester.tap(find.text(l10n.settingsMirrorFrontCamera));
        await tester.pumpAndSettle();

        expect(switchValue(tester), isTrue);
        expect(
          sharedPreferences.getBool(
            FrontCameraMirrorPreferenceService.prefsKey,
          ),
          isTrue,
        );
      });
    });
  });
}
