// ABOUTME: Widget tests for the account-wide "Let people remix my videos"
// ABOUTME: switch: the kind 0 write it triggers and the revert on failure.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/remix_setting.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

UserProfile _profile({bool? allowVideoReuse}) => UserProfile(
  pubkey: _pubkey,
  displayName: 'Creator',
  rawData: {
    'display_name': 'Creator',
    divineAllowVideoReuseKey: ?allowVideoReuse,
  },
  createdAt: DateTime(2026),
  eventId: 'a' * 64,
);

void main() {
  group(RemixSetting, () {
    late _MockProfileRepository repository;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(_profile());
    });

    setUp(() {
      repository = _MockProfileRepository();
      when(
        () => repository.fetchFreshProfile(
          pubkey: _pubkey,
          requireRawKind0: true,
        ),
      ).thenAnswer((_) async => _profile());
    });

    void stubSave(Future<UserProfile> Function() answer) {
      when(
        () => repository.saveProfileEvent(
          displayName: any(named: 'displayName'),
          about: any(named: 'about'),
          website: any(named: 'website'),
          picture: any(named: 'picture'),
          banner: any(named: 'banner'),
          allowVideoReuse: any(named: 'allowVideoReuse'),
          currentProfile: any(named: 'currentProfile'),
        ),
      ).thenAnswer((_) => answer());
    }

    Future<void> pumpSetting(WidgetTester tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: const Scaffold(body: RemixSetting()),
          mockAuthService: createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: _pubkey,
          ),
          mockProfileRepository: repository,
          additionalOverrides: [
            currentAuthStateProvider.overrideWithValue(
              AuthState.authenticated,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    DivineSwitch remixSwitch(WidgetTester tester) =>
        tester.widget<DivineSwitch>(find.byType(DivineSwitch));

    group('renders', () {
      testWidgets('shows the title and subtitle', (tester) async {
        await pumpSetting(tester);

        expect(find.text(l10n.remixSettingAllowTitle), findsOneWidget);
        expect(find.text(l10n.remixSettingAllowSubtitle), findsOneWidget);
      });

      testWidgets('reflects a blocked account', (tester) async {
        when(
          () => repository.fetchFreshProfile(
            pubkey: _pubkey,
            requireRawKind0: true,
          ),
        ).thenAnswer((_) async => _profile(allowVideoReuse: false));

        await pumpSetting(tester);

        expect(remixSwitch(tester).value, isFalse);
        expect(remixSwitch(tester).onChanged, isNotNull);
      });

      testWidgets('stays disabled until the profile is read', (tester) async {
        final read = Completer<UserProfile?>();
        when(
          () => repository.fetchFreshProfile(
            pubkey: _pubkey,
            requireRawKind0: true,
          ),
        ).thenAnswer((_) => read.future);

        await pumpSetting(tester);

        expect(remixSwitch(tester).onChanged, isNull);
        read.complete(_profile());
        await tester.pumpAndSettle();
        expect(remixSwitch(tester).onChanged, isNotNull);
      });
    });

    group('interactions', () {
      testWidgets('turning it off publishes the block', (tester) async {
        stubSave(() async => _profile(allowVideoReuse: false));
        await pumpSetting(tester);
        expect(remixSwitch(tester).value, isTrue);

        await tester.tap(find.byType(DivineSwitch));
        await tester.pumpAndSettle();

        verify(
          () => repository.saveProfileEvent(
            displayName: 'Creator',
            about: any(named: 'about'),
            website: any(named: 'website'),
            picture: any(named: 'picture'),
            banner: any(named: 'banner'),
            allowVideoReuse: false,
            currentProfile: _profile(),
          ),
        ).called(1);
        expect(remixSwitch(tester).value, isFalse);
      });

      testWidgets('a failed save reverts the switch and says so', (
        tester,
      ) async {
        stubSave(
          () async => throw const ProfilePublishFailedException('rejected'),
        );
        await pumpSetting(tester);

        await tester.tap(find.byType(DivineSwitch));
        await tester.pumpAndSettle();

        expect(remixSwitch(tester).value, isTrue);
        expect(find.text(l10n.profileSetupPublishFailed), findsOneWidget);
      });

      testWidgets('an offline save names the network', (tester) async {
        stubSave(
          () async => throw const NoRelaysConnectedException('offline'),
        );
        await pumpSetting(tester);

        await tester.tap(find.byType(DivineSwitch));
        await tester.pumpAndSettle();

        expect(remixSwitch(tester).value, isTrue);
        expect(find.text(l10n.profileSetupNoRelaysConnected), findsOneWidget);
      });
    });
  });
}
