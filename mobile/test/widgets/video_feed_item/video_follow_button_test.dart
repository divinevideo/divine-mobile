// ABOUTME: Tests for VideoFollowButton widget using MyFollowingBloc
// ABOUTME: Validates follow/unfollow button state, tap behavior, and styling

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockMyFollowingBloc extends MockBloc<MyFollowingEvent, MyFollowingState>
    implements MyFollowingBloc {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group('VideoFollowButtonView', () {
    late _MockMyFollowingBloc mockMyFollowingBloc;

    setUpAll(() {
      registerFallbackValue(const MyFollowingToggleRequested(''));
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
    });

    Widget createTestWidget({required String pubkey}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<MyFollowingBloc>.value(
            value: mockMyFollowingBloc,
            child: VideoFollowButtonView(pubkey: pubkey),
          ),
        ),
      );
    }

    group('button state', () {
      testWidgets('shows follow icon when not following', (tester) async {
        when(
          () => mockMyFollowingBloc.state,
        ).thenReturn(const MyFollowingState(status: MyFollowingStatus.success));

        await tester.pumpWidget(createTestWidget(pubkey: validPubkey('other')));
        await tester.pump();

        // Button uses SVG icons now - find by SvgPicture widget
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('has Follow semantic label when not following', (
        tester,
      ) async {
        when(
          () => mockMyFollowingBloc.state,
        ).thenReturn(const MyFollowingState(status: MyFollowingStatus.success));

        await tester.pumpWidget(createTestWidget(pubkey: validPubkey('other')));
        await tester.pump();

        expect(find.bySemanticsLabel('Follow'), findsOneWidget);
      });

      testWidgets('hides entirely when already following the author', (
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

        // No button at all when following — the affordance disappears.
        expect(find.byType(SvgPicture), findsNothing);
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.bySemanticsLabel('Follow'), findsNothing);
        expect(find.bySemanticsLabel('Following'), findsNothing);
      });
    });

    group('tap target', () {
      Finder paintedBadge() => find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );

      void stubNotFollowing() {
        when(() => mockMyFollowingBloc.state).thenReturn(
          const MyFollowingState(status: MyFollowingStatus.success),
        );
        when(
          () => mockMyFollowingBloc.stream,
        ).thenAnswer((_) => const Stream.empty());
      }

      testWidgets('advertises a target that meets the Android guideline', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final pubkey = validPubkey('follow-target');
        stubNotFollowing();

        // Centred deliberately. MinimumTapTargetGuideline bails out without
        // measuring anything when the node touches a viewport edge, and the
        // button pumped straight into a Scaffold body sits in the top-start
        // corner — the guideline then passes over a 20dp target.
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: BlocProvider<MyFollowingBloc>.value(
                  value: mockMyFollowingBloc,
                  child: VideoFollowButtonView(pubkey: pubkey),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('keeps painting the badge at its original 20dp', (
        tester,
      ) async {
        final pubkey = validPubkey('badge-paint');
        stubNotFollowing();

        await tester.pumpWidget(createTestWidget(pubkey: pubkey));
        await tester.pump();

        expect(tester.getSize(paintedBadge()), const Size(20, 20));
      });

      testWidgets('follows from the corner of the target, not just the badge', (
        tester,
      ) async {
        // The guideline reads the semantics rect, so a node can advertise 48dp
        // while only 20dp of it responds. Tap 40dp in from the origin — inside
        // the target, well outside the painted badge — and require the event.
        final pubkey = validPubkey('corner-tap');
        stubNotFollowing();

        await tester.pumpWidget(createTestWidget(pubkey: pubkey));
        await tester.pump();

        final target = find.byType(VideoFollowButtonView);
        expect(
          tester.getSize(target),
          const Size(
            followButtonTapTargetSize,
            followButtonTapTargetSize,
          ),
        );

        await tester.tapAt(tester.getTopLeft(target) + const Offset(40, 40));
        await tester.pump();

        final captured = verify(
          () => mockMyFollowingBloc.add(captureAny()),
        ).captured;
        expect(captured.single, isA<MyFollowingToggleRequested>());
        expect(
          (captured.single as MyFollowingToggleRequested).pubkey,
          pubkey,
        );
      });
    });

    group('interactions', () {
      testWidgets(
        'dispatches MyFollowingToggleRequested on tap when not following',
        (tester) async {
          final otherPubkey = validPubkey('other');
          when(() => mockMyFollowingBloc.state).thenReturn(
            const MyFollowingState(status: MyFollowingStatus.success),
          );

          await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
          await tester.pump();

          await tester.tap(find.byType(GestureDetector));
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
        },
      );
    });
  });

  group(VideoFollowButton, () {
    testWidgets(
      'renders nothing when the author does not accept interactions from us',
      (tester) async {
        final authorPubkey = 'a' * 64;
        final mockBlocklist = _MockContentBlocklistRepository();
        when(() => mockBlocklist.hasBlockedUs(authorPubkey)).thenReturn(true);
        when(() => mockBlocklist.isBlocked(any())).thenReturn(false);
        when(() => mockBlocklist.isFollowSevered(any())).thenReturn(false);
        when(() => mockBlocklist.currentState).thenReturn(
          ContentPolicyState(
            currentUserPubkey: 'b' * 64,
            mutedPubkeys: const {},
            blockedPubkeys: const {},
            pubkeysBlockingUs: {authorPubkey},
            pubkeysMutingUs: const {},
          ),
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: VideoFollowButton(pubkey: authorPubkey)),
            additionalOverrides: [
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklist,
              ),
            ],
          ),
        );
        await tester.pump();

        // Absence, not a disabled state — no view, no icon, no tooltip.
        expect(find.byType(VideoFollowButtonView), findsNothing);
        expect(find.byType(SvgPicture), findsNothing);
        expect(find.byType(Tooltip), findsNothing);
      },
    );

    testWidgets('renders the follow view for a regular author', (
      tester,
    ) async {
      final authorPubkey = 'a' * 64;
      final mockBlocklist = _MockContentBlocklistRepository();
      when(() => mockBlocklist.hasBlockedUs(any())).thenReturn(false);
      when(() => mockBlocklist.isBlocked(any())).thenReturn(false);
      when(() => mockBlocklist.isFollowSevered(any())).thenReturn(false);
      when(
        () => mockBlocklist.currentState,
      ).thenReturn(ContentPolicyState.empty());

      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: VideoFollowButton(pubkey: authorPubkey)),
          additionalOverrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklist,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(VideoFollowButtonView), findsOneWidget);
    });

    _MockContentBlocklistRepository blocklist({
      required String authorPubkey,
      required bool blocksUs,
    }) {
      final mock = _MockContentBlocklistRepository();
      when(() => mock.hasBlockedUs(authorPubkey)).thenReturn(blocksUs);
      when(() => mock.isBlocked(any())).thenReturn(false);
      when(() => mock.isFollowSevered(any())).thenReturn(false);
      when(() => mock.currentState).thenReturn(
        ContentPolicyState(
          currentUserPubkey: 'b' * 64,
          mutedPubkeys: const {},
          blockedPubkeys: const {},
          pubkeysBlockingUs: blocksUs ? {authorPubkey} : const {},
          pubkeysMutingUs: const {},
        ),
      );
      return mock;
    }

    Widget hostWith(_MockContentBlocklistRepository mock, String pubkey) =>
        testMaterialApp(
          home: Scaffold(body: VideoFollowButton(pubkey: pubkey)),
          additionalOverrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(mock),
          ],
        );

    testWidgets('holds the reservation when the author blocks us', (
      tester,
    ) async {
      final authorPubkey = 'd' * 64;

      await tester.pumpWidget(
        hostWith(
          blocklist(authorPubkey: authorPubkey, blocksUs: true),
          authorPubkey,
        ),
      );
      await tester.pump();

      // The affordance is absent, but the box it lived in is not: collapsing
      // the author cluster is itself a tell that correlates with the block.
      expect(find.byType(VideoFollowButtonView), findsNothing);
      expect(
        tester.getSize(find.byType(VideoFollowButton)),
        const Size(followButtonTapTargetSize, followButtonTapTargetSize),
      );
    });

    testWidgets('does not resize when the blocklist flips while on screen', (
      tester,
    ) async {
      // canTargetUser watches blocklistVersion, so it can change under a
      // mounted item. The reservation is decided in initState and must not
      // follow it — otherwise the row shifts 21dp in front of the viewer.
      final authorPubkey = 'e' * 64;

      await tester.pumpWidget(
        hostWith(
          blocklist(authorPubkey: authorPubkey, blocksUs: false),
          authorPubkey,
        ),
      );
      await tester.pump();
      final before = tester.getSize(find.byType(VideoFollowButton));
      expect(find.byType(VideoFollowButtonView), findsOneWidget);

      // Same tree, new blocklist: the element is reused, so initState does not
      // re-run and this is the live flip rather than a fresh mount.
      await tester.pumpWidget(
        hostWith(
          blocklist(authorPubkey: authorPubkey, blocksUs: true),
          authorPubkey,
        ),
      );
      await tester.pump();

      expect(find.byType(VideoFollowButtonView), findsNothing);
      expect(tester.getSize(find.byType(VideoFollowButton)), before);
    });

    testWidgets('reserves the tap target before the following list resolves', (
      tester,
    ) async {
      // The reservation is what keeps the author cluster from resizing under
      // the reader a beat after the item appears: it is decided in initState,
      // so the footprint is already final on the first frame, while the view
      // inside it is still deciding whether to paint anything.
      final authorPubkey = 'c' * 64;
      final mockBlocklist = _MockContentBlocklistRepository();
      when(() => mockBlocklist.hasBlockedUs(any())).thenReturn(false);
      when(() => mockBlocklist.isBlocked(any())).thenReturn(false);
      when(() => mockBlocklist.isFollowSevered(any())).thenReturn(false);
      when(
        () => mockBlocklist.currentState,
      ).thenReturn(ContentPolicyState.empty());

      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: VideoFollowButton(pubkey: authorPubkey)),
          additionalOverrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklist,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(VideoFollowButton)),
        const Size(followButtonTapTargetSize, followButtonTapTargetSize),
      );
    });
  });
}
