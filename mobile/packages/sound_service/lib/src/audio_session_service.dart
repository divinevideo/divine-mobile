// ABOUTME: Audio-session-only configuration helpers shared by playback flows.
// ABOUTME: Keeps AVAudioSession policy out of player lifecycle code.

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:sound_service/src/audio_session_wrapper.dart';
import 'package:unified_logger/unified_logger.dart';

/// Configures the platform audio session for recorder and editor handoffs.
class AudioSessionService {
  /// Creates an [AudioSessionService].
  AudioSessionService({AudioSessionWrapper? audioSessionWrapper})
    : _audioSessionWrapper =
          audioSessionWrapper ?? DefaultAudioSessionWrapper();

  final AudioSessionWrapper _audioSessionWrapper;

  /// How many voice calls hold the platform audio session. There is one
  /// session per process and several services configure it, so every
  /// instance shares the count.
  static int _callHolds = 0;

  /// Whether a voice call holds the platform audio session.
  ///
  /// The configurations below leave the session alone then: switching it to
  /// playback takes the call's microphone and speaker away, and the call
  /// sets up the session it needs itself.
  static bool get isHeldByCall => _callHolds > 0;

  /// Holds the platform audio session for a voice call until
  /// [releaseFromCall].
  static void holdForCall() => _callHolds++;

  /// Lets go of a hold taken with [holdForCall].
  static void releaseFromCall() {
    if (_callHolds > 0) _callHolds--;
  }

  /// Whether a call holds the session, so [configuration] is skipped.
  bool _keptForCall(String configuration) {
    if (!isHeldByCall) return false;
    Log.debug(
      "Kept the call's audio session instead of $configuration",
      name: 'AudioSessionService',
      category: LogCategory.video,
    );
    return true;
  }

  /// Configures the audio session for recording mode, unless a voice call
  /// holds it ([isHeldByCall]).
  ///
  /// This sets up the audio session to:
  /// - Allow audio playback during recording via A2DP to Bluetooth headphones
  /// - Use built-in microphone for recording (NOT Bluetooth mic)
  /// - Route to speaker when no headphones connected
  ///
  /// IMPORTANT: Only uses allowBluetoothA2dp, NOT allowBluetooth.
  /// allowBluetooth enables HFP (phone call mode) which causes
  /// "call started/ended" sounds on Bluetooth headsets.
  Future<void> configureForRecording() async {
    if (_keptForCall('recording')) return;
    try {
      await _audioSessionWrapper.configure(
        audio_session.AudioSessionConfiguration(
          avAudioSessionCategory:
              audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
              audio_session.AVAudioSessionCategoryOptions.allowBluetoothA2dp,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );

      Log.debug(
        'Configured audio session for recording mode',
        name: 'AudioSessionService',
        category: LogCategory.video,
      );
    } on Exception catch (e) {
      Log.warning(
        'Failed to configure audio session for recording: $e',
        name: 'AudioSessionService',
        category: LogCategory.video,
      );
      // Keep playback usable if the platform rejects configuration.
    }
  }

  /// Configures the audio session for mixed playback, unless a voice call
  /// holds it ([isHeldByCall]).
  ///
  /// This allows audio to play simultaneously with other audio sources
  /// (e.g., video player). Use this in the video editor to prevent
  /// the audio from pausing the video.
  Future<void> configureForMixedPlayback() async {
    if (_keptForCall('mixed playback')) return;
    try {
      await _audioSessionWrapper.configure(
        const audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );

      Log.debug(
        'Configured audio session for mixed playback',
        name: 'AudioSessionService',
        category: LogCategory.video,
      );
    } on Exception catch (e) {
      Log.warning(
        'Failed to configure audio session for mixed playback: $e',
        name: 'AudioSessionService',
        category: LogCategory.video,
      );
      // Keep playback usable if the platform rejects configuration.
    }
  }

  /// Resets the audio session to default playback configuration, unless a
  /// voice call holds it ([isHeldByCall]).
  ///
  /// Call this when exiting recording mode.
  Future<void> resetAudioSession() async {
    if (_keptForCall('the default')) return;
    try {
      await _audioSessionWrapper.configure(
        const audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              audio_session.AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioFocusGainType:
              audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
          avAudioSessionSetActiveOptions:
              audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );

      Log.debug('Reset audio session to default', name: 'AudioSessionService');
    } on Exception catch (e) {
      Log.warning(
        'Failed to reset audio session: $e',
        name: 'AudioSessionService',
        category: LogCategory.video,
      );
      // Don't rethrow - allow continued operation even if reset fails.
    }
  }
}
