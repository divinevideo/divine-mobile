import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/live_nostr_codec.dart';

class LiveRepository {
  LiveRepository({
    required NostrClient nostrClient,
    required LiveNostrCodec codec,
    LiveApiService? liveApiService,
  }) : _nostrClient = nostrClient,
       _codec = codec,
       _liveApiService = liveApiService;

  final NostrClient _nostrClient;
  final LiveNostrCodec _codec;
  final LiveApiService? _liveApiService;

  /// Resolves a direct link without relying on the discovery window.
  Future<LiveRoom?> fetchRoom(String roomId) async {
    final events = await _nostrClient.queryEvents([
      Filter(kinds: const [30312], d: [roomId]),
    ]);
    final rooms = <String, LiveRoom>{};
    final versions = <String, Event>{};
    for (final event in events) {
      final room = _tryParseRoom(event);
      if (room == null ||
          room.id != roomId ||
          !_acceptVersion(versions, room.address, event)) {
        continue;
      }
      rooms[room.address] = room;
    }
    // A d tag alone cannot distinguish conflicting authors.
    return rooms.length == 1 ? rooms.values.single : null;
  }

  Future<List<LiveRoom>> fetchPublicRooms({int limit = 50}) async {
    final events = await _nostrClient.queryEvents([
      Filter(kinds: const <int>[30312], limit: limit),
    ]);

    final rooms = <String, LiveRoom>{};
    final versions = <String, Event>{};
    for (final event in events) {
      final room = _tryParseRoom(event);
      if (room == null) {
        continue;
      }
      if (!_acceptVersion(versions, room.address, event)) {
        continue;
      }
      if (room.visibility == LiveRoomVisibility.public) {
        rooms[room.address] = room;
      } else {
        rooms.remove(room.address);
      }
    }

    return _sortedRooms(rooms.values);
  }

  Stream<List<LiveRoom>> watchPublicRooms({int limit = 50}) {
    return _watchCollection<LiveRoom>(
      queryFilters: <Filter>[
        Filter(kinds: const <int>[30312], limit: limit),
      ],
      subscribeFilters: <Filter>[
        Filter(kinds: const <int>[30312], limit: limit),
      ],
      parse: _tryParseRoom,
      keyOf: (room) => room.address,
      shouldInclude: (room) => room.visibility == LiveRoomVisibility.public,
      sort: _sortedRooms,
      subscriptionPrefix: 'live_rooms',
    );
  }

  Future<List<LiveSession>> fetchSessions({
    String? roomAddress,
    String? sessionId,
    int limit = 50,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        kinds: const <int>[30313],
        a: roomAddress == null ? null : <String>[roomAddress],
        d: sessionId == null ? null : [sessionId],
        limit: limit,
      ),
    ]);

    final sessions = <String, LiveSession>{};
    final versions = <String, Event>{};
    for (final event in events) {
      final session = _tryParseSession(event);
      if (session != null &&
          _acceptVersion(versions, session.addressKey, event)) {
        sessions[session.addressKey] = session;
      }
    }

    return _sortedSessions(sessions.values);
  }

  Stream<List<LiveSession>> watchSessions({
    String? roomAddress,
    String? sessionId,
    int limit = 50,
  }) {
    final filters = <Filter>[
      Filter(
        kinds: const <int>[30313],
        a: roomAddress == null ? null : <String>[roomAddress],
        d: sessionId == null ? null : [sessionId],
        limit: limit,
      ),
    ];

    return _watchCollection<LiveSession>(
      queryFilters: filters,
      subscribeFilters: filters,
      parse: _tryParseSession,
      keyOf: (session) => session.addressKey,
      sort: _sortedSessions,
      subscriptionPrefix: 'live_sessions',
    );
  }

  Stream<List<LivePresence>> watchPresence({
    required String sessionAddress,
    int limit = 50,
  }) {
    final filters = <Filter>[
      Filter(
        kinds: const <int>[10312],
        a: <String>[sessionAddress],
        limit: limit,
      ),
    ];

    return _watchCollection<LivePresence>(
      queryFilters: filters,
      subscribeFilters: filters,
      parse: _tryParsePresence,
      keyOf: (presence) => '${presence.sessionAddressKey}:${presence.pubkey}',
      sort: _sortedPresence,
      subscriptionPrefix: 'live_presence',
    );
  }

  Future<Event?> publishRoom(LiveRoom room) async {
    final signedEvent = await _codec.buildRoomEvent(room, _nostrClient.signer);
    final result = await _nostrClient.publishEvent(
      signedEvent,
      targetRelays: room.relays.isEmpty ? null : room.relays,
    );
    return switch (result) {
      PublishSuccess(:final event) => event,
      PublishNoRelays() || PublishFailed() => null,
    };
  }

  Future<Event?> publishSession({
    required LiveSession session,
    required String roomAddress,
    required String hostPubkey,
  }) async {
    final signedEvent = await _codec.buildSessionEvent(
      session: session,
      roomAddress: roomAddress,
      hostPubkey: hostPubkey,
      signer: _nostrClient.signer,
    );
    final result = await _nostrClient.publishEvent(signedEvent);
    return switch (result) {
      PublishSuccess(:final event) => event,
      PublishNoRelays() || PublishFailed() => null,
    };
  }

  Future<Event?> publishPresence({
    required String sessionAddress,
    required LiveRole role,
    required bool handRaised,
  }) async {
    final signedEvent = await _codec.buildPresenceEvent(
      sessionAddress: sessionAddress,
      role: role,
      handRaised: handRaised,
      signer: _nostrClient.signer,
    );
    final result = await _nostrClient.publishEvent(signedEvent);
    return switch (result) {
      PublishSuccess(:final event) => event,
      PublishNoRelays() || PublishFailed() => null,
    };
  }

  Future<LiveRoomRecording?> fetchRecording({
    required String roomId,
  }) async {
    final liveApiService = _liveApiService;
    if (liveApiService == null) {
      return null;
    }

    return liveApiService.fetchRecording(roomId: roomId);
  }

  Stream<List<T>> _watchCollection<T>({
    required List<Filter> queryFilters,
    required List<Filter> subscribeFilters,
    required T? Function(Event event) parse,
    required String Function(T item) keyOf,
    required List<T> Function(Iterable<T> items) sort,
    required String subscriptionPrefix,
    bool Function(T item)? shouldInclude,
  }) {
    final cache = <String, T>{};
    final versions = <String, Event>{};
    final subscriptionId =
        '$subscriptionPrefix-${DateTime.now().microsecondsSinceEpoch}';
    late final StreamController<List<T>> controller;
    StreamSubscription<Event>? subscription;

    Future<void> loadInitial() async {
      final events = await _nostrClient.queryEvents(
        queryFilters,
        subscriptionId: '${subscriptionId}_initial',
      );
      for (final event in events) {
        final item = parse(event);
        if (item == null || !_acceptVersion(versions, keyOf(item), event)) {
          continue;
        }
        if (shouldInclude != null && !shouldInclude(item)) {
          cache.remove(keyOf(item));
          continue;
        }
        cache[keyOf(item)] = item;
      }
      if (!controller.isClosed) {
        controller.add(sort(cache.values));
      }
    }

    void handleEvent(Event event) {
      final item = parse(event);
      if (item == null || !_acceptVersion(versions, keyOf(item), event)) {
        return;
      }

      if (shouldInclude != null && !shouldInclude(item)) {
        cache.remove(keyOf(item));
      } else {
        cache[keyOf(item)] = item;
      }

      if (!controller.isClosed) {
        controller.add(sort(cache.values));
      }
    }

    controller = StreamController<List<T>>(
      onListen: () {
        unawaited(loadInitial());
        subscription = _nostrClient
            .subscribe(
              subscribeFilters,
              subscriptionId: subscriptionId,
            )
            .listen(handleEvent);
      },
      onCancel: () async {
        await subscription?.cancel();
        await _nostrClient.unsubscribe(subscriptionId);
      },
    );

    return controller.stream;
  }

  // NIP-01 retains the lowest event ID when replacement timestamps tie.
  // Keep versions even for excluded items so stale events cannot restore them.
  bool _acceptVersion(Map<String, Event> versions, String key, Event event) {
    final current = versions[key];
    if (current != null &&
        (event.createdAt < current.createdAt ||
            (event.createdAt == current.createdAt &&
                event.id.compareTo(current.id) >= 0))) {
      return false;
    }
    versions[key] = event;
    return true;
  }

  LiveRoom? _tryParseRoom(Event event) {
    try {
      return _codec.parseRoom(event);
    } on FormatException {
      return null;
    }
  }

  LiveSession? _tryParseSession(Event event) {
    try {
      return _codec.parseSession(event);
    } on FormatException {
      return null;
    }
  }

  LivePresence? _tryParsePresence(Event event) {
    try {
      return _codec.parsePresence(event);
    } on FormatException {
      return null;
    }
  }

  List<LiveRoom> _sortedRooms(Iterable<LiveRoom> items) {
    final rooms = items.toList(growable: false);
    rooms.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return rooms;
  }

  List<LiveSession> _sortedSessions(Iterable<LiveSession> items) {
    final sessions = items.toList(growable: false);
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  List<LivePresence> _sortedPresence(Iterable<LivePresence> items) {
    final presence = items.toList(growable: false);
    presence.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return presence;
  }
}
