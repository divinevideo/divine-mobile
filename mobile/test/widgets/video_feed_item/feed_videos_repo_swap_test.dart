// ABOUTME: Regression test pinning the auth-flip resilience contract for the
// BlocProvider<VideoInteractionsBloc> site inside __OverlayState.build() in
// mobile/lib/widgets/video_feed_item/feed_videos.dart.
//
// That widget does `ref.watch(...)` on all three repository providers and
// gates its BlocProvider with a composite ValueKey. When any provider
// rebuilds (auth flip / sign-out / account switch), the key changes, the
// stale bloc is closed, and a fresh one wraps the new repositories.
//
// This test mirrors the contract already pinned for the pooled feed items at:
//   mobile/test/screens/feed/pooled_video_feed_item_repo_swap_test.dart
// See also: state_management.md § "Bridging Riverpod-provided dependencies
// into BlocProvider" for the rationale.

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

/// Mirror of the BlocProvider pattern from `__OverlayState.build()` in
/// `mobile/lib/widgets/video_feed_item/feed_videos.dart`. The production
/// widget is private and pulls in many video-player dependencies, so this
/// fixture reproduces only the repo-watch + keyed-BlocProvider shape that
/// the test exercises. Reviewers should verify it stays in sync with the
/// production call site.
class _Fixture extends ConsumerStatefulWidget {
  const _Fixture();

  @override
  ConsumerState<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends ConsumerState<_Fixture> {
  @override
  Widget build(BuildContext context) {
    // Mirrors __OverlayState.build() — see feed_videos.dart.
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);

    return BlocProvider<VideoInteractionsBloc>(
      key: ValueKey((likesRepository, commentsRepository, repostsRepository)),
      create: (_) =>
          VideoInteractionsBloc(
              eventId: 'test-event',
              authorPubkey: 'test-pubkey',
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: const _Probe(),
    );
  }
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Toggle to force `likesRepositoryProvider` to return a different mock —
/// mirrors what happens in production when auth flips.
final _likesRepoSwap = StateProvider<int>((ref) => 0);

void main() {
  group('FeedVideos _Overlay — BlocProvider repo-swap (#3503)', () {
    late _MockLikesRepository mockLikesA;
    late _MockLikesRepository mockLikesB;
    late _MockCommentsRepository mockComments;
    late _MockRepostsRepository mockReposts;

    setUp(() {
      mockLikesA = _MockLikesRepository();
      mockLikesB = _MockLikesRepository();
      mockComments = _MockCommentsRepository();
      mockReposts = _MockRepostsRepository();

      // VideoInteractionsBloc subscribes/fetches on construction; stub so
      // the bloc can run without throwing during the test.
      when(
        mockLikesA.watchLikedEventIds,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        mockLikesB.watchLikedEventIds,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        () => mockLikesA.isLikedResolvingCoordinate(
          eventId: any(named: 'eventId'),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => mockLikesB.isLikedResolvingCoordinate(
          eventId: any(named: 'eventId'),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => mockLikesA.getLikeCount(
          any(),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockLikesB.getLikeCount(
          any(),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        mockReposts.watchRepostedAddressableIds,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      when(
        () => mockReposts.getRepostCountByEventId(any()),
      ).thenAnswer((_) async => 0);
      when(
        () => mockComments.getCommentsCount(
          any(),
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenAnswer((_) async => 0);
    });

    testWidgets(
      'swaps VideoInteractionsBloc when likesRepositoryProvider rebuilds',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            likesRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_likesRepoSwap);
              return v == 0 ? mockLikesA : mockLikesB;
            }),
            commentsRepositoryProvider.overrideWith((_) => mockComments),
            repostsRepositoryProvider.overrideWith((_) => mockReposts),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: _Fixture()),
          ),
        );

        final probeContext = tester.element(find.byType(_Probe));
        final blocA = BlocProvider.of<VideoInteractionsBloc>(probeContext);
        expect(
          blocA.isClosed,
          isFalse,
          reason: 'initial bloc should be alive',
        );

        // Flip the toggle — likesRepositoryProvider rebuilds with a new
        // mock instance, the composite ValueKey changes, BlocProvider
        // closes blocA and creates a fresh bloc wrapping mockLikesB.
        container.read(_likesRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocB = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        expect(
          blocB,
          isNot(same(blocA)),
          reason:
              'BlocProvider should create a new bloc when the composite '
              'repo key changes — without the ref.watch + ValueKey pattern '
              'the overlay snapshots a stale repository on cold launch and '
              'like attempts throw `Bad state: No public key available`',
        );
      },
    );

    testWidgets(
      'preserves the same VideoInteractionsBloc when no repo identity changes',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            likesRepositoryProvider.overrideWith((ref) {
              ref.watch(_likesRepoSwap);
              return mockLikesA; // same instance regardless of toggle
            }),
            commentsRepositoryProvider.overrideWith((_) => mockComments),
            repostsRepositoryProvider.overrideWith((_) => mockReposts),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: _Fixture()),
          ),
        );

        final blocA = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        // Force the override to re-run while keeping the same instance;
        // the record key compares by identity so the BlocProvider is stable.
        container.read(_likesRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        expect(
          blocAfter,
          same(blocA),
          reason:
              'identical repo identities should keep the same bloc — '
              'the record key prevents unnecessary churn on rebuilds',
        );
      },
    );

    // Documents the intentional trade-off from the state_management.md rule:
    // when the composite record key changes, the old bloc is closed and the
    // new one starts from initial state. Optimistic flips and in-flight
    // publishes against the previous repository are intentionally dropped —
    // replaying them against a new NostrClient / signer would be unsafe.
    testWidgets(
      'resets bloc state when likesRepositoryProvider rebuilds (intentional)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            likesRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_likesRepoSwap);
              return v == 0 ? mockLikesA : mockLikesB;
            }),
            commentsRepositoryProvider.overrideWith((_) => mockComments),
            repostsRepositoryProvider.overrideWith((_) => mockReposts),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: _Fixture()),
          ),
        );

        final blocBefore = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        // Synthesise an optimistic like state.
        blocBefore.emit(
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 7,
          ),
        );
        await tester.pump();
        expect(blocBefore.state.isLiked, isTrue);
        expect(blocBefore.state.likeCount, equals(7));

        // Flip the override → key changes → BlocProvider tears down
        // blocBefore and creates a fresh bloc from initial state.
        container.read(_likesRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        expect(
          blocAfter,
          isNot(same(blocBefore)),
          reason: 'precondition: a swap should have happened',
        );
        expect(
          blocAfter.state.isLiked,
          isFalse,
          reason: 'new bloc should not inherit blocBefore.isLiked',
        );
        expect(
          blocAfter.state.likeCount,
          isNull,
          reason: 'new bloc should not inherit blocBefore.likeCount',
        );
      },
    );
  });
}
