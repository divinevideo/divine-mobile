// ABOUTME: Service for tracking which videos have been viewed by the user with engagement metrics
// ABOUTME: Stores view history with timestamps, loop counts, and watch duration for smart feed ordering
// ABOUTME: Split storage: seen set (id+lastSeen) in Drift seen_videos table (unbounded, ~1yr TTL),
// ABOUTME: rich metrics (loops/durations) stay bounded in SharedPreferences JSON (1000).

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Engagement metrics for a seen video
class SeenVideoMetrics {
  SeenVideoMetrics({
    required this.videoId,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.loopCount = 0,
    this.totalWatchDuration = Duration.zero,
    this.lastWatchDuration = Duration.zero,
  });

  final String videoId;
  final DateTime firstSeenAt;
  DateTime lastSeenAt;
  int loopCount;
  Duration totalWatchDuration;
  Duration lastWatchDuration;

  void updateSession({
    required DateTime timestamp,
    int? loops,
    Duration? watchDuration,
  }) {
    lastSeenAt = timestamp;
    if (loops != null) loopCount += loops;
    if (watchDuration != null) {
      lastWatchDuration = watchDuration;
      totalWatchDuration += watchDuration;
    }
  }

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'firstSeenAt': firstSeenAt.millisecondsSinceEpoch,
    'lastSeenAt': lastSeenAt.millisecondsSinceEpoch,
    'loopCount': loopCount,
    'totalWatchDurationMs': totalWatchDuration.inMilliseconds,
    'lastWatchDurationMs': lastWatchDuration.inMilliseconds,
  };

  factory SeenVideoMetrics.fromJson(Map<String, dynamic> json) =>
      SeenVideoMetrics(
        videoId: json['videoId'] as String,
        firstSeenAt: DateTime.fromMillisecondsSinceEpoch(
          json['firstSeenAt'] as int,
        ),
        lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
          json['lastSeenAt'] as int,
        ),
        loopCount: json['loopCount'] as int? ?? 0,
        totalWatchDuration: Duration(
          milliseconds: json['totalWatchDurationMs'] as int? ?? 0,
        ),
        lastWatchDuration: Duration(
          milliseconds: json['lastWatchDurationMs'] as int? ?? 0,
        ),
      );
}

/// Service for tracking seen videos with engagement metrics.
///
/// Storage split (fixes 1000-cap truncation for heavy viewers — p90 6,458/30d):
/// * Seen set (id + lastSeen) → Drift `seen_videos` table, unbounded (~1yr TTL),
///   indexed on `videoId`/`lastSeenAt`. Reads via DAO, writes batched.
/// * Rich metrics (loops, watch durations) → bounded SharedPreferences JSON
///   (`seen_video_metrics`, 1000 most recent). Keeps existing ANR-safe size.
///
/// Migration: on first init with a DB available, existing SharedPreferences
/// JSON is bulk-inserted into `seen_videos` (idempotent), then retained.
/// When no DB is present (tests, early startup), falls back to pure
/// SharedPreferences in-memory set so tests stay hermetic without a Drift
/// instance.
class SeenVideosService {
  SeenVideosService({
    @visibleForTesting Duration? saveDebounceDuration,
    AppDatabase? database,
    @visibleForTesting SharedPreferences? prefsOverride,
  }) : _saveDebounceDuration =
           saveDebounceDuration ?? const Duration(milliseconds: 100),
       _database = database,
       _prefsOverride = prefsOverride;

  /// Legacy id-only list, read once and removed after migrating to metrics.
  ///
  /// Still present on installs that have not launched since the metrics
  /// format landed, so account cleanup must keep clearing it.
  static const String legacySeenVideosStorageKey = 'seen_video_ids';

  /// Current seen-video metrics, rewritten on every debounced save.
  static const String seenVideosMetricsStorageKey = 'seen_video_metrics';

  /// Gates the one-time copy of [seenVideosMetricsStorageKey] into Drift.
  ///
  /// Cleared with the data it gates: left set while the metrics and the Drift
  /// rows are wiped, it would tell the next account's first launch that a
  /// migration it never ran had already happened.
  static const String seenVideosMigratedStorageKey =
      'seen_videos_migrated_to_db';
  static const int _maxSeenVideos = 1000;

  final Map<String, SeenVideoMetrics> _seenVideos = {};
  final Map<String, DateTime> _seenLastSeen = {};
  final Duration _saveDebounceDuration;
  final AppDatabase? _database;
  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  Future<void>? _initializeFuture;
  Timer? _saveDebounceTimer;
  Completer<void>? _pendingSaveCompleter;

  bool get isInitialized => _isInitialized;
  int get seenVideoCount => _seenLastSeen.length;
  AppDatabase? get _effectiveDb => _database;

  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    final pending = _initializeFuture;
    if (pending != null) return pending;
    final future = _initialize();
    _initializeFuture = future;
    return future;
  }

  Future<void> _initialize() async {
    try {
      _prefs = _prefsOverride ?? await SharedPreferences.getInstance();
      await _loadSeenVideos();
      if (_effectiveDb != null) {
        unawaited(
          _effectiveDb!.seenVideosDao.pruneExpired().then<void>(
            (_) {},
            onError: (Object e, StackTrace s) {},
          ),
        );
      }
      _isInitialized = true;
      Log.info(
        '📱️ SeenVideosService initialized with ${_seenLastSeen.length} seen videos (${_seenVideos.length} with metrics)',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize SeenVideosService: $e',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    } finally {
      if (!_isInitialized) _initializeFuture = null;
    }
  }

  Future<void> _loadSeenVideos() async {
    if (_prefs == null) return;
    try {
      final metricsJson = _prefs!.getString(seenVideosMetricsStorageKey);
      if (metricsJson != null) {
        final metricsList = jsonDecode(metricsJson) as List<dynamic>;
        _seenVideos.clear();
        _seenLastSeen.clear();
        for (final json in metricsList) {
          final metrics = SeenVideoMetrics.fromJson(
            json as Map<String, dynamic>,
          );
          _seenVideos[metrics.videoId] = metrics;
          _seenLastSeen[metrics.videoId] = metrics.lastSeenAt;
        }
        Log.debug(
          '📱 Loaded ${_seenVideos.length} seen videos with metrics',
          name: 'SeenVideosService',
          category: LogCategory.system,
        );
      } else {
        final legacyList = _prefs!.getStringList(legacySeenVideosStorageKey);
        if (legacyList != null && legacyList.isNotEmpty) {
          _seenVideos.clear();
          _seenLastSeen.clear();
          final now = DateTime.now();
          for (final videoId in legacyList) {
            _seenVideos[videoId] = SeenVideoMetrics(
              videoId: videoId,
              firstSeenAt: now,
              lastSeenAt: now,
            );
            _seenLastSeen[videoId] = now;
          }
          Log.info(
            '📱 Migrated ${_seenVideos.length} videos from legacy format',
            name: 'SeenVideosService',
            category: LogCategory.system,
          );
          await _saveSeenVideosNow();
          await _prefs!.remove(legacySeenVideosStorageKey);
        }
      }
      if (_effectiveDb != null) {
        try {
          final dbRows = await _effectiveDb!.seenVideosDao.getAll();
          for (final row in dbRows) {
            final lastSeen = DateTime.fromMillisecondsSinceEpoch(
              row.lastSeenAt,
            );
            final existing = _seenLastSeen[row.videoId];
            if (existing == null || lastSeen.isAfter(existing)) {
              _seenLastSeen[row.videoId] = lastSeen;
            }
          }
          final migrated =
              _prefs!.getBool(seenVideosMigratedStorageKey) ?? false;
          if (!migrated && dbRows.isEmpty && _seenVideos.isNotEmpty) {
            await _migrateMetricsToDb();
            await _prefs!.setBool(seenVideosMigratedStorageKey, true);
          } else if (dbRows.isNotEmpty && !migrated) {
            await _prefs!.setBool(seenVideosMigratedStorageKey, true);
          }
          Log.debug(
            '📱 Seen DB hydrated: ${dbRows.length} rows, merged to ${_seenLastSeen.length} total',
            name: 'SeenVideosService',
            category: LogCategory.system,
          );
        } catch (e) {
          Log.warning(
            'Seen DB hydrate failed, using prefs set: $e',
            name: 'SeenVideosService',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Error loading seen videos: $e',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _migrateMetricsToDb() async {
    final db = _effectiveDb;
    if (db == null || _seenVideos.isEmpty) return;
    try {
      final rows = _seenVideos.values
          .map(
            (m) => SeenVideoRow(
              videoId: m.videoId,
              firstSeenAt: m.firstSeenAt.millisecondsSinceEpoch,
              lastSeenAt: m.lastSeenAt.millisecondsSinceEpoch,
            ),
          )
          .toList();
      await db.seenVideosDao.markSeenBatch(rows);
      Log.info(
        '📱 Migrated ${rows.length} seen ids to Drift',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        'Seen DB migration failed: $e',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _saveSeenVideosNow() async {
    if (_prefs == null) return;
    try {
      final sortedVideos = _seenVideos.values.toList()
        ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
      final videosToSave = sortedVideos.length > _maxSeenVideos
          ? sortedVideos.sublist(0, _maxSeenVideos)
          : sortedVideos;
      if (videosToSave.length < _seenVideos.length) {
        _seenVideos.clear();
        for (final metrics in videosToSave) {
          _seenVideos[metrics.videoId] = metrics;
        }
      }
      final metricsList = videosToSave.map((m) => m.toJson()).toList();
      await _prefs!.setString(
        seenVideosMetricsStorageKey,
        jsonEncode(metricsList),
      );
      Log.debug(
        '📱 Saved ${videosToSave.length} seen videos with metrics (seen set: ${_seenLastSeen.length})',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving seen videos: $e',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _scheduleSeenVideosSave() {
    if (_prefs == null) return Future.value();
    _saveDebounceTimer?.cancel();
    final completer = _pendingSaveCompleter ??= Completer<void>();
    _saveDebounceTimer = Timer(
      _saveDebounceDuration,
      () => unawaited(_flushPendingSeenVideosSave()),
    );
    return completer.future;
  }

  Future<void> _flushPendingSeenVideosSave() async {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
    final completer = _pendingSaveCompleter;
    if (completer == null) return;
    _pendingSaveCompleter = null;
    try {
      await _saveSeenVideosNow();
      if (!completer.isCompleted) completer.complete();
    } catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
  }

  bool hasSeenVideo(String videoId) => _seenLastSeen.containsKey(videoId);
  Set<String> getSeenVideoIds() => _seenLastSeen.keys.toSet();
  SeenVideoMetrics? getVideoMetrics(String videoId) => _seenVideos[videoId];
  Future<void> markVideoAsSeen(String videoId) async =>
      recordVideoView(videoId);

  Future<void> recordVideoView(
    String videoId, {
    int? loopCount,
    Duration? watchDuration,
  }) async {
    final now = DateTime.now();
    final existing = _seenVideos[videoId];
    if (existing != null) {
      existing.updateSession(
        timestamp: now,
        loops: loopCount,
        watchDuration: watchDuration,
      );
      Log.debug(
        '📱 Updated video metrics: $videoId (loops: ${existing.loopCount}, watch: ${existing.totalWatchDuration.inSeconds}s)',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    } else {
      _seenVideos[videoId] = SeenVideoMetrics(
        videoId: videoId,
        firstSeenAt: now,
        lastSeenAt: now,
        loopCount: loopCount ?? 0,
        totalWatchDuration: watchDuration ?? Duration.zero,
        lastWatchDuration: watchDuration ?? Duration.zero,
      );
      Log.debug(
        '📱️ Marking video as seen: $videoId',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
    _seenLastSeen[videoId] = now;
    await Future.wait([
      _persistSeenVideo(
        videoId,
        firstSeenAt: _seenVideos[videoId]!.firstSeenAt.millisecondsSinceEpoch,
        lastSeenAt: now.millisecondsSinceEpoch,
      ),
      _scheduleSeenVideosSave(),
    ]);
  }

  Future<void> markVideosAsSeen(List<String> videoIds) async {
    var hasChanges = false;
    final now = DateTime.now();
    for (final videoId in videoIds) {
      if (!_seenLastSeen.containsKey(videoId)) {
        _seenLastSeen[videoId] = now;
        _seenVideos.putIfAbsent(
          videoId,
          () => SeenVideoMetrics(
            videoId: videoId,
            firstSeenAt: now,
            lastSeenAt: now,
          ),
        );
        hasChanges = true;
      } else if (!_seenVideos.containsKey(videoId)) {
        _seenVideos[videoId] = SeenVideoMetrics(
          videoId: videoId,
          firstSeenAt: _seenLastSeen[videoId]!,
          lastSeenAt: now,
        );
        _seenLastSeen[videoId] = now;
        hasChanges = true;
      }
    }
    if (hasChanges) {
      await Future.wait([
        _persistSeenVideos(videoIds, nowMs: now.millisecondsSinceEpoch),
        _scheduleSeenVideosSave(),
      ]);
    }
  }

  Future<void> _persistSeenVideo(
    String videoId, {
    required int firstSeenAt,
    required int lastSeenAt,
  }) async {
    final database = _effectiveDb;
    if (database == null) return;
    try {
      await database.seenVideosDao.markSeen(
        videoId,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt,
      );
    } catch (error) {
      Log.warning(
        'Seen DB write failed; preferences remain available: $error',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _persistSeenVideos(
    Iterable<String> videoIds, {
    required int nowMs,
  }) async {
    final database = _effectiveDb;
    if (database == null) return;
    try {
      await database.seenVideosDao.upsertBatch(videoIds, nowMs: nowMs);
    } catch (error) {
      Log.warning(
        'Seen DB batch write failed; preferences remain available: $error',
        name: 'SeenVideosService',
        category: LogCategory.system,
      );
    }
  }

  List<SeenVideoMetrics> getVideosByRecency({int? limit}) {
    final sorted = _seenVideos.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    return limit != null && limit < sorted.length
        ? sorted.sublist(0, limit)
        : sorted;
  }

  List<String> getVideosNotSeenSince(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _seenLastSeen.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
  }

  bool wasSeenRecently(
    String videoId, {
    Duration within = const Duration(hours: 24),
  }) {
    final lastSeen = _seenLastSeen[videoId];
    if (lastSeen == null) return false;
    final cutoff = DateTime.now().subtract(within);
    return lastSeen.isAfter(cutoff);
  }

  Future<void> clearSeenVideos() async {
    await _initializeFuture;
    Log.debug(
      '📱️ Clearing all seen videos',
      name: 'SeenVideosService',
      category: LogCategory.system,
    );
    _seenVideos.clear();
    _seenLastSeen.clear();
    await _flushPendingSeenVideosSave();
    if (_prefs != null) {
      await _prefs!.remove(seenVideosMetricsStorageKey);
      await _prefs!.remove(legacySeenVideosStorageKey);
      await _prefs!.remove(seenVideosMigratedStorageKey);
    }
    if (_effectiveDb != null) {
      await _effectiveDb!.seenVideosDao.clearAll();
    }
  }

  Future<void> markVideoAsUnseen(String videoId) async {
    if (!_seenLastSeen.containsKey(videoId)) return;
    Log.debug(
      '📱️ Marking video as unseen: $videoId',
      name: 'SeenVideosService',
      category: LogCategory.system,
    );
    _seenLastSeen.remove(videoId);
    _seenVideos.remove(videoId);
    if (_effectiveDb != null) {
      try {
        await _effectiveDb!.seenVideosDao.remove(videoId);
      } catch (_) {
        // best-effort cleanup: remove failure is non-fatal
      }
    }
    await _scheduleSeenVideosSave();
  }

  Map<String, dynamic> getStatistics() {
    final totalLoops = _seenVideos.values.fold<int>(
      0,
      (sum, metrics) => sum + metrics.loopCount,
    );
    final totalWatchTime = _seenVideos.values.fold<Duration>(
      Duration.zero,
      (sum, metrics) => sum + metrics.totalWatchDuration,
    );
    return {
      'totalSeen': _seenLastSeen.length,
      'metricsCount': _seenVideos.length,
      'storageLimit': _maxSeenVideos,
      'percentageFull': (_seenVideos.length / _maxSeenVideos * 100)
          .toStringAsFixed(1),
      'totalLoops': totalLoops,
      'totalWatchTimeMinutes': totalWatchTime.inMinutes,
      'averageLoopsPerVideo': _seenVideos.isEmpty
          ? 0
          : (totalLoops / _seenVideos.length).toStringAsFixed(1),
    };
  }

  Future<void> dispose() => _flushPendingSeenVideosSave();
}
