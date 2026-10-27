// ABOUTME: Tests the buttons over a playing video's stickers: where they stand
// ABOUTME: as the feed fits the video, when they show, and how taps resolve.

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/player_gesture_surface.dart';
import 'package:openvine/widgets/video_feed_item/video_sticker_tap_areas.dart';

class _MockController extends Mock implements DivineVideoPlayerController {}

const _link = VideoStickerRegion(
  kind: VideoStickerKind.link,
  target: 'https://divine.video/about',
  centerX: 0.5,
  centerY: 0.25,
  width: 0.4,
  height: 0.05,
);

VideoEvent _video(List<VideoStickerRegion> regions) => VideoEvent(
  id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
  stickerRegions: regions,
);

DivineVideoPlayerState _playing(Duration position) => DivineVideoPlayerState(
  status: PlaybackStatus.playing,
  position: position,
  videoWidth: 1080,
  videoHeight: 1920,
);

void main() {
  group('videoFrameRect', () {
    const box = Size(360, 640);

    test('fills the box with a video of its shape', () {
      expect(
        videoFrameRect(9 / 16, box, shouldPortraitExpand: true),
        equals(Offset.zero & box),
      );
    });

    test('covers the box with a wide video, cutting its sides off', () {
      final frame = videoFrameRect(16 / 9, box, shouldPortraitExpand: true);

      expect(frame.height, equals(640));
      expect(frame.width, closeTo(640 * 16 / 9, 1e-9));
      expect(frame.center, equals(box.center(Offset.zero)));
    });

    test('contains a square video, and any video the feed does not expand', () {
      expect(
        videoFrameRect(1, box, shouldPortraitExpand: true),
        equals(const Rect.fromLTWH(0, 140, 360, 360)),
      );
      expect(
        videoFrameRect(16 / 9, box, shouldPortraitExpand: false).width,
        equals(360),
      );
    });
  });

  group(VideoStickerTapAreas, () {
    late _MockController controller;
    late StreamController<DivineVideoPlayerState> states;
    late List<VideoStickerRegion> opened;
    late int playerTaps;
    late int playerDoubleTaps;

    setUp(() {
      controller = _MockController();
      states = StreamController<DivineVideoPlayerState>.broadcast();
      opened = [];
      playerTaps = 0;
      playerDoubleTaps = 0;
      when(() => controller.state).thenReturn(_playing(Duration.zero));
      when(() => controller.stateStream).thenAnswer((_) => states.stream);
    });

    tearDown(() => states.close());

    Future<void> pump(
      WidgetTester tester,
      List<VideoStickerRegion> regions,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Stack(
            children: [
              Positioned.fill(
                child: PlayerGestureSurface(
                  interactiveReady: true,
                  isOwnVideo: false,
                  onTap: () => playerTaps++,
                  onDoubleTapDown: (_) => playerDoubleTaps++,
                  onLongPressStart: () {},
                ),
              ),
              Positioned.fill(
                child: VideoStickerTapAreas(
                  video: _video(regions),
                  controller: controller,
                  onOpen: (_, region) => opened.add(region),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> tapAt(WidgetTester tester, Offset position) async {
      await tester.tapAt(position);
      await tester.pump(kDoubleTapTimeout);
    }

    group('interactions', () {
      testWidgets('opens the sticker a single tap lands on', (tester) async {
        await pump(tester, [_link]);

        await tapAt(tester, const Offset(240, 160));

        expect(opened, equals([_link]));
        expect(playerTaps, isZero);
      });

      testWidgets('leaves a tap beside the sticker to the player', (
        tester,
      ) async {
        await pump(tester, [_link]);

        await tapAt(tester, const Offset(180, 400));

        expect(opened, isEmpty);
        expect(playerTaps, equals(1));
      });

      testWidgets('leaves a double tap on the sticker to the player', (
        tester,
      ) async {
        await pump(tester, [_link]);

        await tester.tapAt(const Offset(180, 160));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(const Offset(180, 160));
        await tester.pump(kDoubleTapTimeout);

        expect(playerDoubleTaps, equals(1));
        expect(opened, isEmpty);
      });

      testWidgets('turns its button with the sticker', (tester) async {
        // Upright, the sticker reaches 72 points above and below its centre
        // but only 24 to either side, half the smallest target.
        const upright = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'summer',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.05,
          rotation: math.pi / 2,
        );
        await pump(tester, [upright]);

        await tapAt(tester, const Offset(180, 320 - 60));
        await tapAt(tester, const Offset(180 + 60, 320));

        expect(opened, equals([upright]));
        expect(playerTaps, equals(1));
      });
    });

    group('renders', () {
      testWidgets('a button only while its sticker shows', (tester) async {
        const later = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'summer',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.1,
          start: Duration(seconds: 2),
        );
        await pump(tester, [later]);
        final label = lookupAppLocalizations(
          const Locale('en'),
        ).videoStickerHashtagSemanticLabel('summer');

        expect(find.bySemanticsLabel(label), findsNothing);

        states.add(_playing(const Duration(milliseconds: 2500)));
        await tester.pump();

        expect(find.bySemanticsLabel(label), findsOneWidget);
      });

      testWidgets('names the link a button opens', (tester) async {
        await pump(tester, [_link]);

        expect(
          find.bySemanticsLabel(
            lookupAppLocalizations(
              const Locale('en'),
            ).videoStickerLinkSemanticLabel('https://divine.video/about'),
          ),
          findsOneWidget,
        );
      });
    });
  });
}
