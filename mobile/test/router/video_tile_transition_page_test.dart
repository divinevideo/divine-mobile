import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show MaterialPage, Theme, ThemeData;
import 'package:openvine/router/video_tile_transition_page.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_flight_transition.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';

const _screenSize = Size(400, 800);
const _tileRect = Rect.fromLTWH(20, 100, 120, 180);

/// Where the player letterboxes the square test video.
const _landing = Rect.fromLTWH(0, 200, 400, 400);

/// A point inside the strip along the leading edge that starts the swipe.
const _edge = Offset(5, 400);

class _Player extends StatelessWidget {
  const _Player();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF000000),
    child: VideoTileTransitionTarget(
      videoId: 'video1',
      aspectRatio: 1,
      coversViewport: false,
      child: SizedBox.expand(),
    ),
  );
}

class _GridPage extends Page<void> {
  const _GridPage({required this.child, super.key = const ValueKey('grid')});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => PageRouteBuilder<void>(
    settings: this,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );
}

/// A grid with one tile, and the player opened out of it when [origin] is set.
class _Host extends StatelessWidget {
  const _Host({
    required this.image,
    required this.origin,
    required this.onTileContext,
    required this.onClosed,
    this.playerKey = const ValueKey('player'),
    this.covered = false,
    this.coveredByMaterialPage = false,
  });

  final ui.Image image;
  final VideoTileOrigin? origin;

  /// The player's page key: a new one makes the navigator build a new route.
  final LocalKey playerKey;

  /// Whether another page, as a profile, is open over the player.
  final bool covered;

  /// Whether the app's default page, as a profile, is open over the player.
  final bool coveredByMaterialPage;
  final ValueChanged<BuildContext> onTileContext;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    final origin = this.origin;
    // Material's fallback theme caches the first platform used in the isolate.
    return Theme(
      data: ThemeData(platform: defaultTargetPlatform),
      child: MediaQuery(
        data: const MediaQueryData(size: _screenSize),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Navigator(
            pages: [
              _GridPage(
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: _tileRect,
                      child: Builder(
                        builder: (tileContext) {
                          onTileContext(tileContext);
                          return VideoTileThumbnailBoundary(
                            child: RawImage(image: image, fit: BoxFit.cover),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (origin != null)
                VideoTileTransitionPage(
                  key: playerKey,
                  origin: origin,
                  child: const _Player(),
                ),
              if (covered)
                const _GridPage(
                  key: ValueKey('profile'),
                  child: ColoredBox(color: Color(0xFF00FF00)),
                ),
              if (coveredByMaterialPage)
                const MaterialPage<void>(
                  key: ValueKey('profile'),
                  child: ColoredBox(color: Color(0xFF00FF00)),
                ),
            ],
            onDidRemovePage: (page) {
              if (page is VideoTileTransitionPage) onClosed();
            },
          ),
        ),
      ),
    );
  }
}

Finder get _picture => find.descendant(
  of: find.byType(VideoTileFlightTransition),
  matching: find.byType(RawImage),
);

double _openness(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.byType(_Player)))!.animation!.value;

bool _playerHasLanded(WidgetTester tester) =>
    VideoTileTransitionScope.hasLandedOf(tester.element(find.byType(_Player)));

bool _playerMayPlay(WidgetTester tester) =>
    VideoTileTransitionScope.mayPlayOf(tester.element(find.byType(_Player)));

/// Drags from [start] by [distance] slowly enough that letting go is no
/// fling, and holds still before returning.
Future<TestGesture> _slowDrag(
  WidgetTester tester, {
  required double distance,
  Offset start = _edge,
}) async {
  final gesture = await tester.startGesture(start);
  for (var moved = 0.0; moved < distance; moved += 10) {
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump(const Duration(milliseconds: 100));
  }
  return gesture;
}

void main() {
  group(VideoTileTransitionPage, () {
    late ui.Image image;
    late bool closed;
    late VideoTileOrigin origin;

    /// Opens the player out of the tile and lets it land.
    Future<void> pumpOpenPlayer(WidgetTester tester) async {
      tester.view.physicalSize = _screenSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      image = (await tester.runAsync(
        () => createTestImage(width: 300, height: 300),
      ))!;
      addTearDown(image.dispose);
      closed = false;
      late BuildContext tileContext;
      await tester.pumpWidget(
        _Host(
          image: image,
          origin: null,
          onTileContext: (context) => tileContext = context,
          onClosed: () => closed = true,
        ),
      );
      origin = VideoTileOrigin.capture(tileContext, videoId: 'video1')!;
      await tester.pumpWidget(
        _Host(
          image: image,
          origin: origin,
          onTileContext: (context) => tileContext = context,
          onClosed: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();
      expect(_playerHasLanded(tester), isTrue);
    }

    group('under another page', () {
      testWidgets(
        "slides behind a page opened over it, as the platform's pages do",
        (tester) async {
          await pumpOpenPlayer(tester);

          await tester.pumpWidget(
            _Host(
              image: image,
              origin: origin,
              coveredByMaterialPage: true,
              onTileContext: (_) {},
              onClosed: () => closed = true,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.getTopLeft(find.byType(_Player)).dx, lessThan(0));
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    });

    group('rebuilt under another page', () {
      /// Covers the player with another page, during which the navigator
      /// replaces the player's route with a new one, then closes that page.
      Future<void> pumpRebuiltUnderProfile(WidgetTester tester) async {
        Widget host({required bool covered}) => _Host(
          image: image,
          origin: origin,
          playerKey: const ValueKey('player2'),
          covered: covered,
          onTileContext: (_) {},
          onClosed: () => closed = true,
        );
        await tester.pumpWidget(host(covered: true));
        await tester.pumpAndSettle();
        await tester.pumpWidget(host(covered: false));
        await tester.pumpAndSettle();
      }

      testWidgets('shows and plays the player once uncovered', (
        tester,
      ) async {
        await pumpOpenPlayer(tester);

        await pumpRebuiltUnderProfile(tester);

        expect(_playerHasLanded(tester), isTrue);
        expect(_playerMayPlay(tester), isTrue);
        expect(_picture, findsNothing);
      });

      testWidgets(
        'flies the picture back towards the tile under the finger',
        (tester) async {
          await pumpOpenPlayer(tester);
          await pumpRebuiltUnderProfile(tester);

          final gesture = await _slowDrag(tester, distance: 100);

          final openness = _openness(tester);
          expect(openness, lessThan(1));
          expect(_picture, findsOneWidget);
          expect(
            tester.getRect(_picture),
            _rectCloseTo(Rect.lerp(_tileRect, _landing, openness)!),
          );
          await gesture.up();
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    });

    group('swiping back from the leading edge', () {
      testWidgets(
        'flies the picture back towards the tile under the finger',
        (tester) async {
          await pumpOpenPlayer(tester);

          final gesture = await _slowDrag(tester, distance: 40);
          final before = _openness(tester);
          await gesture.moveBy(const Offset(100, 0));
          await tester.pump();

          // A quarter of the screen's width closes a quarter of the way,
          // with the picture as far along, not eased.
          final openness = _openness(tester);
          expect(before - openness, closeTo(0.25, 0.001));
          expect(_picture, findsOneWidget);
          expect(
            tester.getRect(_picture),
            _rectCloseTo(Rect.lerp(_tileRect, _landing, openness)!),
          );

          await gesture.up();
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'keeps the player playing beneath the picture, without controls',
        (tester) async {
          await pumpOpenPlayer(tester);

          final gesture = await _slowDrag(tester, distance: 100);

          expect(_playerMayPlay(tester), isTrue);
          expect(_playerHasLanded(tester), isFalse);

          await gesture.up();
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'keeps flying the picture after the drag returns to where it started',
        (tester) async {
          await pumpOpenPlayer(tester);

          final gesture = await _slowDrag(tester, distance: 100);
          // Back past where the drag started, which fully opens the route.
          for (var moved = 0.0; moved < 150; moved += 10) {
            await gesture.moveBy(const Offset(-10, 0));
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(_openness(tester), equals(1));
          await gesture.moveBy(const Offset(100, 0));
          await tester.pump();

          final openness = _openness(tester);
          expect(openness, closeTo(0.75, 0.001));
          expect(_picture, findsOneWidget);
          expect(
            tester.getRect(_picture),
            _rectCloseTo(Rect.lerp(_tileRect, _landing, openness)!),
          );
          expect(_playerHasLanded(tester), isFalse);

          await gesture.up();
          await tester.pumpAndSettle();
          expect(_playerHasLanded(tester), isTrue);
          expect(_picture, findsNothing);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'closes the player when let go past halfway',
        (tester) async {
          await pumpOpenPlayer(tester);

          final gesture = await _slowDrag(tester, distance: 250);
          await gesture.up();
          await tester.pumpAndSettle();

          expect(closed, isTrue);
          expect(find.byType(_Player), findsNothing);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'settles the player back open when let go before halfway',
        (tester) async {
          await pumpOpenPlayer(tester);

          final gesture = await _slowDrag(tester, distance: 100);
          expect(_openness(tester), lessThan(1));
          await gesture.up();
          await tester.pumpAndSettle();

          expect(closed, isFalse);
          expect(_openness(tester), equals(1));
          expect(_playerHasLanded(tester), isTrue);
          expect(_picture, findsNothing);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'closes the player on a quick flick, however short',
        (tester) async {
          await pumpOpenPlayer(tester);

          await tester.flingFrom(_edge, const Offset(80, 0), 1000);
          await tester.pumpAndSettle();

          expect(closed, isTrue);
          expect(find.byType(_Player), findsNothing);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'ignores a drag that starts away from the edge',
        (tester) async {
          await pumpOpenPlayer(tester);

          final gesture = await _slowDrag(
            tester,
            distance: 250,
            start: const Offset(200, 400),
          );

          expect(_openness(tester), equals(1));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(closed, isFalse);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      testWidgets(
        'is left to the system back gesture on Android',
        (tester) async {
          await pumpOpenPlayer(tester);

          final gesture = await _slowDrag(tester, distance: 250);

          expect(_openness(tester), equals(1));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(closed, isFalse);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    });
  });
}

Matcher _rectCloseTo(Rect expected) => isA<Rect>()
    .having((r) => r.left, 'left', closeTo(expected.left, 0.01))
    .having((r) => r.top, 'top', closeTo(expected.top, 0.01))
    .having((r) => r.right, 'right', closeTo(expected.right, 0.01))
    .having((r) => r.bottom, 'bottom', closeTo(expected.bottom, 0.01));
