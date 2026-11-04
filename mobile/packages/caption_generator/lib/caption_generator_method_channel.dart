// ABOUTME: MethodChannel implementation of the caption generator platform.
// ABOUTME: Maps native PlatformException codes onto the typed exceptions.

import 'package:caption_generator/caption_generator_platform_interface.dart';
import 'package:caption_generator/src/exceptions.dart';
import 'package:caption_generator/src/models/caption_segment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [CaptionGeneratorPlatform] that uses method channels.
class MethodChannelCaptionGenerator extends CaptionGeneratorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('caption_generator');

  @override
  Future<List<CaptionSegment>> transcribe({
    required String audioPath,
    String? localeIdentifier,
    bool preferOnDeviceRecognition = true,
    bool requireOnDeviceRecognition = false,
  }) async {
    try {
      final raw = await methodChannel.invokeMethod<List<Object?>>(
        'transcribe',
        <String, Object?>{
          'audioPath': audioPath,
          // Native Android EXTRA_LANGUAGE wants a BCP-47 tag (hyphens); accept
          // ICU-style underscores from callers and normalize them here.
          'localeIdentifier': localeIdentifier?.replaceAll('_', '-'),
          'preferOnDeviceRecognition': preferOnDeviceRecognition,
          'requireOnDeviceRecognition': requireOnDeviceRecognition,
        },
      );
      return (raw ?? const <Object?>[])
          .map(
            (segment) =>
                CaptionSegment.fromMap(segment! as Map<Object?, Object?>),
          )
          .toList();
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapPlatformException(error), stackTrace);
    }
  }

  CaptionGenerationException _mapPlatformException(PlatformException error) {
    final message = error.message ?? 'Transcription failed';
    return switch (error.code) {
      'audio_not_found' => AudioFileNotFoundException(
        _audioPathFromNativeMessage(message),
      ),
      'invalid_audio' => UnsupportedAudioFormatException(message),
      'not_authorized' => const SpeechNotAuthorizedException(),
      'recognizer_unavailable' => SpeechRecognizerUnavailableException(message),
      _ => TranscriptionFailedException(message, cause: error),
    };
  }

  String _audioPathFromNativeMessage(String message) {
    const prefix = 'Audio file not found: ';
    return message.startsWith(prefix)
        ? message.substring(prefix.length)
        : message;
  }
}
