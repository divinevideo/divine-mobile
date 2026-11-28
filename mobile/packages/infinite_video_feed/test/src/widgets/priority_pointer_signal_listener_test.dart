import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/widgets/priority_pointer_signal_listener.dart';

void main() {
  group(PriorityPointerSignalListener, () {
    late List<String> winners;

    void bid(PointerSignalEvent event, String name) =>
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (_) => winners.add(name),
        );

    setUp(() {
      winners = <String>[];
    });

    Future<void> scrollAt(WidgetTester tester, Offset position) =>
        tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, 40),
          ),
        );

    testWidgets('bids for a scroll before the scrollable inside it', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PriorityPointerSignalListener(
            onPointerSignal: (event) => bid(event, 'priority'),
            child: ListView(
              controller: controller,
              children: [
                for (var i = 0; i < 20; i++) const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      );

      await scrollAt(tester, const Offset(400, 300));
      await tester.pump();

      expect(winners, equals(['priority']));
      expect(controller.offset, equals(0));
    });

    testWidgets('does not hear a scroll outside itself', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          // Nothing around the listener rejects the scroll for it, so only
          // its own bounds keep it out.
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (event) => bid(event, 'below'),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: PriorityPointerSignalListener(
                  onPointerSignal: (event) => bid(event, 'priority'),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );

      await scrollAt(tester, const Offset(400, 300));

      expect(winners, equals(['below']));
    });

    testWidgets('hears only pointer signals', (tester) async {
      final events = <PointerEvent>[];
      await tester.pumpWidget(
        PriorityPointerSignalListener(
          onPointerSignal: events.add,
          child: const SizedBox.expand(),
        ),
      );

      await tester.tapAt(const Offset(400, 300));

      expect(events, isEmpty);
    });

    testWidgets('calls the handler of the latest build', (tester) async {
      Widget build(String name) => PriorityPointerSignalListener(
        onPointerSignal: (event) => bid(event, name),
        child: const SizedBox.expand(),
      );
      await tester.pumpWidget(build('first'));
      await tester.pumpWidget(build('second'));

      await scrollAt(tester, const Offset(400, 300));

      expect(winners, equals(['second']));
    });
  });
}
