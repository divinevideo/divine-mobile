import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_media.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';
import 'package:openvine/services/video_editor/caption_remote_transcriber.dart';

/// Wires the existing transcription pipeline without exposing it to the view.
final publishingIdeasMediaProvider = Provider<PublishingIdeasMedia>(
  (ref) => PublishingIdeasMedia(
    captions: CaptionGenerationService.production(
      remoteTranscriber: BlossomCaptionTranscriber(
        ref.watch(blossomUploadServiceProvider),
      ),
    ),
  ),
);
