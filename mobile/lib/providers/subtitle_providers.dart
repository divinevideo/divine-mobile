// ABOUTME: Providers for subtitle fetching with ordered fallback chain.
// ABOUTME: Delegates fetch logic to fetchSubtitleCues in subtitle_fetcher.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subtitle_providers.g.dart';

const _subtitleVisibilityPreferenceKey = 'subtitle_visibility_enabled';

typedef SubtitleVisibilityOverride = ({String videoId, bool visible});

final subtitleHttpClientProvider = Provider<http.Client>((ref) {
  final client = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(client.close);
  return client;
});

final subtitlePollDelayProvider = Provider<SubtitlePollDelay>(
  (_) => Future<void>.delayed,
);

final subtitleVisibilityOverrideProvider =
    NotifierProvider<
      SubtitleVisibilityOverrideNotifier,
      SubtitleVisibilityOverride?
    >(SubtitleVisibilityOverrideNotifier.new);

final ProviderFamily<bool, String> subtitleVisibilityForVideoProvider = Provider
    .autoDispose
    .family<bool, String>((ref, videoId) {
      final override = ref.watch(subtitleVisibilityOverrideProvider);
      if (override?.videoId == videoId) return override!.visible;
      return ref.watch(subtitleVisibilityProvider);
    });

class SubtitleVisibilityOverrideNotifier
    extends Notifier<SubtitleVisibilityOverride?> {
  final Map<Object, String> _activeVideoByOwner = <Object, String>{};
  final Map<String, int> _activeOwnerCountsByVideo = <String, int>{};

  @override
  SubtitleVisibilityOverride? build() => null;

  void setForVideo(String videoId, bool visible) {
    if (!ref.mounted) return;
    state = (videoId: videoId, visible: visible);
  }

  /// Removes this video's scoped visibility override, if it owns one.
  void clearForVideo(String videoId) {
    if (!ref.mounted || state?.videoId != videoId) return;
    state = null;
  }

  void syncOwnerToVideo(Object owner, String videoId) {
    if (!ref.mounted) return;
    final previousVideoId = _activeVideoByOwner[owner];
    if (previousVideoId == videoId) return;

    if (previousVideoId != null) {
      _removeOwner(previousVideoId);
    }
    _activeVideoByOwner[owner] = videoId;
    _activeOwnerCountsByVideo[videoId] =
        (_activeOwnerCountsByVideo[videoId] ?? 0) + 1;

    _clearUnownedOverrideUnlessVideo(videoId);
  }

  void clearOwner(Object owner) {
    if (!ref.mounted) return;
    final previousVideoId = _activeVideoByOwner.remove(owner);
    if (previousVideoId == null) return;

    _removeOwner(previousVideoId);
    if (state?.videoId == previousVideoId &&
        !_hasActiveOwner(previousVideoId)) {
      state = null;
    }
  }

  void _removeOwner(String videoId) {
    final count = _activeOwnerCountsByVideo[videoId];
    if (count == null) return;
    if (count <= 1) {
      _activeOwnerCountsByVideo.remove(videoId);
    } else {
      _activeOwnerCountsByVideo[videoId] = count - 1;
    }
  }

  void _clearUnownedOverrideUnlessVideo(String videoId) {
    final current = state;
    if (current == null || current.videoId == videoId) return;
    if (!_hasActiveOwner(current.videoId)) {
      state = null;
    }
  }

  bool _hasActiveOwner(String videoId) =>
      (_activeOwnerCountsByVideo[videoId] ?? 0) > 0;
}

/// Fetches subtitle cues for a video, using ordered fallback.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
///    directly — zero network cost.
/// 2. For each ref in [textTrackRefs] (or [textTrackRef] for back-compat),
///    try HTTP fetch or relay query in order.
/// 3. If [sha256] is present, fetch from Blossom at
///    `https://media.divine.video/{sha256}/vtt`.
/// 4. Otherwise returns an empty list (no subtitles available).
@riverpod
Future<List<SubtitleCue>> subtitleCues(
  Ref ref, {
  required String videoId,
  String? textTrackRef,
  List<String> textTrackRefs = const [],
  String? textTrackContent,
  String? sha256,
}) async {
  if (textTrackContent != null && textTrackContent.isNotEmpty) {
    return SubtitleService.parseVtt(textTrackContent);
  }

  final refs = textTrackRefs.isNotEmpty
      ? textTrackRefs
      : [if (textTrackRef != null && textTrackRef.isNotEmpty) textTrackRef];
  final result = await fetchSubtitleCues(
    httpClient: ref.read(subtitleHttpClientProvider),
    nostrClient: ref.read(nostrServiceProvider),
    delay: ref.read(subtitlePollDelayProvider),
    textTrackContent: textTrackContent,
    textTrackRefs: refs,
    sha256: sha256,
  );
  return result.cues;
}

/// Tracks global subtitle visibility (CC on/off).
///
/// When enabled, subtitles are shown on all videos that have them.
/// This acts as an app-wide preference - toggling on one video
/// applies to all videos.
@riverpod
class SubtitleVisibility extends _$SubtitleVisibility {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_subtitleVisibilityPreferenceKey) ?? true;
  }

  /// Persist a known subtitle visibility state globally.
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_subtitleVisibilityPreferenceKey, enabled);
  }

  /// Toggle subtitle visibility globally.
  Future<void> toggle() => setEnabled(!state);
}
