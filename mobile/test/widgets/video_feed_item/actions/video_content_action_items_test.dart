// ABOUTME: Tests for the content action row items both video sheets offer.
// ABOUTME: Covers when Add to clips and Remix are offered, and how they look.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_row.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_items.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideoContentActionsBloc
    extends MockBloc<VideoContentActionsEvent, VideoContentActionsState>
    implements VideoContentActionsBloc {}

final VideoEvent _video = VideoEvent(
  id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
  createdAt: 1757385263,
  content: 'Test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
  videoUrl: 'https://example.com/video.mp4',
);

final VideoEvent _declinedReuse = VideoEvent(
  id: _video.id,
  pubkey: _video.pubkey,
  createdAt: _video.createdAt,
  content: _video.content,
  timestamp: _video.timestamp,
  videoUrl: _video.videoUrl,
  nostrEventTags: const [
    ['allow_video_reuse', 'false'],
  ],
);

void main() {
  group('addToClipsActionItem', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    late _MockVideoContentActionsBloc contentActions;

    setUp(() {
      contentActions = _MockVideoContentActionsBloc();
      when(
        () => contentActions.state,
      ).thenReturn(const VideoContentActionsState());
    });

    Future<VideoActionRowItem?> buildItem(
      WidgetTester tester, {
      required bool isWeb,
    }) async {
      VideoActionRowItem? item;
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<VideoContentActionsBloc>.value(
            value: contentActions,
            child: Builder(
              builder: (context) {
                item = addToClipsActionItem(
                  context,
                  video: _video,
                  isOwnContent: true,
                  isWeb: isWeb,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return item;
    }

    testWidgets('is offered on the viewer own video off the web', (
      tester,
    ) async {
      final item = await buildItem(tester, isWeb: false);

      expect(item?.label, l10n.shareSheetAddToClips);
    });

    testWidgets('is not offered on the web, even on the viewer own video', (
      tester,
    ) async {
      final item = await buildItem(tester, isWeb: true);

      expect(item, isNull);
    });
  });

  group('remixVideoActionItem', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    late _MockVideoContentActionsBloc contentActions;

    setUp(() {
      contentActions = _MockVideoContentActionsBloc();
    });

    Future<VideoActionRowItem?> buildItem(
      WidgetTester tester, {
      required VideoEvent video,
      bool isOwnContent = false,
      bool isWeb = false,
      VideoContentActionsState state = const VideoContentActionsState(),
    }) async {
      when(() => contentActions.state).thenReturn(state);
      VideoActionRowItem? item;
      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<VideoContentActionsBloc>.value(
            value: contentActions,
            child: Builder(
              builder: (context) {
                item = remixVideoActionItem(
                  context,
                  bloc: contentActions,
                  video: video,
                  isOwnContent: isOwnContent,
                  isWeb: isWeb,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return item;
    }

    testWidgets('is offered as Remix with the film slate icon', (
      tester,
    ) async {
      final item = await buildItem(tester, video: _video);

      expect(item?.label, l10n.metadataRemixAction);
      expect(item?.icon, DivineIconName.filmSlate);
      expect(item?.isPending, isFalse);
    });

    testWidgets('is not offered when the creator declines reuse', (
      tester,
    ) async {
      expect(_declinedReuse.allowVideoReuse, isFalse);

      final item = await buildItem(tester, video: _declinedReuse);

      expect(item, isNull);
    });

    testWidgets('is offered on the viewer own video that declines reuse', (
      tester,
    ) async {
      final item = await buildItem(
        tester,
        video: _declinedReuse,
        isOwnContent: true,
      );

      expect(item?.label, l10n.metadataRemixAction);
    });

    testWidgets('is offered on the web, where it points to the app', (
      tester,
    ) async {
      final item = await buildItem(tester, video: _video, isWeb: true);

      expect(item?.label, l10n.metadataRemixAction);
    });

    testWidgets('is pending while the remix is being prepared', (
      tester,
    ) async {
      final item = await buildItem(
        tester,
        video: _video,
        state: const VideoContentActionsState(isPreparingRemix: true),
      );

      expect(item?.isPending, isTrue);
    });
  });
}
