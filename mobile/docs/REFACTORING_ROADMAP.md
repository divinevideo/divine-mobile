# VideoEventService Refactoring Roadmap

## Executive Summary

**Problem**: VideoEventService has grown to 3,277 lines with 9 distinct responsibilities, violating Single Responsibility Principle (SRP).

**Solution**: Extract 7 focused services from VideoEventService, each handling a specific concern.

**Timeline**: 6 phases over ~4-6 weeks

**Status**: Phase 1 (Foundation) - IN PROGRESS

---

## Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VideoEventService                         │
│                      (3,277 lines)                           │
├─────────────────────────────────────────────────────────────┤
│ 1. Subscription Management (8 feed types)                    │
│ 2. Event Reception & Routing                                 │
│ 3. Event Processing (Nostr → VideoEvent)                     │
│ 4. Filtering (blocklist, hashtags, groups, URLs)             │
│ 5. Caching (8 separate event lists)                          │
│ 6. Pagination (cursor tracking, historical loading)          │
│ 7. Sorting (engagement, chronological)                       │
│ 8. Retry & Recovery (error detection, auto-retry)            │
│ 9. Search (NIP-50 implementation)                            │
└─────────────────────────────────────────────────────────────┘
```

**Key Metrics**:
- **Lines**: 3,277
- **Methods**: 71
- **State Fields**: 48
- **Dependencies**: 7 services
- **Subscription Types**: 8 (homeFeed, discovery, hashtag, group, profile, mentions, search, latestByAuthor)

---

## Target Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                   VideoEventOrchestrator                         │
│              (Facade coordinating all services)                  │
└────────────────────────┬─────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
    │ Video   │    │ Video   │    │ Video   │
    │Subscrip-│    │ Event   │    │ Cache   │
    │tion     │    │Processor│    │ Manager │
    │ Manager │    │         │    │         │
    └─────────┘    └─────────┘    └─────────┘
         │               │               │
    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
    │ Video   │    │ Video   │    │ Video   │
    │ Filter  │    │ Sort    │    │ Search  │
    │ Service │    │ Service │    │ Service │
    └─────────┘    └─────────┘    └─────────┘
                         │
                    ┌────▼────┐
                    │ Retry   │
                    │ Handler │
                    └─────────┘
```

### Extracted Services

#### 1. VideoSubscriptionManager
**Responsibility**: Managing Nostr subscriptions for video feeds
- Create/cancel subscriptions per feed type
- Manage subscription lifecycle
- Handle EOSE (end of stored events)
- Priority management

**Estimated Size**: ~400 lines

#### 2. VideoEventProcessor
**Responsibility**: Converting Nostr events to VideoEvent objects
- Parse NIP-71 event structure
- Extract video metadata (title, URL, thumbnail, duration)
- Validate event structure
- Handle both Kind 22 and Kind 34236

**Estimated Size**: ~300 lines

#### 3. VideoCacheManager
**Responsibility**: Managing in-memory event caches per subscription type
- Maintain 8 separate event lists
- Deduplication logic
- Size limits (120 events/list)
- Cache invalidation

**Estimated Size**: ~250 lines

#### 4. VideoFilterService
**Responsibility**: Filtering events based on various criteria
- Blocklist filtering (users, content)
- Hashtag filtering
- Group filtering
- URL validation
- Adult content filtering

**Estimated Size**: ~350 lines

#### 5. VideoSortService
**Responsibility**: Sorting video events by different strategies
- Engagement-based sorting (loop count)
- Chronological sorting
- Unseen content prioritization
- Custom sort strategies

**Estimated Size**: ~200 lines

#### 6. VideoSearchService
**Responsibility**: NIP-50 search implementation
- Search query construction
- Result filtering
- Search result caching
- Search history tracking

**Estimated Size**: ~300 lines

#### 7. VideoRetryHandler
**Responsibility**: Error detection and retry logic
- Classify errors (retriable vs permanent)
- Exponential backoff
- Connection status monitoring
- Retry limits

**Estimated Size**: ~250 lines

#### 8. VideoEventOrchestrator (Facade)
**Responsibility**: Coordinating all services, providing simple API
- Public API matching current VideoEventService interface
- Delegate calls to appropriate services
- Handle cross-service coordination
- Maintain backward compatibility

**Estimated Size**: ~400 lines

---

## Phase-by-Phase Migration Plan

### Phase 1: Foundation (CURRENT)
**Goal**: Prepare for service splitting without changing behavior

**Tasks**:
- ✅ Create `SocialEventServiceBase` abstract class
- ✅ Create `SubscriptionUtils` helper class
- ✅ Create `NostrErrorUtils` helper class
- ✅ Add documentation to VideoEventService
- ✅ Create this roadmap document

**Deliverables**:
- Foundation utilities created
- Documentation added
- Zero behavior changes
- Clean analyze output

**Estimated Time**: 2-3 hours

**Risks**: None (no behavioral changes)

---

### Phase 2: Extract Filtering & Sorting
**Goal**: Move stateless logic to dedicated services

**Tasks**:
1. Create `VideoFilterService` class
   - Move blocklist filtering logic
   - Move hashtag/group filtering
   - Move URL validation
   - Add comprehensive tests

2. Create `VideoSortService` class
   - Move all sorting strategies
   - Move unseen content prioritization
   - Add comprehensive tests

3. Update VideoEventService to use new services
   - Inject services via constructor
   - Replace inline filtering with service calls
   - Replace inline sorting with service calls

4. Verify no behavioral changes
   - Run existing tests
   - Manual testing of all feed types

**Deliverables**:
- `VideoFilterService` with tests
- `VideoSortService` with tests
- VideoEventService reduced by ~500 lines
- All existing tests pass

**Estimated Time**: 1-2 days

**Risks**:
- Filter logic may have subtle edge cases
- Sorting order must remain identical

**Mitigation**:
- Write characterization tests before extraction
- Compare outputs before/after for same inputs

---

### Phase 3: Extract Event Processing
**Goal**: Isolate Nostr event → VideoEvent conversion

**Tasks**:
1. Create `VideoEventProcessor` class
   - Move `_convertNostrEventToVideoEvent()` method
   - Move NIP-71 parsing logic
   - Move metadata extraction
   - Add comprehensive tests

2. Update VideoEventService
   - Inject processor via constructor
   - Replace inline processing with processor calls

3. Verify no behavioral changes
   - Test with real Nostr events
   - Test with malformed events
   - Test with both Kind 22 and 34236

**Deliverables**:
- `VideoEventProcessor` with tests
- VideoEventService reduced by ~300 lines
- All existing tests pass

**Estimated Time**: 1 day

**Risks**:
- Event parsing may have subtle dependencies on service state
- Error handling might be tightly coupled

**Mitigation**:
- Make processor stateless where possible
- Pass all required context as parameters

---

### Phase 4: Extract Cache Management
**Goal**: Isolate in-memory event caching

**Tasks**:
1. Create `VideoCacheManager` class
   - Move `_eventLists` map and related state
   - Move deduplication logic
   - Move size limit enforcement
   - Move cache invalidation
   - Add comprehensive tests

2. Update VideoEventService
   - Inject cache manager via constructor
   - Replace direct cache access with manager calls
   - Maintain `ChangeNotifier` behavior

3. Verify no behavioral changes
   - Test cache size limits
   - Test deduplication
   - Test per-subscription isolation

**Deliverables**:
- `VideoCacheManager` with tests
- VideoEventService reduced by ~250 lines
- All existing tests pass

**Estimated Time**: 1-2 days

**Risks**:
- Cache manager must trigger `notifyListeners()` correctly
- Event ordering must be preserved

**Mitigation**:
- Use callbacks to notify parent service
- Add ordering verification tests

---

### Phase 5: Extract Subscription Management
**Goal**: Isolate Nostr subscription creation/cancellation

**Tasks**:
1. Create `VideoSubscriptionManager` class
   - Move subscription creation logic
   - Move filter construction per feed type
   - Move subscription tracking
   - Move EOSE handling
   - Add comprehensive tests

2. Update VideoEventService
   - Inject subscription manager via constructor
   - Replace inline subscription logic with manager calls

3. Verify no behavioral changes
   - Test all 8 subscription types
   - Test subscription cancellation
   - Test priority handling

**Deliverables**:
- `VideoSubscriptionManager` with tests
- VideoEventService reduced by ~400 lines
- All existing tests pass

**Estimated Time**: 2 days

**Risks**:
- Subscription lifecycle is complex
- Multiple subscription types may interact

**Mitigation**:
- Test each subscription type independently
- Test subscription type switching

---

### Phase 6: Extract Search & Retry, Create Orchestrator
**Goal**: Complete extraction and create facade

**Tasks**:
1. Create `VideoSearchService` class
   - Move NIP-50 search logic
   - Move search result handling
   - Add comprehensive tests

2. Create `VideoRetryHandler` class
   - Move error classification logic
   - Move retry logic with backoff
   - Add comprehensive tests

3. Create `VideoEventOrchestrator` class (Facade)
   - Implement same public API as VideoEventService
   - Delegate to appropriate services
   - Handle cross-service coordination
   - Add integration tests

4. Update providers to use Orchestrator
   - Replace VideoEventService with VideoEventOrchestrator
   - Verify DI setup in `app_providers.dart`
   - Run full app test suite

5. Deprecate VideoEventService
   - Mark as `@deprecated`
   - Add migration guide
   - Remove in future release

**Deliverables**:
- `VideoSearchService` with tests
- `VideoRetryHandler` with tests
- `VideoEventOrchestrator` with integration tests
- Migration guide
- All 7 new services in production

**Estimated Time**: 3-4 days

**Risks**:
- Orchestrator coordination is complex
- Provider migration may break existing code

**Mitigation**:
- Maintain 100% API compatibility
- Extensive integration testing
- Gradual rollout (feature flag?)

---

## Testing Strategy

### Unit Tests
**Target**: Each extracted service has ≥90% coverage

**Approach**:
1. Write tests BEFORE extraction (TDD)
2. Test each responsibility in isolation
3. Mock dependencies
4. Cover edge cases and error paths

**Example Tests**:
- `VideoFilterService`: Blocklist filtering, URL validation, hashtag matching
- `VideoSortService`: Engagement sorting, chronological sorting, unseen prioritization
- `VideoEventProcessor`: NIP-71 parsing, metadata extraction, error handling
- `VideoCacheManager`: Deduplication, size limits, per-subscription isolation

### Integration Tests
**Target**: Verify services work together correctly

**Approach**:
1. Test service interactions
2. Test VideoEventOrchestrator facade
3. Test real Nostr event flows
4. Test error propagation

**Example Tests**:
- Full video feed flow: subscription → events → processing → filtering → sorting → caching
- Search flow: query → subscription → results → filtering
- Error flow: network failure → retry → recovery

### Characterization Tests
**Target**: Prevent behavioral changes during refactoring

**Approach**:
1. Capture current behavior BEFORE extraction
2. Run same tests AFTER extraction
3. Assert identical outputs

**Example Tests**:
- Input: Real Nostr events → Output: VideoEvent list (must match exactly)
- Input: Blocklist + events → Output: Filtered list (must match exactly)

### Regression Tests
**Target**: Prevent breaking existing functionality

**Approach**:
1. Run FULL test suite after each phase
2. Manual testing of all feed types
3. Test on real devices (iOS, Android, Web)

---

## Dependency Management

### Service Dependencies

```
VideoEventOrchestrator
  ├─ VideoSubscriptionManager
  │   └─ NostrService
  ├─ VideoEventProcessor
  │   └─ (stateless)
  ├─ VideoCacheManager
  │   └─ (stateless)
  ├─ VideoFilterService
  │   ├─ ContentBlocklistService
  │   └─ (stateless logic)
  ├─ VideoSortService
  │   └─ (stateless)
  ├─ VideoSearchService
  │   └─ VideoSubscriptionManager
  └─ VideoRetryHandler
      └─ ConnectionStatusService
```

### Dependency Injection Setup

Update `app_providers.dart`:

```dart
// Phase 2: Add filter & sort services
final videoFilterServiceProvider = Provider<VideoFilterService>((ref) {
  return VideoFilterService(
    blocklistService: ref.watch(contentBlocklistServiceProvider),
  );
});

final videoSortServiceProvider = Provider<VideoSortService>((ref) {
  return VideoSortService();
});

// Phase 3: Add processor
final videoEventProcessorProvider = Provider<VideoEventProcessor>((ref) {
  return VideoEventProcessor();
});

// Phase 4: Add cache manager
final videoCacheManagerProvider = Provider<VideoCacheManager>((ref) {
  return VideoCacheManager();
});

// Phase 5: Add subscription manager
final videoSubscriptionManagerProvider = Provider<VideoSubscriptionManager>((ref) {
  return VideoSubscriptionManager(
    nostrService: ref.watch(nostrServiceProvider),
  );
});

// Phase 6: Add search & retry, create orchestrator
final videoSearchServiceProvider = Provider<VideoSearchService>((ref) {
  return VideoSearchService(
    subscriptionManager: ref.watch(videoSubscriptionManagerProvider),
  );
});

final videoRetryHandlerProvider = Provider<VideoRetryHandler>((ref) {
  return VideoRetryHandler(
    connectionStatus: ref.watch(connectionStatusServiceProvider),
  );
});

final videoEventOrchestratorProvider = Provider<VideoEventOrchestrator>((ref) {
  return VideoEventOrchestrator(
    subscriptionManager: ref.watch(videoSubscriptionManagerProvider),
    processor: ref.watch(videoEventProcessorProvider),
    cacheManager: ref.watch(videoCacheManagerProvider),
    filterService: ref.watch(videoFilterServiceProvider),
    sortService: ref.watch(videoSortServiceProvider),
    searchService: ref.watch(videoSearchServiceProvider),
    retryHandler: ref.watch(videoRetryHandlerProvider),
  );
});
```

---

## File Structure

```
lib/
├─ services/
│  ├─ base/
│  │  └─ social_event_service_base.dart  ✅ (Phase 1)
│  ├─ video/
│  │  ├─ video_event_orchestrator.dart   (Phase 6 - Facade)
│  │  ├─ video_subscription_manager.dart (Phase 5)
│  │  ├─ video_event_processor.dart      (Phase 3)
│  │  ├─ video_cache_manager.dart        (Phase 4)
│  │  ├─ video_filter_service.dart       (Phase 2)
│  │  ├─ video_sort_service.dart         (Phase 2)
│  │  ├─ video_search_service.dart       (Phase 6)
│  │  └─ video_retry_handler.dart        (Phase 6)
│  └─ video_event_service.dart           (Deprecated after Phase 6)
├─ utils/
│  ├─ subscription_utils.dart            ✅ (Phase 1)
│  └─ nostr_error_utils.dart             ✅ (Phase 1)
└─ providers/
   ├─ video_events_providers.dart        (Update Phase 6)
   └─ home_feed_provider.dart            (Update Phase 6)

test/
└─ unit/
   └─ services/
      └─ video/
         ├─ video_filter_service_test.dart       (Phase 2)
         ├─ video_sort_service_test.dart         (Phase 2)
         ├─ video_event_processor_test.dart      (Phase 3)
         ├─ video_cache_manager_test.dart        (Phase 4)
         ├─ video_subscription_manager_test.dart (Phase 5)
         ├─ video_search_service_test.dart       (Phase 6)
         ├─ video_retry_handler_test.dart        (Phase 6)
         └─ video_event_orchestrator_test.dart   (Phase 6)
```

---

## Backward Compatibility

### API Compatibility
**Goal**: Zero breaking changes for existing code

**Strategy**:
1. VideoEventOrchestrator implements same public API as VideoEventService
2. Method signatures remain identical
3. Return types remain identical
4. Behavioral compatibility verified via tests

### Migration Path
**Option 1**: Gradual migration (Recommended)
1. Keep VideoEventService as deprecated wrapper
2. Providers use VideoEventOrchestrator
3. Remove VideoEventService in v2.0

**Option 2**: Hard cutover
1. Replace VideoEventService with VideoEventOrchestrator
2. Update all imports in same PR
3. Remove VideoEventService immediately

**Recommendation**: Option 1 (gradual migration) for safety

---

## Success Criteria

### Phase 1 (Foundation)
- ✅ All foundation utilities created
- ✅ Documentation added
- ✅ `flutter analyze` passes
- ✅ All existing tests pass
- ✅ Zero behavioral changes

### Phase 2 (Filter & Sort)
- [ ] VideoFilterService extracted with ≥90% coverage
- [ ] VideoSortService extracted with ≥90% coverage
- [ ] VideoEventService reduced by ~500 lines
- [ ] `flutter analyze` passes
- [ ] All existing tests pass
- [ ] Characterization tests verify identical behavior

### Phase 3 (Processor)
- [ ] VideoEventProcessor extracted with ≥90% coverage
- [ ] VideoEventService reduced by ~300 lines
- [ ] `flutter analyze` passes
- [ ] All existing tests pass

### Phase 4 (Cache)
- [ ] VideoCacheManager extracted with ≥90% coverage
- [ ] VideoEventService reduced by ~250 lines
- [ ] `flutter analyze` passes
- [ ] All existing tests pass
- [ ] Cache behavior identical (deduplication, size limits)

### Phase 5 (Subscription)
- [ ] VideoSubscriptionManager extracted with ≥90% coverage
- [ ] VideoEventService reduced by ~400 lines
- [ ] `flutter analyze` passes
- [ ] All existing tests pass
- [ ] All 8 subscription types work identically

### Phase 6 (Orchestrator)
- [ ] VideoSearchService extracted with ≥90% coverage
- [ ] VideoRetryHandler extracted with ≥90% coverage
- [ ] VideoEventOrchestrator created with ≥90% coverage
- [ ] All providers updated to use Orchestrator
- [ ] `flutter analyze` passes
- [ ] All existing tests pass
- [ ] Integration tests verify full flows
- [ ] Migration guide published
- [ ] VideoEventService marked deprecated

### Final Success
- [ ] VideoEventService reduced from 3,277 to <100 lines (deprecated wrapper)
- [ ] 7 focused services created, each <400 lines
- [ ] Overall test coverage ≥90%
- [ ] Zero behavioral changes
- [ ] Zero breaking changes for existing code
- [ ] App runs identically on all platforms

---

## Rollback Plan

### Per Phase
**If phase fails**:
1. Revert all changes from phase
2. Review failure cause
3. Adjust approach
4. Retry phase

**Git Strategy**:
- Each phase = separate branch
- PR per phase
- Merge only after all tests pass

### Full Rollback
**If refactoring must be abandoned**:
1. Revert to Phase 1 (foundation only)
2. Keep utility classes (no harm)
3. Keep documentation
4. Plan alternative approach

---

## Future Enhancements (Post-Refactoring)

After successful refactoring, these become easier:

1. **Advanced Caching**: Implement persistent cache with SQLite
2. **Smart Preloading**: Preload videos based on scroll position
3. **Background Sync**: Sync video feeds in background
4. **Improved Error Handling**: More granular error types, better retry strategies
5. **Performance Optimization**: Lazy loading, pagination improvements
6. **Metrics & Monitoring**: Track service performance, cache hit rates
7. **Plugin Architecture**: Allow custom filters, sorters, processors

---

## Questions & Decisions

### Open Questions
1. **Should VideoEventOrchestrator be a Singleton or Provider?**
   - Answer: Provider (better for testing, DI)

2. **Should we maintain VideoEventService as deprecated wrapper?**
   - Answer: Yes (gradual migration is safer)

3. **Should cache size limits be configurable?**
   - Answer: Yes (move to config/constants)

### Decisions Made
1. ✅ Use Riverpod for dependency injection
2. ✅ Maintain 100% API compatibility
3. ✅ Gradual migration over hard cutover
4. ✅ TDD for all new services
5. ✅ Characterization tests to prevent regression

---

## Timeline Estimate

| Phase | Tasks | Duration | Start | End |
|-------|-------|----------|-------|-----|
| 1. Foundation | Create utilities, docs | 2-3 hours | Day 1 | Day 1 |
| 2. Filter & Sort | Extract 2 services | 1-2 days | Day 2 | Day 3 |
| 3. Processor | Extract event processing | 1 day | Day 4 | Day 4 |
| 4. Cache | Extract cache management | 1-2 days | Day 5 | Day 6 |
| 5. Subscription | Extract subscription logic | 2 days | Day 7 | Day 8 |
| 6. Orchestrator | Create facade, migrate | 3-4 days | Day 9 | Day 12 |
| **Testing Buffer** | Extra time for testing | 3 days | Day 13 | Day 15 |
| **TOTAL** | | **15 days** | | |

**Note**: Timeline assumes full-time focus. Actual calendar time will be longer with other work.

---

## Metrics & Tracking

### Code Metrics (Before)
- VideoEventService: 3,277 lines
- Test coverage: ~60%
- Responsibilities: 9
- Methods: 71
- State fields: 48

### Code Metrics (Target After)
- VideoEventOrchestrator: ~400 lines
- 7 services: ~2,050 lines total (~293 avg)
- Test coverage: ≥90%
- Responsibilities: 1 per service
- Methods: ~10-15 per service
- State fields: <10 per service

### Progress Tracking
- [ ] Phase 1: Foundation (0% → 100%)
- [ ] Phase 2: Filter & Sort (0%)
- [ ] Phase 3: Processor (0%)
- [ ] Phase 4: Cache (0%)
- [ ] Phase 5: Subscription (0%)
- [ ] Phase 6: Orchestrator (0%)

**Overall Progress**: 16% (Phase 1 complete)

---

## Resources

### References
- [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single-responsibility_principle)
- [Facade Pattern](https://refactoring.guru/design-patterns/facade)
- [Strangler Fig Pattern](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Working Effectively with Legacy Code](https://www.goodreads.com/book/show/44919.Working_Effectively_with_Legacy_Code)

### Tools
- Flutter DevTools for performance monitoring
- Dart Analyzer for static analysis
- Code coverage tools for test coverage

---

## Conclusion

This refactoring is ambitious but achievable. The phase-by-phase approach minimizes risk while steadily improving code quality. The end result will be a more maintainable, testable, and extensible video event system.

**Next Step**: Complete Phase 1 verification, then begin Phase 2 (Extract Filtering & Sorting).
