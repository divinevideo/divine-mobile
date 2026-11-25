// ABOUTME: Tests the question, Add yours and replies cards: what the frames show,
// ABOUTME: who joined or replied in the player's copy, and the buttons on them.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:file/local.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/interactive_sticker_card.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(InteractiveStickerCard, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final question = SocialStickerData.interactive(
      SocialStickerKind.question,
      prompt: 'Ask me anything',
    );
    const addYours = SocialStickerData(
      kind: SocialStickerKind.addYours,
      prompt: 'Show your desk',
      hashtag: 'desksetup',
    );
    final replies = SocialStickerData.interactive(
      SocialStickerKind.replies,
      prompt: 'Reply with a video',
    );
    const responses = StickerResponses(
      count: 3,
      latest: [
        StickerResponsePreview(),
        StickerResponsePreview(isBlurred: true),
      ],
    );

    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      Locale? locale,
    }) => tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: SizedBox(width: 360, height: 300, child: child)),
      ),
    );

    group('renders', () {
      testWidgets('a question over its answer field', (tester) async {
        await pump(
          tester,
          FittedBox(child: InteractiveStickerCard(data: question)),
        );

        expect(find.text('Ask me anything'), findsOneWidget);
        expect(find.text(l10n.videoStickerQuestionAnswerHint), findsOneWidget);
      });

      testWidgets('an Add yours with no one in the frames', (tester) async {
        await pump(
          tester,
          const FittedBox(child: InteractiveStickerCard(data: addYours)),
        );

        expect(find.text('#desksetup'), findsOneWidget);
        expect(find.text(l10n.videoStickerAddYoursButton), findsOneWidget);
        expect(find.text(l10n.videoStickerAddYoursJoined(0)), findsNothing);
      });

      testWidgets('the copy of an Add yours with who joined', (tester) async {
        await pump(
          tester,
          const InteractiveStickerCopy(data: addYours, responses: responses),
        );

        expect(find.text(l10n.videoStickerAddYoursJoined(3)), findsOneWidget);
      });

      testWidgets('the copy of a replies sticker with how many replied', (
        tester,
      ) async {
        await pump(
          tester,
          InteractiveStickerCopy(data: replies, responses: responses),
        );

        expect(find.text(l10n.videoStickerRepliesCount(3)), findsOneWidget);
        expect(find.byType(ImageFiltered), findsNothing);
      });

      testWidgets('an avatar with no picture in its own color', (tester) async {
        await pump(
          tester,
          const InteractiveStickerCopy(
            data: addYours,
            responses: StickerResponses(
              count: 1,
              latest: [
                StickerResponsePreview(avatarColor: VineTheme.accentPink),
              ],
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox && widget.color == VineTheme.accentPink,
          ),
          findsOneWidget,
        );
      });

      testWidgets('a count that is only a floor with a plus', (tester) async {
        const floor = StickerResponses(count: 500, countIsAtLeast: true);
        await pump(
          tester,
          const InteractiveStickerCopy(data: addYours, responses: floor),
        );
        expect(
          find.text(l10n.videoStickerAddYoursJoinedAtLeast('500+')),
          findsOneWidget,
        );

        await pump(
          tester,
          InteractiveStickerCopy(
            data: replies,
            responses: floor,
            onOpenResponses: () {},
          ),
        );
        expect(
          find.text(l10n.videoStickerRepliesCountAtLeast('500+')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            l10n.videoStickerRepliesSemanticLabelAtLeast('500+'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a replies sticker the same size with or without who '
          'replied, so the copy lies on the frames', (tester) async {
        await pump(
          tester,
          FittedBox(child: InteractiveStickerCard(data: replies)),
        );
        final without = tester.getSize(find.byType(InteractiveStickerCard));
        await pump(
          tester,
          FittedBox(
            child: InteractiveStickerCard(data: replies, responses: responses),
          ),
        );

        expect(
          tester.getSize(find.byType(InteractiveStickerCard)),
          equals(without),
        );
      });
      group('in a language with a long count', () {
        const german = Locale('de');
        final de = lookupAppLocalizations(german);
        const joined = StickerResponses(
          count: 12,
          latest: [
            StickerResponsePreview(),
            StickerResponsePreview(),
            StickerResponsePreview(),
          ],
        );

        testWidgets('the whole count of an Add yours beside its button', (
          tester,
        ) async {
          await pump(
            tester,
            InteractiveStickerCopy(
              data: addYours,
              responses: joined,
              onJoin: () {},
              onOpenResponses: () {},
            ),
            locale: german,
          );
          final count = find.text(de.videoStickerAddYoursJoined(12));

          expect(
            tester.renderObject<RenderParagraph>(count).didExceedMaxLines,
            isFalse,
          );
          expect(
            tester.getRect(count).right,
            lessThanOrEqualTo(
              tester.getRect(find.text(de.videoStickerAddYoursButton)).left,
            ),
          );
        });

        testWidgets('a count too long for the row scaled down, not cut short', (
          tester,
        ) async {
          const vietnamese = Locale('vi');
          final vi = lookupAppLocalizations(vietnamese);
          await pump(
            tester,
            InteractiveStickerCopy(
              data: addYours,
              responses: const StickerResponses(
                count: 500,
                countIsAtLeast: true,
                latest: [
                  StickerResponsePreview(),
                  StickerResponsePreview(),
                  StickerResponsePreview(),
                ],
              ),
              onJoin: () {},
              onOpenResponses: () {},
            ),
            locale: vietnamese,
          );
          final count = find.text(vi.videoStickerAddYoursJoinedAtLeast('500+'));

          expect(
            tester.renderObject<RenderParagraph>(count).didExceedMaxLines,
            isFalse,
          );
          expect(
            tester.getRect(count).right,
            lessThanOrEqualTo(
              tester.getRect(find.text(vi.videoStickerAddYoursButton)).left,
            ),
          );
        });

        testWidgets('an Add yours the same size with or without who joined, '
            'so the copy lies on the frames', (tester) async {
          await pump(
            tester,
            const FittedBox(child: InteractiveStickerCard(data: addYours)),
            locale: german,
          );
          final without = tester.getSize(find.byType(InteractiveStickerCard));
          await pump(
            tester,
            const FittedBox(
              child: InteractiveStickerCard(
                data: addYours,
                overFrames: true,
                responses: joined,
              ),
            ),
            locale: german,
          );

          expect(
            tester.getSize(find.byType(InteractiveStickerCard)),
            equals(without),
          );
        });

        testWidgets('an Add yours inviting to watch its series the size of '
            'the one to join, so it fills the same box', (tester) async {
          await pump(
            tester,
            const FittedBox(
              child: InteractiveStickerCard(data: addYours, responses: joined),
            ),
            locale: german,
          );
          final joinable = tester.getSize(find.byType(InteractiveStickerCard));
          await pump(
            tester,
            const FittedBox(
              child: InteractiveStickerCard(
                data: addYours,
                overFrames: true,
                responses: joined,
                watchOnly: true,
              ),
            ),
            locale: german,
          );

          expect(find.text(de.videoStickerAddYoursWatchSeries), findsOneWidget);
          expect(
            tester.getSize(find.byType(InteractiveStickerCard)),
            equals(joinable),
          );
        });
      });
    });

    group('renders at any system text size', () {
      testWidgets('its icons the size they have in the frames', (
        tester,
      ) async {
        Future<Size> iconSizeAt(double textScale) async {
          await pump(
            tester,
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: FittedBox(child: InteractiveStickerCard(data: replies)),
              ),
            ),
          );
          return tester.renderObject<RenderBox>(find.byType(DivineIcon)).size;
        }

        final regular = await iconSizeAt(1);
        expect(await iconSizeAt(2), equals(regular));
      });
    });

    group('interactions', () {
      testWidgets("a tap on a question's field answers it", (tester) async {
        var answered = 0;
        await pump(
          tester,
          InteractiveStickerCopy(data: question, onAnswer: () => answered++),
        );

        await tester.tap(find.text(l10n.videoStickerQuestionAnswerHint));

        expect(answered, equals(1));
      });

      testWidgets('an Add yours joins on its button and opens who joined '
          'beside it', (tester) async {
        var joined = 0;
        var opened = 0;
        await pump(
          tester,
          InteractiveStickerCopy(
            data: addYours,
            responses: responses,
            onJoin: () => joined++,
            onOpenResponses: () => opened++,
          ),
        );

        await tester.tap(find.text(l10n.videoStickerAddYoursButton));
        await tester.tap(find.text(l10n.videoStickerAddYoursJoined(3)));

        expect(joined, equals(1));
        expect(opened, equals(1));
      });

      testWidgets('an Add yours a viewer may not join opens its series, '
          'counting the answers beyond its thumbnails', (tester) async {
        var opened = 0;
        await pump(
          tester,
          InteractiveStickerCopy(
            data: addYours,
            responses: const StickerResponses(
              count: 7,
              latest: [
                StickerResponsePreview(),
                StickerResponsePreview(),
                StickerResponsePreview(),
              ],
            ),
            watchOnly: true,
            onOpenResponses: () => opened++,
          ),
        );

        expect(find.text(l10n.videoStickerAddYoursButton), findsNothing);
        expect(find.text('+5'), findsOneWidget);
        tester.semantics.tap(
          find.semantics.byLabel(
            l10n.videoStickerAddYoursWatchSeriesSemanticLabel('Show your desk'),
          ),
        );

        expect(opened, equals(1));
      });

      testWidgets('a replies sticker opens the replies', (tester) async {
        var opened = 0;
        await pump(
          tester,
          InteractiveStickerCopy(
            data: replies,
            responses: responses,
            onOpenResponses: () => opened++,
          ),
        );

        await tester.tap(find.text('Reply with a video'));

        expect(opened, equals(1));
      });

      testWidgets("a screen reader answers a question's field", (
        tester,
      ) async {
        var answered = 0;
        await pump(
          tester,
          InteractiveStickerCopy(data: question, onAnswer: () => answered++),
        );

        tester.semantics.tap(
          find.semantics.byLabel(
            l10n.videoStickerQuestionAnswerSemanticLabel('Ask me anything'),
          ),
        );

        expect(answered, equals(1));
      });

      testWidgets('a screen reader opens the replies', (tester) async {
        var opened = 0;
        await pump(
          tester,
          InteractiveStickerCopy(
            data: replies,
            responses: responses,
            onOpenResponses: () => opened++,
          ),
        );

        tester.semantics.tap(
          find.semantics.byLabel(l10n.videoStickerRepliesSemanticLabel(3)),
        );

        expect(opened, equals(1));
      });
    });
    group('the thumbnails of a replies sticker', () {
      // Only this file asks for them: a load left pending stays cached.
      const a = 'https://example.com/replies-sticker-thumbnail-a.jpg';
      const b = 'https://example.com/replies-sticker-thumbnail-b.jpg';
      late Set<String> loadable;
      late Map<String, Completer<FileInfo?>> held;
      late String picture;
      late ValueNotifier<List<StickerResponsePreview>> latest;

      setUp(() {
        loadable = {a, b};
        held = {};
        latest = ValueNotifier(const [
          StickerResponsePreview(thumbnailUrl: a),
          StickerResponsePreview(thumbnailUrl: b),
        ]);
      });

      tearDown(() {
        latest.dispose();
        debugImageCacheOverride = null;
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
      });

      Finder thumbnail(String url) => find.byWidgetPredicate(
        (widget) => widget is VineCachedImage && widget.imageUrl == url,
      );

      FileInfo served(String url) => FileInfo(
        const LocalFileSystem().file(picture),
        FileSource.Cache,
        DateTime(2100),
        url,
      );

      /// Pumps a replies sticker with [latest], its thumbnails in [loadable]
      /// served from a picture on disk and the others [held] loading.
      Future<void> pumpThumbnails(
        WidgetTester tester, {
        bool reduceMotion = false,
      }) async {
        picture = (await tester.runAsync(_writePng))!;
        final cache = createMockMediaCacheManager();
        when(() => cache.getFileFromCache(any())).thenAnswer((invocation) {
          final url = invocation.positionalArguments.first as String;
          if (!loadable.contains(url)) {
            return (held[url] ??= Completer<FileInfo?>()).future;
          }
          return Future.value(served(url));
        });
        debugImageCacheOverride = cache;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduceMotion),
                child: Center(
                  child: SizedBox(
                    width: 360,
                    height: 300,
                    child: ValueListenableBuilder(
                      valueListenable: latest,
                      builder: (_, latest, _) => InteractiveStickerCopy(
                        data: replies,
                        responses: StickerResponses(
                          count: latest.length,
                          latest: latest,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      /// Lets the pictures of [urls] load, which takes the real event loop,
      /// and the thumbnail they make shown fade in.
      Future<void> load(WidgetTester tester, List<String> urls) async {
        final context = tester.element(find.byType(InteractiveStickerCopy));
        await tester.runAsync(() async {
          var loaded = false;
          unawaited(
            Future.wait([
              for (final url in urls) VineCachedImage.precache(context, url),
            ]).then((_) => loaded = true),
          );
          // The sticker asked for them first, so their loads move on as
          // the test's clock is pumped.
          final waited = Stopwatch()..start();
          while (!loaded && waited.elapsed < const Duration(seconds: 10)) {
            await pumpEventQueue();
            await tester.pump();
          }
          expect(loaded, isTrue);
        });
        await tester.pumpAndSettle();
      }

      double opacityOf(WidgetTester tester, String url) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: thumbnail(url),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      testWidgets('fades the next one in over the one before, in turn', (
        tester,
      ) async {
        await pumpThumbnails(tester);
        await load(tester, [a, b]);

        expect(thumbnail(a), findsOneWidget);
        expect(thumbnail(b), findsNothing);

        await tester.pump(repliesThumbnailInterval);

        // The one before stays drawn under the one fading in.
        expect(thumbnail(a), findsOneWidget);
        expect(thumbnail(b), findsOneWidget);
        expect(opacityOf(tester, b), lessThan(1));

        await tester.pumpAndSettle();

        expect(thumbnail(a), findsNothing);
        expect(thumbnail(b), findsOneWidget);
      });

      testWidgets('shows the next one only once its picture is loaded', (
        tester,
      ) async {
        loadable = {a};
        await pumpThumbnails(tester);
        await load(tester, [a]);

        await tester.pump(repliesThumbnailInterval);
        await tester.pump(repliesThumbnailInterval);

        expect(thumbnail(a), findsOneWidget);
        expect(thumbnail(b), findsNothing);
      });

      testWidgets('starts with the newest, also when an older one loads '
          'first', (tester) async {
        loadable = {b};
        await pumpThumbnails(tester);
        await load(tester, [b]);

        expect(thumbnail(a), findsNothing);
        expect(thumbnail(b), findsNothing);

        held[a]!.complete(served(a));
        await load(tester, [a]);

        expect(thumbnail(a), findsOneWidget);
        expect(thumbnail(b), findsNothing);
      });

      testWidgets('keeps the one it shows when the card is built again with '
          'the avatars of the same replies', (tester) async {
        await pumpThumbnails(tester);
        await load(tester, [a, b]);
        await tester.pump(repliesThumbnailInterval);
        await tester.pumpAndSettle();

        latest.value = const [
          StickerResponsePreview(
            thumbnailUrl: a,
            avatarUrl: 'https://example.com/replies-sticker-avatar-a.jpg',
          ),
          StickerResponsePreview(
            thumbnailUrl: b,
            avatarUrl: 'https://example.com/replies-sticker-avatar-b.jpg',
          ),
        ];
        await tester.pump();

        expect(thumbnail(a), findsNothing);
        expect(thumbnail(b), findsOneWidget);
      });

      testWidgets('holds the newest still when the viewer asked for less '
          'motion', (tester) async {
        await pumpThumbnails(tester, reduceMotion: true);
        await load(tester, [a, b]);

        await tester.pump(repliesThumbnailInterval);
        await tester.pump(repliesThumbnailInterval);

        expect(thumbnail(a), findsOneWidget);
        expect(thumbnail(b), findsNothing);
      });
    });
  });
}

/// Writes a small picture to disk, removed after the test, and returns its
/// path.
Future<String> _writePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 9, 16),
    ui.Paint()..color = const Color(0xFF27C58B),
  );
  final image = await recorder.endRecording().toImage(9, 16);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory.systemTemp.createTempSync('replies_thumbnails_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}/thumbnail.png')
    ..writeAsBytesSync(png!.buffer.asUint8List());
  return file.path;
}
