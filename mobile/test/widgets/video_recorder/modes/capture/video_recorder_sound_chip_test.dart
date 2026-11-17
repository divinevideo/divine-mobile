import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_sound_chip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  final sound = AudioEvent(
    id: 'sound',
    pubkey: 'a' * 64,
    createdAt: 0,
    title: 'Bruh Sound Effect',
    url: 'https://example.com/audio.mp3',
  );

  final clip = DivineVideoClip(
    id: 'clip1',
    video: EditorVideo.file('/test/clip1.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2026),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );

  group(VideoRecorderSoundChip, () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Future<void> pumpChip(
      WidgetTester tester, {
      AudioEvent? selectedSound,
      List<DivineVideoClip> clips = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _TestClipManagerNotifier(clips: clips),
            ),
            videoEditorProvider.overrideWith(
              () => _TestVideoEditorNotifier(selectedSound),
            ),
          ],
          child: BlocProvider<VideoRecorderBloc>.value(
            value: recorderBloc,
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Row(children: [VideoRecorderSoundChip()]),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('offers a sound while the session is empty', (tester) async {
        await pumpChip(tester);

        expect(find.text(l10n.videoEditorAudioAddAudio), findsOneWidget);
      });

      // A sound picked now would not line up with the takes already there.
      testWidgets('hides itself once a clip was recorded without a sound', (
        tester,
      ) async {
        await pumpChip(tester, clips: [clip]);

        expect(find.byType(VideoEditorAudioChip), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('says how to change a sound the clips are synced to', (
        tester,
      ) async {
        await pumpChip(tester, selectedSound: sound, clips: [clip]);
        expect(find.textContaining('Bruh Sound Effect'), findsOneWidget);

        await tester.tap(find.byType(VideoEditorAudioChip));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoRecorderSoundLockedHint), findsOneWidget);
        // The picker stayed shut, so remote record was never paused for it.
        verifyNever(
          () => recorderBloc.add(const VideoRecorderRemoteRecordPaused()),
        );
      });
    });
  });
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({required this.clips});

  @override
  final List<DivineVideoClip> clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: clips);
}

class _TestVideoEditorNotifier extends VideoEditorNotifier {
  _TestVideoEditorNotifier(this._selectedSound);

  final AudioEvent? _selectedSound;

  @override
  VideoEditorProviderState build() =>
      VideoEditorProviderState(selectedSound: _selectedSound);
}
