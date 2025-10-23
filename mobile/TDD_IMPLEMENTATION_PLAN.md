# TDD Implementation Plan: Drift + Riverpod Reactive Database

## Executive Summary

**Question**: "will we need to change how we load data in to riverpod?"

**Answer**: **YES** - Significant but beneficial changes required:
- **AsyncNotifier with Timers** → **StreamProvider with Drift `.watch()`**
- **Manual polling (every 10 minutes)** → **Automatic reactivity (instant updates)**
- **Manual listeners on services** → **Database-driven streams**
- **Manual cache expiry checks** → **Drift handles freshness**
- **ChangeNotifier on services** → **Pure database queries**

**Impact**: POSITIVE - Eliminates ~400 lines of manual polling/caching code, UI updates automatically when data changes, no more timer management.

---

## Current Riverpod Patterns Analysis

### Pattern 1: AsyncNotifier with Manual Polling (HomeFeed)

**Current Code** (`home_feed_provider.dart`):
```dart
@Riverpod(keepAlive: false)
class HomeFeed extends _$HomeFeed {
  Timer? _autoRefreshTimer;

  @override
  Future<VideoFeedState> build() async {
    final pollInterval = ref.read(homeFeedPollIntervalProvider); // 10 minutes

    // Manual timer setup for auto-refresh
    void startAutoRefresh() {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = Timer(pollInterval, () {
        if (ref.mounted) {
          ref.invalidateSelf(); // Force rebuild every 10 minutes
        }
      });
    }

    ref.onResume(() => startAutoRefresh());
    ref.onCancel(() => _autoRefreshTimer?.cancel());
    ref.onDispose(() => _autoRefreshTimer?.cancel());

    startAutoRefresh();

    // Get social data (who user follows)
    final socialData = ref.watch(social.socialProvider);
    final followingPubkeys = socialData.followingPubkeys;

    // Subscribe to VideoEventService (which uses ChangeNotifier)
    final videoEventService = ref.watch(videoEventServiceProvider);
    await videoEventService.subscribeToHomeFeed(followingPubkeys, limit: 100);

    // Wait for events to stabilize (300ms debounce)
    final completer = Completer<void>();
    int stableCount = 0;
    Timer? stabilityTimer;

    void checkStability() {
      final currentCount = videoEventService.homeFeedVideos.length;
      if (currentCount != stableCount) {
        stableCount = currentCount;
        stabilityTimer?.cancel();
        stabilityTimer = Timer(const Duration(milliseconds: 300), () {
          if (!completer.isCompleted) completer.complete();
        });
      }
    }

    videoEventService.addListener(checkStability);
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) completer.complete();
    });

    checkStability();
    await completer.future;

    // Clean up
    videoEventService.removeListener(checkStability);
    stabilityTimer?.cancel();

    // Get videos from service
    final followingVideos = List<VideoEvent>.from(videoEventService.homeFeedVideos);

    // Reorder by seen/unseen
    final seenVideosState = ref.watch(seenVideosProvider);
    // ... reordering logic ...

    return VideoFeedState(videos: reorderedVideos, ...);
  }
}
```

**Problems**:
- 80+ lines of timer management code
- Manual polling every 10 minutes (inefficient, slow updates)
- Complex stabilization logic with multiple timers
- Manual listener registration/cleanup
- No real-time updates (must wait for 10-minute timer)

**Drift Pattern** (AFTER migration):
```dart
@riverpod
Stream<VideoFeedState> homeFeed(HomeFeedRef ref) {
  final db = ref.watch(databaseProvider);
  final socialData = ref.watch(socialProvider);
  final followingPubkeys = socialData.followingPubkeys;

  if (followingPubkeys.isEmpty) {
    return Stream.value(VideoFeedState.empty());
  }

  // Drift's .watch() returns Stream<List<NostrEvent>>
  // Automatically updates when database changes - NO TIMERS NEEDED!
  return db.nostrEventsDao
    .watchVideoEventsByAuthors(followingPubkeys)
    .map((events) {
      // Convert to VideoEvent models
      final videos = events.map(VideoEvent.fromNostrEvent).toList();

      // Reorder by seen/unseen (reactive)
      final seenIds = ref.watch(seenVideosProvider).seenVideoIds;
      final unseen = videos.where((v) => !seenIds.contains(v.id)).toList();
      final seen = videos.where((v) => seenIds.contains(v.id)).toList();

      return VideoFeedState(
        videos: [...unseen, ...seen],
        hasMoreContent: videos.length >= 100,
        isLoadingMore: false,
        error: null,
        lastUpdated: DateTime.now(),
      );
    });
}
```

**Benefits**:
- **80 lines → 25 lines** (70% reduction)
- **NO TIMERS** - automatic reactivity
- **Instant UI updates** when new events arrive (vs 10-minute delay)
- **NO manual listener management**
- **NO stabilization logic** - Drift handles batching

---

### Pattern 2: StreamProvider with Manual Listeners (VideoEvents)

**Current Code** (`video_events_providers.dart`):
```dart
@Riverpod(keepAlive: false)
class VideoEvents extends _$VideoEvents {
  StreamController<List<VideoEvent>>? _controller;
  Timer? _debounceTimer;
  List<VideoEvent>? _pendingEvents;

  @override
  Stream<List<VideoEvent>> build() {
    _controller = StreamController<List<VideoEvent>>.broadcast();

    final videoEventService = ref.watch(videoEventServiceProvider);
    final isAppReady = ref.watch(appReadyProvider);
    final isTabActive = ref.watch(isDiscoveryTabActiveProvider);

    ref.onDispose(() {
      _debounceTimer?.cancel();
      videoEventService.removeListener(_onVideoEventServiceChange); // Manual cleanup
      _controller?.close();
    });

    // Manual listener registration
    videoEventService.removeListener(_onVideoEventServiceChange);
    videoEventService.addListener(_onVideoEventServiceChange);

    videoEventService.subscribeToDiscovery(limit: 100);

    // Emit initial events
    final currentEvents = List<VideoEvent>.from(videoEventService.discoveryVideos);
    _controller!.add(currentEvents);

    return _controller!.stream;
  }

  void _onVideoEventServiceChange() {
    final service = ref.read(videoEventServiceProvider);
    final newEvents = List<VideoEvent>.from(service.discoveryVideos);

    // Store pending events for debounced emission
    _pendingEvents = newEvents;

    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Create a new debounce timer (500ms)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingEvents != null && _controller != null) {
        _controller!.add(_pendingEvents!);
        _pendingEvents = null;
      }
    });
  }
}
```

**Problems**:
- Manual StreamController management
- Manual listener registration/cleanup
- Manual debouncing with Timer
- Complex lifecycle management
- Still depends on VideoEventService's ChangeNotifier

**Drift Pattern** (AFTER migration):
```dart
@riverpod
Stream<List<VideoEvent>> videoEvents(VideoEventsRef ref) {
  final db = ref.watch(databaseProvider);
  final seenIds = ref.watch(seenVideosProvider).seenVideoIds;

  // Drift's .watch() automatically debounces and batches updates!
  return db.nostrEventsDao
    .watchAllVideoEvents(limit: 100)
    .map((events) {
      final videos = events.map(VideoEvent.fromNostrEvent).toList();

      // Reorder: unseen first
      final unseen = videos.where((v) => !seenIds.contains(v.id)).toList();
      final seen = videos.where((v) => seenIds.contains(v.id)).toList();

      return [...unseen, ...seen];
    });
}
```

**Benefits**:
- **NO manual StreamController** - Drift provides stream
- **NO manual listeners** - database reactivity
- **NO debounce timer** - Drift handles batching internally
- **NO lifecycle management** - Riverpod handles cleanup
- **50+ lines → 15 lines** (70% reduction)

---

### Pattern 3: Notifier with Manual Cache (UserProfile)

**Current Code** (`user_profile_providers.dart`):
```dart
// Manual in-memory cache with expiry
final Map<String, UserProfile> _userProfileCache = {};
final Map<String, DateTime> _userProfileCacheTimestamps = {};
const Duration _userProfileCacheExpiry = Duration(minutes: 10);

UserProfile? _getCachedUserProfile(String pubkey) {
  final profile = _userProfileCache[pubkey];
  final timestamp = _userProfileCacheTimestamps[pubkey];

  if (profile != null && timestamp != null) {
    final age = DateTime.now().difference(timestamp);
    if (age < _userProfileCacheExpiry) {
      return profile; // Cache hit
    } else {
      _clearUserProfileCache(pubkey); // Expired
    }
  }

  return null; // Cache miss
}

void _cacheUserProfile(String pubkey, UserProfile profile) {
  _userProfileCache[pubkey] = profile;
  _userProfileCacheTimestamps[pubkey] = DateTime.now();
}

@riverpod
Future<UserProfile?> fetchUserProfile(Ref ref, String pubkey) async {
  // Check cache first
  final cached = _getCachedUserProfile(pubkey);
  if (cached != null) return cached;

  // Fetch from service
  final userProfileService = ref.watch(userProfileServiceProvider);
  final profile = await userProfileService.fetchProfile(pubkey);

  if (profile != null) {
    _cacheUserProfile(pubkey, profile);
  }

  return profile;
}
```

**Problems**:
- Manual cache management (~100 lines)
- Manual expiry checks (10 minutes)
- Duplicate caching logic (memory cache + state cache)
- No reactivity - must manually invalidate

**Drift Pattern** (AFTER migration):
```dart
@riverpod
Stream<UserProfile?> userProfile(UserProfileRef ref, String pubkey) {
  final db = ref.watch(databaseProvider);

  // Drift handles caching, expiry, and reactivity!
  return db.userProfilesDao.watchProfile(pubkey);
}

// DAO implementation (in database layer)
@DriftAccessor(tables: [UserProfiles])
class UserProfilesDao extends DatabaseAccessor<AppDatabase> {
  UserProfilesDao(AppDatabase db) : super(db);

  // Reactive query - auto-updates when profile changes
  Stream<UserProfile?> watchProfile(String pubkey) {
    return (select(userProfiles)
      ..where((p) => p.pubkey.equals(pubkey)))
      .watchSingleOrNull()
      .map((row) => row != null ? UserProfile.fromDrift(row) : null);
  }

  // Insert/update profile (automatically triggers watchers)
  Future<void> upsertProfile(UserProfile profile) {
    return into(userProfiles).insertOnConflictUpdate(
      UserProfilesCompanion.insert(
        pubkey: profile.pubkey,
        displayName: Value(profile.displayName),
        // ... other fields
        lastFetched: DateTime.now(),
      ),
    );
  }
}
```

**Benefits**:
- **NO manual cache** - Drift handles it
- **NO expiry checks** - can query `lastFetched` in SQL
- **Reactive updates** - UI updates when profile changes
- **100+ lines → 20 lines** (80% reduction)

---

## Riverpod Pattern Changes Summary

### 1. AsyncNotifier → StreamProvider
**When**: Provider fetches data that changes over time
**Before**: Manual timers, manual refresh logic
**After**: Drift `.watch()` provides auto-updating stream

**Example**:
```dart
// BEFORE
@Riverpod(keepAlive: false)
class MyData extends _$MyData {
  Timer? _timer;

  @override
  Future<List<Item>> build() async {
    _timer = Timer(Duration(minutes: 5), () => ref.invalidateSelf());
    return fetchItems();
  }
}

// AFTER
@riverpod
Stream<List<Item>> myData(MyDataRef ref) {
  final db = ref.watch(databaseProvider);
  return db.itemsDao.watchAllItems();
}
```

### 2. Manual Listeners → Drift Streams
**When**: Provider listens to service changes
**Before**: `addListener()` / `removeListener()` on ChangeNotifier
**After**: Drift query streams

**Example**:
```dart
// BEFORE
service.addListener(_onChange);
ref.onDispose(() => service.removeListener(_onChange));

// AFTER
// No listeners needed - Drift handles it!
```

### 3. Manual Cache → Drift Cache
**When**: Provider caches fetched data
**Before**: Map-based cache with manual expiry
**After**: Database IS the cache

**Example**:
```dart
// BEFORE
final cache = <String, Profile>{};
if (cache.containsKey(id)) return cache[id];
cache[id] = await fetch(id);

// AFTER
// Database queries automatically cache results
return db.profilesDao.watchProfile(id);
```

### 4. FutureProvider → Remains (for one-time fetches)
**When**: Provider fetches data once (no updates needed)
**Before/After**: **NO CHANGE** - FutureProvider still appropriate

**Example**:
```dart
// Still valid for one-time data
@riverpod
Future<AppConfig> appConfig(AppConfigRef ref) async {
  final db = ref.watch(databaseProvider);
  return db.configDao.getConfig();
}
```

---

## TDD Implementation Phases

### Phase 1: Infrastructure & Schema (Week 1)

#### 1.1: Setup Drift Dependencies
**Test**: Verify Drift can open shared database
```dart
// test/infrastructure/drift_setup_test.dart
test('AppDatabase opens shared nostr_sdk database', () async {
  final db = AppDatabase();

  // Verify database path matches nostr_sdk
  final expectedPath = await DBUtil.getPath('openvine', 'local_relay.db');
  expect(db.executor.path, equals(expectedPath));

  await db.close();
});

test('AppDatabase can query existing nostr_sdk event table', () async {
  final db = AppDatabase();

  // Verify we can read from nostr_sdk's event table
  final events = await db.customSelect('SELECT * FROM event LIMIT 1').get();
  expect(events, isA<List>());

  await db.close();
});
```

**Implementation**:
1. Add dependencies:
   ```yaml
   dependencies:
     drift: ^2.14.0
     drift_flutter: ^0.1.0
     sqlite3_flutter_libs: ^0.5.20

   dev_dependencies:
     drift_dev: ^2.14.0
     build_runner: ^2.4.7
   ```

2. Create `lib/database/app_database.dart`:
   ```dart
   import 'dart:io';
   import 'package:drift/drift.dart';
   import 'package:drift/native.dart';
   import 'package:path/path.dart' as p;
   import 'package:path_provider/path_provider.dart';

   part 'app_database.g.dart';

   @DriftDatabase(tables: [], include: {})
   class AppDatabase extends _$AppDatabase {
     AppDatabase() : super(_openConnection());

     @override
     int get schemaVersion => 3; // nostr_sdk is at 2

     static QueryExecutor _openConnection() {
       return LazyDatabase(() async {
         final dbPath = await _getSharedDatabasePath();
         return NativeDatabase(File(dbPath), logStatements: true);
       });
     }

     static Future<String> _getSharedDatabasePath() async {
       final docDir = await getApplicationDocumentsDirectory();
       return p.join(docDir.path, 'openvine', 'database', 'local_relay.db');
     }
   }
   ```

3. Run tests:
   ```bash
   flutter test test/infrastructure/drift_setup_test.dart
   ```

#### 1.2: Define Drift Schema
**Test**: Verify schema generation
```dart
// test/infrastructure/schema_test.dart
test('Drift generates UserProfiles table', () async {
  final db = AppDatabase();

  // Verify table exists
  final result = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='user_profiles'"
  ).getSingleOrNull();

  expect(result, isNotNull);

  await db.close();
});

test('UserProfiles table has correct columns', () async {
  final db = AppDatabase();

  final columns = await db.customSelect(
    "PRAGMA table_info(user_profiles)"
  ).get();

  final columnNames = columns.map((c) => c.data['name']).toList();
  expect(columnNames, contains('pubkey'));
  expect(columnNames, contains('display_name'));
  expect(columnNames, contains('last_fetched'));

  await db.close();
});
```

**Implementation**:
1. Create `lib/database/tables.dart`:
   ```dart
   import 'package:drift/drift.dart';

   // Maps to nostr_sdk's existing event table (read-only for now)
   @DataClassName('NostrEventRow')
   class NostrEvents extends Table {
     @override
     String get tableName => 'event'; // Use existing table

     TextColumn get id => text()();
     TextColumn get pubkey => text()();
     IntColumn get createdAt => integer().named('created_at')();
     IntColumn get kind => integer()();
     TextColumn get tags => text()(); // JSON
     TextColumn get content => text()();
     TextColumn get sig => text()();
     TextColumn get sources => text().nullable()();

     @override
     Set<Column> get primaryKey => {id};
   }

   // NEW: Denormalized user profiles from kind 0 events
   @DataClassName('UserProfileRow')
   class UserProfiles extends Table {
     @override
     String get tableName => 'user_profiles';

     TextColumn get pubkey => text()();
     TextColumn get displayName => text().nullable().named('display_name')();
     TextColumn get name => text().nullable()();
     TextColumn get about => text().nullable()();
     TextColumn get picture => text().nullable()();
     TextColumn get banner => text().nullable()();
     TextColumn get nip05 => text().nullable()();
     TextColumn get lud16 => text().nullable()();
     DateTimeColumn get lastFetched => dateTime().named('last_fetched')();

     @override
     Set<Column> get primaryKey => {pubkey};
   }
   ```

2. Update `app_database.dart`:
   ```dart
   @DriftDatabase(tables: [NostrEvents, UserProfiles])
   class AppDatabase extends _$AppDatabase {
     // ... existing code ...

     @override
     MigrationStrategy get migration => MigrationStrategy(
       onCreate: (m) async {
         // Create ONLY our new tables - event table already exists!
         await m.createTable(userProfiles);
       },
       onUpgrade: (m, from, to) async {
         if (from < 3) {
           // First migration: add user_profiles table
           await m.createTable(userProfiles);
         }
       },
     );
   }
   ```

3. Run code generation:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Run tests:
   ```bash
   flutter test test/infrastructure/schema_test.dart
   ```

#### 1.3: Create DAO Layer
**Test**: Verify DAO operations
```dart
// test/dao/user_profiles_dao_test.dart
test('UserProfilesDao can insert profile', () async {
  final db = AppDatabase();
  final dao = db.userProfilesDao;

  final profile = UserProfile(
    pubkey: 'test_pubkey_123',
    displayName: 'Test User',
    lastFetched: DateTime.now(),
  );

  await dao.upsertProfile(profile);

  final fetched = await dao.getProfile('test_pubkey_123');
  expect(fetched, isNotNull);
  expect(fetched!.displayName, equals('Test User'));

  await db.close();
});

test('UserProfilesDao watch emits updates', () async {
  final db = AppDatabase();
  final dao = db.userProfilesDao;

  final stream = dao.watchProfile('test_pubkey_456');

  // Initially null
  expect(await stream.first, isNull);

  // Insert profile
  final profile = UserProfile(
    pubkey: 'test_pubkey_456',
    displayName: 'Test User 2',
    lastFetched: DateTime.now(),
  );
  await dao.upsertProfile(profile);

  // Stream should emit the new profile
  final updated = await stream.first;
  expect(updated, isNotNull);
  expect(updated!.displayName, equals('Test User 2'));

  await db.close();
});
```

**Implementation**:
1. Create `lib/database/daos/user_profiles_dao.dart`:
   ```dart
   import 'package:drift/drift.dart';
   import 'package:openvine/database/app_database.dart';
   import 'package:openvine/database/tables.dart';
   import 'package:openvine/models/user_profile.dart';

   part 'user_profiles_dao.g.dart';

   @DriftAccessor(tables: [UserProfiles])
   class UserProfilesDao extends DatabaseAccessor<AppDatabase>
       with _$UserProfilesDaoMixin {
     UserProfilesDao(AppDatabase db) : super(db);

     // Get single profile (one-time fetch)
     Future<UserProfile?> getProfile(String pubkey) async {
       final row = await (select(userProfiles)
         ..where((p) => p.pubkey.equals(pubkey)))
         .getSingleOrNull();

       return row != null ? UserProfile.fromDrift(row) : null;
     }

     // Watch profile (reactive stream)
     Stream<UserProfile?> watchProfile(String pubkey) {
       return (select(userProfiles)
         ..where((p) => p.pubkey.equals(pubkey)))
         .watchSingleOrNull()
         .map((row) => row != null ? UserProfile.fromDrift(row) : null);
     }

     // Upsert profile (insert or update)
     Future<void> upsertProfile(UserProfile profile) {
       return into(userProfiles).insertOnConflictUpdate(
         UserProfilesCompanion.insert(
           pubkey: profile.pubkey,
           displayName: Value(profile.displayName),
           name: Value(profile.name),
           about: Value(profile.about),
           picture: Value(profile.picture),
           banner: Value(profile.banner),
           nip05: Value(profile.nip05),
           lud16: Value(profile.lud16),
           lastFetched: profile.lastFetched ?? DateTime.now(),
         ),
       );
     }
   }
   ```

2. Add DAO to database:
   ```dart
   @DriftDatabase(
     tables: [NostrEvents, UserProfiles],
     daos: [UserProfilesDao],
   )
   class AppDatabase extends _$AppDatabase {
     // DAOs are auto-generated as getters!
   }
   ```

3. Run code generation and tests:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   flutter test test/dao/user_profiles_dao_test.dart
   ```

---

### Phase 2: Riverpod Integration (Week 1-2)

#### 2.1: Create Database Provider
**Test**: Verify database provider lifecycle
```dart
// test/providers/database_provider_test.dart
test('Database provider creates singleton instance', () {
  final container = ProviderContainer();

  final db1 = container.read(databaseProvider);
  final db2 = container.read(databaseProvider);

  expect(identical(db1, db2), isTrue);

  container.dispose();
});

test('Database provider disposes on container dispose', () async {
  final container = ProviderContainer();

  final db = container.read(databaseProvider);
  expect(db.executor.isOpen, isTrue);

  container.dispose();

  // Give dispose time to complete
  await Future.delayed(Duration(milliseconds: 100));

  expect(db.executor.isOpen, isFalse);
});
```

**Implementation**:
```dart
// lib/providers/database_provider.dart
@Riverpod(keepAlive: true) // Singleton
AppDatabase database(DatabaseRef ref) {
  final db = AppDatabase();

  ref.onDispose(() {
    db.close();
  });

  return db;
}
```

#### 2.2: Migrate UserProfile Provider to Drift
**Test**: Verify reactive profile provider
```dart
// test/providers/user_profile_drift_test.dart
test('userProfile provider emits updates from database', () async {
  final container = ProviderContainer();
  final db = container.read(databaseProvider);

  // Watch profile (initially null)
  final stream = container.read(userProfileProvider('test_pubkey'));
  expect(await stream.first, isNull);

  // Insert profile directly to database
  final profile = UserProfile(
    pubkey: 'test_pubkey',
    displayName: 'Test User',
    lastFetched: DateTime.now(),
  );
  await db.userProfilesDao.upsertProfile(profile);

  // Provider should automatically emit update!
  final updated = await stream.first;
  expect(updated, isNotNull);
  expect(updated!.displayName, equals('Test User'));

  container.dispose();
});
```

**Implementation**:
```dart
// lib/providers/user_profile_drift_provider.dart
@riverpod
Stream<UserProfile?> userProfile(UserProfileRef ref, String pubkey) {
  final db = ref.watch(databaseProvider);
  return db.userProfilesDao.watchProfile(pubkey);
}

// Batch fetch (insert to DB, then providers auto-update)
@riverpod
class UserProfileFetcher extends _$UserProfileFetcher {
  @override
  FutureOr<void> build() {}

  Future<void> fetchProfiles(List<String> pubkeys) async {
    final userProfileService = ref.read(userProfileServiceProvider);
    final db = ref.read(databaseProvider);

    for (final pubkey in pubkeys) {
      final profile = await userProfileService.fetchProfile(pubkey);
      if (profile != null) {
        // Insert to DB - all watchers auto-update!
        await db.userProfilesDao.upsertProfile(profile);
      }
    }
  }
}
```

#### 2.3: Migrate HomeFeed Provider to Drift
**Test**: Verify reactive home feed
```dart
// test/providers/home_feed_drift_test.dart
test('homeFeed provider emits when new video event inserted', () async {
  final container = ProviderContainer(
    overrides: [
      socialProvider.overrideWith((ref) => SocialData(
        followingPubkeys: ['author1', 'author2'],
      )),
    ],
  );
  final db = container.read(databaseProvider);

  // Watch home feed
  final stream = container.read(homeFeedProvider);

  // Initially empty
  final initial = await stream.first;
  expect(initial.videos, isEmpty);

  // Insert video event from followed author
  final event = NostrEventRow(
    id: 'event_123',
    pubkey: 'author1',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    kind: 34236, // Video event
    tags: jsonEncode([['title', 'Test Video']]),
    content: 'Test content',
    sig: 'test_sig',
  );
  await db.into(db.nostrEvents).insert(event);

  // Provider should automatically emit update!
  final updated = await stream.first;
  expect(updated.videos.length, equals(1));
  expect(updated.videos[0].id, equals('event_123'));

  container.dispose();
});

test('homeFeed does NOT emit Timer-based refreshes', () async {
  final container = ProviderContainer();

  // Watch home feed
  final stream = container.read(homeFeedProvider);

  // Get initial value
  final initial = await stream.first;

  // Wait 11 minutes (old pattern would trigger auto-refresh)
  await Future.delayed(Duration(minutes: 11));

  // Stream should NOT emit (no database changes)
  // This test would fail with old Timer-based pattern!
  expect(stream.isBroadcast, isTrue); // Still alive

  container.dispose();
});
```

**Implementation**:
```dart
// lib/providers/home_feed_drift_provider.dart
@riverpod
Stream<VideoFeedState> homeFeed(HomeFeedRef ref) {
  final db = ref.watch(databaseProvider);
  final socialData = ref.watch(socialProvider);
  final followingPubkeys = socialData.followingPubkeys;
  final seenIds = ref.watch(seenVideosProvider).seenVideoIds;

  if (followingPubkeys.isEmpty) {
    return Stream.value(VideoFeedState.empty());
  }

  // Drift reactive query - auto-updates when events change!
  return db.nostrEventsDao
    .watchVideoEventsByAuthors(followingPubkeys, limit: 100)
    .map((events) {
      final videos = events.map(VideoEvent.fromNostrEvent).toList();

      // Reorder: unseen first
      final unseen = videos.where((v) => !seenIds.contains(v.id)).toList();
      final seen = videos.where((v) => seenIds.contains(v.id)).toList();

      return VideoFeedState(
        videos: [...unseen, ...seen],
        hasMoreContent: videos.length >= 100,
        isLoadingMore: false,
        error: null,
        lastUpdated: DateTime.now(),
      );
    });
}
```

---

### Phase 3: Event Router & Caching (Week 2)

#### 3.1: Create Event Router
**Test**: Verify event routing to database
```dart
// test/services/event_router_test.dart
test('EventRouter inserts all events to database', () async {
  final db = AppDatabase();
  final router = EventRouter(db);

  // Route kind 0 (profile) event
  final profileEvent = Event(
    id: 'event_profile',
    pubkey: 'author1',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    kind: 0,
    tags: [],
    content: jsonEncode({'name': 'Test User'}),
    sig: 'sig',
  );
  await router.handleEvent(profileEvent);

  // Verify inserted to event table
  final eventRow = await db.nostrEventsDao.getEvent('event_profile');
  expect(eventRow, isNotNull);

  // Verify profile extracted and cached
  final profile = await db.userProfilesDao.getProfile('author1');
  expect(profile, isNotNull);
  expect(profile!.name, equals('Test User'));

  await db.close();
});

test('EventRouter handles video events', () async {
  final db = AppDatabase();
  final router = EventRouter(db);

  // Route kind 34236 (video) event
  final videoEvent = Event(
    id: 'event_video',
    pubkey: 'author2',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    kind: 34236,
    tags: [['title', 'Test Video']],
    content: 'Video content',
    sig: 'sig',
  );
  await router.handleEvent(videoEvent);

  // Verify inserted to event table
  final eventRow = await db.nostrEventsDao.getEvent('event_video');
  expect(eventRow, isNotNull);
  expect(eventRow!.kind, equals(34236));

  await db.close();
});
```

**Implementation**:
```dart
// lib/services/event_router.dart
class EventRouter {
  final AppDatabase _db;

  EventRouter(this._db);

  Future<void> handleEvent(Event event) async {
    // Step 1: Insert ALL events to database (single source of truth)
    await _db.nostrEventsDao.insertEvent(event);

    // Step 2: Route to specialized tables based on kind
    switch (event.kind) {
      case 0: // Profile metadata
        await _handleProfileEvent(event);
        break;

      case 3: // Contacts
        await _handleContactsEvent(event);
        break;

      case 7: // Reactions
        // TODO: Create reactions DAO
        break;

      case 6: // Reposts
      case 34236: // Videos
        // Already in event table, queryable via video DAO
        break;

      default:
        // Still in event table, just not processed further
        break;
    }

    Log.verbose(
      'Routed event ${event.id} (kind ${event.kind}) to database',
      name: 'EventRouter',
      category: LogCategory.system,
    );
  }

  Future<void> _handleProfileEvent(Event event) async {
    try {
      final profile = UserProfile.fromNostrEvent(event);
      await _db.userProfilesDao.upsertProfile(profile);

      Log.debug(
        'Extracted and cached profile for ${event.pubkey}',
        name: 'EventRouter',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to parse profile event: $e',
        name: 'EventRouter',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _handleContactsEvent(Event event) async {
    // TODO: Implement contacts DAO
  }
}
```

#### 3.2: Integrate EventRouter with NostrService
**Test**: Verify events flow through router
```dart
// test/integration/nostr_to_drift_test.dart
test('Events from NostrService flow to Drift database', () async {
  final db = AppDatabase();
  final router = EventRouter(db);
  final nostrService = NostrService();

  // Connect router to NostrService event stream
  nostrService.eventStream.listen((event) {
    router.handleEvent(event);
  });

  // Subscribe to video events
  await nostrService.subscribe([
    Filter(kinds: [34236], limit: 10),
  ]);

  // Wait for events
  await Future.delayed(Duration(seconds: 2));

  // Verify events in database
  final events = await db.nostrEventsDao.getAllVideoEvents(limit: 10);
  expect(events, isNotEmpty);

  await db.close();
});
```

---

### Phase 4: Data Migration (Week 2-3)

#### 4.1: Hive to Drift Migration Script
**Test**: Verify migration preserves data
```dart
// test/migration/hive_to_drift_test.dart
test('Migration copies all profiles from Hive to Drift', () async {
  // Setup Hive with test data
  await Hive.initFlutter();
  final profileBox = await Hive.openBox<UserProfile>('profiles');

  final testProfiles = [
    UserProfile(pubkey: 'user1', displayName: 'User 1'),
    UserProfile(pubkey: 'user2', displayName: 'User 2'),
    UserProfile(pubkey: 'user3', displayName: 'User 3'),
  ];

  for (final profile in testProfiles) {
    await profileBox.put(profile.pubkey, profile);
  }

  // Run migration
  final db = AppDatabase();
  final migrator = HiveToDriftMigrator(db);
  await migrator.migrateProfiles();

  // Verify all profiles migrated
  for (final profile in testProfiles) {
    final migrated = await db.userProfilesDao.getProfile(profile.pubkey);
    expect(migrated, isNotNull);
    expect(migrated!.displayName, equals(profile.displayName));
  }

  await db.close();
  await profileBox.close();
});

test('Migration preserves data integrity', () async {
  // Test that migration doesn't lose or corrupt data
  // ... similar test with more complex data
});

test('Migration is idempotent', () async {
  // Test that running migration twice doesn't cause errors
  final db = AppDatabase();
  final migrator = HiveToDriftMigrator(db);

  await migrator.migrateProfiles();
  await migrator.migrateProfiles(); // Second run should be safe

  await db.close();
});
```

**Implementation**: See DRIFT_MIGRATION_PLAN.md Phase 3 for full migration script.

---

## Testing Checklist

### Unit Tests
- [ ] AppDatabase opens shared database path
- [ ] Schema tables created correctly
- [ ] DAO CRUD operations work
- [ ] DAO `.watch()` emits updates
- [ ] Database provider lifecycle
- [ ] EventRouter routes events correctly

### Integration Tests
- [ ] Riverpod providers react to database changes
- [ ] NostrService events flow to database
- [ ] Multiple providers watching same data update together
- [ ] Provider cleanup doesn't break database connections

### Platform Tests
- [ ] Android: Database works
- [ ] iOS: Database works
- [ ] macOS: Database works
- [ ] Windows: Database works
- [ ] Linux: Database works
- [ ] Web: sqlite3.wasm works

### Performance Tests
- [ ] 100k+ events in database (query performance)
- [ ] Concurrent read/write operations
- [ ] Memory usage over time
- [ ] Stream subscription memory leaks

---

## Success Metrics

### Code Reduction
- **Target**: 50-70% reduction in provider/service code
- **Expected**: ~500 lines removed (timers, listeners, cache management)

### Performance Improvements
- **Feed Updates**: 10 minutes → Instant (on event arrival)
- **Profile Loading**: Cache hit ratio 90%+
- **Memory Usage**: 20-30% reduction (no duplicate caches)

### Developer Experience
- **Provider Complexity**: 80+ lines → 15-25 lines per provider
- **Maintenance**: No timer management, no cache expiry logic
- **Debugging**: SQL queries vs opaque service layer

---

## Risk Mitigation

### Risk 1: Breaking Existing UI
**Mitigation**:
- Feature flag for Drift vs Hive
- Side-by-side testing (both systems running)
- A/B rollout

### Risk 2: Migration Data Loss
**Mitigation**:
- Keep Hive boxes until migration confirmed
- Rollback mechanism
- Extensive migration tests

### Risk 3: Performance Regression
**Mitigation**:
- Benchmark before/after
- Load testing with production data
- Query optimization

---

## Next Steps

1. **Review this plan with Rabble** - Get approval on approach
2. **Start Phase 1.1** - Setup Drift dependencies and verify shared database
3. **Create test infrastructure** - Setup test helpers for database testing
4. **Implement Phase 1** - Infrastructure complete (Week 1)
5. **Begin Phase 2** - Migrate one provider as proof-of-concept

---

*Generated: 2025-10-22*
*Author: Claude Code*
