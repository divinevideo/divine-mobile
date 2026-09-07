import 'package:meta/meta.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Divine's published NIP-89 application handler identity.
abstract final class Nip89ClientTag {
  /// Shared preferences key controlling whether attribution is emitted.
  static const String preferenceKey = 'nip89_client_tag_enabled';

  /// Human-readable client name advertised in the `client` tag.
  static const String clientName = 'Divine';

  /// Pubkey of Divine's published kind `31990` handler event.
  static const String handlerPubkey =
      'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540';

  /// Stable `d` identifier of Divine's published kind `31990` handler event.
  static const String handlerDIdentifier = 'divine-mobile';

  /// Relay hint embedded in the NIP-89 client tag.
  static const String relayHint = 'wss://relay.divine.video';

  /// Kinds that must never carry the public `client` tag.
  ///
  /// The app's signing path consults this set before it appends the tag and
  /// signs, and that path takes a caller-supplied kind — including a kind
  /// chosen by a third-party app through the Nostr apps bridge. This set is
  /// its only guard, so an omission here is a real exposure rather than a
  /// missing belt alongside a brace.
  static const Set<int> _excludedKinds = {
    // NIP-59 requires a seal's tags be empty ("Tags MUST always be empty in a
    // `kind:13`"), so this entry is a spec requirement, not a preference.
    EventKind.sealEventKind,
    // Both NIP-59 outer wrappers. They are broadcast in the clear to the
    // recipient's relays, so a `client` tag on either is publicly visible and
    // would undercut NIP-17's "No Metadata Leak" guarantee. Keep them together:
    // 21059 was added to NIP-59 after this set was first written (#8177).
    EventKind.giftWrap,
    EventKind.ephemeralGiftWrap,
    EventKind.authentication,
    EventKind.nostrRemoteSigning,
    EventKind.blossomHttpAuth,
    EventKind.httpAuth,
    EventKind.zap,
  };

  static SharedPreferences? _prefs;
  static bool? _cachedEnabled;

  /// Canonical Divine NIP-89 client tag.
  static List<String> get tag => const [
    'client',
    clientName,
    '31990:$handlerPubkey:$handlerDIdentifier',
    relayHint,
  ];

  /// Returns whether [kind] should never receive a public client tag.
  static bool shouldSkipKind(int kind) => _excludedKinds.contains(kind);

  /// Returns whether [tags] already contain a `client` tag.
  static bool hasClientTag(Iterable<List<String>> tags) =>
      tags.any(_isClientTag);

  /// Returns whether Divine should emit the `client` tag for new events.
  static Future<bool> isEnabled() async {
    final cachedEnabled = _cachedEnabled;
    if (cachedEnabled != null) {
      return cachedEnabled;
    }

    final prefs = await _getPrefs();
    final enabled = prefs.getBool(preferenceKey) ?? true;
    _cachedEnabled = enabled;
    return enabled;
  }

  /// Persists whether Divine should emit the `client` tag for new events.
  static Future<void> setEnabled({required bool enabled}) async {
    final prefs = await _getPrefs();
    _cachedEnabled = enabled;
    await prefs.setBool(preferenceKey, enabled);
  }

  /// Ensures [event] has the canonical Divine NIP-89 client tag.
  ///
  /// Returns `true` when the event was changed. The event is updated in place
  /// so callers that keep a reference observe the final id/signature.
  static Future<bool> applyToEvent(Event event) async {
    if (shouldSkipKind(event.kind) || hasClientTag(event.tags)) {
      return false;
    }

    if (!await isEnabled()) {
      return false;
    }

    final rebuilt = Event(
      event.pubkey,
      event.kind,
      <List<String>>[...event.tags.map(List<String>.from), tag],
      event.content,
      createdAt: event.createdAt,
    );

    event
      ..tags = rebuilt.tags
      ..id = rebuilt.id
      ..sig = '';
    return true;
  }

  static bool _isClientTag(List<String> tag) =>
      tag.isNotEmpty && tag.first == 'client';

  static Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @visibleForTesting
  /// Clears cached preference state between tests.
  static void resetForTest() {
    _prefs = null;
    _cachedEnabled = null;
  }
}
