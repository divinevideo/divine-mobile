// ABOUTME: Regression tests for scroll helpers used by widget tests.
// ABOUTME: Pins the settled-frame guarantee before viewport-sensitive actions.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'scroll.dart';

void main() {
  group('scrollUntilTappable', () {
    testWidgets(
      'scrollUntilTappable pumps the post-scroll frame before returning',
      (
        tester,
      ) async {
        const targetKey = Key('target');

        await tester.pumpWidget(
          const _ScrollProbe(targetKey: targetKey),
        );

        await tester.scrollUntilVisible(
          find.byKey(targetKey),
          240,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('post-scroll frame pending'), findsOneWidget);

        await tester.pumpWidget(
          const _ScrollProbe(targetKey: targetKey),
        );
        await tester.pumpAndSettle();

        await scrollUntilTappable(
          tester,
          find.byKey(targetKey),
          240,
          scrollable: find.byType(Scrollable),
        );

        expect(find.text('post-scroll frame settled'), findsOneWidget);
      },
    );
  });
}

class _ScrollProbe extends StatefulWidget {
  const _ScrollProbe({required this.targetKey});

  final Key targetKey;

  @override
  State<_ScrollProbe> createState() => _ScrollProbeState();
}

class _ScrollProbeState extends State<_ScrollProbe> {
  bool _settledAfterScroll = true;
  bool _settleScheduled = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 320,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              if (_settleScheduled) {
                return false;
              }
              setState(() {
                _settledAfterScroll = false;
                _settleScheduled = true;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _settledAfterScroll = true;
                  _settleScheduled = false;
                });
              });
              return false;
            },
            child: ListView(
              children: [
                for (var index = 0; index < 20; index++)
                  SizedBox(height: 80, child: Text('before $index')),
                SizedBox(
                  key: widget.targetKey,
                  height: 80,
                  child: Text(
                    _settledAfterScroll
                        ? 'post-scroll frame settled'
                        : 'post-scroll frame pending',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
