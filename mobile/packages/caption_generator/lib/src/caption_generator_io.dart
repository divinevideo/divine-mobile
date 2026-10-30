// ABOUTME: IO implementation for on-device closed captions.
// ABOUTME: Uses SFSpeechRecognizer on Apple and SpeechRecognizer on Android.

import 'dart:io';

import 'package:caption_generator/caption_generator_platform_interface.dart';
import 'package:caption_generator/src/exceptions.dart';
import 'package:caption_generator/src/models/caption_segment.dart';
import 'package:caption_generator/src/wav_preprocessor.dart';
import 'package:flutter/foundation.dart';

/// Generates closed captions from an audio file using the operating system's
/// on-device speech recognition.
///
/// This is a best-effort, last-resort transcription path: accuracy depends on
/// the audio quality and the on-device recognizer, so results should be
/// presented as editable suggestions rather than authoritative captions.
///
/// The input is typically the WAV file produced by `pro_video_editor` audio
/// extraction. Apple platforms accept any audio container the OS can read;
/// Android requires a 16-bit integer or 32-bit float PCM WAV, which this
/// class converts to the 16 kHz mono PCM the platform recognizer expects.
///
/// On Android the platform `SpeechRecognizer` supports file input from
/// Android 14 on; older devices and devices without Google's on-device
/// recognition service throw [SpeechRecognizerUnavailableException].
class CaptionGenerator {
  /// Creates a caption generator.
  CaptionGenerator();

  CaptionGeneratorPlatform get _platform => CaptionGeneratorPlatform.instance;

  /// Transcribes the audio file at [audioPath] into word-level
  /// [CaptionSegment]s ordered by start time.
  ///
  /// Use `groupCaptionSegments` to merge the word-level result into
  /// display-ready caption cues. Returns an empty list when no speech was
  /// recognized.
  ///
  /// [localeIdentifier] selects the recognition language as a BCP-47 tag
  /// (e.g. `en-US`); underscores are normalized to hyphens. Defaults to the
  /// device locale. On Android, word end times are approximated from the next
  /// word's start because the platform only reports start offsets.
  ///
  /// [preferOnDeviceRecognition] keeps recognition on-device on Apple
  /// platforms whenever the locale supports it; otherwise Apple's
  /// server-based recognition is used. Android always runs on-device.
  /// [requireOnDeviceRecognition] instead fails when local recognition is
  /// unavailable, without allowing server-based recognition.
  ///
  /// Throws:
  ///
  /// * [AudioFileNotFoundException] if [audioPath] does not exist.
  /// * [UnsupportedAudioFormatException] if the audio cannot be read
  ///   (Android WAV requirements above).
  /// * [SpeechNotAuthorizedException] if speech recognition is not authorized:
  ///   the user denied it (Apple), or the `RECORD_AUDIO` permission the
  ///   platform recognizer requires is not granted (Android).
  /// * [SpeechRecognizerUnavailableException] if the device or locale has no
  ///   recognizer — on Android also below Android 14 or without Google's
  ///   on-device recognition service.
  /// * [TranscriptionFailedException] for any other recognizer failure, or if
  ///   reading or writing the audio during Android WAV preparation fails.
  /// * [UnsupportedError] on platforms other than Android, iOS, and macOS.
  Future<List<CaptionSegment>> generateCaptions({
    required String audioPath,
    String? localeIdentifier,
    bool preferOnDeviceRecognition = true,
    bool requireOnDeviceRecognition = false,
  }) async {
    if (!File(audioPath).existsSync()) {
      throw AudioFileNotFoundException(audioPath);
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _generateOnAndroid(
        audioPath: audioPath,
        localeIdentifier: localeIdentifier,
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => _platform.transcribe(
        audioPath: audioPath,
        localeIdentifier: localeIdentifier,
        preferOnDeviceRecognition: preferOnDeviceRecognition,
        requireOnDeviceRecognition: requireOnDeviceRecognition,
      ),
      _ => throw UnsupportedError(
        'caption_generator supports Android, iOS, and macOS only.',
      ),
    };
  }

  Future<List<CaptionSegment>> _generateOnAndroid({
    required String audioPath,
    required String? localeIdentifier,
  }) async {
    final prepared = await WavPreprocessor.prepareForRecognition(
      inputPath: audioPath,
    );
    try {
      return await _platform.transcribe(
        audioPath: prepared.path,
        localeIdentifier: localeIdentifier,
      );
    } finally {
      await prepared.dispose();
    }
  }
}
