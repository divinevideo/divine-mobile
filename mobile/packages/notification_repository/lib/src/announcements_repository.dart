import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:models/notification_item.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:rxdart/rxdart.dart';

/// Account-bound persistence supplied by the application.
abstract interface class AnnouncementStore {
  /// Reads the repository's opaque catalog cache envelope.
  Future<String?> readCatalog();

  /// Stores the repository's opaque catalog cache envelope.
  Future<void> writeCatalog(String value);

  /// Reads namespaced announcement IDs seen by this account.
  Future<List<String>> readSeen();

  /// Replaces this account's namespaced seen IDs.
  Future<void> writeSeen(List<String> ids);
}

/// Fetches the fixed public Divine catalog and applies local eligibility.
///
/// The injected client must be dedicated to this public, anonymous endpoint.
/// This repository owns and closes that client.
class AnnouncementsRepository {
  /// Creates an account-bound repository without reading storage or fetching.
  AnnouncementsRepository({
    required http.Client httpClient,
    required AnnouncementStore store,
    required String platform,
    required String appVersion,
    Clock clock = const Clock(),
    Duration requestTimeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient,
       _store = store,
       _platform = platform,
       _appVersion = _version(appVersion),
       _clock = clock,
       _requestTimeout = requestTimeout;

  static final Uri _endpoint = Uri.https(
    'announcements.divine.video',
    '/v1/announcements',
  );
  static const int _maximumBytes = 512 * 1024;
  static const _maximumItems = 50;
  static const _platforms = {
    'android',
    'ios',
    'macos',
    'windows',
    'linux',
    'web',
  };
  static final _uuid = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _marketingVersion = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
  );
  static final _utcDate = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
    r'(?:\.(\d{1,6}))?Z$',
  );

  final http.Client _httpClient;
  final AnnouncementStore _store;
  final String _platform;
  final Version? _appVersion;
  final Clock _clock;
  final Duration _requestTimeout;
  final _snapshots = BehaviorSubject<List<AnnouncementNotification>>.seeded(
    const [],
  );
  List<AnnouncementNotification>? _catalog;
  Map<String, Object?>? _catalogJson;
  String? _etag;
  Set<String> _seen = {};
  Future<void>? _initialization;
  Future<void>? _refresh;
  Future<void> _writes = Future.value();
  Future<void>? _closeFuture;
  Timer? _eligibilityTimer;
  bool _closed = false;

  /// Current eligible announcements, newest first, with local seen state.
  ///
  /// Eligibility is recalculated so cached rows cannot outlive their expiry.
  List<AnnouncementNotification> get items {
    if (_closed) return const [];
    final now = _clock.now().toUtc();
    final eligible =
        (_catalog ?? const <AnnouncementNotification>[])
            .where(
              (item) =>
                  !item.timestamp.isAfter(now) &&
                  item.expiresAt.isAfter(now) &&
                  (item.platforms.isEmpty ||
                      item.platforms.contains(_platform)) &&
                  (item.minimumAppVersion == null ||
                      (_appVersion != null &&
                          _appVersion >= _version(item.minimumAppVersion!)!)),
            )
            .map((item) => item.copyWith(isRead: _seen.contains(item.id)))
            .toList()
          ..sort((a, b) {
            final byDate = b.timestamp.compareTo(a.timestamp);
            return byDate == 0 ? a.id.compareTo(b.id) : byDate;
          });
    return List.unmodifiable(eligible);
  }

  /// Current snapshot, updated at publication and expiry without a fetch.
  /// Seeded with an empty list before initialization.
  Stream<List<AnnouncementNotification>> watchSnapshot() => _snapshots.stream;

  /// Hydrates cache and account seen state without automatically fetching.
  Future<void> initialize() {
    if (_closed) return Future.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    String? cached;
    var seen = const <String>[];
    try {
      cached = await _store.readCatalog();
    } on Exception {
      // Storage is optional: a public refresh can recover the catalog.
    }
    if (_closed) return;
    try {
      seen = await _store.readSeen();
    } on Exception {
      // Missing local seen state is equivalent to a fresh installation.
    }
    if (_closed) return;
    if (cached != null && utf8.encode(cached).length <= _maximumBytes + 4096) {
      try {
        final envelope = _object(jsonDecode(cached));
        if (envelope['source'] != _endpoint.toString() ||
            envelope['cacheVersion'] != 1) {
          throw const FormatException('Unsupported announcement cache');
        }
        final catalog = _object(envelope['catalog']);
        if (utf8.encode(jsonEncode(catalog)).length > _maximumBytes) {
          throw const FormatException('Cached catalog too large');
        }
        final parsed = _decodeCatalog(catalog);
        _etag = _validatedEtag(envelope['etag']);
        _catalog = parsed;
        _catalogJson = catalog;
      } on FormatException {
        // Only completely validated cached snapshots may be displayed.
      }
    }
    _seen = seen.toSet();
    _pruneSeen();
    _emit();
  }

  /// Fetches a complete snapshot; failures retain the last valid catalog.
  /// Concurrent refreshes share the same request.
  Future<void> refresh() {
    if (_closed) return Future.value();
    return _refresh ??= _refreshCatalog().whenComplete(() => _refresh = null);
  }

  Future<void> _refreshCatalog() async {
    await initialize();
    if (_closed) return;
    try {
      final fetched = await _fetch();
      if (_closed) return;
      if (fetched != null) {
        _catalog = _decodeCatalog(fetched.catalog);
        _catalogJson = fetched.catalog;
        _etag = fetched.etag;
        _pruneSeen();
        final encoded = jsonEncode({
          'cacheVersion': 1,
          'source': _endpoint.toString(),
          'etag': _etag,
          'catalog': _catalogJson,
        });
        final seen = List<String>.unmodifiable(_seen);
        await _persist(() async {
          await _store.writeCatalog(encoded);
          await _store.writeSeen(seen);
        });
      }
    } on Exception {
      // Network, schema, and storage failures never erase valid cached rows.
    }
    _emit();
  }

  Future<_FetchedCatalog?> _fetch() async {
    StreamSubscription<List<int>>? subscription;
    var abandoned = false;
    final operation = () async {
      final request = http.Request('GET', _endpoint)
        ..followRedirects = false
        ..headers['accept'] = 'application/json';
      if (_etag != null && _catalog != null) {
        request.headers['if-none-match'] = _etag!;
      }
      final response = await _httpClient.send(request);
      if (abandoned || _closed) {
        unawaited(response.stream.listen(null).cancel());
        return null;
      }
      final responseUrl = response.request?.url;
      if (responseUrl != null && responseUrl != _endpoint) {
        unawaited(response.stream.listen(null).cancel());
        throw const FormatException('Unexpected catalog source');
      }
      if (response.statusCode == 304 && _catalog != null) {
        unawaited(response.stream.listen(null).cancel());
        return null;
      }
      final contentType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (response.statusCode != 200 ||
          contentType != 'application/json' ||
          (response.contentLength ?? 0) > _maximumBytes) {
        unawaited(response.stream.listen(null).cancel());
        throw const FormatException('Unavailable catalog response');
      }
      final bytes = <int>[];
      final completed = Completer<void>();
      subscription = response.stream.listen(
        (chunk) {
          if (completed.isCompleted) return;
          if (bytes.length + chunk.length > _maximumBytes) {
            completed.completeError(const FormatException('Catalog too large'));
            return;
          }
          bytes.addAll(chunk);
        },
        onError: (Object error, StackTrace stack) {
          if (!completed.isCompleted) completed.completeError(error, stack);
        },
        onDone: () {
          if (!completed.isCompleted) completed.complete();
        },
      );
      await completed.future;
      return _FetchedCatalog(
        _object(jsonDecode(utf8.decode(bytes))),
        _validatedEtag(response.headers['etag']),
      );
    }();
    try {
      return await operation.timeout(_requestTimeout);
    } finally {
      abandoned = true;
      unawaited(subscription?.cancel());
    }
  }

  /// Marks only the named rows from an applied snapshot as seen.
  Future<void> markSeen(Iterable<String> namespacedIds) async {
    await initialize();
    if (_closed) return;
    final retainedIds = (_catalog ?? const <AnnouncementNotification>[])
        .map((item) => item.id)
        .toSet();
    final previous = _seen.length;
    _seen.addAll(namespacedIds.where(retainedIds.contains));
    _pruneSeen();
    _emit();
    if (_seen.length == previous) return;
    final seen = List<String>.unmodifiable(_seen);
    await _persist(() => _store.writeSeen(seen));
  }

  void _pruneSeen() {
    final catalog = _catalog;
    if (catalog != null) {
      final retainedIds = catalog.map((item) => item.id).toSet();
      _seen = _seen.intersection(retainedIds);
      return;
    }
    // A missing or unreadable catalog cannot prove an ID was withdrawn.
    _seen = _seen
        .where(
          (id) =>
              id.startsWith('announcement:') &&
              _uuid.hasMatch(id.substring('announcement:'.length)),
        )
        .take(_maximumItems)
        .toSet();
  }

  Future<void> _persist(Future<void> Function() write) {
    if (_closed) return Future.value();
    return _writes = _writes.then((_) => write()).onError((_, _) {
      // Persistence is best-effort; queued writes continue after one failure.
    });
  }

  void _emit() {
    if (_closed) return;
    _eligibilityTimer?.cancel();
    _eligibilityTimer = null;
    final now = _clock.now().toUtc();
    DateTime? nextBoundary;
    for (final item in _catalog ?? const <AnnouncementNotification>[]) {
      for (final boundary in [item.timestamp, item.expiresAt]) {
        if (boundary.isAfter(now) &&
            (nextBoundary == null || boundary.isBefore(nextBoundary))) {
          nextBoundary = boundary;
        }
      }
    }
    if (nextBoundary != null) {
      final remaining = nextBoundary.difference(now);
      // Browser timers overflow for long catalog lifetimes; recheck daily.
      const maximumDelay = Duration(days: 1);
      _eligibilityTimer = Timer(
        remaining > maximumDelay ? maximumDelay : remaining,
        _emit,
      );
    }
    _snapshots.add(items);
  }

  /// Stops new work immediately and drains writes before cleanup may proceed.
  /// Repeated calls return the same close future, including during teardown.
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closed = true;
    _eligibilityTimer?.cancel();
    _eligibilityTimer = null;
    _httpClient.close();
    return _closeFuture = () async {
      await _writes;
      await _snapshots.close();
    }();
  }

  static List<AnnouncementNotification> _decodeCatalog(
    Map<String, Object?> catalog,
  ) {
    if (catalog['schemaVersion'] is! int || catalog['schemaVersion'] != 1) {
      throw const FormatException('Unsupported catalog schema');
    }
    final entries = catalog['announcements'];
    if (entries is! List || entries.length > _maximumItems) {
      throw const FormatException('Invalid catalog entries');
    }
    final ids = <String>{};
    final result = <AnnouncementNotification>[];
    for (final entry in entries) {
      final value = _object(entry);
      final id = value['id'];
      if (id is! String || !_uuid.hasMatch(id) || !ids.add(id.toLowerCase())) {
        throw const FormatException('Invalid announcement identity');
      }
      final title = _text(value['title'], 120);
      final body = _text(value['body'], 8000);
      final published = _date(value['publishedAt']);
      final expires = _date(value['expiresAt']);
      if (!expires.isAfter(published) ||
          expires.difference(published) > const Duration(days: 90)) {
        throw const FormatException('Invalid announcement expiry');
      }
      final platforms = value['platforms'];
      if (platforms is! List ||
          platforms.any(
            (item) => item is! String || !_platforms.contains(item),
          ) ||
          platforms.toSet().length != platforms.length) {
        throw const FormatException('Invalid announcement platforms');
      }
      final minimumVersion = value['minimumAppVersion'];
      if (minimumVersion != null &&
          (minimumVersion is! String || _version(minimumVersion) == null)) {
        throw const FormatException('Invalid announcement minimum version');
      }
      final url = value['learnMoreUrl'];
      Uri? learnMore;
      if (url != null) {
        if (url is! String || url.length > 2048) {
          throw const FormatException('Invalid announcement URL');
        }
        learnMore = Uri.tryParse(url);
        if (learnMore == null ||
            learnMore.scheme != 'https' ||
            !const {
              'divine.video',
              'about.divine.video',
            }.contains(learnMore.host) ||
            learnMore.userInfo.isNotEmpty ||
            learnMore.port != 443) {
          throw const FormatException('Invalid announcement URL');
        }
      }
      result.add(
        AnnouncementNotification(
          announcementId: id,
          title: title,
          body: body,
          timestamp: published,
          expiresAt: expires,
          platforms: platforms.cast<String>(),
          minimumAppVersion: minimumVersion as String?,
          learnMoreUrl: learnMore,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static Map<String, Object?> _object(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Expected an announcement object');
    }
    return value;
  }

  static String _text(Object? value, int maximum) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.trim().runes.length > maximum) {
      throw const FormatException('Invalid announcement text');
    }
    return value.trim();
  }

  static DateTime _date(Object? value) {
    if (value is! String) throw const FormatException('Invalid date');
    final match = _utcDate.firstMatch(value);
    final date = DateTime.tryParse(value);
    if (match == null ||
        date == null ||
        date.year < 2000 ||
        date.year > 2100 ||
        date.year != int.parse(match[1]!) ||
        date.month != int.parse(match[2]!) ||
        date.day != int.parse(match[3]!) ||
        date.hour != int.parse(match[4]!) ||
        date.minute != int.parse(match[5]!) ||
        date.second != int.parse(match[6]!)) {
      throw const FormatException('Invalid date');
    }
    return date;
  }

  static Version? _version(String value) {
    if (!_marketingVersion.hasMatch(value)) return null;
    return Version.parse(value);
  }

  static String? _validatedEtag(Object? value) {
    if (value == null) return null;
    if (value is! String ||
        value.length > 512 ||
        !RegExp(r'^(W/)?"[\x21\x23-\x7E]*"$').hasMatch(value)) {
      throw const FormatException('Invalid catalog ETag');
    }
    return value;
  }
}

class _FetchedCatalog {
  _FetchedCatalog(this.catalog, this.etag);
  final Map<String, Object?> catalog;
  final String? etag;
}
