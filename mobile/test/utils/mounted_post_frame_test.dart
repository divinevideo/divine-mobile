import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/mounted_post_frame.dart';

void main() {
  group('addPostFrameCallbackIfMounted', () {
    testWidgets('runs the callback (reading context) while still mounted', (
      tester,
    ) async {
      var didRun = false;
      TextDirection? contextLookup;
      final key = GlobalKey<_ProbeState>();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _Probe(
            key: key,
            onRun: (context) {
              didRun = true;
              // An inherited-widget lookup — the kind of context access that
              // throws when run after the State is unmounted.
              contextLookup = Directionality.of(context);
            },
          ),
        ),
      );

      key.currentState!.scheduleGuardedWork();
      // Drive the frame that flushes the pending post-frame callback while the
      // probe is still mounted.
      tester.binding.scheduleFrame();
      await tester.pump();

      expect(didRun, isTrue);
      expect(contextLookup, TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'skips the callback when the widget is disposed before the frame',
      (tester) async {
        var didRun = false;
        final key = GlobalKey<_ProbeState>();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: _Probe(
              key: key,
              onRun: (context) {
                didRun = true;
                // Throws ("looking up a deactivated widget's ancestor") if the
                // guard ever lets this run against an unmounted State.
                Directionality.of(context);
              },
            ),
          ),
        );

        key.currentState!.scheduleGuardedWork();
        // Replace the tree before the scheduled callback runs: this frame both
        // disposes the probe and flushes the pending post-frame callback, which
        // now fires against an unmounted State and must be dropped by the guard.
        await tester.pumpWidget(const SizedBox.shrink());

        expect(didRun, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onRun, super.key});

  final void Function(BuildContext context) onRun;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  void scheduleGuardedWork() {
    addPostFrameCallbackIfMounted(() => widget.onRun(context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
