// ABOUTME: Tests for ProfileFollowersStat, the profile header's followers column
// ABOUTME: Pins the single isOwnProfile flag that gates the OthersFollowersBloc read

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/widgets/profile/profile_followers_stat.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockOthersFollowersBloc
    extends MockBloc<OthersFollowersEvent, OthersFollowersState>
    implements OthersFollowersBloc {}

const _targetPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group(ProfileFollowersStat, () {
    late _MockOthersFollowersBloc othersFollowersBloc;

    setUp(() {
      othersFollowersBloc = _MockOthersFollowersBloc();
      when(() => othersFollowersBloc.state).thenReturn(
        const OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: ['a', 'b', 'c'],
          rawFollowersPubkeys: ['a', 'b', 'c'],
          authoritativeFollowerCount: 42,
          targetPubkey: _targetPubkey,
        ),
      );
    });

    /// Mirrors [ProfileGridView]: the ancestor `OthersFollowersBloc` exists
    /// only for other people's profiles, and the same flag is handed down to
    /// the stat. Both must be driven by one value — see below.
    Widget buildSubject({required bool isOwnProfile}) {
      final stat = ProfileFollowersStat(
        pubkey: _targetPubkey,
        displayName: 'Target',
        isOwnProfile: isOwnProfile,
        initialCount: 7,
      );

      return testMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: isOwnProfile
                ? stat
                : BlocProvider<OthersFollowersBloc>.value(
                    value: othersFollowersBloc,
                    child: stat,
                  ),
          ),
        ),
      );
    }

    testWidgets('shows the ancestor bloc count on another profile', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isOwnProfile: false));
      await tester.pump();

      expect(find.text('42'), findsOneWidget);
    });

    // Regression guard for #1695 (Crashlytics `Provider<OthersFollowersBloc>
    // not found for BlocBuilder<OthersFollowersBloc, OthersFollowersState>`,
    // #6527). The stat used to decide "is this me?" from
    // `nostrServiceProvider.publicKey` while ProfileGridView gated the
    // provider on `authService.currentPublicKeyHex`. During startup the two
    // disagreed, so an own profile got no provider but still built the
    // other-profile view. Any second source of truth reintroduces that crash
    // here, because this tree deliberately has no OthersFollowersBloc.
    testWidgets('never reads OthersFollowersBloc on the own profile', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isOwnProfile: true));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileFollowersStat), findsOneWidget);
    });
  });
}
