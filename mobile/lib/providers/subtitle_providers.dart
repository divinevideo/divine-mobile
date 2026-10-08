// ABOUTME: Providers for subtitle fetching with ordered fallback chain.
// ABOUTME: Delegates fetch logic to fetchSubtitleCues in subtitle_fetcher.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/providers/listenable_provider_bridge.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_language_preference_service.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subtitle_providers.g.dart';

const _subtitleVisibilityPreferenceKey = 'subtitle_visibility_enabled';

final subtitleHttpClientProvider = Provider<http.Client>((ref) {
  final client = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(client.close);
  return client;
});

final subtitlePollDelayProvider = Provider<SubtitlePollDelay>(
  (_) => Future<void>.delayed,
);

/// Owns the viewer's subtitle translation preferences.
final subtitleLanguagePreferenceServiceProvider =
    Provider<SubtitleLanguagePreferenceService>(
      (_) => SubtitleLanguagePreferenceService(),
    );

/// Publishes preference changes without recreating the service listener.
final subtitleLanguagePreferenceVersionProvider =
    NotifierProvider<SubtitleLanguagePreferenceVersion, int>(
      SubtitleLanguagePreferenceVersion.new,
    );

class SubtitleLanguagePreferenceVersion extends Notifier<int> {
  @override
  int build() {
    final service = ref.watch(subtitleLanguagePreferenceServiceProvider);
    listenForProviderLifetime(ref, service, increment);
    return 0;
  }

  void increment() => state++;
}

/// Fetches the track and its verified machine-translation attribution.
@riverpod
Future<SubtitleFetchResult> subtitleTrack(
  Ref ref, {
  required String videoId,
  String? textTrackRef,
  List<String> textTrackRefs = const [],
  String? textTrackContent,
  String? sha256,
  String? sourceLang,
  String? appLocaleCode,
}) async {
  ref.watch(subtitleLanguagePreferenceVersionProvider);
  final service = ref.watch(subtitleLanguagePreferenceServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  await service.initialize();
  if (!ref.mounted) {
    return const SubtitleFetchResult(SubtitleFetchStatus.unavailable);
  }
  final effectiveAppLocale =
      appLocaleCode ?? currentAppUiLocale(prefs).languageCode;
  final wantsTranslation = service.shouldTranslate(
    sourceLanguage: sourceLang,
    appLocaleCode: effectiveAppLocale,
  );
  final lang = wantsTranslation
      ? service.effectiveTargetLanguage(effectiveAppLocale)
      : null;

  if (!wantsTranslation &&
      textTrackContent != null &&
      textTrackContent.isNotEmpty) {
    final embedded = SubtitleFetchResult.fromBody(textTrackContent);
    if (embedded?.status == SubtitleFetchStatus.available) return embedded!;
  }
  final refs = textTrackRefs.isNotEmpty
      ? textTrackRefs
      : [if (textTrackRef != null && textTrackRef.isNotEmpty) textTrackRef];
  return fetchSubtitleCues(
    httpClient: ref.read(subtitleHttpClientProvider),
    nostrClient: ref.read(nostrServiceProvider),
    delay: ref.read(subtitlePollDelayProvider),
    textTrackContent: textTrackContent,
    textTrackRefs: refs,
    sha256: sha256,
    lang: lang,
  );
}

/// Cue-only view for callers that do not render track attribution.
@riverpod
Future<List<SubtitleCue>> subtitleCues(
  Ref ref, {
  required String videoId,
  String? textTrackRef,
  List<String> textTrackRefs = const [],
  String? textTrackContent,
  String? sha256,
  String? sourceLang,
}) async {
  final result = await ref.watch(
    subtitleTrackProvider(
      videoId: videoId,
      textTrackRef: textTrackRef,
      textTrackRefs: textTrackRefs,
      textTrackContent: textTrackContent,
      sha256: sha256,
      sourceLang: sourceLang,
    ).future,
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
