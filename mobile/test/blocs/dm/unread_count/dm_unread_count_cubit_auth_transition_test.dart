// ABOUTME: Widget-level test for the DmUnreadCountCubit's repository-sync
// ABOUTME: contract. Mirrors main.dart's wiring: a stable BlocProvider plus a
// ABOUTME: sync widget that ref.listens the dm/follow/blocklist providers and
// ABOUTME: forwards new identities to setRepositories, so the Messages badge
// ABOUTME: stops undercounting after a provider rebuild. See #4976 / #5472.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

// Full 64-character hex Nostr IDs for test data — never truncate.
const _me = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _alice =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

// currentUserHasSent defaults to false: an unreplied 1:1 chat from _alice. It
// only joins the inbox (and the count) once _alice is a followed contact.
DmConversation _unreadFromAlice() => DmConversation(
  id: 'alice-convo',
  participantPubkeys: const [_me, _alice],
  isGroup: false,
  createdAt: 1700000000,
  lastMessageTimestamp: 1700000000,
  isRead: false,
);

/// Override targets — tests mutate these to flip the repository instances the
/// sync widget forwards to the cubit.
final _dmSelector = StateProvider<DmRepository>((_) {
  throw StateError('must be overridden');
});
final _followSelector = StateProvider<FollowRepository>((_) {
  throw StateError('must be overridden');
});

int _mountCount = 0;

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.child});

  final Widget child;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    _mountCount += 1;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Mirrors `AppShellBadgeScope`'s `_InboxBadgeRepositorySync`: forwards new
/// repository identities to the existing cubit instead of recreating it.
class _DmRepositorySync extends ConsumerWidget {
  const _DmRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(_dmSelector, (_, _) => _sync(context, ref));
    ref.listen(_followSelector, (_, _) => _sync(context, ref));
    return child;
  }

  void _sync(BuildContext context, WidgetRef ref) {
    context.read<DmUnreadCountCubit>().setRepositories(
      dmRepository: ref.read(_dmSelector),
      followRepository: ref.read(_followSelector),
    );
  }
}

/// Probe mirroring `AppShellBadgeScope`'s wiring around the badge cubit: the
/// [BlocProvider] identity stays stable and repository flips are forwarded to
/// the existing cubit, so descendants do not remount.
class _BadgeProbe extends ConsumerWidget {
  const _BadgeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider<DmUnreadCountCubit>(
      create: (_) => DmUnreadCountCubit(
        dmRepository: ref.read(_dmSelector),
        followRepository: ref.read(_followSelector),
        // These tests assert repository-forwarding behaviour, not debounce
        // timing, so disable the coalescing delay for prompt settling.
        recomputeDebounce: Duration.zero,
      ),
      child: _DmRepositorySync(
        child: _MountProbe(
          child: BlocBuilder<DmUnreadCountCubit, int>(
            builder: (context, count) =>
                Text('count=$count', textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );
  }
}

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

_MockFollowRepository _buildFollow({required bool followsAlice}) {
  final follow = _MockFollowRepository();
  when(
    () => follow.followingStream,
  ).thenAnswer((_) => const Stream<List<String>>.empty());
  when(() => follow.isFollowing(any())).thenAnswer(
    (inv) => followsAlice && inv.positionalArguments.first == _alice,
  );
  return follow;
}

void main() {
  setUp(() {
    _mountCount = 0;
  });

  group(DmUnreadCountCubit, () {
    testWidgets(
      'forwarding a fresh follow repository to the existing cubit makes a '
      'followed-but-unreplied unread chat start counting, without remounting',
      (tester) async {
        final dmA = _buildDm();
        final dmB = _buildDm();
        addTearDown(() async {
          await dmA.accepted.close();
          await dmA.potential.close();
          await dmB.accepted.close();
          await dmB.potential.close();
        });
        final followStale = _buildFollow(followsAlice: false);
        final followFresh = _buildFollow(followsAlice: true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _dmSelector.overrideWith((ref) => dmA.dm),
              _followSelector.overrideWith((ref) => followStale),
            ],
            child: const _BadgeProbe(),
          ),
        );

        dmA.accepted.add(const []);
        dmA.potential.add([_unreadFromAlice()]);
        await tester.pump(const Duration(milliseconds: 20));

        // Stale follow repo doesn't know the follow -> _alice is a request -> 0.
        expect(find.text('count=0'), findsOneWidget);
        expect(_mountCount, 1);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(_BadgeProbe)),
        );
        container.read(_dmSelector.notifier).state = dmB.dm;
        container.read(_followSelector.notifier).state = followFresh;
        await tester.pump();

        dmB.accepted.add(const []);
        dmB.potential.add([_unreadFromAlice()]);
        await tester.pump(const Duration(milliseconds: 20));

        // The sync widget forwarded the fresh repos to the SAME cubit, which
        // re-subscribed: _alice is now followed -> counted. The probe did not
        // remount (the BlocProvider identity stayed stable).
        expect(find.text('count=1'), findsOneWidget);
        expect(_mountCount, 1);
      },
    );

    testWidgets(
      'a late emission from the previous repository does not overwrite the count',
      (tester) async {
        final dmA = _buildDm();
        final dmB = _buildDm();
        addTearDown(() async {
          await dmA.accepted.close();
          await dmA.potential.close();
          await dmB.accepted.close();
          await dmB.potential.close();
        });
        final follow = _buildFollow(followsAlice: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              _dmSelector.overrideWith((ref) => dmA.dm),
              _followSelector.overrideWith((ref) => follow),
            ],
            child: const _BadgeProbe(),
          ),
        );

        dmA.accepted.add(const []);
        dmA.potential.add(const []);
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('count=0'), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(_BadgeProbe)),
        );
        container.read(_dmSelector.notifier).state = dmB.dm;
        await tester.pump();
        dmB.accepted.add(const []);
        dmB.potential.add(const []);
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('count=0'), findsOneWidget);

        // Old repo emits 3 unread after the swap: must be ignored.
        dmA.accepted.add([
          DmConversation(
            id: 'old1',
            participantPubkeys: const [_me, _alice],
            isGroup: false,
            createdAt: 1700000000,
            lastMessageTimestamp: 1700000000,
            isRead: false,
            currentUserHasSent: true,
          ),
        ]);
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('count=0'), findsOneWidget);
        expect(find.text('count=1'), findsNothing);
      },
    );
  });
}
