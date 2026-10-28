// ABOUTME: Account-scoped trusted chat mentions and durable local read metadata.
// ABOUTME: Keeps decrypted message text in memory, never in the metadata store.
import 'dart:async';
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:rxdart/rxdart.dart' hide NotificationKind;
import 'package:unified_logger/unified_logger.dart';

/// Which room mentions can alert, and how many rows the inbox keeps.
abstract final class ChatMentionLimits {
  /// Older mentions are history, not news.
  static const int maxAgeSeconds = 7 * 24 * 3600;

  /// Tolerated sender clock skew; a later timestamp is implausible.
  static const maxFutureSkewSeconds = 300;

  /// Rows kept, newest first: one per sender and room.
  static const maxRows = 50;
}

/// Turns trusted mentions of [owner] in rooms the owner has opened into
/// in-app notification rows, with read state kept in [store].
class ChatMentionRepository implements LocalNotificationSource {
  ChatMentionRepository({
    required this.owner,
    required this.communityId,
    required this.store,
    required this.canNotify,
    required this.now,
    this.loadActors,
    this.createRoom,
    this.startRoom,
  });

  final String owner;

  /// The community every observed room belongs to; rows open rooms in it.
  final String communityId;
  final AccountScopedStore store;
  final bool Function(String author) canNotify;
  final int Function() now;
  final Future<List<ActorInfo>> Function(Set<String> authors)? loadActors;
  final _actors = <String, ActorInfo>{};
  final _loadingActors = <String>{};
  final ConcordRepository Function(String channel)? createRoom;
  final Future<void> Function(String channel, ConcordRepository repository)?
  startRoom;
  static const _stateKey = 'mention-state';
  final _rooms = <String, int>{};
  final _seen = <String, String>{};
  final _messages = <String, List<ChatMessage>>{};
  final _repositories = <String, ConcordRepository>{};
  final _subscriptions = <String, StreamSubscription<void>>{};
  final _failedRooms = <String>{};
  Future<void>? _refreshing;
  final _snapshots = BehaviorSubject<List<NotificationItem>>.seeded(const []);
  Future<void>? _initializing;
  Future<void> _writes = Future.value();
  Future<void> _mutations = Future.value();
  bool _closed = false;

  @override
  List<NotificationItem> get items => _snapshots.value;
  @override
  Stream<List<NotificationItem>> watchSnapshot() => _snapshots.stream;

  /// Loads the saved enrollments and read markers and starts their rooms.
  ///
  /// Completes once state is loaded; a room that fails to start is left for
  /// [refresh]. Throws only when the store cannot be read, and a later call
  /// retries.
  Future<void> initialize() {
    if (_closed) return Future.value();
    return _initializing ??= _initialize().catchError((
      Object error,
      StackTrace stack,
    ) {
      _initializing = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _initialize() async {
    final raw = await store.get(_stateKey);
    if (_closed) return;
    final state = raw == null ? null : _decodeState(raw);
    if (raw != null && state == null) {
      // An unreadable record must not disable alerts; the next write replaces it.
      Log.warning(
        'Discarding unreadable chat mention state',
        name: 'ChatMentions',
      );
    }
    if (state != null) {
      _rooms.addAll(state.rooms);
      _seen.addAll(state.seen);
    }
    await Future.wait([
      for (final channel in List<String>.of(_rooms.keys))
        _observeOrDefer(channel),
    ]);
  }

  /// Starts [channel]; a failure leaves it unobserved for [refresh] to retry.
  Future<void> _observeOrDefer(String channel) =>
      _observe(channel).catchError((Object error, StackTrace stack) {
        Log.warning(
          'Chat mention room failed to start; refresh retries it',
          name: 'ChatMentions',
          error: error,
          stackTrace: stack,
        );
      });

  /// Starts alerting on [channel]; messages sent before enrollment never
  /// alert. Rethrows a refused write, leaving [channel] unenrolled, and a
  /// failed room start.
  Future<void> enroll(String channel) async {
    await initialize();
    if (_closed) return;
    await _mutate(() async {
      if (_closed || _rooms.containsKey(channel)) return;
      _rooms[channel] = now();
      try {
        await _persist();
      } on Object {
        _rooms.remove(channel);
        _messages.remove(channel);
        rethrow;
      }
    });
    if (!_closed) await _observe(channel);
  }

  /// Runs [change] after every earlier state change, so a failed write's
  /// rollback lands before the next write snapshots the state.
  Future<void> _mutate(Future<void> Function() change) {
    final mutation = _mutations.then((_) => change());
    _mutations = mutation.catchError((Object _) {});
    return mutation;
  }

  Future<void> _observe(String channel) async {
    if (createRoom == null || _closed || _repositories.containsKey(channel)) {
      return;
    }
    final repository = createRoom!(channel);
    _repositories[channel] = repository;
    try {
      await startRoom!(channel, repository);
      if (_closed) return;
      void refresh() =>
          updateRoom(channel, repository.timeline(now: now()).messages);
      _subscriptions[channel] = repository.changes.listen(
        (_) => refresh(),
        onError: (Object error, StackTrace stack) {
          // The relay gave up or a write failed: keep the last snapshot until
          // refresh() rebuilds this room.
          Log.warning(
            'Chat mention room stopped',
            name: 'ChatMentions',
            error: error,
            stackTrace: stack,
          );
          _failedRooms.add(channel);
        },
      );
      refresh();
    } on Object {
      _repositories.remove(channel);
      await repository.close();
      rethrow;
    }
  }

  @override
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    await initialize();
    if (_closed) return;
    for (final channel in List<String>.of(_failedRooms)) {
      await _subscriptions.remove(channel)?.cancel();
      await _repositories.remove(channel)?.close();
      _failedRooms.remove(channel);
    }
    // A snapshot: enroll may add a room while a start below is awaited.
    for (final channel in List<String>.of(_rooms.keys)) {
      if (_closed) return;
      await _observeOrDefer(channel);
    }
    reevaluate();
  }

  /// Replaces [channel]'s buffered messages with [messages] and rebuilds rows.
  void updateRoom(String channel, List<ChatMessage> messages) {
    if (_closed || !_rooms.containsKey(channel)) return;
    _messages[channel] = List.of(messages);
    reevaluate();
  }

  /// Requests the profiles of senders whose rows still show a generated name.
  /// A row can appear after its message did, once the sender is followed or
  /// unblocked, so this runs on every rebuild rather than only on arrival.
  void _loadMissingActors(Iterable<String> authors) {
    if (loadActors == null) return;
    final missing = {
      for (final author in authors)
        if (!_actors.containsKey(author) && !_loadingActors.contains(author))
          author,
    };
    if (missing.isEmpty) return;
    _loadingActors.addAll(missing);
    runDetached(
      _resolveActors(missing),
      'load chat mention senders',
      logName: 'ChatMentions',
      category: LogCategory.storage,
    );
  }

  /// Rows keep the generated fallback name until a load succeeds; the next
  /// [updateRoom] retries any sender still missing.
  Future<void> _resolveActors(Set<String> authors) async {
    try {
      final actors = await loadActors!(authors);
      if (_closed) return;
      for (final actor in actors) {
        _actors[actor.pubkey] = actor;
      }
      reevaluate();
    } finally {
      _loadingActors.removeAll(authors);
    }
  }

  /// Rebuilds rows from buffered messages, reapplying [canNotify] to rows
  /// already shown.
  void reevaluate() {
    if (_closed) return;
    final ownerReference = 'nostr:${NostrKeyUtils.encodePubKey(owner)}';
    final current = now();
    final groups = <String, ({String channel, ChatMessage message})>{};
    for (final entry in _messages.entries) {
      for (final message in entry.value) {
        if (message.author == owner ||
            !message.mentionedPubkeys.contains(owner) ||
            // A p tag alone is not a mention: NIP-22 replies tag the parent's
            // author. The owner's key must also show in the effective body.
            !message.effectiveBody.contains(ownerReference) ||
            !canNotify(message.author) ||
            message.createdAt < _rooms[entry.key]! ||
            message.createdAt < current - ChatMentionLimits.maxAgeSeconds ||
            message.createdAt >
                current + ChatMentionLimits.maxFutureSkewSeconds ||
            message.isExpiredAt(current)) {
          continue;
        }
        final id = 'chat:${entry.key}:${message.author}';
        final previous = groups[id]?.message;
        if (previous == null ||
            message.createdAt > previous.createdAt ||
            (message.createdAt == previous.createdAt &&
                (message.ms > previous.ms ||
                    (message.ms == previous.ms &&
                        message.id.compareTo(previous.id) > 0)))) {
          groups[id] = (channel: entry.key, message: message);
        }
      }
    }
    final rows = [
      for (final entry in groups.entries)
        ActorNotification(
          id: entry.key,
          type: NotificationKind.mention,
          actor:
              _actors[entry.value.message.author] ??
              ActorInfo(
                pubkey: entry.value.message.author,
                displayName: UserProfile.defaultDisplayNameFor(
                  entry.value.message.author,
                ),
              ),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            entry.value.message.createdAt * 1000 + entry.value.message.ms,
          ),
          isRead:
              (_seen[entry.key] ?? '').compareTo(
                _readOrder(
                  entry.value.message.createdAt * 1000 + entry.value.message.ms,
                  entry.value.message.id,
                ),
              ) >=
              0,
          sourceEventIds: [entry.value.message.id],
          chatTarget: ChatNotificationTarget(
            communityId: communityId,
            channelId: entry.value.channel,
          ),
        ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final shown = rows.take(ChatMentionLimits.maxRows).toList();
    _snapshots.add(List.unmodifiable(shown));
    _loadMissingActors(shown.map((row) => row.actor.pubkey));
  }

  @override
  Future<void> markSeen(List<String> ids) {
    final captured = [
      for (final item in items.where((item) => ids.contains(item.id))) item,
    ];
    return _mutate(() async {
      if (_closed) return;
      final before = Map<String, String>.of(_seen);
      for (final item in captured) {
        final order = _readOrder(
          item.timestamp.millisecondsSinceEpoch,
          item.sourceEventIds.single,
        );
        if (order.compareTo(_seen[item.id] ?? '') > 0) {
          _seen[item.id] = order;
        }
      }
      // Mark-all runs on every inbox open; writing an unchanged (possibly
      // not-yet-loaded) state could replace the saved rooms with nothing.
      if (_seen.length == before.length &&
          _seen.entries.every((entry) => before[entry.key] == entry.value)) {
        return;
      }
      try {
        await _persist();
      } on Object {
        _seen
          ..clear()
          ..addAll(before);
        rethrow;
      }
      reevaluate();
    });
  }

  String _readOrder(int milliseconds, String id) =>
      '${milliseconds.toString().padLeft(16, '0')}:$id';

  Future<void> _persist() {
    final value = jsonEncode({'rooms': _rooms, 'seen': _seen});
    final write = _writes.then((_) => store.put(_stateKey, value));
    _writes = write.catchError((Object _) {});
    return write;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait([
      for (final subscription in _subscriptions.values) subscription.cancel(),
    ]);
    await Future.wait([
      for (final repository in _repositories.values) repository.close(),
    ]);
    await _mutations;
    await _writes;
    _messages.clear();
    await _snapshots.close();
  }
}

/// Reads the persisted room enrollments and read markers, or null when the
/// record is not the shape this repository writes.
({Map<String, int> rooms, Map<String, String> seen})? _decodeState(
  String raw,
) {
  final Object? data;
  try {
    data = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (data
      case {
        'rooms': final Map<String, Object?> rooms,
        'seen': final Map<String, Object?> seen,
      }
      when rooms.values.every((value) => value is int) &&
          seen.values.every((value) => value is String)) {
    return (
      rooms: Map<String, int>.from(rooms),
      seen: Map<String, String>.from(seen),
    );
  }
  return null;
}
