// ABOUTME: Checks the text in a DM bubble against the fill actually painted
// ABOUTME: behind it, in both appearances, at the 4.5:1 normal-text bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_bubble.dart';
import 'package:openvine/screens/inbox/dm_display_text.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../../helpers/contrast.dart';
import '../../../../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

const _time = '2:30 PM';
const _testHexPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _videoShare = 'https://divine.video/video/abc123';
const _quotedRef = DmSharedVideoRef(
  coordinateOrId: '34236:$_testHexPubkey:vid',
  videoKind: DmSharedVideoKind.addressableShortVideo,
  authorPubkey: _testHexPubkey,
);

/// Composites the fills behind [element], nearest first, out to the first
/// opaque one: what the text is actually drawn on, washes included.
Color _fillBehind(Element element) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    final color = switch (widget) {
      ColoredBox(:final color) => color,
      DecoratedBox(decoration: BoxDecoration(:final color)) => color,
      _ => null,
    };
    if (color != null) {
      layers.add(color);
      if (color.a == 1) return false;
    }
    return true;
  });
  expect(layers, isNotEmpty, reason: 'no fill found behind the text');
  return layers.reversed.reduce(
    (below, above) => Color.alphaBlend(above, below),
  );
}

/// The effective style of the leaf span painting [needle]. The root of a
/// `RichText` carries the inherited default, which says nothing about the leaf.
TextStyle _leafStyle(RichText richText, String needle) {
  TextStyle? found;
  void walk(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is TextSpan) {
      if (span.text?.contains(needle) ?? false) found ??= style;
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child, style);
      }
    }
  }

  walk(richText.text, const TextStyle());
  expect(found, isNotNull, reason: 'no span paints "$needle"');
  return found!;
}

Element _richTextElement(WidgetTester tester, String needle) => tester.element(
  find
      .byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains(needle),
      )
      .first,
);

void _expectReadable(String what, Color ink, Color fill) {
  final ratio = contrastRatio(ink, fill);
  expect(
    ratio,
    greaterThanOrEqualTo(4.5),
    reason: '$what measured ${ratio.toStringAsFixed(2)}:1',
  );
  expect(VineThemeColors.debugFallbackCount, 0);
}

/// Fails when a fixture stopped parsing as a video, which would otherwise
/// measure a text bubble and pass.
void _expectOnMediaCard(WidgetTester tester) {
  final colors = Theme.of(
    tester.element(find.byType(MessageBubble)),
  ).extension<VineThemeColors>()!;
  expect(_fillBehind(tester.element(find.text(_time))), colors.mediaCard);
}

void _expectTextReadable(WidgetTester tester, String what, String text) {
  final finder = find.text(text);
  _expectReadable(
    what,
    tester.widget<Text>(finder).style!.color!,
    _fillBehind(tester.element(finder)),
  );
}

void _expectSpanReadable(WidgetTester tester, String what, String needle) {
  final element = _richTextElement(tester, needle);
  _expectReadable(
    what,
    _leafStyle(element.widget as RichText, needle).color!,
    _fillBehind(element),
  );
}

void _expectCodeReadable(WidgetTester tester, String needle) {
  final element = _richTextElement(tester, needle);
  final style = _leafStyle(element.widget as RichText, needle);
  _expectReadable(
    'code',
    style.color!,
    Color.alphaBlend(style.background!.color, _fillBehind(element)),
  );
}

void main() {
  group('$MessageBubble text contrast', () {
    final strings = AppLocalizationsEn();

    for (final (appearance, theme) in [
      ('light', VineTheme.lightTheme),
      ('dark', VineTheme.theme),
    ]) {
      group('in $appearance', () {
        late _MockVideosRepository videosRepository;

        setUp(() {
          VineThemeColors.debugFallbackCount = 0;
          videosRepository = _MockVideosRepository();
          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(
              any(),
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => null);
        });

        tearDown(() => VineThemeColors.debugFallbackCount = 0);

        Future<void> pumpBubble(
          WidgetTester tester,
          MessageBubble bubble,
        ) async {
          await tester.pumpWidget(
            testMaterialApp(
              theme: theme,
              home: Scaffold(body: SingleChildScrollView(child: bubble)),
              mockNostrService: createMockNostrService(),
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(videosRepository),
              ],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }

        void resolveQuotedVideo() {
          when(
            () => videosRepository.fetchVideoWithStatsForRouteId(
              any(),
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer(
            (_) async => VideoEvent(
              id: _testHexPubkey,
              pubkey: _testHexPubkey,
              createdAt: 1757385263,
              content: 'Test',
              timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
              title: 'Quoted Title',
            ),
          );
        }

        group('time label', () {
          testWidgets('is readable on a sent text bubble', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: 'hello',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectTextReadable(tester, 'time', _time);
          });

          testWidgets('is readable on a received text bubble', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: 'hello',
                timestamp: _time,
                isSent: false,
              ),
            );

            _expectTextReadable(tester, 'time', _time);
          });

          testWidgets('is readable on a sent video card', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: _videoShare,
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectOnMediaCard(tester);
            _expectTextReadable(tester, 'time', _time);
          });

          testWidgets('is readable on a received video card', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: _videoShare,
                timestamp: _time,
                isSent: false,
              ),
            );

            _expectOnMediaCard(tester);
            _expectTextReadable(tester, 'time', _time);
          });
        });

        group('sent video card', () {
          testWidgets('keeps a personal note readable', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: 'note under video\n\n"Title"\n\n$_videoShare',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectOnMediaCard(tester);
            _expectSpanReadable(tester, 'note', 'note under video');
          });

          testWidgets('keeps text after the link readable', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: '$_videoShare\n\ntext after the link',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectOnMediaCard(tester);
            _expectSpanReadable(tester, 'text', 'text after the link');
          });

          testWidgets('keeps the show more control readable', (tester) async {
            await pumpBubble(
              tester,
              MessageBubble(
                message: '$_videoShare\n\n${'a' * dmInitialDisplayCodeUnits}',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectOnMediaCard(tester);
            _expectTextReadable(
              tester,
              'show more',
              strings.profileShowMore,
            );
          });

          testWidgets('keeps a link readable', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: 'see https://example.com\n\n"Title"\n\n$_videoShare',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectOnMediaCard(tester);
            _expectSpanReadable(tester, 'link', 'example.com');
          });

          testWidgets('keeps a code run readable on its chip', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: 'run `snip` now\n\n"Title"\n\n$_videoShare',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectOnMediaCard(tester);
            _expectCodeReadable(tester, 'snip');
          });

          testWidgets('keeps the unavailable caption readable', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: _videoShare,
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectOnMediaCard(tester);
            _expectTextReadable(
              tester,
              'unavailable',
              strings.notificationsVideoUnavailable,
            );
          });
        });

        group('video card with the display limit reached', () {
          for (final (side, isSent) in [('sent', true), ('received', false)]) {
            testWidgets('keeps the limit caption readable when $side', (
              tester,
            ) async {
              await pumpBubble(
                tester,
                MessageBubble(
                  message: '$_videoShare\n\n${'a' * dmMaxDisplayCodeUnits}',
                  timestamp: _time,
                  isSent: isSent,
                ),
              );
              await tester.ensureVisible(find.text(strings.profileShowMore));
              await tester.tap(find.text(strings.profileShowMore));
              await tester.pump();

              _expectOnMediaCard(tester);
              _expectTextReadable(
                tester,
                'limit caption',
                strings.dmMessageDisplayLimitReached,
              );
            });
          }
        });

        group('sent text bubble', () {
          testWidgets('keeps the message text readable', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: 'hello there',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectSpanReadable(tester, 'message', 'hello there');
          });

          testWidgets('keeps a link readable', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: 'see https://example.com today',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectSpanReadable(tester, 'link', 'example.com');
          });

          testWidgets('keeps a code run readable on its chip', (tester) async {
            await pumpBubble(
              tester,
              const MessageBubble(
                message: 'run `snip` now',
                timestamp: _time,
                isSent: true,
              ),
            );

            _expectCodeReadable(tester, 'snip');
          });

          testWidgets('keeps the expansion controls readable', (tester) async {
            await pumpBubble(
              tester,
              MessageBubble(
                message: 'a' * (dmMaxDisplayCodeUnits + 1),
                timestamp: _time,
                isSent: true,
              ),
            );
            await tester.ensureVisible(find.text(strings.profileShowMore));
            await tester.tap(find.text(strings.profileShowMore));
            await tester.pump();

            _expectTextReadable(
              tester,
              'show less',
              strings.profileShowLess,
            );
            _expectTextReadable(
              tester,
              'limit caption',
              strings.dmMessageDisplayLimitReached,
            );
          });
        });

        for (final (side, isSent) in [('sent', true), ('received', false)]) {
          group('quoted video on a $side bubble', () {
            testWidgets('keeps the title and author readable', (tester) async {
              resolveQuotedVideo();
              await pumpBubble(
                tester,
                MessageBubble(
                  message: 'reply text',
                  timestamp: _time,
                  isSent: isSent,
                  quotedVideoRef: _quotedRef,
                ),
              );

              _expectTextReadable(tester, 'title', 'Quoted Title');
              _expectTextReadable(
                tester,
                'author',
                UserProfile.defaultDisplayNameFor(_testHexPubkey),
              );
            });

            testWidgets('keeps the unavailable caption readable', (
              tester,
            ) async {
              await pumpBubble(
                tester,
                MessageBubble(
                  message: 'reply text',
                  timestamp: _time,
                  isSent: isSent,
                  quotedVideoRef: _quotedRef,
                ),
              );

              _expectTextReadable(
                tester,
                'unavailable',
                strings.notificationsVideoUnavailable,
              );
            });
          });
        }
      });
    }
  });
}
