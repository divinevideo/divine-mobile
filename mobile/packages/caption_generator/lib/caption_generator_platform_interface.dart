// ABOUTME: Platform interface for on-device speech-to-text caption generation.
// ABOUTME: Defines the transcribe contract platform implementations honor.

import 'package:caption_generator/caption_generator_method_channel.dart';
import 'package:caption_generator/src/models/caption_segment.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that implementations of caption_generator must implement.
abstract class CaptionGeneratorPlatform extends PlatformInterface {
  /// Constructs a CaptionGeneratorPlatform.
  CaptionGeneratorPlatform() : super(token: _token);

  static final Object _token = Object();

  static CaptionGeneratorPlatform _instance = MethodChannelCaptionGenerator();

  /// The default instance of [CaptionGeneratorPlatform] to use.
  ///
  /// Defaults to [MethodChannelCaptionGenerator].
  static CaptionGeneratorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CaptionGeneratorPlatform] when
  /// they register themselves.
  static set instance(CaptionGeneratorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Transcribes the audio file at [audioPath] into word-level segments.
  ///
  /// [localeIdentifier] selects the recognition language as a BCP-47 tag
  /// (e.g. `en-US`, device locale by default). [preferOnDeviceRecognition]
  /// keeps recognition on-device on Apple platforms whenever the locale
  /// supports it; Android is always on-device.
  /// [requireOnDeviceRecognition] forbids server-based recognition and fails
  /// when local recognition is unavailable.
  Future<List<CaptionSegment>> transcribe({
    required String audioPath,
    String? localeIdentifier,
    bool preferOnDeviceRecognition = true,
    bool requireOnDeviceRecognition = false,
  }) {
    throw UnimplementedError('transcribe() has not been implemented.');
  }
}
