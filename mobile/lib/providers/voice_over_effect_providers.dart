// ABOUTME: Provides what the voice-effect sheet needs: the service that renders
// ABOUTME: and bakes voice effects, and a player for looping auditions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/video_editor/voice_over_effect_service.dart';
import 'package:sound_service/sound_service.dart';

/// The [VoiceOverEffectService] the voice-effect sheet processes takes with.
///
/// Stateless and safe to share: every call works on its own files.
final voiceOverEffectServiceProvider = Provider<VoiceOverEffectService>(
  (ref) => VoiceOverEffectService(),
);

/// Creates the player a voice-effect sheet loops its auditions on.
///
/// A factory rather than a player, because each sheet owns and disposes its
/// own.
final voiceOverAuditionPlayerFactoryProvider =
    Provider<AudioClipPlayer Function()>((ref) => AudioClipPlayer.new);
