// ABOUTME: Tests for FollowFromProfileButton widget using MyFollowingBloc
// ABOUTME: Validates follow/unfollow button state, tap behavior, and visibility logic

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';

class _MockMyFollowingBloc extends MockBloc<MyFollowingEvent, MyFollowingState>
    implements MyFollowingBloc {}

class _MockOthersFollowersBloc
    extends MockBloc<OthersFollowersEvent, OthersFollowersState>
    implements OthersFollowersBloc {}

void main() {
  group('FollowFromProfileButtonView', () {
    late _MockMyFollowingBloc mockMyFollowingBloc;
    late _MockOthersFollowersBloc mockOthersFollowersBloc;

    setUpAll(() {
      registerFallbackValue(const MyFollowingToggleRequested(''));
      registerFallbackValue(const OthersFollowersIncrementRequested(''));
      registerFallbackValue(const OthersFollowersDecrementRequested(''));
    });

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockMyFollowingBloc = _MockMyFollowingBloc();
      mockOthersFollowersBloc = _MockOthersFollowersBloc();
    });

    Widget createTestWidget({
      required String pubkey,
      String? currentUserPubkey,
      bool includeOthersFollowersBloc = false,
    }) {
      Widget child = BlocProvider<MyFollowingBloc>.value(
        value: mockMyFollowingBloc,
        child: FollowFromProfileButtonView(
          pubkey: pubkey,
          displayName: 'Test User',
          currentUserPubkey: currentUserPubkey,
        ),
      );

      if (includeOthersFollowersBloc) {
        child = BlocProvider<OthersFollowersBloc>.value(
          value: mockOthersFollowersBloc,
          child: child,
        );
      }

      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SizedBox(width: 200, child: child)),
      );
    }

    group('button state', () {
      testWidgets(
        'renders nothing when the author does not accept interactions from us',
        (tester) async {
          when(
            () => mockMyFollowingBloc.state,
          ).thenReturn(const MyFollowingState());

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: BlocProvider<MyFollowingBloc>.value(
                  value: mockMyFollowingBloc,
                  child: FollowFromProfileButtonView(
                    pubkey: validPubkey('author'),
                    displayName: 'Author',
                    currentUserPubkey: validPubkey('viewer'),
                    canTargetAuthor: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          // Absence, not a disabled state — no button, no text, no tooltip.
          expect(find.byType(OutlinedButton), findsNothing);
          expect(find.byType(ElevatedButton), findsNothing);
          expect(find.text('Follow'), findsNothing);
          expect(find.byType(Tooltip), findsNothing);
        },
      );

      testWidgets('shows DivineButton with "Follow" when not following', (
        tester,
      ) async {
        when(
          () => mockMyFollowingBloc.state,
        ).thenReturn(const MyFollowingState(status: MyFollowingStatus.success));

        await tester.pumpWidget(createTestWidget(pubkey: validPubkey('other')));
        await tester.pump();

        expect(find.text('Follow'), findsOneWidget);
        expect(find.byType(DivineButton), findsOneWidget);
        // The unfollow E2E journey watches this button reappear, and does it
        // by id so the assertion survives a non-English device.
        expect(
          find.bySemanticsIdentifier(SemanticIds.profileFollowAction),
          findsOneWidget,
        );
      });

      testWidgets('shows icon-only DivineButton when following', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        when(() => mockMyFollowingBloc.state).thenReturn(
          MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [otherPubkey],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        // Following state shows icon-only button (no label text)
        expect(find.text('Follow'), findsNothing);
        expect(find.byType(DivineButton), findsOneWidget);
        // Verify it has the userCheck icon
        expect(find.byType(DivineIcon), findsOneWidget);
      });

      testWidgets('announces the icon-only following button as unfollow', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        when(() => mockMyFollowingBloc.state).thenReturn(
          MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [otherPubkey],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.unfollowUserSemanticLabel),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('dispatches MyFollowingToggleRequested when tapping Follow', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        when(
          () => mockMyFollowingBloc.state,
        ).thenReturn(const MyFollowingState(status: MyFollowingStatus.success));

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        await tester.tap(find.text('Follow'));
        await tester.pump();

        final captured = verify(
          () => mockMyFollowingBloc.add(captureAny()),
        ).captured;
        expect(captured.length, 1);
        expect(captured.first, isA<MyFollowingToggleRequested>());
        expect(
          (captured.first as MyFollowingToggleRequested).pubkey,
          otherPubkey,
        );
      });

      testWidgets(
        'shows unfollow confirmation sheet when tapping follow button',
        (tester) async {
          final otherPubkey = validPubkey('other');
          when(() => mockMyFollowingBloc.state).thenReturn(
            MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [otherPubkey],
            ),
          );

          await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
          await tester.pump();

          await tester.tap(find.byType(DivineButton));
          await tester.pumpAndSettle();

          // Verify confirmation sheet is shown
          expect(find.text('Unfollow Test User?'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);
          expect(find.text('Unfollow'), findsOneWidget);
        },
      );

      testWidgets(
        'dispatches MyFollowingToggleRequested when confirming unfollow',
        (tester) async {
          final otherPubkey = validPubkey('other');
          when(() => mockMyFollowingBloc.state).thenReturn(
            MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [otherPubkey],
            ),
          );

          await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
          await tester.pump();

          // Open confirmation sheet
          await tester.tap(find.byType(DivineButton));
          await tester.pumpAndSettle();

          // Tap Unfollow to confirm
          await tester.tap(find.text('Unfollow'));
          await tester.pumpAndSettle();

          final captured = verify(
            () => mockMyFollowingBloc.add(captureAny()),
          ).captured;
          expect(captured.length, 1);
          expect(captured.first, isA<MyFollowingToggleRequested>());
        },
      );

      testWidgets('does not dispatch when cancelling unfollow confirmation', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        when(() => mockMyFollowingBloc.state).thenReturn(
          MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [otherPubkey],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        // Open confirmation sheet
        await tester.tap(find.byType(DivineButton));
        await tester.pumpAndSettle();

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(() => mockMyFollowingBloc.add(any()));
      });

      testWidgets('shows localized snackbar when follow toggle fails', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        final states = StreamController<MyFollowingState>();
        addTearDown(states.close);
        whenListen(
          mockMyFollowingBloc,
          states.stream,
          initialState: const MyFollowingState(
            status: MyFollowingStatus.success,
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        states.add(
          const MyFollowingState(status: MyFollowingStatus.toggleFailure),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.followersUpdateFollowFailed), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
      });
    });

    group('optimistic follower count update', () {
      testWidgets(
        'dispatches OthersFollowersIncrementRequested when following',
        (tester) async {
          final otherPubkey = validPubkey('other');
          final currentUserPubkey = validPubkey('me');

          when(() => mockMyFollowingBloc.state).thenReturn(
            const MyFollowingState(status: MyFollowingStatus.success),
          );
          when(() => mockOthersFollowersBloc.state).thenReturn(
            const OthersFollowersState(status: OthersFollowersStatus.success),
          );

          await tester.pumpWidget(
            createTestWidget(
              pubkey: otherPubkey,
              currentUserPubkey: currentUserPubkey,
              includeOthersFollowersBloc: true,
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Follow'));
          await tester.pump();

          final captured = verify(
            () => mockOthersFollowersBloc.add(captureAny()),
          ).captured;
          expect(captured.length, 1);
          expect(captured.first, isA<OthersFollowersIncrementRequested>());
          expect(
            (captured.first as OthersFollowersIncrementRequested)
                .followerPubkey,
            currentUserPubkey,
          );
        },
      );

      testWidgets(
        'dispatches OthersFollowersDecrementRequested when unfollowing',
        (tester) async {
          final otherPubkey = validPubkey('other');
          final currentUserPubkey = validPubkey('me');

          when(() => mockMyFollowingBloc.state).thenReturn(
            MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [otherPubkey],
            ),
          );
          when(() => mockOthersFollowersBloc.state).thenReturn(
            OthersFollowersState(
              status: OthersFollowersStatus.success,
              followersPubkeys: [currentUserPubkey],
            ),
          );

          await tester.pumpWidget(
            createTestWidget(
              pubkey: otherPubkey,
              currentUserPubkey: currentUserPubkey,
              includeOthersFollowersBloc: true,
            ),
          );
          await tester.pump();

          // Open confirmation sheet
          await tester.tap(find.byType(DivineButton));
          await tester.pumpAndSettle();

          // Confirm unfollow
          await tester.tap(find.text('Unfollow'));
          await tester.pumpAndSettle();

          final captured = verify(
            () => mockOthersFollowersBloc.add(captureAny()),
          ).captured;
          expect(captured.length, 1);
          expect(captured.first, isA<OthersFollowersDecrementRequested>());
          expect(
            (captured.first as OthersFollowersDecrementRequested)
                .followerPubkey,
            currentUserPubkey,
          );
        },
      );

      testWidgets(
        'does not dispatch to OthersFollowersBloc when not provided',
        (tester) async {
          final otherPubkey = validPubkey('other');
          final currentUserPubkey = validPubkey('me');

          when(() => mockMyFollowingBloc.state).thenReturn(
            const MyFollowingState(status: MyFollowingStatus.success),
          );

          await tester.pumpWidget(
            createTestWidget(
              pubkey: otherPubkey,
              currentUserPubkey: currentUserPubkey,
              // OthersFollowersBloc not provided
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Follow'));
          await tester.pump();

          // Should not throw and should still dispatch to MyFollowingBloc
          verify(() => mockMyFollowingBloc.add(any())).called(1);
          verifyNever(() => mockOthersFollowersBloc.add(any()));
        },
      );
    });
  });
}
