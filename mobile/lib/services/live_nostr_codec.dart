import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';

class LiveNostrCodec {
  const LiveNostrCodec();

  LiveRoom parseRoom(Event event) {
    _requireKind(event, 30312, 'room');
    final roomId = _requiredTagValue(event.tags, 'd', 'room id');

    return LiveRoom(
      id: roomId,
      hostPubkey: event.pubkey,
      title:
          _firstTagValue(event.tags, 'title') ??
          _firstTagValue(event.tags, 'room') ??
          roomId,
      summary:
          _firstTagValue(event.tags, 'summary') ??
          (event.content.trim().isEmpty ? '' : event.content),
      imageUrl: _firstTagValue(event.tags, 'image'),
      relays: _tagValues(event.tags, 'relays'),
      visibility: LiveRoomVisibility.fromNostrStatus(
        _firstTagValue(event.tags, 'status'),
      ),
    );
  }

  Future<Event> buildRoomEvent(LiveRoom room, NostrSigner signer) async {
    final pubkey = await _requiredSignerPubkey(
      signer,
      label: 'room event',
    );
    if (pubkey != room.hostPubkey) {
      throw StateError('Signer pubkey does not match the room host pubkey');
    }

    final tags = <List<String>>[
      ['d', room.id],
      ['room', room.title],
      ['status', room.visibility.nostrStatusValue],
    ];

    if (room.imageUrl != null && room.imageUrl!.isNotEmpty) {
      tags.add(['image', room.imageUrl!]);
    }
    if (room.relays.isNotEmpty) {
      tags.add(['relays', ...room.relays]);
    }

    final signedEvent = await signer.signEvent(
      Event(pubkey, 30312, tags, room.summary),
    );
    if (signedEvent == null) {
      throw StateError('Signer returned null while signing the room event');
    }
    return signedEvent;
  }

  Future<Event> buildSessionEvent({
    required LiveSession session,
    required String roomAddress,
    required String hostPubkey,
    required NostrSigner signer,
  }) async {
    final pubkey = await _requiredSignerPubkey(
      signer,
      label: 'session event',
    );
    if (pubkey != hostPubkey) {
      throw StateError('Signer pubkey does not match the session host pubkey');
    }

    final tags = <List<String>>[
      ['d', session.id],
      ['a', roomAddress],
      ['status', session.status.tagValue],
      ['starts', _unixSeconds(session.startedAt)],
      ['current_participants', session.audienceCount.toString()],
    ];

    if (session.endedAt != null) {
      tags.add(['ends', _unixSeconds(session.endedAt!)]);
    }

    for (final speakerPubkey in session.speakerPubkeys) {
      final role = speakerPubkey == hostPubkey
          ? LiveRole.host
          : LiveRole.speaker;
      tags.add(['p', speakerPubkey, '', role.name]);
    }

    return _signEvent(
      signer: signer,
      pubkey: pubkey,
      kind: 30313,
      tags: tags,
      content: '',
      label: 'session event',
    );
  }

  Future<Event> buildPresenceEvent({
    required String sessionAddress,
    required LiveRole role,
    required bool handRaised,
    required NostrSigner signer,
  }) async {
    final pubkey = await _requiredSignerPubkey(
      signer,
      label: 'presence event',
    );
    final handValue = handRaised ? '1' : '0';

    return _signEvent(
      signer: signer,
      pubkey: pubkey,
      kind: 10312,
      tags: <List<String>>[
        ['a', sessionAddress],
        ['role', role.name],
        ['hand', handValue],
      ],
      content: '',
      label: 'presence event',
    );
  }

  Future<Event> buildChatMessageEvent({
    required String sessionAddress,
    required String content,
    required NostrSigner signer,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        'Chat message cannot be empty',
      );
    }

    final pubkey = await _requiredSignerPubkey(
      signer,
      label: 'chat message event',
    );

    return _signEvent(
      signer: signer,
      pubkey: pubkey,
      kind: 1311,
      tags: <List<String>>[
        ['a', sessionAddress],
      ],
      content: trimmedContent,
      label: 'chat message event',
    );
  }

  LiveSession parseSession(Event event) {
    _requireKind(event, 30313, 'session');
    final sessionId = _requiredTagValue(event.tags, 'd', 'session id');
    final roomAddress = _requiredAddressForKind(event.tags, 30312, 'room');
    final speakerPubkeys = <String>[];

    for (final tag in event.tags.where(
      (tag) => tag.isNotEmpty && tag.first == 'p',
    )) {
      if (tag.length < 2 || tag[1].isEmpty) {
        continue;
      }
      final role = LiveRole.fromNostrRole(tag.length > 3 ? tag[3] : null);
      if (role.canPublish && !speakerPubkeys.contains(tag[1])) {
        speakerPubkeys.add(tag[1]);
      }
    }

    return LiveSession(
      id: sessionId,
      roomId: _dTagFromAddress(roomAddress),
      hostPubkey: event.pubkey,
      status: LiveSessionStatus.fromTagValue(
        _firstTagValue(event.tags, 'status'),
      ),
      startedAt:
          _parseDateTime(_firstTagValue(event.tags, 'starts')) ??
          _eventTimestamp(event),
      endedAt: _parseDateTime(_firstTagValue(event.tags, 'ends')),
      speakerPubkeys: speakerPubkeys,
      audienceCount:
          _parseInt(_firstTagValue(event.tags, 'current_participants')) ??
          _parseInt(_firstTagValue(event.tags, 'total_participants')) ??
          0,
    );
  }

  LivePresence parsePresence(Event event) {
    _requireKind(event, 10312, 'presence');
    final sessionAddress = _requiredAddressForKind(
      event.tags,
      30313,
      'session',
    );

    return LivePresence(
      sessionId: _dTagFromAddress(sessionAddress),
      sessionHostPubkey: _authorFromAddress(sessionAddress),
      pubkey: event.pubkey,
      role: LiveRole.fromNostrRole(_firstTagValue(event.tags, 'role')),
      handRaised: _isRaisedHand(_firstTagValue(event.tags, 'hand')),
      updatedAt: _eventTimestamp(event),
    );
  }

  LiveChatMessage parseChatMessage(Event event) {
    _requireKind(event, 1311, 'chat message');
    final sessionAddress = _requiredAddressForKind(
      event.tags,
      30313,
      'session',
    );

    return LiveChatMessage(
      id: event.id,
      sessionAddress: sessionAddress,
      pubkey: event.pubkey,
      content: event.content,
      createdAt: _eventTimestamp(event),
    );
  }

  void _requireKind(Event event, int expectedKind, String label) {
    if (event.kind != expectedKind) {
      throw FormatException(
        'Expected live $label event kind $expectedKind but received ${event.kind}',
      );
    }
  }

  String _requiredTagValue(
    List<List<String>> tags,
    String name,
    String label,
  ) {
    final value = _firstTagValue(tags, name);
    if (value == null || value.isEmpty) {
      throw FormatException('Missing required $label tag "$name"');
    }
    return value;
  }

  String _requiredAddressForKind(
    List<List<String>> tags,
    int kind,
    String label,
  ) {
    for (final tag in tags) {
      if (tag.length > 1 && tag.first == 'a' && tag[1].startsWith('$kind:')) {
        return tag[1];
      }
    }
    throw FormatException('Missing required $label address tag for kind $kind');
  }

  String? _firstTagValue(List<List<String>> tags, String name) {
    for (final tag in tags) {
      if (tag.length > 1 && tag.first == name) {
        return tag[1];
      }
    }
    return null;
  }

  List<String> _tagValues(List<List<String>> tags, String name) {
    for (final tag in tags) {
      if (tag.length > 1 && tag.first == name) {
        return tag.sublist(1);
      }
    }
    return const [];
  }

  DateTime? _parseDateTime(String? unixSeconds) {
    final seconds = _parseInt(unixSeconds);
    if (seconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  DateTime _eventTimestamp(Event event) {
    return DateTime.fromMillisecondsSinceEpoch(
      event.createdAt * 1000,
      isUtc: true,
    );
  }

  int? _parseInt(String? rawValue) => int.tryParse(rawValue ?? '');

  String _unixSeconds(DateTime value) {
    return (value.toUtc().millisecondsSinceEpoch ~/ 1000).toString();
  }

  String _dTagFromAddress(String address) {
    final parts = address.split(':');
    return parts.length > 2 ? parts[2] : '';
  }

  String _authorFromAddress(String address) {
    final parts = address.split(':');
    return parts.length > 1 ? parts[1] : '';
  }

  bool _isRaisedHand(String? rawValue) {
    switch (rawValue?.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
        return true;
      default:
        return false;
    }
  }

  Future<String> _requiredSignerPubkey(
    NostrSigner signer, {
    required String label,
  }) async {
    final pubkey = await signer.getPublicKey();
    if (pubkey == null || pubkey.isEmpty) {
      throw StateError('Signer did not provide a public key for $label');
    }
    return pubkey;
  }

  Future<Event> _signEvent({
    required NostrSigner signer,
    required String pubkey,
    required int kind,
    required List<List<String>> tags,
    required String content,
    required String label,
  }) async {
    final signedEvent = await signer.signEvent(
      Event(pubkey, kind, tags, content),
    );
    if (signedEvent == null) {
      throw StateError('Signer returned null while signing the $label');
    }
    return signedEvent;
  }
}
