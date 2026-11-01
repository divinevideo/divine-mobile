// ABOUTME: Checks the text in a DM bubble against the fill actually painted
// ABOUTME: behind it, in both appearances, at the 4.5:1 normal-text bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/message_bubble.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../../helpers/contrast.dart';
import '../../../../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

const _time = '2:30 PM';
const _videoShare = 'https://divine.video/video/abc123';

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

void main() {
  group('$MessageBubble text contrast', () {
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
      });
    }
  });
}
