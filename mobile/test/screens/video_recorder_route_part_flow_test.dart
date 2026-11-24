import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/view/collab_room_flow_scopes.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/observability/screen_frame_trace.dart';
import 'package:openvine/router/challenge_recording_gate.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/widgets/screen_frame_trace_scope.dart';

const _roomId = '0123456789abcdef0123456789abcdef';

void main() {
  group('VideoRecorderRoute part flow', () {
    const part = CollabRoomPartContext(roomId: _roomId, cellAspectRatio: 1);

    /// The widget the route builds with [part] as the camera flow's part.
    Future<Widget> built(
      WidgetTester tester,
      VideoRecorderRoute route,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(collabRoomPartProvider.notifier).set(part);
      late Widget widget;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                widget = route.build(context, ref);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return widget;
    }

    testWidgets('traces visits to the standalone recorder', (tester) async {
      final scope = await built(tester, const VideoRecorderRoute());

      expect(
        scope,
        isA<ScreenFrameTraceScope>().having(
          (scope) => scope.screen,
          'screen',
          TracedScreen.recorder,
        ),
      );
    });

    testWidgets("ends the part's flow with the recorder's route", (
      tester,
    ) async {
      final scope = await built(
        tester,
        const VideoRecorderRoute(collabRoomId: _roomId),
      ) as ScreenFrameTraceScope;
      final gate = scope.child as ChallengeRecordingGate;

      expect(
        gate.child,
        isA<CollabRoomPartFlowScope>().having(
          (scope) => scope.part,
          'part',
          same(part),
        ),
      );
    });

    testWidgets('leaves a recorder of no room out of the flow', (tester) async {
      final scope = await built(
        tester,
        const VideoRecorderRoute(),
      ) as ScreenFrameTraceScope;
      final gate = scope.child as ChallengeRecordingGate;

      expect(gate.child, isNot(isA<CollabRoomPartFlowScope>()));
    });
  });
}
