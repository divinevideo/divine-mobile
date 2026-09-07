// ABOUTME: Pins the green-screen background photo to the camera — the gallery
// ABOUTME: is how an AI-generated image would get into a Divine video.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/video_editor/video_clip_chroma_key_screen.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKeyDetection, EditorVideo;

import '../../helpers/shared_channel_override.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

void main() {
  group(VideoClipChromaKeyScreen, () {
    late _MockClipEditorBloc bloc;
    late List<MethodCall> pickerCalls;

    setUp(() {
      bloc = _MockClipEditorBloc();
      when(() => bloc.state).thenReturn(const ClipEditorState());
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());

      pickerCalls = <MethodCall>[];
      overrideSharedChannel(
        const MethodChannel('plugins.flutter.io/image_picker'),
        (call) async {
          pickerCalls.add(call);
          // Null reads as "user backed out", which stops the screen before it
          // touches the filesystem.
          return null;
        },
      );
    });

    // An empty video path keeps the preview player out of the test: the screen
    // skips initialization rather than reaching for a native plugin.
    final clip = DivineVideoClip(
      id: 'clip-1',
      video: EditorVideo.file(''),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2025),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );

    Future<void> pump(
      WidgetTester tester, {
      required ChromaKeyDetectFn detect,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ClipEditorBloc>.value(
              value: bloc,
              child: VideoClipChromaKeyScreen(
                clip: clip,
                detect: detect,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('starts auto-detect as soon as the screen opens', (
      tester,
    ) async {
      final detection = Completer<ChromaKeyDetection>();

      await pump(tester, detect: (_) => detection.future);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final autoDetect = tester.widget<DivineButton>(
        find.widgetWithText(
          DivineButton,
          l10n.videoEditorChromaKeyAutoDetect,
        ),
      );
      expect(autoDetect.isLoading, isTrue);
    });

    testWidgets('shoots the background photo instead of opening the gallery', (
      tester,
    ) async {
      final detection = Completer<ChromaKeyDetection>();
      await pump(tester, detect: (_) => detection.future);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final imageChip = find.text(l10n.videoEditorChromaKeyBackgroundImage);
      await tester.ensureVisible(imageChip);
      await tester.tap(imageChip);
      await tester.pump();

      expect(pickerCalls, hasLength(1));
      expect(pickerCalls.single.method, equals('pickImage'));
      expect(
        (pickerCalls.single.arguments as Map)['source'],
        equals(ImageSource.camera.index),
      );
    });
  });
}
