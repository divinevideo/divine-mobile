import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/router/recorder_sound_selection.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/screen_frame_trace_scope.dart';

class _MockAuthService extends Mock implements AuthService {}

class _Editor extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  void invalidateFinalRenderedClip() {}

  @override
  void triggerAutosave() {}
}

void main() {
  group('VideoRecorderRoute sound handoff', () {
    testWidgets('marks an incoming sound for the editor timeline', (
      tester,
    ) async {
      final auth = _MockAuthService();
      final owner = 'a' * 64;
      final sound = AudioEvent(
        id: 'b' * 64,
        pubkey: 'c' * 64,
        createdAt: 0,
        url: 'https://example.com/audio.mp3',
      );
      final selection = RecorderSoundSelection(
        sound: sound,
        ownerPubkey: owner,
      );
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          videoEditorProvider.overrideWith(_Editor.new),
        ],
      );
      addTearDown(container.dispose);
      late RecorderSoundSelectionGate gate;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                // Exercise the route's actual account-checked handoff without
                // opening the native camera below the selection gate.
                final scope = VideoRecorderRoute(initialSound: selection).build(
                  context,
                  ref,
                ) as ScreenFrameTraceScope;
                gate = scope.child as RecorderSoundSelectionGate;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      gate.apply(selection);
      final state = container.read(videoEditorProvider);
      expect(state.selectedSound, same(sound));
      expect(state.seedSelectedSoundAsAudioTrack, isTrue);
    });
  });
}
