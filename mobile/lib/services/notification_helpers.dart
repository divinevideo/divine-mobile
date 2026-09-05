// ABOUTME: Pure helper functions for notification payload processing
// ABOUTME: shared by the notification and push notification services.

/// Parses an addressable event ID into its components.
///
/// Format: "kind:pubkey:d-tag". The d-tag may contain colons.
/// Returns `(kind, pubkey, dTag)` or null if the format is invalid.
({int kind, String pubkey, String dTag})? parseAddressableId(
  String addressableId,
) {
  final parts = addressableId.split(':');
  if (parts.length < 3) return null;

  final kind = int.tryParse(parts[0]);
  if (kind == null) return null;

  return (kind: kind, pubkey: parts[1], dTag: parts.sublist(2).join(':'));
}

/// Field names shared between the writer of the local-notification tap payload
/// ([localNotificationTapPayload]) and its readers ([parseFcmPayload] and
/// `NotificationService.handleNotificationTapPayload`). Centralised so the
/// three sites cannot drift apart when a routing field is added or renamed.
abstract class NotificationPayloadKeys {
  /// FCM wire key for the notification type (lowercase
  /// `like`/`comment`/`follow`/`mention`/`repost`/`campaign`). Stored on a
  /// locally-emitted payload under [notificationType].
  static const String wireType = 'type';

  /// The event acted upon (present for like/comment/repost; absent for
  /// follow/mention, which carry no `e` tag).
  static const String referencedEventId = 'referencedEventId';

  /// Authoritative NIP-33 addressable coordinate (`kind:pubkey:d-tag`) of the
  /// referenced video, taken from the source event's signed `a`/`A` tag. Stable
  /// across NIP-33 replacements, so the tap router prefers it over
  /// [referencedEventId]. Present only when the source event carries an `a`/`A`
  /// tag (like/comment/repost on an addressable video).
  static const String referencedAddress = 'referencedAddress';

  /// The source event itself (the like/comment/follow/mention event).
  static const String eventId = 'eventId';

  /// Normalised notification type carried on a locally-emitted payload.
  static const String notificationType = 'notificationType';

  /// Hex pubkey of the actor — used to route follows and unresolved taps.
  static const String senderPubkey = 'senderPubkey';

  /// Campaign destination type. The campaign service currently emits
  /// `app_route`.
  static const String tapTargetType = 'tapTargetType';

  /// Campaign destination value, such as an absolute in-app route.
  static const String tapTargetValue = 'tapTargetValue';
}

/// Normalises a raw push-notification payload map into the fields the tap
/// router needs.
///
/// Mirrors the `divine-push-service` data-only contract: `type` (lowercase
/// `like`/`comment`/`follow`/`mention`/`repost`), `referencedEventId` (present
/// only when the source event has an `e` tag — i.e. like/comment/repost),
/// `eventId` (the source event itself, always present), and `senderPubkey`
/// (the actor). Translates the wire key `'type'` to `notificationType` so
/// callers see one shape whether the payload came from the FCM wire or a
/// locally-emitted notification JSON.
///
/// Also surfaces `referencedAddress` (the authoritative NIP-33 coordinate from
/// the source event's signed `a`/`A` tag) so the tap router can route to the
/// stable address without walking the event.
///
/// Campaigns are routable through `tapTargetType` / `tapTargetValue` without a
/// Nostr event. Other payloads return `null` only when they carry no event,
/// address, or actor target.
({
  String? referencedEventId,
  String? referencedAddress,
  String? eventId,
  String? notificationType,
  String? senderPubkey,
  String? tapTargetType,
  String? tapTargetValue,
})?
parseFcmPayload(Map<String, dynamic> data) {
  String? nonEmpty(String key) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  final referencedEventId = nonEmpty(NotificationPayloadKeys.referencedEventId);
  final referencedAddress = nonEmpty(NotificationPayloadKeys.referencedAddress);
  final eventId = nonEmpty(NotificationPayloadKeys.eventId);
  final senderPubkey = nonEmpty(NotificationPayloadKeys.senderPubkey);
  final notificationType =
      nonEmpty(NotificationPayloadKeys.wireType) ??
      nonEmpty(NotificationPayloadKeys.notificationType);
  final tapTargetType = nonEmpty(NotificationPayloadKeys.tapTargetType);
  final tapTargetValue = nonEmpty(NotificationPayloadKeys.tapTargetValue);

  if (referencedEventId == null &&
      referencedAddress == null &&
      eventId == null &&
      senderPubkey == null &&
      notificationType != 'campaign') {
    return null;
  }

  return (
    referencedEventId: referencedEventId,
    referencedAddress: referencedAddress,
    eventId: eventId,
    notificationType: notificationType,
    senderPubkey: senderPubkey,
    tapTargetType: tapTargetType,
    tapTargetValue: tapTargetValue,
  );
}

/// Builds the normalized local-notification tap payload from an FCM [data] map.
///
/// Single source of truth for the JSON shape carried on a locally-displayed
/// notification, so the background and foreground paths cannot drift. Built by
/// running [data] through [parseFcmPayload] and re-keying the result, so the
/// writer shares the readers' empty-string normalization through one point
/// rather than re-deriving it.
///
/// The FCM wire key `type` is stored under [NotificationPayloadKeys.
/// notificationType]; actor and campaign target fields are preserved so taps
/// without a Nostr event can still route. Consumed on tap by
/// `NotificationService.handleNotificationTapPayload`.
Map<String, dynamic> localNotificationTapPayload(Map<String, dynamic> data) {
  final parsed = parseFcmPayload(data);
  return {
    NotificationPayloadKeys.referencedEventId: parsed?.referencedEventId,
    NotificationPayloadKeys.referencedAddress: parsed?.referencedAddress,
    NotificationPayloadKeys.eventId: parsed?.eventId,
    NotificationPayloadKeys.notificationType: parsed?.notificationType,
    NotificationPayloadKeys.senderPubkey: parsed?.senderPubkey,
    NotificationPayloadKeys.tapTargetType: ?parsed?.tapTargetType,
    NotificationPayloadKeys.tapTargetValue: ?parsed?.tapTargetValue,
  };
}
