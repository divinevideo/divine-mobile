import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/media_availability_checker.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

/// Current policy remains separate from retained signed membership. Unknown
/// media/moderation never grants playback; a hidden pinned revision is not
/// replaced by a newer or duplicate video.
class ChallengeVideoPolicy {
  ChallengeVideoPolicy({
    required this.client,
    required this.moderation,
    required this.checkOwner,
    required this.sourceAllowed,
    this.media = const MediaAvailabilityChecker(),
  });
  final NostrClient client;
  final VideoModerationStatusService moderation;
  final Future<void> Function() checkOwner;
  final bool Function(NostrEvent) sourceAllowed;
  final MediaAvailabilityChecker media;
  final _allowedUntil = <String, DateTime>{};
  final _currentIds = <String, String>{};

  static bool isVideo(NostrEvent event) =>
      const [21, 22, 34235, 34236].contains(event.kind);
  static String _identity(NostrEvent event) => event.kind >= 30000
      ? '${event.kind}:${event.pubkey}:${event.tags.where((tag) => tag.length > 1 && tag.first == 'd').map((tag) => tag[1]).firstOrNull ?? ''}'
      : event.id;

  String? currentVideoId(NostrEvent event) => _currentIds[_identity(event)];

  bool isVisible(NostrEvent event) =>
      sourceAllowed(event) &&
      (!isVideo(event) ||
          (_allowedUntil[event.id]?.isAfter(DateTime.now()) ?? false));

  Future<void> refresh(NostrEvent event) async {
    await checkOwner();
    _allowedUntil.remove(event.id);
    _currentIds.remove(_identity(event));
    if (!isVideo(event) || !sourceAllowed(event)) return;
    final identifiers = event.tags.where(
      (tag) => tag.length > 1 && tag.first == 'd',
    );
    if (event.kind >= 30000 &&
        (identifiers.length != 1 || identifiers.single[1].isEmpty)) {
      return;
    }
    final sdk = Event.fromJson(event.toJson());
    final video = VideoEvent.fromNostrEvent(sdk);
    final relays = client.configuredRelays
        .where(client.isRelayAllowed)
        .toList();
    if (relays.isEmpty) return;
    final filter = event.kind >= 30000
        ? Filter(
            kinds: [event.kind],
            authors: [event.pubkey],
            d: [
              event.tags.firstWhere(
                (tag) => tag.length > 1 && tag.first == 'd',
              )[1],
            ],
            until: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            limit: 2,
          )
        : Filter(ids: [event.id], limit: 1);
    final read = await client.readEvents(
      [filter],
      tempRelays: relays,
      relayTypes: const [RelayType.temp],
      useCache: false,
      requireAllRelaysSettled: true,
      maxCollectedEvents: 2,
      maxCollectedBytes: 256 * 1024,
    );
    await checkOwner();
    if (!read.isComplete ||
        read.possiblyCapped ||
        read.answeredNetworkRelayCount !=
            relays.map(normalizeRelayUrl).toSet().length) {
      return;
    }
    final verified =
        read.events.map((e) => NostrEvent.fromJson(e.toJson())).toList()
          ..sort((a, b) {
            final time = b.createdAt.compareTo(a.createdAt);
            return time == 0 ? a.id.compareTo(b.id) : time;
          });
    if (verified.isNotEmpty) _currentIds[_identity(event)] = verified.first.id;
    final hash = VideoModerationStatusService.resolveSha256(
      explicitSha256: video.sha256,
      videoUrl: video.videoUrl,
    );
    final url = video.videoUrl;
    if (hash == null || url == null) return;
    final status = await moderation.fetchStatus(hash);
    await checkOwner();
    if (status == null ||
        !status.moderated ||
        status.isUnavailableDueToModeration ||
        status.needsReview) {
      return;
    }
    final available = await media.isConfirmedAvailable(url);
    await checkOwner();
    if (available && sourceAllowed(event)) {
      _allowedUntil[event.id] = DateTime.now().add(const Duration(seconds: 30));
    }
  }
}
