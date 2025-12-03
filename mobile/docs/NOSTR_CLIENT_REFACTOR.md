# Nostr Client Refactor Plan

## Goal
Remove the embedded relay dependency and implement a direct WebSocket-based Nostr client following VGV's layered architecture with separate packages for each component.

## Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ App Layer (VideoEventService, UserProfileService, etc.)    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│ NostrService + SubscriptionManager                          │
│ - Connects to ws://localhost:7447                           │
│ - Converts between nostr_sdk and embedded relay formats     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│ EmbeddedNostrRelay (flutter_embedded_nostr_relay)           │
│ - SQLite event storage                                      │
│ - WebSocket server on port 7447                             │
│ - External relay management                                 │
│ - Per-relay WebSocket connections                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
     [Relay A]    [Relay B]    [Relay C]
```

## Target Architecture (VGV Layered)

```
┌─────────────────────────────────────────────────────────────┐
│ lib/ - Presentation + Business Logic                        │
│ ├── video_feed/bloc/   (VideoCubit)                        │
│ ├── profile/bloc/      (ProfileCubit)                      │
│ └── ...                                                     │
└──────────────────────┬──────────────────────────────────────┘
                       │ (Repository Layer)
┌──────────────────────▼──────────────────────────────────────┐
│ packages/                                                   │
│ ├── video_repository/      (composes nostr_client)         │
│ ├── profile_repository/    (composes nostr_client)         │
│ └── social_repository/     (composes nostr_client)         │
└──────────────────────┬──────────────────────────────────────┘
                       │ (Data Layer)
┌──────────────────────▼──────────────────────────────────────┐
│ packages/                                                   │
│ ├── nostr_client/          (high-level Nostr API)          │
│ ├── nostr_relay_manager/   (relay pool + subscriptions)    │
│ └── nostr_socket_manager/  (WebSocket connections)         │
└──────────────────────┬──────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
     [Relay A]    [Relay B]    [Relay C]
       (1 WS)      (1 WS)       (1 WS)
```

---

## VGV Layer Responsibilities

| Layer | Location | Flutter Deps | Responsibility |
|-------|----------|--------------|----------------|
| Presentation | `lib/*/view/` | Yes | UI widgets, user interaction |
| Business Logic | `lib/*/bloc/` | No | State management via Bloc/Cubit |
| Repository | `packages/*_repository/` | No | Domain logic, compose data clients |
| Data | `packages/*_client/` | No | Raw data access, domain-agnostic |

**Key Rules:**
- Data flows exclusively upward
- Each layer accesses only the layer directly beneath it
- Repository layer cannot depend on other repositories
- Data layer must be domain-agnostic and reusable

---

## Package Structure

```
mobile/
├── lib/
│   ├── video_feed/
│   │   ├── bloc/
│   │   │   ├── video_feed_cubit.dart
│   │   │   └── video_feed_state.dart
│   │   └── view/
│   │       └── video_feed_page.dart
│   ├── profile/
│   │   ├── bloc/
│   │   └── view/
│   └── ...
│
└── packages/
    │
    │── nostr_socket_manager/        # Data Layer (lowest)
    │   ├── lib/
    │   │   ├── nostr_socket_manager.dart
    │   │   └── src/
    │   │       ├── socket_manager.dart
    │   │       ├── models/
    │   │       │   ├── connection_state.dart
    │   │       │   └── relay_message.dart
    │   │       └── exceptions/
    │   │           └── socket_exception.dart
    │   ├── test/
    │   └── pubspec.yaml
    │
    ├── nostr_relay_manager/         # Data Layer
    │   ├── lib/
    │   │   ├── nostr_relay_manager.dart
    │   │   └── src/
    │   │       ├── relay_manager.dart
    │   │       ├── models/
    │   │       │   ├── relay_info.dart
    │   │       │   ├── relay_config.dart
    │   │       │   └── subscription_state.dart
    │   │       └── exceptions/
    │   │           └── relay_exception.dart
    │   ├── test/
    │   └── pubspec.yaml             # depends on nostr_socket_manager
    │
    ├── nostr_client/                # Data Layer (highest data layer)
    │   ├── lib/
    │   │   ├── nostr_client.dart
    │   │   └── src/
    │   │       ├── nostr_client.dart
    │   │       ├── event_validator.dart
    │   │       ├── models/
    │   │       │   ├── nostr_event.dart
    │   │       │   ├── nostr_filter.dart
    │   │       │   └── broadcast_result.dart
    │   │       └── exceptions/
    │   │           └── nostr_exception.dart
    │   ├── test/
    │   └── pubspec.yaml             # depends on nostr_relay_manager
    │
    ├── video_repository/            # Repository Layer
    │   ├── lib/
    │   │   ├── video_repository.dart
    │   │   └── src/
    │   │       ├── video_repository.dart
    │   │       └── models/
    │   │           └── video.dart
    │   ├── test/
    │   └── pubspec.yaml             # depends on nostr_client
    │
    ├── profile_repository/          # Repository Layer
    │   ├── lib/
    │   │   ├── profile_repository.dart
    │   │   └── src/
    │   │       ├── profile_repository.dart
    │   │       └── models/
    │   │           └── user_profile.dart
    │   ├── test/
    │   └── pubspec.yaml             # depends on nostr_client
    │
    └── social_repository/           # Repository Layer
        ├── lib/
        │   ├── social_repository.dart
        │   └── src/
        │       ├── social_repository.dart
        │       └── models/
        │           ├── reaction.dart
        │           └── repost.dart
        ├── test/
        └── pubspec.yaml             # depends on nostr_client
```

---

## Package Specifications

### nostr_socket_manager (Data Layer)

Single WebSocket per relay with connection pooling. Domain-agnostic.

```dart
// lib/src/socket_manager.dart
abstract class ISocketManager {
  Future<void> connect(String relayUrl);
  Future<void> disconnect(String relayUrl);
  void send(String relayUrl, List<dynamic> message);
  Stream<RelayMessage> messages(String relayUrl);
  ConnectionState getState(String relayUrl);
  Stream<ConnectionState> stateChanges(String relayUrl);
}
```

**Handles:**
- WebSocket lifecycle (connect, ping, reconnect with backoff)
- Message serialization/deserialization (JSON arrays)
- Connection state tracking
- AUTH challenge/response (NIP-42)

**Dependencies:** `web_socket_channel`, `meta`

### nostr_relay_manager (Data Layer)

Relay pool management and subscription routing. Domain-agnostic.

```dart
// lib/src/relay_manager.dart
abstract class IRelayManager {
  Future<void> addRelay(String url, {RelayConfig? config});
  Future<void> removeRelay(String url);
  List<RelayInfo> get relays;

  String subscribe(List<Map<String, dynamic>> filters, {List<String>? relayUrls});
  void closeSubscription(String subscriptionId);
  Stream<Map<String, dynamic>> events(String subscriptionId);
  Stream<void> eose(String subscriptionId);

  Future<Map<String, bool>> publish(Map<String, dynamic> event, {List<String>? relayUrls});
}
```

**Handles:**
- Subscription fanout to multiple relays
- Per-relay EOSE tracking
- OK message handling for publishes
- Relay capability detection (NIP-11)

**Dependencies:** `nostr_socket_manager`, `meta`

### nostr_client (Data Layer)

High-level Nostr operations with event processing. Domain-agnostic.

```dart
// lib/src/nostr_client.dart
abstract class INostrClient {
  Future<void> initialize({List<String>? relays});
  Future<void> dispose();

  Stream<NostrEvent> subscribe(List<NostrFilter> filters, {void Function()? onEose});
  Future<List<NostrEvent>> query(List<NostrFilter> filters, {Duration? timeout});
  Future<BroadcastResult> broadcast(NostrEvent event);

  Future<void> addRelay(String url);
  Future<void> removeRelay(String url);
  List<String> get connectedRelays;
}
```

**Handles:**
- Event signature validation
- Cross-relay deduplication (by event ID)
- Replaceable event handling (NIP-01, NIP-33)
- Filter optimization and batching

**Dependencies:** `nostr_relay_manager`, `meta`, `crypto`

### video_repository (Repository Layer)

Domain-specific video logic. Composes nostr_client.

```dart
// lib/src/video_repository.dart
abstract class IVideoRepository {
  Stream<Video> watchVideos({List<String>? authors, List<String>? hashtags});
  Stream<Video> watchHomeFeed(List<String> followedPubkeys);
  Future<List<Video>> getVideosByAuthor(String pubkey);
  Future<void> publishVideo(Video video);
  Future<void> deleteVideo(String videoId);
}
```

**Handles:**
- Kind 34236 event parsing (NIP-71)
- Kind 16 repost handling
- Video model mapping
- Blocklist filtering

**Dependencies:** `nostr_client`

### profile_repository (Repository Layer)

Domain-specific profile logic. Composes nostr_client.

```dart
// lib/src/profile_repository.dart
abstract class IProfileRepository {
  Stream<UserProfile> watchProfile(String pubkey);
  Future<UserProfile?> getProfile(String pubkey);
  Future<void> updateProfile(UserProfile profile);
  Future<List<UserProfile>> batchGetProfiles(List<String> pubkeys);
}
```

**Handles:**
- Kind 0 event parsing
- Profile caching (in-memory LRU)
- Missing profile tracking

**Dependencies:** `nostr_client`

### social_repository (Repository Layer)

Domain-specific social interactions. Composes nostr_client.

```dart
// lib/src/social_repository.dart
abstract class ISocialRepository {
  Stream<List<String>> watchFollowing(String pubkey);
  Future<void> follow(String pubkey);
  Future<void> unfollow(String pubkey);
  Future<void> likeVideo(String videoId);
  Future<void> unlikeVideo(String videoId);
  Future<void> repostVideo(String videoId);
}
```

**Handles:**
- Kind 3 contact list management
- Kind 7 reactions
- Kind 16 reposts

**Dependencies:** `nostr_client`

---

## Migration Phases

### Phase 1: Create nostr_socket_manager
```bash
very_good create flutter_package nostr_socket_manager --desc "WebSocket connection manager for Nostr relays"
```

- Implement WebSocket connection pooling
- Add exponential backoff reconnection
- Add AUTH (NIP-42) support
- 100% test coverage

### Phase 2: Create nostr_relay_manager
```bash
very_good create flutter_package nostr_relay_manager --desc "Relay pool and subscription manager for Nostr"
```

- Implement relay pool management
- Add subscription fanout
- Add EOSE aggregation
- 100% test coverage

### Phase 3: Create nostr_client
```bash
very_good create flutter_package nostr_client --desc "High-level Nostr client for Flutter"
```

- Implement event deduplication
- Add signature validation
- Add replaceable event handling
- 100% test coverage

### Phase 4: Create repositories
```bash
very_good create flutter_package video_repository --desc "Video domain repository"
very_good create flutter_package profile_repository --desc "Profile domain repository"
very_good create flutter_package social_repository --desc "Social interactions repository"
```

- Migrate VideoEventService → video_repository
- Migrate UserProfileService → profile_repository
- Migrate SocialService → social_repository
- 100% test coverage

### Phase 5: Migrate lib/ to use repositories
- Update Blocs/Cubits to use repositories
- Remove old services
- Remove embedded relay dependency

---

## Risks and Mitigations

### Risk 1: Loss of SQLite Caching
**Current:** Embedded relay stores events in SQLite.
**Impact:** Slower startup, no offline access.

**Options:**
| Option | Pros | Cons |
|--------|------|------|
| A. Add cache package | Full offline | Complexity |
| B. In-memory LRU | Simple | Lost on restart |
| C. Cache in repository | Per-domain control | Duplication |

**Recommendation:** Option C - each repository manages its own cache strategy.

### Risk 2: Subscription Explosion
**Mitigation:** nostr_relay_manager batches filters to same relay set.

### Risk 3: EOSE Complexity
**Mitigation:** nostr_relay_manager tracks per-relay EOSE, fires aggregate.

### Risk 4: Breaking Tests
**Mitigation:** Create adapter implementing old INostrService interface.

---

## What We Lose

1. **P2P Sync** - Can add as separate package later
2. **Local WebSocket Server** - Not needed for mobile
3. **Tor Support** - Can add to nostr_socket_manager later
4. **Negentropy Sync** - Can add as separate package later

---

## Testing Strategy

Each package must have 100% test coverage (VGV standard).

### Unit Tests per Package
- `nostr_socket_manager`: Mock WebSocket, test reconnection
- `nostr_relay_manager`: Mock socket manager, test routing
- `nostr_client`: Mock relay manager, test deduplication
- `*_repository`: Mock nostr_client, test domain logic

### Integration Tests
- Connect to real relay, send/receive events
- Test AUTH flow with relay3.divine.video

---

## Open Questions

1. **Cache Strategy:** In-memory LRU per repository, or shared cache package?
2. **Relay Selection:** How to choose relays per subscription type?
3. **Error Propagation:** How to surface relay errors through layers?

---

## References

- [VGV Layered Architecture](https://engineering.verygood.ventures/architecture/architecture/)
- [VGV Engineering Philosophy](https://engineering.verygood.ventures/engineering/philosophy/)
- [Very Good CLI](https://cli.vgv.dev/)