// ABOUTME: Drives the chroma-key screen: key colour, tolerances, background
// ABOUTME: choice, and the auto-detect measurement.

import 'dart:async';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

part 'chroma_key_editor_state.dart';

/// Measures the chroma-key screen in a video.
///
/// Injected so tests can supply a measurement without decoding a frame; in the
/// app it is [ChromaKey.detect], which samples a ring around the frame border
/// through the thumbnail pipeline — one decode, no render.
typedef ChromaKeyDetectFn =
    Future<ChromaKeyDetection> Function(EditorVideo video);

/// The key a clip starts from before anything is measured or adjusted.
///
/// The green preset rather than a bare default so the preview shows a
/// plausible matte the moment the screen opens, even if auto-detect fails.
const _initialKey = ClipChromaKey(key: ChromaKey.greenScreen());

/// Owns the chroma-key settings while the screen is open.
///
/// Everything here is in-memory: the clip is only updated when the screen is
/// confirmed, and the key is applied by the renderer at export rather than
/// baked into the clip's file.
class ChromaKeyEditorCubit extends Cubit<ChromaKeyEditorState>
    with CloseGuardedEmit<ChromaKeyEditorState> {
  /// Starts measuring straight away when the clip arrives without a key.
  ///
  /// Set [detectOnOpen] to `false` only to keep a test off the measurement
  /// path; the screen leaves it on.
  ChromaKeyEditorCubit({
    required EditorVideo video,
    ClipChromaKey? initialChromaKey,
    ChromaKeyDetectFn detect = ChromaKey.detect,
    bool detectOnOpen = true,
  }) : _video = video,
       _detect = detect,
       super(
         ChromaKeyEditorState(chromaKey: initialChromaKey ?? _initialKey),
       ) {
    // Measuring beats guessing and costs one thumbnail decode, so the screen
    // opens on a real cutout — or on the reason there isn't one — instead of
    // an inert panel the user has to know to poke. A clip that already has a
    // key keeps it: re-measuring would throw the user's tuning away.
    if (detectOnOpen && initialChromaKey == null) {
      unawaited(detectFromFootage());
    }
  }

  static const _logName = 'ChromaKeyEditorCubit';

  /// The lowest similarity the UI may set. `ChromaKey` rejects zero, which
  /// would key nothing at all.
  static const minSimilarity = 0.01;

  final EditorVideo _video;
  final ChromaKeyDetectFn _detect;

  /// Measures the screen off the footage and adopts colour and similarity.
  ///
  /// Smoothness, spill and the chosen background are the user's, so a
  /// measurement never overwrites them.
  Future<void> detectFromFootage() async {
    if (state.isDetecting) return;
    // Both callers discard this future — the constructor with `unawaited`, the
    // button with a tear-off assigned to a `VoidCallback` — so an `emit` that
    // threw here would escape as an unhandled zone error instead of surfacing
    // as a failure state.
    if (!emitIfOpen(
      state.copyWith(detectionStatus: ChromaKeyDetectionStatus.detecting),
    )) {
      return;
    }

    // Only the measurement is wrapped. A wider `try` would catch the emits
    // below as well and file a post-close `emit` throw as a detection failure,
    // which is both wrong and unfalsifiable from a test.
    final ChromaKeyDetection detection;
    try {
      detection = await _detect(_video);
    } on ChromaKeyDetectionException catch (error, stackTrace) {
      // Expected: plenty of footage has no screen reaching the frame border.
      // The UI says so and the user sets the key by hand — not a crash report.
      Log.info(
        'Chroma-key auto-detect found no usable screen: ${error.message}',
        name: _logName,
        category: LogCategory.video,
      );
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(detectionStatus: ChromaKeyDetectionStatus.failure),
      );
      return;
    } catch (error, stackTrace) {
      // Same split as the bake in `ClipEditorBloc`: a decode or channel failure
      // is expected and stays out of Crashlytics, an invariant violation does
      // not.
      addError(
        switch (error) {
          StateError() ||
          TypeError() ||
          RangeError() => Reportable(error, context: 'detectFromFootage'),
          _ => error,
        },
        stackTrace,
      );
      emitIfOpen(
        state.copyWith(detectionStatus: ChromaKeyDetectionStatus.failure),
      );
      return;
    }

    emitIfOpen(
      state.copyWith(
        chromaKey: ClipChromaKey(
          key: state.chromaKey.key.copyWith(
            color: detection.color,
            similarity: detection.similarity,
          ),
          backgroundVideoPath: state.chromaKey.backgroundVideoPath,
        ),
        detectionStatus: ChromaKeyDetectionStatus.idle,
      ),
    );
  }

  /// Clears a failed measurement so the UI stops reporting it.
  void acknowledgeDetectionFailure() {
    if (state.detectionStatus != ChromaKeyDetectionStatus.failure) return;
    emit(state.copyWith(detectionStatus: ChromaKeyDetectionStatus.idle));
  }

  /// Sets the screen colour to remove.
  void setKeyColor(Color color) =>
      _updateKey((key) => key.copyWith(color: color));

  /// Sets how far from the key colour a pixel may sit and still be removed.
  void setSimilarity(double value) =>
      _updateKey((key) => key.copyWith(similarity: value));

  /// Sets the width of the soft ramp just beyond the similarity threshold.
  void setSmoothness(double value) =>
      _updateKey((key) => key.copyWith(smoothness: value));

  /// Sets how strongly the key's colour cast is pulled off the subject.
  void setSpill(double value) =>
      _updateKey((key) => key.copyWith(spill: value));

  /// Adopts the green-screen preset, keeping the chosen background.
  void useGreenScreenPreset() => _usePreset(const ChromaKey.greenScreen());

  /// Adopts the blue-screen preset, keeping the chosen background.
  ///
  /// Blue keys tighter than green and despills more gently: denim, blue eyes
  /// and light blue shirts all crowd a blue screen.
  void useBlueScreenPreset() => _usePreset(const ChromaKey.blueScreen());

  void _usePreset(ChromaKey preset) {
    final current = state.chromaKey;
    emit(
      state.copyWith(
        chromaKey: ClipChromaKey(
          key: preset.copyWith(
            backgroundColor: current.key.backgroundColor,
            backgroundImage: current.key.backgroundColor == null
                ? current.key.backgroundImage
                : null,
          ),
          backgroundVideoPath: current.backgroundVideoPath,
        ),
      ),
    );
  }

  /// Leaves the keyed area unfilled.
  void useTransparentBackground() => _setBackground(
    state.chromaKey.withKey(
      state.chromaKey.key.copyWith(removeBackground: true),
    ),
  );

  /// Fills the keyed area with [color].
  void useColorBackground(Color color) => _setBackground(
    state.chromaKey.withKey(
      state.chromaKey.key.copyWith(backgroundColor: color),
    ),
  );

  /// Fills the keyed area with the image at [path], stretched to the frame.
  void useImageBackground(String path) => _setBackground(
    state.chromaKey.withKey(
      state.chromaKey.key.copyWith(
        backgroundImage: EditorLayerImage.file(path),
      ),
    ),
  );

  /// Plays the library video at [path] behind the subject.
  void useVideoBackground(String path) =>
      _setBackground(state.chromaKey.withVideoBackground(path));

  void _setBackground(ClipChromaKey chromaKey) =>
      emit(state.copyWith(chromaKey: chromaKey));

  void _updateKey(ChromaKey Function(ChromaKey key) update) {
    final current = state.chromaKey;
    emit(
      state.copyWith(
        chromaKey: ClipChromaKey(
          key: update(current.key),
          backgroundVideoPath: current.backgroundVideoPath,
        ),
      ),
    );
  }
}
