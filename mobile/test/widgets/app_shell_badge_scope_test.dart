// ABOUTME: Pumps the REAL AppShellBadgeScope so the production `lazy: false`
// ABOUTME: eager-create flags (#6115) are pinned — flipping either back to lazy
// ABOUTME: turns the eager-create test red. Also documents the pre-fix crash:
// ABOUTME: a lazy create started from _InboxBadgeRepositorySync's listener
// ABOUTME: re-enters itself mid-wave and throws a Null-cast TypeError.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/widgets/app_shell_badge_scope.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

/// Pass-through inbox gate. The scope reads [protectedMinorInboxGateProvider]
/// to build the DM cubit; these tests are about creation timing, not the
/// protected-minor predicate, so the gate never hides anything.
class _PassThroughInboxGate implements ProtectedMinorInboxGate {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  void notifyRestrictionChanged() {}

  @override
  List<DmConversation> filter(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) => conversations;
}

// Full 64-character hex Nostr IDs for test data — never truncate.
const _me = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _alice =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

// Stable key on the scope's leaf child so tests can read the created cubit
// through it without adding a consumer that would itself trigger a create.
const _childKey = ValueKey<String>('badge-scope-probe-child');

DmConversation _unreadAccepted() => DmConversation(
  id: 'accepted-convo',
  participantPubkeys: const [_me, _alice],
  isGroup: false,
  createdAt: 1700000000,
  lastMessageTimestamp: 1700000000,
  isRead: false,
  currentUserHasSent: true,
);

/// Override targets — tests mutate these to flip the repository instances
/// behind the REAL [dmRepositoryProvider] / [followRepositoryProvider], so a
/// single frame can carry a two-provider invalidation wave exactly like the
/// auth-ready rebuild in production.
final _dmSelector = StateProvider<DmRepository>((_) {
  throw StateError('must be overridden');
});
final _followSelector = StateProvider<FollowRepository>((_) {
  throw StateError('must be overridden');
});

({
  _MockDmRepository dm,
  StreamController<List<DmConversation>> accepted,
  StreamController<List<DmConversation>> potential,
})
_buildDm() {
  final dm = _MockDmRepository();
  final accepted = StreamController<List<DmConversation>>.broadcast();
  final potential = StreamController<List<DmConversation>>.broadcast();
  when(() => dm.userPubkey).thenReturn(_me);
  when(
    () => dm.userPubkeyStream,
  ).thenAnswer((_) => const Stream<String>.empty());
  when(
    () => dm.watchAcceptedConversations(unreadOnly: true),
  ).thenAnswer((_) => accepted.stream);
  when(
    () => dm.watchPotentialRequests(unreadOnly: true),
  ).thenAnswer((_) => potential.stream);
  return (dm: dm, accepted: accepted, potential: potential);
}

_MockFollowRepository _buildFollow() {
  final follow = _MockFollowRepository();
  when(
    () => follow.followingStream,
  ).thenAnswer((_) => const Stream<List<String>>.empty());
  when(() => follow.isFollowing(any())).thenReturn(false);
  return follow;
}

_MockContentBlocklistRepository _buildBlocklist() {
  final blocklist = _MockContentBlocklistRepository();
  when(
    () => blocklist.stateStream,
  ).thenAnswer((_) => const Stream<ContentPolicyState>.empty());
  when(
    () => blocklist.filterBlockedConversations(
      any(),
      userPubkey: any(named: 'userPubkey'),
    ),
  ).thenAnswer(
    (invocation) =>
        invocation.positionalArguments.first as List<DmConversation>,
  );
  return blocklist;
}

({_MockNotificationRepository repo, StreamController<int> unread})
_buildNotif() {
  final repo = _MockNotificationRepository();
  final unread = StreamController<int>.broadcast();
  when(repo.watchUnreadCount).thenAnswer((_) => unread.stream);
  return (repo: repo, unread: unread);
}

void main() {
  late List<Object> guardedErrors;
  late ProviderContainer container;

  /// Builds the container inside `runZonedGuarded` — production does the same
  /// (main.dart), so guarded Riverpod listener errors route to the zone
  /// handler captured at construction. That lets these tests assert both
  /// "no error" (fixed path) and the exact Null-cast TypeError (documented
  /// lazy path) deterministically.
  ProviderContainer buildContainer(ProviderContainer Function() build) {
    late ProviderContainer built;
    runZonedGuarded(
      () => built = build(),
      (error, stackTrace) => guardedErrors.add(error),
    );
    addTearDown(built.dispose);
    return built;
  }

  /// Pumps the REAL [AppShellBadgeScope] with mock repositories behind the
  /// production providers. The leaf child is a non-consumer sentinel: nothing
  /// in the tree reads the cubits, so their creation can only come from the
  /// scope's `lazy: false` flags.
  Future<void> pumpScope(
    WidgetTester tester, {
    required DmRepository dm,
    required FollowRepository follow,
    required NotificationRepository notification,
    required ContentBlocklistRepository blocklist,
  }) async {
    container = buildContainer(
      () => ProviderContainer(
        overrides: [
          _dmSelector.overrideWith((ref) => dm),
          _followSelector.overrideWith((ref) => follow),
          dmRepositoryProvider.overrideWith((ref) => ref.watch(_dmSelector)),
          followRepositoryProvider.overrideWith(
            (ref) => ref.watch(_followSelector),
          ),
          contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          protectedMinorInboxGateProvider.overrideWithValue(
            _PassThroughInboxGate(),
          ),
          notificationRepositoryProvider.overrideWithValue(notification),
          isDmRestrictedProvider.overrideWithValue(false),
        ],
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppShellBadgeScope(child: SizedBox.shrink(key: _childKey)),
      ),
    );
  }

  /// Flips both repository providers in one frame — the production
  /// invalidation wave (all badge repositories watch nostrServiceProvider and
  /// rebuild together on auth-ready / account switch).
  void flipWave({required DmRepository dm, required FollowRepository follow}) {
    container.read(_dmSelector.notifier).state = dm;
    container.read(_followSelector.notifier).state = follow;
  }

  setUp(() {
    guardedErrors = [];
  });

  group('$AppShellBadgeScope eager create (#6115)', () {
    testWidgets(
      'creates both badge cubits at mount — before any consumer or provider '
      'wave can trigger a lazy create',
      (tester) async {
        final dmA = _buildDm();
        final notif = _buildNotif();
        addTearDown(() async {
          await dmA.accepted.close();
          await dmA.potential.close();
          await notif.unread.close();
        });

        await pumpScope(
          tester,
          dm: dmA.dm,
          follow: _buildFollow(),
          notification: notif.repo,
          blocklist: _buildBlocklist(),
        );

        // `lazy: false` constructs both cubits during the scope's build —
        // before _InboxBadgeRepositorySync registers its listeners — so each
        // has already subscribed to its repository with no consumer present.
        // Flipping either flag back to lazy leaves these subscriptions
        // un-created and turns the verifies red.
        verify(
          () => dmA.dm.watchAcceptedConversations(unreadOnly: true),
        ).called(1);
        verify(notif.repo.watchUnreadCount).called(1);
        expect(guardedErrors, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a two-provider wave fired before any consumer read re-points the DM '
      'cubit at the fresh repositories without a re-entrant create',
      (tester) async {
        final dmA = _buildDm();
        final dmB = _buildDm();
        final notif = _buildNotif();
        addTearDown(() async {
          await dmA.accepted.close();
          await dmA.potential.close();
          await dmB.accepted.close();
          await dmB.potential.close();
          await notif.unread.close();
        });

        await pumpScope(
          tester,
          dm: dmA.dm,
          follow: _buildFollow(),
          notification: notif.repo,
          blocklist: _buildBlocklist(),
        );

        flipWave(dm: dmB.dm, follow: _buildFollow());
        await tester.pump();

        expect(guardedErrors, isEmpty);
        expect(tester.takeException(), isNull);

        // The sync listeners forwarded the fresh repositories: the cubit now
        // watches dmB, so an unread conversation there reaches its state.
        verify(
          () => dmB.dm.watchAcceptedConversations(unreadOnly: true),
        ).called(1);

        dmB.accepted.add([_unreadAccepted()]);
        dmB.potential.add(const []);
        await tester.pump(const Duration(milliseconds: 250));

        final cubit = tester
            .element(find.byKey(_childKey))
            .read<DmUnreadCountCubit>();
        expect(cubit.state, 1);
      },
    );
  });

  group('pre-fix mechanism (#6115 documentation)', () {
    // This group deliberately does NOT pump AppShellBadgeScope: it reproduces
    // the pre-fix crash, which needs `lazy: true` — the exact flag the scope
    // now hardcodes to false. It pins the mechanism the eager tests above
    // guard against, so the fix can never be silently reverted without a red
    // test somewhere.
    int createCount = 0;
    DmUnreadCountCubit? createdCubit;

    setUp(() {
      createCount = 0;
      // Owned and closed by the BlocProvider that created it.
      createdCubit = null;
    });

    Future<void> pumpProbe(
      WidgetTester tester, {
      required DmRepository dm,
      required FollowRepository follow,
    }) async {
      container = buildContainer(
        () => ProviderContainer(
          overrides: [
            _dmSelector.overrideWith((ref) => dm),
            _followSelector.overrideWith((ref) => follow),
            dmRepositoryProvider.overrideWith((ref) => ref.watch(_dmSelector)),
            followRepositoryProvider.overrideWith(
              (ref) => ref.watch(_followSelector),
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _LazyBadgeProbe(
            onCreate: (cubit) {
              createCount += 1;
              createdCubit = cubit;
            },
          ),
        ),
      );
    }

    testWidgets(
      'with a lazy create the same wave re-enters it and throws the Null '
      'cast, then self-heals',
      (tester) async {
        final dmA = _buildDm();
        final dmB = _buildDm();
        addTearDown(() async {
          await dmA.accepted.close();
          await dmA.potential.close();
          await dmB.accepted.close();
          await dmB.potential.close();
        });

        await pumpProbe(tester, dm: dmA.dm, follow: _buildFollow());

        // No consumer below the provider, so the lazy create never ran.
        expect(createCount, 0);

        flipWave(dm: dmB.dm, follow: _buildFollow());
        await tester.pump();

        // First listener starts the lazy create; create's ref.read flushes
        // the other still-dirty provider, whose notification re-enters
        // context.read<DmUnreadCountCubit>() mid-create: the provider's value
        // is still null and the `_value as T` cast throws (#6115).
        expect(guardedErrors, [isA<TypeError>()]);

        // Self-healing (why the crash is non-fatal in production): the outer
        // create completed and the cubit still tracks the fresh repository.
        expect(createCount, 1);
        dmB.accepted.add([_unreadAccepted()]);
        dmB.potential.add(const []);
        await tester.pump(const Duration(milliseconds: 20));
        expect(createdCubit!.state, 1);
      },
    );
  });
}

/// Mirrors `AppShellBadgeScope`'s wiring but with `lazy: true`, to reproduce
/// the pre-fix crash. The child is deliberately NOT a cubit consumer: in
/// production the crash window is the cold-start stretch before the first
/// bottom-nav/inbox build reads the cubit, so only the sync listener may
/// trigger the create.
class _LazyBadgeProbe extends ConsumerWidget {
  const _LazyBadgeProbe({required this.onCreate});

  final ValueChanged<DmUnreadCountCubit> onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lazy (BlocProvider's default): the create must be triggered by the sync
    // listener mid-wave, never eagerly — that is the pre-fix path being pinned.
    return BlocProvider<DmUnreadCountCubit>(
      create: (_) {
        final cubit = DmUnreadCountCubit(
          dmRepository: ref.read(dmRepositoryProvider),
          followRepository: ref.read(followRepositoryProvider),
          // These tests assert creation/re-entrancy behaviour, not debounce
          // timing, so disable the coalescing delay for prompt settling.
          recomputeDebounce: Duration.zero,
        );
        onCreate(cubit);
        return cubit;
      },
      child: const _DmRepositorySync(child: SizedBox.shrink()),
    );
  }
}

/// Mirrors `_InboxBadgeRepositorySync`'s DM sync: forwards new repository
/// identities to the existing cubit from inside Riverpod notifications.
class _DmRepositorySync extends ConsumerWidget {
  const _DmRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void sync() {
      context.read<DmUnreadCountCubit>().setRepositories(
        dmRepository: ref.read(dmRepositoryProvider),
        followRepository: ref.read(followRepositoryProvider),
      );
    }

    ref
      ..listen(dmRepositoryProvider, (_, _) => sync())
      ..listen(followRepositoryProvider, (_, _) => sync());
    return child;
  }
}
