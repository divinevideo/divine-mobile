// ABOUTME: The feed description's tappable node must carry its own label.
// ABOUTME: It lost it whenever the text held a hashtag, mention or URL, because
// ABOUTME: LinkifiedText then splits and nothing merges up to name the node.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../builders/test_video_event_builder.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

void main() {
  group('video description semantics', () {
    late _MockVideoInteractionsBloc interactions;
    late _MockRepostsRepository reposts;

    setUp(() {
      interactions = _MockVideoInteractionsBloc();
      reposts = _MockRepostsRepository();
      when(() => interactions.stream).thenAnswer((_) => const Stream.empty());
      when(
        () => interactions.state,
      ).thenReturn(const VideoInteractionsState());
      when(
        () => reposts.fetchEventReposters(
          eventId: any(named: 'eventId'),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => const <String>[]);
    });

    Future<void> pump(WidgetTester tester, String description) async {
      final follow = createMockFollowRepository();
      when(() => follow.isFollowing(any())).thenReturn(true);
      when(follow.watchMyFollowingCached).thenAnswer(
        (_) => Stream.value(
          const CacheResult<FollowingSnapshot>.live(
            FollowingSnapshot(pubkeys: <String>[], count: 0),
          ),
        ),
      );

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: <Override>[
            repostsRepositoryProvider.overrideWithValue(reposts),
          ],
          mockFollowRepository: follow,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: interactions,
                child: VideoOverlayActions(
                  video: TestVideoEventBuilder.create(content: description),
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Finder descriptionNode() => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == 'video_description',
    );

    testWidgets('a linkified description still names its tappable node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // A hashtag is the common case on this app, and it is exactly what broke
      // it: LinkifiedText emits several spans, so the description text no
      // longer merges into the gesture node the way a plain title does.
      await pump(tester, 'And a #PuffPuffPost from the feed');

      // The guideline is what caught this on device. It fails if the detector
      // is allowed to publish its own anonymous tappable node again.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      // ...and the label has to sit on the node that owns the action, not on a
      // silent parent. Asserted directly, because the guideline alone still
      // passes if the description stops being tappable at all.
      final node = tester.getSemantics(descriptionNode());
      expect(node.label, isNotEmpty);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'the labelled node must be the one that opens the sheet',
      );
      handle.dispose();
    });

    testWidgets('a link-free description is labelled too', (tester) async {
      final handle = tester.ensureSemantics();
      // The control. This case passed even before the fix — which is why the
      // bug survived: it is data-dependent, so a fixture without a link
      // reports the feature working.
      await pump(tester, 'No links in this description at all');

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      final node = tester.getSemantics(descriptionNode());
      expect(node.label, isNotEmpty);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    });
  });
}
