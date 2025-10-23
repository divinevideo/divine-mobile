# Drift Migration Plan for OpenVine

## Executive Summary

**Goal**: Migrate from fragmented Hive+SQLite caching to unified Drift database for reactive Nostr event management.

**Status**: ✅ FEASIBLE - Drift supports all OpenVine platforms
**Effort**: Medium-Large (2-3 weeks estimated)
**Risk**: Medium (requires careful data migration)

---

## 1. Platform Compatibility Analysis

### OpenVine Target Platforms
- ✅ Android
- ✅ iOS
- ✅ macOS
- ✅ Windows
- ✅ Linux
- ✅ Web

### Drift Platform Support
**CONFIRMED**: Drift supports ALL OpenVine platforms as of 2025
- Native platforms (Android, iOS, macOS, Windows, Linux): `drift_flutter` package
- Web: Requires `sqlite3.wasm` and `drift_worker.js` in web/ folder
- Cross-tab database sharing on web (bonus feature)

---

## 2. Current Database Usage Audit

### Existing Dependencies
```yaml
hive_ce: ^2.6.0              # ❌ Being deprecated
hive_ce_flutter: ^2.1.0      # ❌ Being deprecated
hive_ce_generator: ^1.6.0    # ❌ Being deprecated
sqflite: ^2.3.3+1            # ⚠️  Not reactive, not used directly by app
```

### Services Currently Using Hive (9 total)
1. **profile_cache_service.dart**
   - `Box<UserProfile>` - profile metadata
   - `Box<DateTime>` - fetch timestamps

2. **personal_event_cache_service.dart**
   - `Box<Map<String, dynamic>>` - user's own events
   - `Box<Map<String, dynamic>>` - event metadata

3. **profile_stats_cache_service.dart**
   - `Box<Map>` - profile statistics

4. **hashtag_cache_service.dart**
   - Uses Hive for hashtag data

5. **cache_recovery_service.dart**
6. **notification_persistence.dart**
7. **notification_service_enhanced.dart**
8. **upload_initialization_helper.dart**
9. **upload_manager.dart**

### Nostr SDK / Embedded Relay
- Uses `nostr_sdk` (Rust-based, local dependency at `../nostr_sdk`)
- Likely has internal SQLite database for relay functionality
- **Key Question**: Does nostr_sdk expose its SQLite database for Drift integration?

---

## 3. Migration Strategy

### Phase 1: Infrastructure Setup (Week 1)
**Goal**: Add Drift, create schema, test on all platforms

#### Tasks:
1. **Add Dependencies**
   ```yaml
   dependencies:
     drift: ^latest
     drift_flutter: ^latest
     sqlite3_flutter_libs: ^latest

   dev_dependencies:
     drift_dev: ^latest
     build_runner: ^latest
   ```

2. **Web Platform Setup**
   - Download `sqlite3.wasm` to `web/`
   - Download `drift_worker.js` to `web/`
   - Configure in `web/index.html`

3. **Create Drift Database Schema**
   ```dart
   // lib/database/app_database.dart
   @DriftDatabase(tables: [
     NostrEvents,       // All Nostr events (kind 0, 1, 3, 7, 6, 34236, etc.)
     UserProfiles,      // Cached profiles
     ProfileStats,      // Profile statistics
     Hashtags,          // Hashtag metadata
     Notifications,     // Notification data
     UploadQueue,       // Pending uploads
   ])
   class AppDatabase extends _$AppDatabase {
     AppDatabase() : super(_openConnection());

     @override
     int get schemaVersion => 1;
   }
   ```

4. **Test on All Platforms**
   - Android ✓
   - iOS ✓
   - macOS ✓
   - Windows ✓
   - Linux ✓
   - Web ✓

### Phase 2: Riverpod Integration (Week 1-2)
**Goal**: Create reactive providers using Drift's `.watch()` streams

#### Pattern:
```dart
// providers/events_provider.dart
final videoEventsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);

  // Drift's .watch() returns Stream that auto-updates!
  return db.nostrEventsDao
    .watchVideoEvents() // Returns Stream<List<NostrEvent>>
    .map((events) => events.map(VideoEvent.fromNostrEvent).toList());
});

// In UI
ref.watch(videoEventsProvider).when(
  data: (videos) => VideoList(videos),
  loading: () => LoadingSpinner(),
  error: (e, st) => ErrorWidget(),
);
```

#### Tasks:
1. Create DAOs (Data Access Objects) for each entity
2. Implement `.watch()` methods for reactive queries
3. Create Riverpod providers wrapping Drift streams
4. Test reactivity: update DB → UI auto-updates

### Phase 3: Data Migration (Week 2)
**Goal**: Migrate existing Hive data to Drift without data loss

#### Migration Script:
```dart
Future<void> migrateHiveToDrift() async {
  final db = AppDatabase();

  // 1. Migrate profiles
  final profileBox = await Hive.openBox<UserProfile>('profiles');
  for (var profile in profileBox.values) {
    await db.userProfilesDao.insertProfile(profile);
  }
  await profileBox.close();

  // 2. Migrate personal events
  final eventsBox = await Hive.openBox<Map<String, dynamic>>('personal_events');
  for (var entry in eventsBox.toMap().entries) {
    await db.nostrEventsDao.insertEvent(
      NostrEvent.fromJson(entry.value),
    );
  }
  await eventsBox.close();

  // 3. Migrate stats, hashtags, notifications, uploads...
  // ... (similar pattern for each Hive box)

  // 4. Delete old Hive boxes after successful migration
  await Hive.deleteBoxFromDisk('profiles');
  await Hive.deleteBoxFromDisk('personal_events');
  // ...

  // 5. Set migration flag
  await db.metadataDao.setMigrationComplete();
}
```

#### Safety Measures:
- Run migration on first app launch after update
- Keep Hive boxes until migration confirmed successful
- Add rollback mechanism if migration fails
- Test migration with production data snapshots

### Phase 4: Service Refactoring (Week 2-3)
**Goal**: Replace Hive calls with Drift DAOs

#### Example: ProfileCacheService
```dart
// BEFORE (Hive)
class ProfileCacheService {
  Box<UserProfile>? _profileBox;

  Future<UserProfile?> getProfile(String pubkey) async {
    return _profileBox?.get(pubkey);
  }

  Future<void> cacheProfile(UserProfile profile) async {
    await _profileBox?.put(profile.pubkey, profile);
  }
}

// AFTER (Drift)
class ProfileCacheService {
  final AppDatabase _db;

  ProfileCacheService(this._db);

  Future<UserProfile?> getProfile(String pubkey) {
    return _db.userProfilesDao.getProfile(pubkey);
  }

  Future<void> cacheProfile(UserProfile profile) {
    return _db.userProfilesDao.insertProfile(profile);
  }

  // Reactive query for Riverpod
  Stream<UserProfile?> watchProfile(String pubkey) {
    return _db.userProfilesDao.watchProfile(pubkey);
  }
}
```

#### Services to Refactor:
1. profile_cache_service.dart
2. personal_event_cache_service.dart
3. profile_stats_cache_service.dart
4. hashtag_cache_service.dart
5. notification_persistence.dart
6. notification_service_enhanced.dart
7. upload_initialization_helper.dart
8. upload_manager.dart
9. cache_recovery_service.dart (may become obsolete)

### Phase 5: Event Router Implementation (Week 3)
**Goal**: Centralize event caching - all events go to Drift

#### New Architecture:
```dart
class EventRouter {
  final AppDatabase _db;
  final StreamController<NostrEvent> _eventStream = StreamController.broadcast();

  void handleEvent(Event event) {
    // Store ALL events in Drift (single source of truth)
    _db.nostrEventsDao.insertEvent(event);

    // Route to specialized caches/services
    switch (event.kind) {
      case 0: // Profile
        _db.userProfilesDao.updateFromEvent(event);
        break;
      case 3: // Contacts
        // TODO: SocialService integration
        break;
      case 7: // Reactions
        // TODO: ReactionsService integration
        break;
      case 6: // Reposts
      case 34236: // Videos
        // Already handled by VideoEventService
        break;
      default:
        // Still cached in nostr_events table
        break;
    }

    // Notify Riverpod providers
    _eventStream.add(event);
  }
}
```

#### VideoEventService Updates:
```dart
// REMOVE: Event discarding
// if (!isVideoKind(event.kind)) return;

// REPLACE WITH: Route to EventRouter
eventRouter.handleEvent(event);

// Only process video-specific logic for video events
if (isVideoKind(event.kind) || event.kind == 6) {
  // ... existing video processing
}
```

---

## 4. Nostr SDK Integration Analysis

### Current State
- `nostr_sdk` is a Rust-based FFI library
- Located at `../nostr_sdk` (local dependency)
- Likely has internal SQLite for relay functionality

### Integration Questions
1. **Does nostr_sdk expose its SQLite database?**
   - If YES: Can Drift query it directly?
   - If NO: Need event sync layer between nostr_sdk and Drift

2. **Event Flow Options**:

   **Option A: Shared SQLite Database**
   ```
   nostr_sdk (Rust) ← writes → SQLite ← reads/writes ← Drift (Dart)
                                 ↓
                          Single source of truth
   ```
   - Pros: True single database, no sync needed
   - Cons: Requires nostr_sdk to expose database, potential locking issues

   **Option B: Sync Layer**
   ```
   nostr_sdk (SQLite) → Event Stream → EventRouter → Drift (SQLite)
                                                        ↓
                                                  App-layer cache
   ```
   - Pros: Clean separation, both databases optimized for their use
   - Cons: Duplicate data, sync complexity

### Recommendation
**Start with Option B** (sync layer):
- Cleaner architecture
- Less risk of breaking nostr_sdk
- Can optimize later if needed

---

## 5. Benefits of Migration

### Performance
- ✅ Faster complex queries (SQL vs key-value)
- ✅ Better indexing for Nostr event filtering
- ✅ Efficient pagination
- ✅ Reduced memory usage (no duplicate caches)

### Developer Experience
- ✅ Type-safe queries (compile-time validation)
- ✅ Single migration system (vs fragmented Hive migrations)
- ✅ Better debugging tools
- ✅ SQL familiarity for team

### Reactivity
- ✅ Native `.watch()` streams for Riverpod
- ✅ Automatic UI updates when data changes
- ✅ No manual notification layer needed
- ✅ Cross-tab synchronization on web

### Architecture
- ✅ Single source of truth for all events
- ✅ Eliminates fragmented caching
- ✅ Standardized query patterns
- ✅ Better testability

---

## 6. Risks and Mitigations

### Risk 1: Data Loss During Migration
**Mitigation**:
- Thorough testing with production data copies
- Keep Hive boxes until migration confirmed
- Implement rollback mechanism
- Beta test with small user group first

### Risk 2: Performance Regression
**Mitigation**:
- Benchmark before/after on all platforms
- Optimize indexes for common queries
- Monitor production metrics
- Have fallback plan

### Risk 3: Web Platform Issues
**Mitigation**:
- Test web extensively (sqlite3.wasm has quirks)
- Implement web-specific error handling
- Consider IndexedDB fallback for web if needed

### Risk 4: Nostr SDK Integration Complexity
**Mitigation**:
- Start with sync layer approach (Option B)
- Document event flow clearly
- Add comprehensive logging
- Test with various event types

### Risk 5: Breaking Changes During Migration
**Mitigation**:
- Feature flag for Drift vs Hive
- Gradual rollout by platform
- Monitor crash reports closely
- Quick rollback capability

---

## 7. Testing Strategy

### Unit Tests
- DAO operations (CRUD)
- Migration logic
- Query correctness
- Data validation

### Integration Tests
- Drift ↔ Riverpod reactivity
- Event routing
- Cross-platform database behavior
- Migration end-to-end

### Platform Tests
- Android (multiple OS versions)
- iOS (multiple OS versions)
- macOS
- Windows
- Linux
- Web (Chrome, Firefox, Safari)

### Load Tests
- 100k+ events in database
- Concurrent read/write operations
- Memory usage over time
- Query performance benchmarks

---

## 8. Rollout Plan

### Phase 1: Canary (Week 1)
- Enable Drift for developers only
- Test on all platforms internally
- Fix critical bugs

### Phase 2: Beta (Week 2)
- Enable for beta testers (10% of users)
- Monitor crash reports
- Collect performance metrics

### Phase 3: Staged Rollout (Week 3)
- 25% of users
- 50% of users
- 75% of users
- 100% of users

### Rollback Plan
- Feature flag to disable Drift
- Fall back to Hive if issues detected
- Keep Hive dependency for 1-2 releases

---

## 9. Success Criteria

### Must Have
- ✅ Zero data loss
- ✅ Works on all 6 platforms
- ✅ Reactive Riverpod integration functional
- ✅ No performance regression

### Nice to Have
- ✅ Faster queries than Hive
- ✅ Reduced memory usage
- ✅ Cleaner codebase
- ✅ Better developer experience

---

## 10. Timeline Estimate

### Week 1: Setup & Infrastructure
- Add Drift dependencies
- Create schema
- Test all platforms
- Create basic DAOs

### Week 2: Migration & Integration
- Implement data migration
- Refactor 4-5 services
- Test Riverpod reactivity
- Fix bugs

### Week 3: Event Router & Rollout
- Implement EventRouter
- Refactor remaining services
- Beta testing
- Gradual rollout

**Total**: 3 weeks for core migration + 1-2 weeks buffer for issues

---

## 11. Next Steps

1. **Approve Migration**: Decision from Rabble
2. **Spike Investigation**: 2-day spike to test Drift on all platforms
3. **Schema Design**: Finalize database schema with team
4. **Start Phase 1**: Add dependencies, create basic setup
5. **Create Migration PR**: Small, reviewable chunks

---

## 12. Questions for Decision

1. Should we migrate personal_event_cache first (isolated, lower risk)?
2. Do we need to keep Hive as fallback for 1-2 releases?
3. What's the rollback trigger? (crash rate? performance metrics?)
4. Should we investigate nostr_sdk database sharing first?

---

## Conclusion

**Drift migration is FEASIBLE and RECOMMENDED** for OpenVine:
- ✅ Supports all platforms
- ✅ Solves reactive database + Riverpod integration
- ✅ Eliminates fragmented caching
- ✅ Future-proof (actively maintained, vs deprecated Hive)

**Estimated effort**: 3 weeks core work + 1-2 weeks polish
**Risk level**: Medium (manageable with proper testing and rollout)
**Impact**: High (improved architecture, performance, developer experience)

---

*Generated by Claude Code*
*Date: 2025-10-22*
