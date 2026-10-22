// ABOUTME: Verifies retired people-list overrides cannot hide list actions.
// ABOUTME: Caller control and tile navigation remain independently available.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group('UserProfileTile list actions', () {
    late _TestAuthService authService;

    setUp(() {
      authService = _TestAuthService()
        ..setCurrentUser(
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        );
    });

    testWidgets(
      'shows add-to-list despite persisted false values for retired flags',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'ff_curatedLists': false,
          'ff_profileListFeatures': false,
        });
        final preferences = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          _buildSubject(authService: authService, preferences: preferences),
        );

        await tester.pumpAndSettle();

        expect(_divineIcon(DivineIconName.listPlus), findsOneWidget);
        final flags = FeatureFlag.values.map((flag) => flag.name);
        expect(flags, isNot(contains('curatedLists')));
        expect(flags, isNot(contains('profileListFeatures')));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(UserProfileTile)),
        );
        expect(
          container
              .read(featureFlagStateProvider)
              .keys
              .map((flag) => flag.name),
          isNot(anyElement(anyOf('curatedLists', 'profileListFeatures'))),
        );
        // Keep the same service and saved preferences while visiting settings.
        final context = tester.element(find.byType(UserProfileTile));
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const FeatureFlagScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Feature Flags'), findsOneWidget);
        expect(find.text('Curated Lists'), findsNothing);
        expect(find.text('Profile List Features'), findsNothing);
      },
    );

    testWidgets('caller can hide the add-to-list action', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authService: authService, showAddToListButton: false),
      );
      await tester.pumpAndSettle();
      expect(_divineIcon(DivineIconName.listPlus), findsNothing);
    });

    testWidgets('tile responds when tapping the avatar-name gap', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        _buildSubject(authService: authService, onTap: () => tapped = true),
      );

      await tester.pumpAndSettle();

      final avatar = find.byType(UserAvatar);
      expect(avatar, findsOneWidget);

      final avatarRect = tester.getRect(avatar);

      await tester.tapAt(Offset(avatarRect.right + 6, avatarRect.center.dy));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}

Widget _buildSubject({
  required _TestAuthService authService,
  SharedPreferences? preferences,
  bool showAddToListButton = true,
  VoidCallback? onTap,
}) {
  return testProviderScope(
    mockSharedPreferences: preferences,
    additionalOverrides: [authServiceProvider.overrideWithValue(authService)],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: UserProfileTile(
          pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          onTap: onTap,
          showAddToListButton: showAddToListButton,
        ),
      ),
    ),
  );
}

class _TestAuthService implements AuthService {
  String? _currentUser;

  void setCurrentUser(String pubkey) {
    _currentUser = pubkey;
  }

  @override
  String? get currentPublicKeyHex => _currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
