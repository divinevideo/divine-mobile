// ABOUTME: Tests the buttons over a playing video's stickers: where they stand
// ABOUTME: as the feed fits the video, when they show, and how taps resolve.

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/utils/sticker_emoji_font.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_pill_palette.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
import 'package:openvine/widgets/video_feed_item/link_sticker_sheet.dart';
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
  style: 'light',
  label: 'divine.video',
);

VideoEvent _video(
  List<VideoStickerRegion> regions, {
  String? audioEventId,
}) => VideoEvent(
  id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
  audioEventId: audioEventId,
  stickerRegions: regions,
);

DivineVideoPlayerState _playing(
  Duration position, {
  int videoWidth = 1080,
  int videoHeight = 1920,
}) => DivineVideoPlayerState(
  status: PlaybackStatus.playing,
  position: position,
  videoWidth: videoWidth,
  videoHeight: videoHeight,
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

  group('openVideoSticker', () {
    testWidgets('shows a link outside Divine in the sheet first', (
      tester,
    ) async {
      const outside = VideoStickerRegion(
        kind: VideoStickerKind.link,
        target: 'https://example.com/hello',
        centerX: 0.5,
        centerY: 0.5,
        width: 0.4,
        height: 0.1,
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openVideoSticker(context, outside, _video(const [])),
                child: const Text('tap'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('tap'));
      await tester.pumpAndSettle();

      expect(find.byType(LinkStickerSheetTile), findsOneWidget);
      expect(find.text('https://example.com/hello'), findsOneWidget);
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
      List<VideoStickerRegion> regions, {
      String? audioEventId,
    }) async {
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
                  video: _video(regions, audioEventId: audioEventId),
                  controller: controller,
                  onOpen: (_, region, _) => opened.add(region),
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

      testWidgets('opens a sound sticker only on a video with a sound', (
        tester,
      ) async {
        const sound = VideoStickerRegion(
          kind: VideoStickerKind.sound,
          target: '',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.1,
          style: 'light',
          label: 'Song\nArtist',
        );
        await pump(tester, [sound]);

        await tapAt(tester, const Offset(180, 320));

        expect(opened, isEmpty);
        expect(playerTaps, equals(1));
        expect(find.byType(SocialStickerView), findsNothing);

        await pump(tester, [sound], audioEventId: 'f' * 64);
        await tapAt(tester, const Offset(180, 320));

        expect(opened, equals([sound]));
        expect(find.byType(SocialStickerView), findsOneWidget);
      });

      testWidgets('opens a sound sticker naming its own sound anywhere', (
        tester,
      ) async {
        const ownSound = VideoStickerRegion(
          kind: VideoStickerKind.sound,
          target: 'bundled_potato_flew',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.1,
        );
        await pump(tester, [ownSound]);

        await tapAt(tester, const Offset(180, 320));

        expect(opened, equals([ownSound]));
      });

      testWidgets('leaves the bars beside a contained video to the player', (
        tester,
      ) async {
        // A square video fills the middle 360 points of the 640-point box;
        // the sticker reaches 18 points above it, into the bar.
        when(
          () => controller.state,
        ).thenReturn(_playing(Duration.zero, videoHeight: 1080));
        const onEdge = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'summer',
          centerX: 0.5,
          centerY: 0,
          width: 0.4,
          height: 0.1,
        );
        await pump(tester, [onEdge]);

        await tapAt(tester, const Offset(180, 140 - 10));
        expect(opened, isEmpty);
        expect(playerTaps, equals(1));

        await tapAt(tester, const Offset(180, 140 + 10));
        expect(opened, equals([onEdge]));
      });

      testWidgets('turns its button with the sticker, clockwise', (
        tester,
      ) async {
        // 144 points long and 48 high, the smallest target. Turned an eighth
        // clockwise, it runs down to the right of its centre; neither point
        // below lies in the unturned box.
        const slanted = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'summer',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.05,
          rotation: math.pi / 4,
        );
        await pump(tester, [slanted]);

        await tapAt(tester, const Offset(222, 362));
        expect(opened, equals([slanted]));
        expect(playerTaps, isZero);

        await tapAt(tester, const Offset(222, 278));
        expect(opened, equals([slanted]));
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

      testWidgets('draws the sticker sharp over its area', (tester) async {
        await pump(tester, [_link]);

        expect(find.byType(SocialStickerView), findsOneWidget);
        expect(find.text('divine.video'), findsOneWidget);
        expect(
          tester.getCenter(find.byType(SocialStickerView)),
          equals(const Offset(180, 160)),
        );
      });

      testWidgets('draws a see-through look without its fill', (
        tester,
      ) async {
        const dark = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'summer',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.1,
          style: 'dark',
          label: 'summer',
        );
        await pump(tester, [dark]);

        expect(find.text('#summer'), findsOneWidget);
        // The see-through pill is in the frames already; a second one over it
        // would come out twice as dark.
        expect(find.byType(SocialStickerCopy), isNot(paints..rrect()));
      });

      testWidgets(
        'draws a see-through look with an emoji once its font is in',
        (tester) async {
          final font = Completer<bool>();
          debugLoadStickerEmojiFont = () => font.future;
          addTearDown(resetStickerEmojiFontForTesting);
          const party = VideoStickerRegion(
            kind: VideoStickerKind.hashtag,
            target: 'party🎉',
            centerX: 0.5,
            centerY: 0.5,
            width: 0.4,
            height: 0.1,
            style: 'dark',
            label: 'party🎉',
          );
          await pump(tester, [party]);

          expect(find.byType(SocialStickerView), findsNothing);
          await tapAt(tester, const Offset(180, 320));
          expect(opened, equals([party]));

          font.complete(true);
          await tester.pumpAndSettle();

          expect(find.text('#party🎉'), findsOneWidget);
        },
      );

      testWidgets('keeps a see-through look in a script it lacks as it is', (
        tester,
      ) async {
        debugLoadStickerEmojiFont = () async => true;
        addTearDown(resetStickerEmojiFontForTesting);
        const tokyo = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: '東京',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.1,
          style: 'dark',
          label: '東京',
        );
        await pump(tester, [tokyo]);
        await tester.pump();

        expect(find.byType(SocialStickerView), findsNothing);
        await tapAt(tester, const Offset(180, 320));
        expect(opened, equals([tokyo]));
      });

      testWidgets('draws a solid look with an emoji before its font is in', (
        tester,
      ) async {
        final font = Completer<bool>();
        debugLoadStickerEmojiFont = () => font.future;
        addTearDown(resetStickerEmojiFontForTesting);
        const party = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'party🎉',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.1,
          style: 'light',
          label: 'party🎉',
        );
        await pump(tester, [party]);

        expect(find.text('#party🎉'), findsOneWidget);
        await tapAt(tester, const Offset(180, 320));
        expect(opened, equals([party]));

        font.complete(true);
        await tester.pumpAndSettle();
        expect(find.text('#party🎉'), findsOneWidget);
      });

      testWidgets(
        'draws a solid look in a script it lacks, its text in proportion',
        (tester) async {
          const tokyo = VideoStickerRegion(
            kind: VideoStickerKind.hashtag,
            target: '東京',
            centerX: 0.5,
            centerY: 0.5,
            width: 0.75,
            height: 0.125,
            style: 'light',
            label: '東京',
          );
          await pump(tester, [tokyo]);

          // The pill fills the sticker's 270 by 80 area, hiding the sticker
          // in the frames however wide this phone draws its text.
          expect(
            find.byType(SocialStickerCopy),
            paints..rrect(
              rrect: RRect.fromRectAndRadius(
                const Rect.fromLTWH(0, 0, 270, 80),
                const Radius.circular(40),
              ),
              color: StickerPillPalette.of(InfoStickerStyle.light).background,
            ),
          );
          final text = find.text('#東京');
          final drawn = tester.getRect(text);
          final laidOut = tester.getSize(text);
          expect(
            drawn.width / drawn.height,
            closeTo(laidOut.width / laidOut.height, 0.001),
          );
          await tapAt(tester, const Offset(180, 320));
          expect(opened, equals([tokyo]));
        },
      );

      testWidgets('draws only the button for a sticker without its look', (
        tester,
      ) async {
        const bare = VideoStickerRegion(
          kind: VideoStickerKind.hashtag,
          target: 'summer',
          centerX: 0.5,
          centerY: 0.5,
          width: 0.4,
          height: 0.1,
        );
        await pump(tester, [bare]);

        expect(find.byType(SocialStickerView), findsNothing);
        await tapAt(tester, const Offset(180, 320));
        expect(opened, equals([bare]));
      });

      testWidgets('waits for the frames before drawing a sticker', (
        tester,
      ) async {
        when(
          () => controller.state,
        ).thenReturn(_playing(Duration.zero, videoWidth: 0, videoHeight: 0));
        await pump(tester, [_link]);

        expect(find.byType(SocialStickerView), findsNothing);

        states.add(_playing(const Duration(milliseconds: 200)));
        await tester.pump();

        expect(find.byType(SocialStickerView), findsOneWidget);
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
