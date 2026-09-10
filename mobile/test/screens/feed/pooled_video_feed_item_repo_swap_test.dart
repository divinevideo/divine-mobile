// ABOUTME: Regression test for #3503 — verifies that the BlocProvider for
// VideoInteractionsBloc on a pooled feed item recreates its bloc when any
// of the three repository providers (likes, comments, reposts) is rebuilt.
//
// The production sites mirror this pattern at:
//   - mobile/lib/widgets/video_feed_item/feed_videos.dart (_Overlay)
// Each does `ref.watch(...)` on the three repos and gates the BlocProvider
// with a composite ValueKey of the three identity hashes. When any
// provider rebuilds (auth flip / sign-out / account switch), the key
// changes, the stale bloc is closed, and a fresh one wraps the new repos.

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

/// Mirror of the production BlocProvider pattern from `_Overlay` in
/// `mobile/lib/widgets/video_feed_item/feed_videos.dart`. Kept in this test
/// file because the production widget is private; reviewers should verify
/// this fixture stays in sync with the production call site.
class _Fixture extends ConsumerWidget {
  const _Fixture();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

/// Toggle a `StateProvider<int>` to force `likesRepositoryProvider` to
/// rebuild and return a different mock — mirrors what happens in
/// production when auth flips (the real provider also rebuilds and
/// returns a fresh repository instance).
final _likesRepoSwap = StateProvider<int>((ref) => 0);

void main() {
  group('Pooled video feed item — BlocProvider repo-swap (#3503)', () {
    late _MockLikesRepository mockLikesA;
    late _MockLikesRepository mockLikesB;
    late _MockCommentsRepository mockComments;
    late _MockRepostsRepository mockReposts;

    setUp(() {
      mockLikesA = _MockLikesRepository();
      mockLikesB = _MockLikesRepository();
      mockComments = _MockCommentsRepository();
      mockReposts = _MockRepostsRepository();

      // VideoInteractionsBloc subscribes to these on construction
      // (VideoInteractionsSubscriptionRequested) and fetches counts
      // (VideoInteractionsFetchRequested). Stub them on both mocks so the
      // bloc can run without throwing during the test.
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
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _Fixture(),
            ),
          ),
        );

        // Capture the bloc that was created when the fixture first built.
        final probeContext = tester.element(find.byType(_Probe));
        final blocA = BlocProvider.of<VideoInteractionsBloc>(probeContext);
        expect(blocA.isClosed, isFalse, reason: 'initial bloc should be alive');

        // Flip the toggle. likesRepositoryProvider rebuilds, _Fixture's
        // watch fires, the composite ValueKey changes, BlocProvider
        // unmounts blocA and creates a new bloc wrapping mockLikesB.
        container.read(_likesRepoSwap.notifier).state = 1;
        await tester.pump();

        final probeContextAfter = tester.element(find.byType(_Probe));
        final blocB = BlocProvider.of<VideoInteractionsBloc>(probeContextAfter);

        expect(
          blocB,
          isNot(same(blocA)),
          reason:
              'BlocProvider should create a new bloc when the composite '
              'repo key changes — without this fix, the first feed items '
              'snapshot a stale repository at cold launch and like '
              'attempts throw `Bad state: No public key available`',
        );
        // (Cleanup of the old bloc is handled by BlocProvider.dispose →
        // bloc.close(); not asserted here because the close future is not
        // awaited in dispose and pumping it through reliably in widget
        // tests adds fragility for no extra guarantee.)
      },
    );

    testWidgets(
      'preserves the same VideoInteractionsBloc when no repo identity changes',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            likesRepositoryProvider.overrideWith((ref) {
              ref.watch(_likesRepoSwap);
              return mockLikesA;
            }),
            commentsRepositoryProvider.overrideWith((_) => mockComments),
            repostsRepositoryProvider.overrideWith((_) => mockReposts),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _Fixture(),
            ),
          ),
        );

        final blocA = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        // Force the override to re-run, but keep returning the same mock
        // — the record key compares fields by `==` (identity for these
        // classes), so identical instances yield equal keys and the
        // BlocProvider keeps the same bloc.
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

    // Documents an intentional trade-off raised in PR #3522 review: when
    // the composite record key changes, the old bloc is closed and the
    // new one starts from initial state. Optimistic flips and in-flight
    // publishes against the previous repo are intentionally dropped —
    // the new repo points at a different NostrClient (different signer,
    // possibly different user) so replaying them would be unsafe.
    //
    // Today the only paths that flip this key are:
    //   - auth state transitions (the cold-launch race this PR fixes),
    //   - sign-in / sign-out / account switch.
    // If a future change adds a non-auth invalidation of one of the
    // three repository providers, this test will fail loudly so the
    // state-loss can be re-evaluated in that context.
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
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _Fixture(),
            ),
          ),
        );

        final blocBefore = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        // Synthesise a non-initial state to prove it actually gets lost.
        // Mirrors what an optimistic like emit would look like: heart
        // flipped + count incremented, no error.
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
        // The fresh bloc starts from initial state — the synthesised
        // optimistic flip on blocBefore is gone. This is intentional:
        // the optimistic state was bound to the previous repository
        // (different NostrClient / signer), and replaying it against
        // the new one is unsafe.
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
