// MPL-2.0
import 'dart:async';
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/src/concord_repository.dart';

/// Activity derived from retained, verified messages in one channel.
class RoomActivitySummary {
  const RoomActivitySummary({
    required this.channelId,
    this.latestMessage,
    this.unreadCount = 0,
    this.recentMessageCount = 0,
    List<String> recentAuthors = const [],
    this.historyLimited = false,
    this.loading = true,
    this.loadFailed = false,
  }) : _recentAuthors = recentAuthors;

  final String channelId;
  final ChatMessage? latestMessage;
  final int unreadCount;
  final int recentMessageCount;
  final List<String> _recentAuthors;

  /// Unique contributors in the last 24 hours, newest contributor first.
  List<String> get recentAuthors => List.unmodifiable(_recentAuthors);

  /// The retained wrap window filled, so counts may be lower bounds.
  final bool historyLimited;
  final bool loading;
  final bool loadFailed;
}

/// Unread totals for an indicator that covers several rooms.
extension RoomActivityTotals on Iterable<RoomActivitySummary> {
  /// Unread messages across every room.
  int get totalUnread =>
      fold(0, (total, summary) => total + summary.unreadCount);

  /// Whether [totalUnread] may be a lower bound. Only rooms that show an
  /// unread count contribute, so the total agrees with the per-room badges.
  bool get totalUnreadLimited => any(
    (summary) => summary.unreadCount > 0 && summary.historyLimited,
  );
}

/// One owned channel session and the store scoped to its account and relay.
class RoomActivityChannel {
  const RoomActivityChannel({
    required this.channelId,
    required this.repository,
    required this.store,
    required this.streamSeedHex,
    required this.streamPubkey,
  });

  final String channelId;
  final ConcordRepository repository;
  final AccountScopedStore store;
  final String streamSeedHex;
  final String streamPubkey;
}

/// Owns room sessions shared by the catalog and the active chat screen.
///
/// Read receipts contain exact message IDs rather than a timestamp watermark:
/// a late delivery must remain unread even when its timestamp sorts earlier.
/// Metadata uses a separate key and never rewrites encrypted message records.
class RoomActivityRepository {
  RoomActivityRepository({
    required this.ownPubkey,
    required List<RoomActivityChannel> channels,
    int Function()? now,
  }) : _now = now ?? _currentTime {
    for (final channel in channels) {
      if (_sources.containsKey(channel.channelId)) {
        throw ArgumentError.value(channel.channelId, 'channels', 'Duplicate');
      }
      _sources[channel.channelId] = _ActivitySource(channel);
      _summaries[channel.channelId] = RoomActivitySummary(
        channelId: channel.channelId,
      );
    }
  }

  final String ownPubkey;
  final int Function() _now;
  final _sources = <String, _ActivitySource>{};
  final _summaries = <String, RoomActivitySummary>{};
  final _changes = StreamController<void>.broadcast();
  Timer? _activityTimer;
  bool _closed = false;
  Future<void>? _closing;

  static int _currentTime() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Map<String, RoomActivitySummary> get summaries =>
      Map.unmodifiable(_summaries);
  Stream<void> get changes => _changes.stream;

  ConcordRepository repositoryFor(String channelId) =>
      _source(channelId).channel.repository;

  _ActivitySource _source(String channelId) =>
      _sources[channelId] ??
      (throw ArgumentError.value(channelId, 'channelId', 'Unknown room'));

  void _notify() {
    if (!_closed) _changes.add(null);
  }

  /// Starts independent rooms; a failed room remains individually retryable.
  Future<void> start() async {
    if (_closed) throw StateError('Room activity is closed');
    await Future.wait<void>([
      for (final id in _sources.keys)
        ensureStarted(id).catchError((Object _) {
          // ensureStarted records the failure on this room's summary.
        }),
    ]);
  }

  /// Concurrent callers share the same restoration and relay subscription.
  Future<void> ensureStarted(String channelId) {
    if (_closed) return Future.error(StateError('Room activity is closed'));
    final source = _source(channelId);
    if (source.started) return Future.value();
    final starting = source.starting;
    if (starting != null) return starting;
    _activityTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      _sources.values
          .where((source) => source.started)
          .forEach(_refreshInBackground);
    });
    return source.starting = _initialize(source).whenComplete(() {
      source.starting = null;
    });
  }

  Future<void> _initialize(_ActivitySource source) async {
    source
      ..loading = true
      ..loadFailed = false;
    _publish(source);
    source.subscription ??= source.channel.repository.changes.listen(
      (_) => _refreshInBackground(source),
      onError: (Object error, StackTrace stack) => _failed(source),
    );
    try {
      final saved = await source.channel.store.get(source.readKey);
      if (_closed) return;
      final readIds = saved == null
          ? <String>{}
          : (jsonDecode(saved) as List).cast<String>().toSet();
      source.readIds = readIds;
      await source.channel.repository.startChannel(
        channelId: source.channel.channelId,
        epoch: 0,
        streamSeedHex: source.channel.streamSeedHex,
        streamPubkey: source.channel.streamPubkey,
        now: _now,
      );
      await source.channel.repository.waitForHistory();
      if (_closed) return;
      if (source.loadFailed) {
        throw StateError('Room history could not be loaded');
      }
      source
        ..started = true
        ..loading = false;
      await _refresh(source);
    } on Object {
      _failed(source);
      rethrow;
    }
  }

  void _failed(_ActivitySource source) {
    if (_closed) return;
    source
      ..started = false
      ..loading = false
      ..loadFailed = true;
    _publish(source);
  }

  void _refreshInBackground(_ActivitySource source) {
    if (_closed) return;
    unawaited(
      _refresh(source).catchError((Object _) {
        _failed(source);
      }),
    );
  }

  Future<void> _refresh(_ActivitySource source) async {
    final saved = await source.channel.store.get('sealed:index');
    if (_closed) return;
    final pending = source.channel.repository.pendingIds.toSet();
    final retainedWraps = saved == null
        ? 0
        : (jsonDecode(saved) as List)
              .cast<String>()
              .where((id) => !pending.contains(id))
              .length;
    final relay = source.channel.repository.relay;
    final wireLimited = switch (relay) {
      final RelayHistoryStatus status => status.historyLimited,
      _ => false,
    };
    if (wireLimited ||
        retainedWraps >= source.channel.repository.historyLimit) {
      source.historyLimited = true;
    }
    _publish(source);
  }

  void _publish(_ActivitySource source) {
    if (_closed) return;
    final now = _now();
    final pending = source.channel.repository.pendingIds.toSet();
    final messages = source.channel.repository
        .timeline(now: now)
        .messages
        .where(
          (message) =>
              message.channelId == source.channel.channelId &&
              !pending.contains(message.id),
        )
        .toList();
    final recent = messages.where(
      (message) => message.createdAt >= now - 86400,
    );
    final recentMessages = recent.toList();
    final authors = <String>{
      for (final message in recentMessages.reversed) message.author,
    };
    _summaries[source.channel.channelId] = RoomActivitySummary(
      channelId: source.channel.channelId,
      latestMessage: messages.lastOrNull,
      unreadCount: messages
          .where(
            (message) =>
                message.author != ownPubkey &&
                !source.readIds.contains(message.id),
          )
          .length,
      recentMessageCount: recentMessages.length,
      recentAuthors: List.unmodifiable(authors),
      historyLimited: source.historyLimited,
      loading: source.loading,
      loadFailed: source.loadFailed,
    );
    _notify();
  }

  /// Acknowledges only the rendered message snapshot after durable storage.
  Future<void> markRead(
    String channelId,
    Iterable<ChatMessage> messages,
  ) async {
    final source = _source(channelId);
    final ids = {
      for (final message in messages)
        if (message.channelId == channelId && message.author != ownPubkey)
          message.id,
    };
    await ensureStarted(channelId);
    if (_closed) return;
    final writing = source.writes.then((_) async {
      if (_closed) return;
      final pending = source.channel.repository.pendingIds.toSet();
      final updated = {...source.readIds, ...ids.difference(pending)};
      if (updated.length == source.readIds.length) return;
      await source.channel.store.put(
        source.readKey,
        jsonEncode(updated.toList()),
      );
      if (_closed) return;
      source.readIds = updated;
      _publish(source);
    });
    source.writes = writing.catchError((Object _) {});
    await writing;
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _activityTimer?.cancel();
    await Future.wait<void>([
      for (final source in _sources.values) _closeSource(source),
    ]);
    await _changes.close();
  }

  Future<void> _closeSource(_ActivitySource source) async {
    // Stop the encrypted writer and relay listener immediately, even while
    // an independent read-receipt write is still awaiting persistence.
    final closing = source.channel.repository.close();
    final subscription = source.subscription;
    await Future.wait<void>([
      closing,
      if (subscription != null) subscription.cancel(),
      source.writes,
    ]);
  }
}

class _ActivitySource {
  _ActivitySource(this.channel);

  final RoomActivityChannel channel;
  // Reserved metadata namespace, separate from all encrypted record keys.
  String get readKey => 'room-activity:v1:read:${channel.channelId}';
  Set<String> readIds = {};
  bool started = false;
  bool loading = true;
  bool loadFailed = false;
  bool historyLimited = false;
  Future<void>? starting;
  Future<void> writes = Future.value();
  // Owned here and cancelled by RoomActivityRepository._closeSource.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? subscription;
}
