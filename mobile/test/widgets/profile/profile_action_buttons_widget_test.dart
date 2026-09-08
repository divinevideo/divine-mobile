// ABOUTME: Tests for profile action button row composition and target gating
// ABOUTME: Verifies target-directed affordances are absent without explanation

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_notify_bell_button.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../helpers/accessibility_guidelines.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNotifySubscriptionsRepository extends Mock
    implements NotifySubscriptionsRepository {}

void main() {
  const targetPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const viewerPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late MockFollowRepository followRepository;
  late _MockContentBlocklistRepository blocklistRepository;
  late MockNostrClient nostrClient;
  late _MockNotifySubscriptionsRepository notifyRepository;
  late StreamController<Set<String>> notifySubscriptions;

  setUp(() {
    notifyRepository = _MockNotifySubscriptionsRepository();
    notifySubscriptions = StreamController<Set<String>>.broadcast();
    when(
      () => notifyRepository.watchSubscriptions(
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) => notifySubscriptions.stream);
    when(
      () => notifyRepository.subscribe(
        ownerPubkey: any(named: 'ownerPubkey'),
        creatorPubkey: any(named: 'creatorPubkey'),
      ),
    ).thenAnswer(
      (_) async => const PeopleListPublishResult.submitted(eventId: 'e1'),
    );
    when(
      () => notifyRepository.unsubscribe(
        ownerPubkey: any(named: 'ownerPubkey'),
        creatorPubkey: any(named: 'creatorPubkey'),
      ),
    ).thenAnswer(
      (_) async => const PeopleListPublishResult.submitted(eventId: 'e1'),
    );
    when(
      () => notifyRepository.reconcile(ownerPubkey: any(named: 'ownerPubkey')),
    ).thenAnswer((_) async => const PeopleListPublishResult.noop());
    followRepository = MockFollowRepository();
    blocklistRepository = _MockContentBlocklistRepository();
    nostrClient = createMockNostrService();

    when(() => nostrClient.publicKey).thenReturn(viewerPubkey);

    when(() => blocklistRepository.isBlocked(any())).thenReturn(false);
    when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);
    when(
      () => blocklistRepository.currentState,
    ).thenReturn(ContentPolicyState.empty());

    when(() => followRepository.followingPubkeys).thenReturn(const []);
    when(
      () => followRepository.followingStream,
    ).thenAnswer((_) => Stream<List<String>>.value(const []));
    when(() => followRepository.watchMyFollowingCached()).thenAnswer(
      (_) => Stream.value(
        const CacheResult.live(
          FollowingSnapshot(pubkeys: <String>[], count: 0),
        ),
      ),
    );
  });

  tearDown(() async {
    await notifySubscriptions.close();
  });

  Widget buildWidget({
    bool isOwnProfile = false,
    bool isMessageRestricted = false,
    bool newPostNotifications = true,
    bool constrainWidth = false,
    VoidCallback? onOpenClips,
  }) {
    final row = ProfileActionButtons(
      userIdHex: isOwnProfile ? viewerPubkey : targetPubkey,
      isOwnProfile: isOwnProfile,
      displayName: 'Target User',
      onEditProfile: () {},
      onOpenClips: onOpenClips ?? () {},
      onMessageUser: () {},
      isMessageRestricted: isMessageRestricted,
      onShareProfile: (_) {},
    );
    return testMaterialApp(
      home: Scaffold(
        // The tap-target guidelines skip nodes that touch the viewport edge,
        // so the accessibility tests inset the row to keep every button
        // evaluable.
        body: constrainWidth
            ? Center(child: SizedBox(width: 360, child: row))
            : row,
      ),
      additionalOverrides: [
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
        notifySubscriptionsRepositoryProvider.overrideWithValue(
          notifyRepository,
        ),
        // Ships default-off, so the bell tests have to ask for it.
        isFeatureEnabledProvider(
          FeatureFlag.newPostNotifications,
        ).overrideWithValue(newPostNotifications),
      ],
      mockFollowRepository: followRepository,
      mockNostrService: nostrClient,
    );
  }

  testWidgets(
    'hides follow and message actions when target cannot be targeted',
    (tester) async {
      when(
        () => blocklistRepository.hasBlockedUs(targetPubkey),
      ).thenReturn(true);
      when(() => blocklistRepository.currentState).thenReturn(
        const ContentPolicyState(
          currentUserPubkey: viewerPubkey,
          mutedPubkeys: {},
          blockedPubkeys: {},
          pubkeysBlockingUs: {targetPubkey},
          pubkeysMutingUs: {},
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.text('Follow'), findsNothing);
      expect(find.text('Message'), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(DivineIconButton), findsOneWidget);
      expect(find.byType(Spacer), findsOneWidget);
    },
  );

  testWidgets(
    'keeps share right-aligned when already following target cannot be targeted',
    (tester) async {
      when(
        () => blocklistRepository.hasBlockedUs(targetPubkey),
      ).thenReturn(true);
      when(() => blocklistRepository.currentState).thenReturn(
        const ContentPolicyState(
          currentUserPubkey: viewerPubkey,
          mutedPubkeys: {},
          blockedPubkeys: {},
          pubkeysBlockingUs: {targetPubkey},
          pubkeysMutingUs: {},
        ),
      );
      when(
        () => followRepository.followingPubkeys,
      ).thenReturn(const [targetPubkey]);
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => Stream<List<String>>.value(const [targetPubkey]));
      when(() => followRepository.watchMyFollowingCached()).thenAnswer(
        (_) => Stream.value(
          const CacheResult.live(
            FollowingSnapshot(pubkeys: [targetPubkey], count: 1),
          ),
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.text('Follow'), findsNothing);
      expect(find.text('Message'), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(DivineIconButton), findsOneWidget);
      expect(find.byType(Spacer), findsOneWidget);
    },
  );

  testWidgets('hides only message action when DM policy restricts the viewer', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget(isMessageRestricted: true));
    await tester.pump();

    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(find.byType(DivineButton), findsOneWidget);
    expect(find.byType(DivineIconButton), findsOneWidget);
  });

  group('library button', () {
    testWidgets('tapping it opens the drafts library', (tester) async {
      var openedClips = 0;

      await tester.pumpWidget(
        buildWidget(isOwnProfile: true, onOpenClips: () => openedClips++),
      );
      await tester.pump();

      final libraryButton = find.byKey(const Key('library-button'));
      expect(libraryButton, findsOneWidget);

      await tester.tap(libraryButton);
      await tester.pump();

      expect(openedClips, 1);
    });
  });

  group('notification bell', () {
    late StreamController<List<String>> followingStream;

    setUp(() {
      followingStream = StreamController<List<String>>.broadcast();
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => followingStream.stream);
    });

    tearDown(() async {
      await followingStream.close();
    });

    void followingTarget() {
      when(
        () => followRepository.followingPubkeys,
      ).thenReturn(const [targetPubkey]);
      when(() => followRepository.watchMyFollowingCached()).thenAnswer(
        (_) => Stream.value(
          const CacheResult.live(
            FollowingSnapshot(pubkeys: [targetPubkey], count: 1),
          ),
        ),
      );
    }

    testWidgets('is absent when the viewer does not follow the target', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileNotifyBellButton), findsNothing);
    });

    testWidgets('appears once the viewer follows the target', (tester) async {
      followingTarget();

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileNotifyBellButton), findsOneWidget);
    });

    testWidgets(
      'stays hidden behind the flag, and reads no subscriptions',
      (tester) async {
        followingTarget();

        await tester.pumpWidget(buildWidget(newPostNotifications: false));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileNotifyBellButton), findsNothing);
        // The cubit must not be constructed either — otherwise a flagged-off
        // build still hits the relay for a list it can never show.
        verifyNever(
          () => notifyRepository.watchSubscriptions(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    testWidgets('tapping it subscribes the viewer to the target', (
      tester,
    ) async {
      followingTarget();

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // The real repository emits nothing until it has actually read the
      // list, and the bell is deliberately inert until that first emission —
      // tapping an unverified "off" would publish a replacement list.
      notifySubscriptions.add(const <String>{});
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ProfileNotifyBellButton));
      await tester.pumpAndSettle();

      verify(
        () => notifyRepository.subscribe(
          ownerPubkey: viewerPubkey,
          creatorPubkey: targetPubkey,
        ),
      ).called(1);
    });

    testWidgets('unfollowing clears the subscription', (tester) async {
      followingTarget();

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      expect(find.byType(ProfileNotifyBellButton), findsOneWidget);

      // The bell unmounts the moment the row flips to not-following, so the
      // teardown has to be driven from a host above it.
      when(() => followRepository.followingPubkeys).thenReturn(const []);
      followingStream.add(const <String>[]);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileNotifyBellButton), findsNothing);
      verify(
        () => notifyRepository.unsubscribe(
          ownerPubkey: viewerPubkey,
          creatorPubkey: targetPubkey,
        ),
      ).called(1);
    });
  });

  group('accessibility', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<void> pumpRow(
      WidgetTester tester, {
      bool isOwnProfile = false,
      bool newPostNotifications = true,
    }) async {
      await tester.pumpWidget(
        buildWidget(
          isOwnProfile: isOwnProfile,
          newPostNotifications: newPostNotifications,
          constrainWidth: true,
        ),
      );
      await tester.pump();
    }

    testWidgets('own-profile row names its edit and share buttons', (
      tester,
    ) async {
      await pumpRow(tester, isOwnProfile: true);

      expect(
        find.bySemanticsLabel(l10n.profileSetupEditProfileTitle),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(SemanticIds.profileEditButton),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.profileShareLabel), findsOneWidget);
      await expectMeetsAccessibilityGuidelines(
        tester,
        guidelines: divineSemanticsGuidelines,
      );
    });

    testWidgets(
      'other-profile row names the icon-only message and share buttons',
      (tester) async {
        await pumpRow(tester);

        expect(find.bySemanticsLabel(l10n.profileMessageLabel), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.profileShareLabel), findsOneWidget);
        await expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: divineSemanticsGuidelines,
        );
      },
    );

    testWidgets('other-profile row names the icon-only unfollow action', (
      tester,
    ) async {
      when(
        () => followRepository.followingPubkeys,
      ).thenReturn(const [targetPubkey]);
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => Stream<List<String>>.value(const [targetPubkey]));
      when(() => followRepository.watchMyFollowingCached()).thenAnswer(
        (_) => Stream.value(
          const CacheResult.live(
            FollowingSnapshot(pubkeys: [targetPubkey], count: 1),
          ),
        ),
      );

      // The bell has its own coverage; keep it out so the row under test is
      // exactly [Message] [Following] [Share].
      await pumpRow(tester, newPostNotifications: false);

      expect(
        find.bySemanticsLabel(l10n.unfollowUserSemanticLabel),
        findsOneWidget,
      );
      await expectMeetsAccessibilityGuidelines(
        tester,
        guidelines: divineSemanticsGuidelines,
      );
    });
  });
}
