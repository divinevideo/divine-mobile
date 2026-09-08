// ABOUTME: Covers the chroma-key screen's on-open measurement reaching the
// ABOUTME: controls, and pins the background photo to the camera — the gallery
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
    show ChromaKeyDetection, ChromaKeyDetectionException, EditorVideo;

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

    // A measurement the screen never asked to be told about: the colour is
    // distinct from the green preset's 0xFF00B140 and the similarity renders
    // as "10" against the preset's "20", so both are legible on screen.
    const measured = ChromaKeyDetection(
      color: Color(0xFF19A55B),
      similarity: 0.1,
      coverage: 0.8,
      spread: 0.02,
    );

    // Only `_ColorSwatchButton` builds a `Semantics(button: true)` carrying
    // the screen-colour label, so this reaches the swatch and not the row's
    // text label, which repeats the same string.
    Color? screenColor(WidgetTester tester, AppLocalizations l10n) {
      final swatch = tester.widget<Container>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.button ?? false) &&
                w.properties.label == l10n.videoEditorChromaKeyScreenColorLabel,
          ),
          matching: find.byType(Container),
        ),
      );
      return (swatch.decoration! as BoxDecoration).color;
    }

    testWidgets('starts auto-detect as soon as the screen opens', (
      tester,
    ) async {
      var calls = 0;
      final detection = Completer<ChromaKeyDetection>();

      await pump(
        tester,
        detect: (_) {
          calls++;
          return detection.future;
        },
      );

      // Nothing has been tapped. The screen opening is the whole trigger,
      // which is what makes the panel arrive on a cutout rather than inert.
      expect(calls, 1);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final autoDetect = tester.widget<DivineButton>(
        find.widgetWithText(
          DivineButton,
          l10n.videoEditorChromaKeyAutoDetect,
        ),
      );
      expect(autoDetect.isLoading, isTrue);
    });

    testWidgets('shows the measured colour and amount once it lands', (
      tester,
    ) async {
      final detection = Completer<ChromaKeyDetection>();
      await pump(tester, detect: (_) => detection.future);

      final l10n = lookupAppLocalizations(const Locale('en'));
      // The green preset the panel opens on, so the assertions below cannot
      // pass on a measurement that never reached the controls.
      expect(screenColor(tester, l10n), const Color(0xFF00B140));
      expect(find.text('20'), findsOneWidget);

      detection.complete(measured);
      await tester.pump();

      expect(screenColor(tester, l10n), const Color(0xFF19A55B));
      expect(find.text('10'), findsOneWidget);
      expect(find.text('20'), findsNothing);
    });

    testWidgets('tells the user when no screen was found', (tester) async {
      final detection = Completer<ChromaKeyDetection>();
      await pump(tester, detect: (_) => detection.future);

      detection.completeError(
        const ChromaKeyDetectionException('no screen'),
      );
      await tester.pump();
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoEditorChromaKeyDetectFailed), findsOneWidget);
      // The key the sliders and swatch act on has to survive, or the user is
      // left with nothing to adjust by hand.
      expect(screenColor(tester, l10n), const Color(0xFF00B140));
    });

    testWidgets('shoots the background photo instead of opening the gallery', (
      tester,
    ) async {
      // A measurement that resolves, so this runs against the settled panel
      // the user actually taps in rather than a permanently mid-detect one.
      await pump(tester, detect: (_) async => measured);
      await tester.pump();

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
