# Nostr SDK for Flutter

ABOUTME: Comprehensive Flutter/Dart SDK for building decentralized Nostr applications
ABOUTME: Provides complete protocol implementation with extensive NIP support and advanced features

A comprehensive Flutter/Dart SDK for building Nostr applications. This library provides a complete implementation of the Nostr protocol with extensive NIP (Nostr Implementation Possibilities) support, designed for building decentralized social applications.

**⚠️ Development Status**: This SDK is under active development (v0.0.1). Use with caution in production environments. 

## Why This SDK?

This is one of the most feature-complete Nostr implementations available, offering:
- **22 NIPs implemented** - One of the most comprehensive NIP coverage in any SDK
- **Production-ready architecture** - Sophisticated relay pooling, connection management, and error handling
- **Advanced security** - Multiple signing strategies including hardware signers and remote signing
- **Offline-first design** - Built-in SQLite caching and local relay support
- **Cross-platform** - Works seamlessly across Android, iOS, web, and desktop
- **Developer-friendly** - Clean APIs, extensive documentation, and examples

## Features

### 🚀 Core Features
- **Full Nostr Protocol Support**: Complete implementation of the Nostr event-based protocol
- **22 NIPs Implemented**: One of the most comprehensive NIP coverage available
- **Cross-Platform**: Support for Android, iOS, web, and desktop via Flutter
- **Pluggable Signing**: Multiple signer implementations (local, remote, hardware)
- **Relay Management**: Advanced relay pooling, connection management, and subscriptions
- **Local Storage**: SQLite-based caching and offline support
- **File Upload**: Multiple file hosting service integrations
- **Lightning Integration**: Zaps, LNURL, and wallet connectivity

### 📋 Supported NIPs

| NIP | Description | Status |
|-----|-------------|---------|
| [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md) | Basic protocol flow | ✅ |
| [NIP-02](https://github.com/nostr-protocol/nips/blob/master/02.md) | Contact Lists | ✅ |
| [NIP-04](https://github.com/nostr-protocol/nips/blob/master/04.md) | Encrypted Direct Messages | ✅ (deprecated) |
| [NIP-05](https://github.com/nostr-protocol/nips/blob/master/05.md) | DNS-based identity verification | ✅ |
| [NIP-07](https://github.com/nostr-protocol/nips/blob/master/07.md) | Browser extension signing | ✅ |
| [NIP-19](https://github.com/nostr-protocol/nips/blob/master/19.md) | bech32-encoded entities | ✅ |
| [NIP-23](https://github.com/nostr-protocol/nips/blob/master/23.md) | Long-form content | ✅ |
| [NIP-29](https://github.com/nostr-protocol/nips/blob/master/29.md) | Relay-based Groups | ✅ |
| [NIP-42](https://github.com/nostr-protocol/nips/blob/master/42.md) | Authentication of clients to relays | ✅ |
| [NIP-44](https://github.com/nostr-protocol/nips/blob/master/44.md) | Versioned Encryption | ✅ |
| [NIP-46](https://github.com/nostr-protocol/nips/blob/master/46.md) | Remote Signing | ✅ |
| [NIP-47](https://github.com/nostr-protocol/nips/blob/master/47.md) | Wallet Connect | ✅ |
| [NIP-50](https://github.com/nostr-protocol/nips/blob/master/50.md) | Search Capability | ✅ |
| [NIP-51](https://github.com/nostr-protocol/nips/blob/master/51.md) | Lists (bookmarks, follow sets) | ✅ |
| [NIP-55](https://github.com/nostr-protocol/nips/blob/master/55.md) | Android signer integration | ✅ |
| [NIP-58](https://github.com/nostr-protocol/nips/blob/master/58.md) | Badges | ✅ |
| [NIP-59](https://github.com/nostr-protocol/nips/blob/master/59.md) | Gift Wrapping | ✅ |
| [NIP-65](https://github.com/nostr-protocol/nips/blob/master/65.md) | Relay List Metadata | ✅ |
| [NIP-69](https://github.com/nostr-protocol/nips/blob/master/69.md) | Polls | ✅ |
| [NIP-75](https://github.com/nostr-protocol/nips/blob/master/75.md) | Zap Goals | ✅ |
| [NIP-94](https://github.com/nostr-protocol/nips/blob/master/94.md) | File Metadata | ✅ |
| [NIP-96](https://github.com/nostr-protocol/nips/blob/master/96.md) | File Storage | ✅ |
| [NIP-172](https://github.com/nostr-protocol/nips/blob/master/172.md) | Community Support | ✅ |

## Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  nostr_sdk:
    git:
      url: https://github.com/your-repo/nostr_sdk
```

Then run:

```bash
flutter pub get
```

### Platform-Specific Setup

#### Android
Add internet permission to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS
Add network permissions to `ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Quick Start

### 1. Basic Setup

```dart
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/relay/event_filter.dart';
import 'package:nostr_sdk/relay/relay.dart';

// Generate a new key pair or use existing private key
final signer = LocalNostrSigner.generate();
// OR use existing key: LocalNostrSigner('your_private_key_hex')

final publicKey = await signer.getPublicKey();
print('Your public key: $publicKey');
print('Your npub: ${Nip19.encodePubKey(publicKey!)}');

// Create event filters for automatic subscriptions
final eventFilters = [
  EventFilter(kinds: [EventKind.TEXT_NOTE], limit: 100)
];

// Initialize Nostr client with relay generator
final nostr = Nostr(
  signer,
  publicKey!,
  eventFilters,
  (relayUrl) => Relay(relayUrl), // Creates temporary relay connections
  onNotice: (relayUrl, notice) => print('Notice from $relayUrl: $notice'),
);

// Add popular relays
final relays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.snort.social',
  'wss://offchain.pub',
];

for (final relayUrl in relays) {
  final success = await nostr.addRelay(Relay(relayUrl));
  print('Relay $relayUrl ${success ? "connected" : "failed"}');
}

// Check connectivity
print('Can read: ${nostr.readable()}');
print('Can write: ${nostr.writable()}');
```

### 2. Sending Events

```dart
// Send a text note
final textEvent = Event(
  publicKey,
  EventKind.TEXT_NOTE,
  [],
  'Hello Nostr! This is my first post from the SDK 🚀',
);

final sentEvent = await nostr.sendEvent(textEvent);
if (sentEvent != null) {
  print('Text note sent! ID: ${sentEvent.id}');
  print('View on Nostr: ${Nip19.encodeNoteId(sentEvent.id)}');
} else {
  print('Failed to send event - check relay connections');
}

// Send a text note with hashtags and mentions
final taggedEvent = Event(
  publicKey,
  EventKind.TEXT_NOTE,
  [
    ['t', 'nostr'],
    ['t', 'flutter'],
    ['p', friendPublicKey, 'wss://relay.damus.io', 'mention'],
  ],
  'Building with #nostr and #flutter! Thanks to nostr:${Nip19.encodePubKey(friendPublicKey)}',
);
await nostr.sendEvent(taggedEvent);

// React to an event (like/dislike)
await nostr.sendLike(eventId, content: '🔥'); // Fire emoji reaction
await nostr.sendLike(eventId, content: '-');  // Dislike

// Repost with commentary
await nostr.sendRepost(
  eventId, 
  relayAddr: 'wss://relay.damus.io',
  content: 'This is an amazing post! 💯'
);

// Delete your own events
await nostr.deleteEvent(eventId);
await nostr.deleteEvents([eventId1, eventId2, eventId3]); // Bulk delete

// Send encrypted direct message (NIP-04 - deprecated but still supported)
final dmEvent = Event(
  publicKey,
  EventKind.DIRECT_MESSAGE,
  [['p', recipientPubkey]],
  await signer.encrypt(recipientPubkey, 'Secret message!'),
);
await nostr.sendEvent(dmEvent);
```

### 3. Subscribing to Events

```dart
// Subscribe to global text notes (live feed)
final globalFeedId = nostr.subscribe(
  [
    {
      'kinds': [EventKind.TEXT_NOTE],
      'limit': 50,
    }
  ],
  (Event event) {
    print('📝 ${event.content}');
    print('   by ${Nip19.encodeSimplePubKey(event.pubkey)}');
    print('   at ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}');
  },
);

// Search for specific content using NIP-50
final searchResults = await nostr.relayPool.searchEvents(
  'bitcoin',
  kinds: [EventKind.TEXT_NOTE],
  limit: 20,
  timeout: Duration(seconds: 10),
);

for (final event in searchResults) {
  print('🔍 Found: ${event.content}');
  print('   by ${Nip19.encodeSimplePubKey(event.pubkey)}');
}

// Subscribe to your mentions
final mentionId = nostr.subscribe(
  [
    {
      'kinds': [EventKind.TEXT_NOTE],
      '#p': [publicKey],
      'limit': 20,
    }
  ],
  (Event event) {
    print('🔔 You were mentioned: ${event.content}');
  },
);

// Subscribe to reactions on your posts
final reactionId = nostr.subscribe(
  [
    {
      'kinds': [EventKind.REACTION],
      '#p': [publicKey],
    }
  ],
  (Event event) {
    print('👍 Reaction: ${event.content}');
  },
);

// Query your own posts (one-time)
final myEvents = await nostr.queryEvents([
  {
    'kinds': [EventKind.TEXT_NOTE],
    'authors': [publicKey],
    'limit': 20,
  }
]);

print('Found ${myEvents.length} of your posts');
for (final event in myEvents) {
  print('📄 ${event.content}');
}

// Query specific event by ID
final specificEvents = await nostr.queryEvents([
  {
    'ids': [eventId],
  }
]);

// Advanced filtering - posts with hashtags from last 24 hours
final since = DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
final hashtagEvents = await nostr.queryEvents([
  {
    'kinds': [EventKind.TEXT_NOTE],
    '#t': ['nostr'], // hashtag filter
    'since': since,
    'limit': 100,
  }
]);

// Subscribe with multiple relays and relay types
final advancedSubId = nostr.subscribe(
  [
    {
      'kinds': [EventKind.TEXT_NOTE, EventKind.REACTION],
      'authors': followingList,
      'limit': 100,
    }
  ],
  (Event event) {
    print('Event from ${event.sources.join(", ")}');
  },
  tempRelays: ['wss://special.relay.com'],
  relayTypes: [RelayType.NORMAL, RelayType.CACHE],
  sendAfterAuth: true,
);

// Cleanup subscriptions
nostr.unsubscribe(globalFeedId);
nostr.unsubscribe(mentionId);
nostr.unsubscribe(reactionId);
```

### 4. Contact Lists

```dart
import 'package:nostr_sdk/nip02/contact_list.dart';
import 'package:nostr_sdk/nip02/contact.dart';

// Create contact list
final contacts = ContactList();
contacts.add(Contact(pubkey: friendPublicKey, relay: 'wss://relay.damus.io'));

// Send contact list
await nostr.sendContactList(contacts, 'My contacts');
```

### 5. Complete Example: Mini Social App

```dart
import 'package:nostr_sdk/nostr_sdk.dart';

class NostrSocialApp {
  late Nostr nostr;
  late String publicKey;
  final List<Event> timeline = [];
  final Map<String, List<Event>> userProfiles = {};

  Future<void> initialize() async {
    // Setup signer and client
    final signer = LocalNostrSigner.generate();
    publicKey = (await signer.getPublicKey())!;
    
    final eventFilters = [
      EventFilter(kinds: [EventKind.TEXT_NOTE], limit: 100)
    ];
    
    nostr = Nostr(
      signer,
      publicKey,
      eventFilters,
      (url) => Relay(url),
      onNotice: (relay, notice) => print('Notice: $notice'),
    );

    // Connect to relays
    final relays = ['wss://relay.damus.io', 'wss://nos.lol'];
    for (final relay in relays) {
      await nostr.addRelay(Relay(relay));
    }
  }

  Future<void> post(String content, {List<String>? hashtags}) async {
    final tags = <List<String>>[];
    
    // Add hashtags
    if (hashtags != null) {
      for (final tag in hashtags) {
        tags.add(['t', tag]);
      }
    }

    final event = Event(publicKey, EventKind.TEXT_NOTE, tags, content);
    final sent = await nostr.sendEvent(event);
    
    if (sent != null) {
      print('✅ Posted: $content');
      timeline.add(sent);
    } else {
      print('❌ Failed to post');
    }
  }

  void startTimelineSubscription() {
    nostr.subscribe(
      [
        {
          'kinds': [EventKind.TEXT_NOTE],
          'limit': 50,
        }
      ],
      (Event event) {
        timeline.add(event);
        _displayEvent(event);
      },
    );
  }

  void _displayEvent(Event event) {
    final author = Nip19.encodeSimplePubKey(event.pubkey);
    final time = DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000);
    
    print('\n📝 $author at ${time.hour}:${time.minute}');
    print('   ${event.content}');
    
    if (event.sources.isNotEmpty) {
      print('   via ${event.sources.first}');
    }
  }

  Future<void> react(String eventId, String reaction) async {
    await nostr.sendLike(eventId, content: reaction);
    print('👍 Reacted with: $reaction');
  }

  Future<void> repost(String eventId, String comment) async {
    await nostr.sendRepost(eventId, content: comment);
    print('🔄 Reposted with: $comment');
  }

  Future<List<Event>> getUserPosts(String userPubkey) async {
    return await nostr.queryEvents([
      {
        'kinds': [EventKind.TEXT_NOTE],
        'authors': [userPubkey],
        'limit': 20,
      }
    ]);
  }

  void close() {
    nostr.close();
  }
}

// Usage
void main() async {
  final app = NostrSocialApp();
  await app.initialize();
  
  // Start listening to timeline
  app.startTimelineSubscription();
  
  // Post content
  await app.post('Hello Nostr! 🚀', hashtags: ['nostr', 'flutter']);
  
  // Wait a bit to see some events
  await Future.delayed(Duration(seconds: 5));
  
  // Cleanup
  app.close();
}
```

## Advanced Usage

### Custom Signers

#### Remote Signer (NIP-46)

```dart
import 'package:nostr_sdk/nip46/nostr_remote_signer.dart';

final remoteSigner = NostrRemoteSigner(
  remoteSignerPubkey: 'npub...',
  relayUrl: 'wss://relay.example.com',
);

final nostr = Nostr(remoteSigner, publicKey, eventFilters, tempRelayGenerator);
```

#### Read-Only Mode

```dart
import 'package:nostr_sdk/signer/pubkey_only_nostr_signer.dart';

final readOnlySigner = PubkeyOnlyNostrSigner(publicKey);
final nostr = Nostr(readOnlySigner, publicKey, eventFilters, tempRelayGenerator);

// Check if read-only
if (nostr.isReadOnly()) {
  print('Running in read-only mode');
}
```

### Search (NIP-50)

```dart
// Simple text search
final results = await nostr.relayPool.searchEvents('nostr protocol');

// Advanced search with filters
final bitcoinPosts = await nostr.relayPool.searchEvents(
  'bitcoin lightning',
  kinds: [EventKind.TEXT_NOTE],
  authors: ['specific_author_pubkey'],
  since: DateTime.now().subtract(Duration(days: 7)),
  limit: 50,
  timeout: Duration(seconds: 10),
  relayUrls: ['wss://relay.nostr.band', 'wss://search.nos.today'],
);

// Process search results
for (final event in bitcoinPosts) {
  print('📄 ${event.content}');
  print('   from ${event.sources.join(", ")}');
}

// Low-level search using Filter class
final filter = Filter(
  search: 'decentralized social media',
  kinds: [EventKind.TEXT_NOTE],
  limit: 10,
);

final subscriptionId = nostr.relayPool.subscribe(
  [filter.toJson()],
  (event) => print('Search result: ${event.content}'),
);

// Remember to unsubscribe when done
nostr.relayPool.unsubscribe(subscriptionId);
```

**Search Features:**
- Full-text search across event content
- Combine with other filters (author, kind, time range)
- Automatic result deduplication
- Timeout support for responsive UIs
- Works with NIP-50 compatible relays
- Graceful fallback for unsupported relays

### Encryption (NIP-44)

```dart
// Encrypt message
final encrypted = await signer.nip44Encrypt(recipientPubkey, 'Secret message');

// Decrypt message
final decrypted = await signer.nip44Decrypt(senderPubkey, encryptedMessage);
```

### Relay Authentication (NIP-42)

The SDK supports NIP-42 authentication for relays that require it. Authentication can be configured per-relay:

```dart
// Configure specific relay to always authenticate
nostr.setRelayAlwaysAuth('wss://auth.relay.com', true);

// Configure multiple relays at once
nostr.configureRelayAuth({
  'wss://auth.relay.com': true,      // Always authenticate
  'wss://public.relay.com': false,   // No authentication required
  'wss://premium.relay.com': true,   // Always authenticate
});

// Check current authentication configuration
final authConfig = nostr.getRelayAuthConfig();
print('Auth config: $authConfig');

// When alwaysAuth is true, all messages (events, subscriptions, queries)
// will be automatically queued until authentication is complete
await nostr.sendEvent(event); // Will authenticate first if needed

// You can also use sendAfterAuth for specific operations
nostr.subscribe(
  [Filter(kinds: [EventKind.TEXT_NOTE])],
  (event) => print('Event: ${event.content}'),
  sendAfterAuth: true, // Will wait for authentication
);
```

**How it works:**
- When a relay is configured with `alwaysAuth: true`, all messages are queued until authentication
- The SDK automatically handles AUTH challenges from relays (reactive authentication)
- Authentication events (kind 22242) are created and signed automatically
- Messages are sent after successful authentication
- Both proactive (alwaysAuth) and reactive (AUTH challenge) modes are supported

### File Uploads

```dart
import 'package:nostr_sdk/upload/nip96_uploader.dart';
import 'package:nostr_sdk/upload/blossom_uploader.dart';

// Upload via NIP-96
final nip96Uploader = Nip96Uploader('https://nostr.build');
final uploadResult = await nip96Uploader.upload(fileBytes, 'image.jpg');

// Upload via Blossom
final blossomUploader = BlossomUploader('https://blossom.server.com');
final blossomResult = await blossomUploader.upload(fileBytes, signer);
```

### Groups (NIP-29)

```dart
import 'package:nostr_sdk/nip29/nip29.dart';
import 'package:nostr_sdk/nip29/group_metadata.dart';

// Create group
final groupMetadata = GroupMetadata(
  groupId: 'my-group',
  name: 'My Group',
  about: 'A test group',
  picture: 'https://example.com/image.jpg',
);

final groupEvent = Nip29.createGroupMetadata(groupMetadata);
await nostr.sendEvent(groupEvent);

// Send group message
final groupMessage = Nip29.createGroupMessage('my-group', 'Hello group!');
await nostr.sendEvent(groupMessage);
```

### Zaps (Lightning)

```dart
import 'package:nostr_sdk/zap/zap.dart';

// Create zap request
final zapRequest = await Zap.createZapRequest(
  recipientPubkey: authorPubkey,
  amount: 1000, // sats
  comment: 'Great post!',
  eventId: eventToZap,
);

// Process with LNURL
final lnurlPay = 'lnurl...';
final invoice = await Zap.requestInvoice(lnurlPay, zapRequest);
```

## Architecture

### Core Classes

#### `Nostr` (lib/nostr.dart:16)
The main client class that orchestrates all Nostr operations:
- **Relay Management**: Handles connections to multiple relays
- **Event Operations**: Send, subscribe, query events
- **Signing Integration**: Works with pluggable signer implementations

Key methods:
- `sendEvent()`, `sendLike()`, `sendRepost()` - Event publishing
- `subscribe()`, `query()`, `queryEvents()` - Event retrieval
- `addRelay()`, `removeRelay()` - Relay management

#### `Event` (lib/event.dart:13)
Represents a Nostr event with:
- Automatic ID generation and validation
- Schnorr signature support
- Proof-of-work capabilities
- JSON serialization

#### `NostrSigner` (lib/signer/nostr_signer.dart:3)
Abstract interface for signing operations:
- Event signing
- Message encryption/decryption (NIP-04, NIP-44)
- Public key management

### Relay System

The SDK uses a sophisticated relay management system:

- **RelayPool** (lib/relay/relay_pool.dart:16): Manages multiple relay connections
- **Connection Types**: Normal relays, temporary relays, cache relays
- **Subscription Management**: Handle multiple subscriptions across relays
- **Load Balancing**: Distribute queries across available relays

### Local Storage

Built-in SQLite support for offline functionality:
- Event caching
- Relay metadata storage
- Cross-platform database utilities

## File Structure

```
lib/
├── nostr.dart              # Main Nostr client
├── event.dart              # Event class and utilities
├── event_kind.dart         # Event type constants
├── signer/                 # Signing implementations
│   ├── nostr_signer.dart
│   ├── local_nostr_signer.dart
│   └── pubkey_only_nostr_signer.dart
├── relay/                  # Relay management
│   ├── relay_pool.dart
│   ├── relay.dart
│   └── event_filter.dart
├── nip02/                  # Contact lists
├── nip04/                  # Encrypted DMs (deprecated)
├── nip44/                  # Versioned encryption
├── nip46/                  # Remote signing
├── nip47/                  # Wallet connect
├── [nip**]/                # Other NIP implementations
├── upload/                 # File upload services
├── zap/                    # Lightning payments
└── utils/                  # Utility functions
```

## Error Handling

```dart
try {
  final event = await nostr.sendEvent(myEvent);
  if (event == null) {
    print('Failed to send event - check connection and signing');
  }
} catch (e) {
  print('Error: $e');
}

// Check relay connectivity
if (!nostr.writable()) {
  print('No writable relays available');
}

if (!nostr.readable()) {
  print('No readable relays available');
}
```

## Testing

The SDK includes comprehensive testing utilities:

```dart
import 'package:nostr_sdk/signer/signer_test.dart';

// Test signer implementations
final testResults = await runSignerTests(mySigner);
```

## Performance Considerations

### Optimization Best Practices

- **Event Filtering**: Use specific filters to reduce bandwidth and processing
- **Relay Selection**: Choose relays geographically close to your users
- **Subscription Management**: Unsubscribe from unused subscriptions to reduce memory usage
- **Local Caching**: Enable local storage for better performance and offline support
- **Connection Pooling**: Reuse relay connections when possible
- **Batch Operations**: Use `deleteEvents()` instead of multiple `deleteEvent()` calls

### Memory Management

```dart
// Limit subscription results
final subscription = nostr.subscribe([
  {
    'kinds': [EventKind.TEXT_NOTE],
    'limit': 50, // Limit to recent events
    'since': DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  }
], onEvent);

// Clean up subscriptions periodically
Timer.periodic(Duration(minutes: 5), (timer) {
  // Remove old subscriptions and cleanup memory
  nostr.unsubscribe(oldSubscriptionId);
});
```

### Relay Health Monitoring

```dart
// Check relay status
final activeRelays = nostr.activeRelays();
print('Active relays: ${activeRelays.length}');

for (final relay in activeRelays) {
  print('${relay.url}: ${relay.relayStatus.connected}');
  print('  Read: ${relay.relayStatus.readAccess}');
  print('  Write: ${relay.relayStatus.writeAccess}');
}

// Monitor connectivity
if (!nostr.readable()) {
  print('⚠️ No readable relays available');
  // Maybe try reconnecting or adding backup relays
}

if (!nostr.writable()) {
  print('⚠️ No writable relays available'); 
  // User can read but not post
}
```

## Troubleshooting

### Common Issues

#### Connection Problems
```dart
// Problem: Relays not connecting
// Solution: Check WebSocket connectivity and try alternative relays

final backupRelays = [
  'wss://relay.nostr.band',
  'wss://nostr.wine',
  'wss://relay.current.fyi',
];

for (final relay in backupRelays) {
  final success = await nostr.addRelay(Relay(relay));
  if (success) break;
}
```

#### Event Not Sending
```dart
// Problem: Events fail to send
// Solution: Check signing and relay write access

try {
  final event = Event(publicKey, EventKind.TEXT_NOTE, [], content);
  
  // Ensure event is properly signed
  await nostr.signEvent(event);
  if (event.sig.isEmpty) {
    throw Exception('Event signing failed');
  }
  
  // Check write access
  if (!nostr.writable()) {
    throw Exception('No writable relays available');
  }
  
  final sent = await nostr.sendEvent(event);
  if (sent == null) {
    throw Exception('Event rejected by all relays');
  }
} catch (e) {
  print('Send error: $e');
}
```

#### Subscription Not Receiving Events
```dart
// Problem: Subscription receives no events
// Solution: Check filters and relay connectivity

// Test with broader filter first
final testSub = nostr.subscribe([
  {
    'kinds': [EventKind.TEXT_NOTE],
    'limit': 10, // Start small
  }
], (event) {
  print('✅ Subscription working: ${event.content}');
});

// Check if any relays support reading
if (!nostr.readable()) {
  print('❌ No readable relays');
  // Add more relays or check network connectivity
}
```

#### Memory Issues
```dart
// Problem: App consuming too much memory
// Solution: Implement proper cleanup and limits

class EventCache {
  final int maxEvents = 1000;
  final List<Event> _events = [];

  void addEvent(Event event) {
    _events.add(event);
    if (_events.length > maxEvents) {
      _events.removeAt(0); // Remove oldest
    }
  }

  void clear() {
    _events.clear();
  }
}
```

### Debug Mode

```dart
// Enable verbose logging for debugging
import 'dart:developer' as dev;

// Log all events
final debugSub = nostr.subscribe([
  {'kinds': [1, 6, 7]} // Text notes, reposts, reactions
], (event) {
  dev.log('Event received: ${event.toJson()}');
});

// Monitor relay messages
final nostr = Nostr(
  signer,
  publicKey,
  eventFilters,
  tempRelayGenerator,
  onNotice: (relay, notice) {
    dev.log('Relay notice from $relay: $notice');
  },
);
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Follow the existing code style and patterns
4. Add tests for new functionality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is extracted from [nostrmo](https://github.com/haorendashu/nostrmo) and maintains the same licensing terms.

## Support

- 🐛 **Issues**: Report bugs and request features on GitHub
- 📖 **Documentation**: Additional docs available in `/docs` directory
- 💬 **Community**: Join Nostr development discussions

## Roadmap

- [ ] Complete NIP implementation coverage
- [ ] Performance optimizations
- [ ] Enhanced testing suite
- [ ] Production stability improvements
- [ ] Documentation expansion
- [ ] Example applications

---

**Note**: This SDK is under active development. APIs may change between versions. Check the changelog and migration guides when upgrading.