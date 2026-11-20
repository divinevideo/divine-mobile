// ABOUTME: One-time repair for corrupted kind 34236 events that have local
// ABOUTME: file paths instead of HTTP URLs in their imeta tags (issue #2144).
// ABOUTME: Reconstructs correct blossom URLs from the SHA-256 hash and
// ABOUTME: republishes corrected events via parameterized replaceable semantics.

import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Scans the current user's kind 34236 video events for corrupted imeta URLs
/// (local file paths instead of HTTP URLs) and republishes corrected events.
///
/// This is a one-time migration gated by a SharedPreferences flag.
/// Safe to run because kind 34236 is parameterized replaceable — publishing
/// a new event with the same `d` tag replaces the old one on the relay.
class CorruptedVideoRepairService {
  CorruptedVideoRepairService({
    required NostrClient nostrClient,
    required AuthService authService,
    required SharedPreferences prefs,
    required String blossomBaseUrl,
    VideoEventService? videoEventService,
  }) : _nostrClient = nostrClient,
       _authService = authService,
       _prefs = prefs,
       _blossomBaseUrl = blossomBaseUrl,
       _videoEventService = videoEventService;

  final NostrClient _nostrClient;
  final AuthService _authService;
  final SharedPreferences _prefs;
  final String _blossomBaseUrl;
  final VideoEventService? _videoEventService;

  static const String _completedKey = 'corrupted_video_repair_v1_completed';
  static const String _logName = 'CorruptedVideoRepair';

  /// Run the repair if it hasn't been completed yet.
  ///
  /// Returns the number of events repaired, `-1` if skipped (already done), or
  /// `0` without marking complete when there is no authenticated identity /
  /// public key yet or the relay scan is incomplete (the caller retries once
  /// the Nostr session is ready or on the next launch).
  ///
  /// The completion flag is only set once the scan actually ran, so calling
  /// this during the pre-restore startup window (no identity yet) cannot
  /// silently disable the one-time migration (#5909-adjacent regression).
  Future<int> repairIfNeeded() async {
    if (_prefs.getBool(_completedKey) == true) return -1;

    try {
      final repaired = await _repairCorruptedEvents();
      if (repaired == null) {
        // Not ready to run: don't mark complete, let the caller retry.
        return 0;
      }
      await _prefs.setBool(_completedKey, true);
      return repaired;
    } catch (e, s) {
      Log.error(
        'Repair failed, will retry on next startup: $e',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
      // Don't set the completed flag — retry on next startup.
      return 0;
    }
  }

  /// Scans and repairs the user's corrupted video events.
  ///
  /// Returns the number repaired, or `null` when the repair could not run:
  /// there is no authenticated identity / public key yet, or the relay scan is
  /// incomplete. The caller must not treat either as a completed run — an
  /// incomplete scan cannot prove that there is nothing to repair, and
  /// latching on it disables the migration permanently (#8213).
  Future<int?> _repairCorruptedEvents() async {
    if (!_authService.isAuthenticated) {
      Log.debug(
        'Not authenticated, skipping repair',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final pubkey = _nostrClient.publicKey;
    if (pubkey.isEmpty) {
      Log.debug(
        'No public key available, skipping repair',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    // Query all of the user's own kind 34236 events from relay
    final filter = Filter(kinds: [EventKind.videoVertical], authors: [pubkey]);

    // queryEventsDetailed, not queryEvents: the latter discards `timedOut` and
    // `noRelays`, so a scan nothing answered returns [] and reads as "no
    // corrupted events" — the loop no-ops, 0 comes back instead of null, and
    // the caller latches _completedKey permanently. `requireAllRelaysSettled`
    // is what makes a relay's `CLOSED` refusal and a partial fan-out surface
    // as `timedOut` rather than completing on whichever relays answered. With
    // useCache: false there is no cached row to fall back on either. #8213.
    final result = await _nostrClient.queryEventsDetailed(
      [filter],
      useCache: false,
      requireAllRelaysSettled: true,
    );
    if (result.noRelays || result.timedOut) {
      Log.warning(
        'Skipping corrupted-video repair: relay scan was incomplete '
        '(noRelays: ${result.noRelays}, timedOut: ${result.timedOut}). '
        'Retrying on the next launch.',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    final events = _newestPerAddress([
      for (final event in result.events)
        if (event.isValid && event.isSigned) event,
    ]);

    Log.info(
      'Scanning ${events.length} video events for corrupted URLs',
      name: _logName,
      category: LogCategory.video,
    );

    var repairedCount = 0;

    for (final event in events) {
      final repairedTags = _repairEventTags(event.tags);
      if (repairedTags == null) continue;

      // Use AuthService for proper signing (handles NIP-46 RPC + validation)
      // createdAt + 1: minimal bump to trigger relay replacement while
      // preserving the original publication date.
      final signedEvent = await _authService.createAndSignEvent(
        kind: EventKind.videoVertical,
        content: event.content,
        tags: repairedTags,
        createdAt: event.createdAt + 1,
      );

      if (signedEvent == null) {
        Log.warning(
          'Failed to sign repaired event for ${event.id}',
          name: _logName,
          category: LogCategory.video,
        );
        continue;
      }

      final sent = await _nostrClient.publishEvent(signedEvent);
      if (sent case PublishSuccess(:final event)) {
        repairedCount++;
        Log.info(
          'Repaired event ${event.id} '
          '(d-tag: ${_getDTag(event.tags)})',
          name: _logName,
          category: LogCategory.video,
        );

        // Update local cache so the fix is visible immediately
        _videoEventService?.updateVideoEvent(VideoEvent.fromNostrEvent(event));
      } else {
        Log.warning(
          'Failed to publish repaired event for ${event.id}',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }

    Log.info(
      'Repair complete: $repairedCount/${events.length} events fixed',
      name: _logName,
      category: LogCategory.video,
    );

    return repairedCount;
  }

  /// The newest revision at each address among [events]. Relays can hold
  /// older revisions too, and a repair built from one of those would replace
  /// the newer revision and delete what only it carried (#11250). An event
  /// with no `d` tag stands alone.
  static List<Event> _newestPerAddress(List<Event> events) {
    final newest = <String, Event>{};
    for (final event in events) {
      final dTag = event.dTagValue;
      final key = dTag.isEmpty
          ? event.id
          : '${event.kind}:${event.pubkey}:$dTag';
      final previous = newest[key];
      if (previous == null ||
          event.createdAt > previous.createdAt ||
          (event.createdAt == previous.createdAt &&
              event.id.compareTo(previous.id) < 0)) {
        newest[key] = event;
      }
    }
    return newest.values.toList();
  }

  /// Inspects and repairs imeta tags that have local file paths.
  /// Returns the full repaired tag list, or null if nothing was actually fixed.
  /// Corruption without a hash (unrepairable) is logged but not republished.
  List<List<String>>? _repairEventTags(List<List<String>> tags) {
    var hasRepair = false;

    final repairedTags = tags.map((tag) {
      if (tag.isEmpty || tag[0] != 'imeta') return tag;

      final repairedComponents = <String>[];
      String? sha256Hash;

      // First pass: extract sha256 hash from the imeta components
      for (final component in tag.skip(1)) {
        if (component.startsWith('x ')) {
          sha256Hash = component.substring(2).trim();
        }
      }

      // Second pass: repair corrupted url components
      for (var i = 0; i < tag.length; i++) {
        if (i == 0) {
          repairedComponents.add(tag[i]); // 'imeta'
          continue;
        }

        final component = tag[i];
        if (component.startsWith('url ')) {
          final url = component.substring(4).trim();
          if (_isLocalFilePath(url)) {
            if (sha256Hash != null && sha256Hash.isNotEmpty) {
              hasRepair = true;
              final repairedUrl = '$_blossomBaseUrl/$sha256Hash';
              repairedComponents.add('url $repairedUrl');
              Log.debug(
                'Repairing URL: $url -> $repairedUrl',
                name: _logName,
                category: LogCategory.video,
              );
            } else {
              // No hash — cannot reconstruct, skip republishing.
              repairedComponents.add(component);
              Log.warning(
                'Cannot repair URL (no x hash): $url',
                name: _logName,
                category: LogCategory.video,
              );
            }
          } else {
            repairedComponents.add(component);
          }
        } else {
          repairedComponents.add(component);
        }
      }

      return repairedComponents;
    }).toList();

    return hasRepair ? repairedTags : null;
  }

  /// Checks if a URL is a local file path instead of an HTTP URL.
  static bool _isLocalFilePath(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return false;
    // Common local path patterns from the corrupted events:
    // /var/mobile/Containers/... (iOS)
    // /data/user/0/... (Android)
    return url.startsWith('/') || url.startsWith('file://');
  }

  static String? _getDTag(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length >= 2 && tag[0] == 'd') return tag[1];
    }
    return null;
  }
}
