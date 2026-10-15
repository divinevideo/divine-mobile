import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';

/// Persistence scoped to one authenticated account by the caller.
abstract interface class HashtagSubscriptionStore {
  /// Reads the last confirmed subscription list.
  Future<String?> read();

  /// Saves the complete list, throwing when persistence fails.
  Future<void> write(String value);
}

/// A followed hashtag with its original display spelling.
class HashtagSubscription extends Equatable {
  /// Parses a hashtag without losing non-Latin characters.
  factory HashtagSubscription.fromTag(String tag) {
    var display = tag.trim();
    if (display.startsWith('#')) display = display.substring(1);
    if (!isValid(tag)) {
      throw ArgumentError.value(tag, 'tag', 'Invalid hashtag');
    }
    return HashtagSubscription._(display.toLowerCase(), display);
  }

  const HashtagSubscription._(this.canonicalTag, this.displayTag);

  /// Whether [tag] names a single nonempty hashtag.
  static bool isValid(String tag) {
    var display = tag.trim();
    if (display.startsWith('#')) display = display.substring(1);
    return display.isNotEmpty && !RegExp(r'[\s#]').hasMatch(display);
  }

  /// Case-insensitive membership key, without a leading #.
  final String canonicalTag;

  /// Spelling used when the tag was first followed.
  final String displayTag;

  @override
  List<Object> get props => [canonicalTag, displayTag];
}

/// Expected cancellation when an account-scoped repository is torn down.
class HashtagSubscriptionRepositoryDisposedException implements Exception {
  /// Creates a repository cancellation.
  const HashtagSubscriptionRepositoryDisposedException();
}

/// Owns confirmed follows; failed reads or writes never replace stored data.
class HashtagSubscriptionRepository {
  /// Creates a repository with account-scoped persistence.
  HashtagSubscriptionRepository({required HashtagSubscriptionStore store})
    : _store = store;

  final HashtagSubscriptionStore _store;
  final _subject = BehaviorSubject<List<HashtagSubscription>>.seeded(const []);
  Future<void> _queue = Future<void>.value();
  Future<void>? _initializing;
  bool _initialized = false;
  bool _disposed = false;

  /// Immutable confirmed follows, sorted by canonical tag.
  List<HashtagSubscription> get subscriptions => _subject.value;

  /// Replays the latest confirmed follows to every subscriber.
  Stream<List<HashtagSubscription>> get subscriptionsStream => _subject.stream;

  /// Loads follows before any mutation. A failed read can be retried.
  Future<void> initialize() {
    if (_disposed) {
      return Future.error(
        const HashtagSubscriptionRepositoryDisposedException(),
      );
    }
    if (_initialized) return Future.value();
    return _initializing ??= _load().whenComplete(() => _initializing = null);
  }

  Future<void> _load() async {
    final raw = await _store.read();
    final tags = <String, HashtagSubscription>{};
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((value) => value is! String)) {
        throw const FormatException('Invalid saved hashtag list');
      }
      for (final value in decoded.cast<String>()) {
        if (!HashtagSubscription.isValid(value)) {
          throw const FormatException('Invalid saved hashtag');
        }
        final tag = HashtagSubscription.fromTag(value);
        tags.putIfAbsent(tag.canonicalTag, () => tag);
      }
    }
    if (_disposed) throw const HashtagSubscriptionRepositoryDisposedException();
    _subject.add(_sorted(tags.values));
    _initialized = true;
  }

  /// Follows [tag] after a durable write. Duplicate follows are safe.
  Future<void> follow(String tag) => _mutate(tag, follow: true);

  /// Removes [tag] after a successful durable write.
  Future<void> unfollow(String tag) => _mutate(tag, follow: false);

  Future<void> _mutate(String value, {required bool follow}) {
    final operation = _queue.then((_) async {
      if (_disposed) {
        throw const HashtagSubscriptionRepositoryDisposedException();
      }
      final tag = HashtagSubscription.fromTag(value);
      await initialize();
      if (_disposed) {
        throw const HashtagSubscriptionRepositoryDisposedException();
      }
      final tags = {for (final tag in subscriptions) tag.canonicalTag: tag};
      if (follow) {
        if (tags.containsKey(tag.canonicalTag)) return;
        tags[tag.canonicalTag] = tag;
      } else {
        if (tags.remove(tag.canonicalTag) == null) return;
      }
      final next = _sorted(tags.values);
      await _store.write(
        jsonEncode(next.map((tag) => tag.displayTag).toList()),
      );
      if (!_disposed) _subject.add(next);
    });
    // Keep a failed mutation from poisoning subsequent queued operations.
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  List<HashtagSubscription> _sorted(Iterable<HashtagSubscription> tags) =>
      List.unmodifiable(
        tags.toList()..sort(
          (a, b) => a.canonicalTag.compareTo(b.canonicalTag),
        ),
      );

  /// Ends observation. In-flight writes still belong to the injected account.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subject.close();
  }
}
