// ABOUTME: Pins the feed overlay's author block to the start edge in both
// ABOUTME: text directions, clear of the action column that mirrors to the
// ABOUTME: end edge, so a right-to-left caption never runs under the buttons.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

/// A phone-sized surface, so a long caption fills the author block.
const Size _surfaceSize = Size(390, 844);

/// The author block's inset from the start edge, mirrored from
/// `video_feed_item.dart`.
const double _startInset = 16;

const String _displayName = 'Alice';

const String _caption =
    'A long caption that runs the full width of the overlay block';

void main() {
  late _MockVideoInteractionsBloc mockInteractionsBloc;
  late VideoEvent testVideo;

  setUp(() {
    mockInteractionsBloc = _MockVideoInteractionsBloc();
    when(
      () => mockInteractionsBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockInteractionsBloc.state,
    ).thenReturn(const VideoInteractionsState());

    testVideo = VideoEvent(
      id: 'rtl-layout-test-0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'A description',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
      title: _caption,
    );
  });

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required TextDirection textDirection,
  }) async {
    await tester.binding.setSurfaceSize(_surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final follow = createMockFollowRepository();
    when(() => follow.isFollowing(any())).thenReturn(false);
    when(follow.watchMyFollowingCached).thenAnswer(
      (_) => Stream.value(
        const CacheResult.live(FollowingSnapshot(pubkeys: [], count: 0)),
      ),
    );

    await tester.pumpWidget(
      testProviderScope(
        mockFollowRepository: follow,
        additionalOverrides: [
          userProfileReactiveProvider.overrideWith((ref, pubkey) async* {
            yield UserProfile(
              pubkey: pubkey,
              displayName: _displayName,
              rawData: const {},
              createdAt: DateTime(2026),
              eventId: 'kind0_event_id',
            );
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoInteractionsBloc>.value(
              value: mockInteractionsBloc,
              child: Directionality(
                textDirection: textDirection,
                // The live feeds pump the overlay fullscreen.
                child: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                  isFullscreen: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group(VideoOverlayActions, () {
    group('author block layout', () {
      for (final textDirection in TextDirection.values) {
        testWidgets(
          'keeps the author block clear of the action column '
          'in ${textDirection.name}',
          (tester) async {
            await pumpOverlay(tester, textDirection: textDirection);

            final actions = tester.getRect(
              find.byType(VideoOverlayActionColumn),
            );

            for (final (label, finder) in [
              ('avatar', find.byType(UserAvatar)),
              ('display name', find.text(_displayName)),
              ('caption', find.text(_caption)),
            ]) {
              final rect = tester.getRect(finder);
              expect(
                actions.overlaps(rect),
                isFalse,
                reason:
                    'the $label at $rect runs under the action column at '
                    '$actions',
              );
            }
          },
        );

        testWidgets(
          'starts the author block at the start edge in ${textDirection.name}',
          (tester) async {
            await pumpOverlay(tester, textDirection: textDirection);

            final avatar = tester.getRect(find.byType(UserAvatar));
            final startEdgeOffset = switch (textDirection) {
              TextDirection.ltr => avatar.left,
              TextDirection.rtl => _surfaceSize.width - avatar.right,
            };

            expect(startEdgeOffset, equals(_startInset));
          },
        );
      }
    });
  });
}
