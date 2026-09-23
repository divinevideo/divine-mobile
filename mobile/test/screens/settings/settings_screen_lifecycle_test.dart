// ABOUTME: Proves SettingsScreen survives being closed while its app-version
// ABOUTME: lookup is still in flight, instead of calling setState after dispose.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:package_info_plus_platform_interface/package_info_data.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

/// Holds the platform lookup open until the test releases it, so the screen
/// can be closed while `_loadAppVersion` is still awaiting.
class _PendingPackageInfo extends PackageInfoPlatform {
  final completer = Completer<PackageInfoData>();

  @override
  Future<PackageInfoData> getAll({String? baseUrl}) => completer.future;
}

void main() {
  group('SettingsScreen lifecycle', () {
    late _MockAuthService authService;
    late _MockLocaleCubit localeCubit;
    late SharedPreferences preferences;
    late _PendingPackageInfo packageInfo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      final originalPackageInfo = PackageInfoPlatform.instance;
      addTearDown(() => PackageInfoPlatform.instance = originalPackageInfo);
      packageInfo = _PendingPackageInfo();
      PackageInfoPlatform.instance = packageInfo;
      authService = _MockAuthService();
      localeCubit = _MockLocaleCubit();
      when(() => localeCubit.state).thenReturn(const LocaleState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.isAnonymous).thenReturn(false);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.automatic);
    });

    testWidgets('closing it mid-version-lookup does not call setState', (
      tester,
    ) async {
      Widget app(Widget home) => ProviderScope(
        overrides: [
          // Membership has separate account/lifecycle coverage.
          supporterApiConfiguredProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<LocaleCubit>.value(
            value: localeCubit,
            child: home,
          ),
        ),
      );

      // initState starts the lookup; it stays pending, so leaving the screen
      // now is the ordinary case of opening settings and going straight back.
      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pumpWidget(app(const SizedBox.shrink()));

      packageInfo.completer.complete(
        PackageInfoData(
          appName: 'Divine',
          packageName: 'video.divine',
          version: '1.0.0',
          buildNumber: '1',
          buildSignature: '',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
