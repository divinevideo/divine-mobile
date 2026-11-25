// ABOUTME: Riverpod provider that wires SubtitleRepository with its
// ABOUTME: infrastructure dependencies (Blossom, VideoEventPublisher, auth,
// ABOUTME: videos repository, personal event cache, Nostr, HTTP client, and
// ABOUTME: poll-delay function).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/repositories/subtitle_repository.dart';

/// Provides a fully-wired [SubtitleRepository] for the subtitle-edit pipeline.
final subtitleRepositoryProvider = Provider<SubtitleRepository>((ref) {
  return SubtitleRepository(
    blossomUploadService: ref.watch(blossomUploadServiceProvider),
    videoEventPublisher: ref.watch(videoEventPublisherProvider),
    videosRepository: ref.watch(videosRepositoryProvider),
    personalEventCache: ref.watch(personalEventCacheServiceProvider),
    authService: ref.watch(authServiceProvider),
    nostrClient: ref.watch(nostrServiceProvider),
    httpClient: ref.watch(subtitleHttpClientProvider),
    pollDelay: ref.watch(subtitlePollDelayProvider),
  );
});
