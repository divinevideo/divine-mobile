// ABOUTME: Tests for announceDetached, the screen-reader announcement helper
// ABOUTME: Pins the announced message and the Directionality-derived direction

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/semantics_announcement.dart';

List<Map<Object?, Object?>> _captureAnnouncements(WidgetTester tester) {
  final announced = <Map<Object?, Object?>>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        announced.add(message['data']! as Map<Object?, Object?>);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}

Future<BuildContext> _pumpHost(
  WidgetTester tester,
  TextDirection textDirection,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: textDirection,
      child: const SizedBox.shrink(),
    ),
  );
  return tester.element(find.byType(SizedBox));
}

void main() {
  group('announceDetached', () {
    testWidgets('announces the message to screen readers', (tester) async {
      final announced = _captureAnnouncements(tester);
      final context = await _pumpHost(tester, TextDirection.ltr);

      announceDetached(
        context,
        'list deleted',
        description: 'announce list deletion',
        logName: 'AnnounceDetachedTest',
      );
      await tester.pump();

      expect(announced, hasLength(1));
      expect(announced.single['message'], 'list deleted');
    });

    testWidgets('takes its direction from the ambient Directionality', (
      tester,
    ) async {
      final announced = _captureAnnouncements(tester);
      final context = await _pumpHost(tester, TextDirection.rtl);

      announceDetached(
        context,
        'list deleted',
        description: 'announce list deletion',
        logName: 'AnnounceDetachedTest',
      );
      await tester.pump();

      expect(announced, hasLength(1));
      expect(announced.single['textDirection'], TextDirection.rtl.index);
    });
  });
}
