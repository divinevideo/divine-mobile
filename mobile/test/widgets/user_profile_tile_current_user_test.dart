// ABOUTME: Verifies UserProfileTile hides self-directed actions on your own row.
// ABOUTME: Pins the isCurrentUser gate on the follow button and add-to-list action.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../helpers/test_provider_overrides.dart';

const _viewerPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _otherPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group('UserProfileTile isCurrentUser gating', () {
    late _TestAuthService authService;

    setUp(() {
      authService = _TestAuthService()..setCurrentUser(_viewerPubkey);
    });

    // Every other argument is held constant across this pair, so the only
    // thing that can move the follow button is the isCurrentUser comparison.
    // The other-user case is the positive control: without it, a finder that
    // matched nothing would make the self case pass for the wrong reason.
    testWidgets("shows the follow button on another user's row", (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(authService, _otherPubkey));
      await tester.pumpAndSettle();

      expect(_divineIcon(DivineIconName.userPlus), findsOneWidget);
    });

    testWidgets('hides the follow button on your own row', (tester) async {
      await tester.pumpWidget(_buildSubject(authService, _viewerPubkey));
      await tester.pumpAndSettle();

      expect(_divineIcon(DivineIconName.userPlus), findsNothing);
      expect(_divineIcon(DivineIconName.userMinus), findsNothing);
    });

    // showAddToList is `profileListFeatures && curatedLists && !isCurrentUser`.
    // Both flags are on here, so only the identity check can hide it.
    testWidgets('hides the add-to-list action on your own row', (tester) async {
      await tester.pumpWidget(_buildSubject(authService, _viewerPubkey));
      await tester.pumpAndSettle();

      expect(_divineIcon(DivineIconName.listPlus), findsNothing);
    });
  });
}

Widget _buildSubject(_TestAuthService authService, String tilePubkey) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: testProviderScope(
      additionalOverrides: [
        authServiceProvider.overrideWithValue(authService),
        isFeatureEnabledProvider(
          FeatureFlag.profileListFeatures,
        ).overrideWithValue(true),
        isFeatureEnabledProvider(
          FeatureFlag.curatedLists,
        ).overrideWithValue(true),
      ],
      child: Scaffold(
        body: UserProfileTile(
          pubkey: tilePubkey,
          isFollowing: false,
          onToggleFollow: () {},
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
