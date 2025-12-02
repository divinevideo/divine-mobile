# API Reference

ABOUTME: Complete reference documentation for all Nostr SDK public APIs and interfaces
ABOUTME: Comprehensive guide covering classes, methods, examples and implementation patterns

Complete reference for the Nostr SDK public APIs and implementation examples.

## Core Classes

### Nostr

The main client class for interacting with the Nostr network.

#### Constructor

```dart
Nostr(
  NostrSigner nostrSigner,
  String publicKey,
  List<EventFilter> eventFilters,
  Relay Function(String) tempRelayGener,
  {Function(String, String)? onNotice}
)
```

**Parameters:**
- `nostrSigner`: Implementation of signing interface
- `publicKey`: User's public key (hex format)
- `eventFilters`: Default filters for subscriptions
- `tempRelayGener`: Function to create temporary relay connections
- `onNotice`: Optional callback for relay notices

#### Properties

```dart
String get publicKey          // User's public key
NostrSigner nostrSigner      // Current signer implementation
```

#### Event Methods

##### sendEvent()
```dart
Future<Event?> sendEvent(
  Event event,
  {List<String>? tempRelays, List<String>? targetRelays}
)
```
Send a signed event to relays.

**Parameters:**
- `event`: The event to send
- `tempRelays`: Optional list of temporary relay URLs
- `targetRelays`: Optional list of specific relay URLs

**Returns:** The sent event with ID and signature, or null if failed

##### sendLike()
```dart
Future<Event?> sendLike(
  String id,
  {String? pubkey, String? content, List<String>? tempRelays, List<String>? targetRelays}
)
```
Send a reaction/like event.

**Parameters:**
- `id`: Event ID to react to
- `pubkey`: Optional target public key
- `content`: Reaction content (default: "+")
- `tempRelays`: Optional temporary relays
- `targetRelays`: Optional target relays

##### sendRepost()
```dart
Future<Event?> sendRepost(
  String id,
  {String? relayAddr, String content = "", List<String>? tempRelays, List<String>? targetRelays}
)
```
Send a repost event.

**Parameters:**
- `id`: Event ID to repost
- `relayAddr`: Optional relay address where original event was seen
- `content`: Optional additional content
- `tempRelays`: Optional temporary relays
- `targetRelays`: Optional target relays

##### deleteEvent()
```dart
Future<Event?> deleteEvent(
  String eventId,
  {List<String>? tempRelays, List<String>? targetRelays}
)
```
Send a deletion event for a specific event.

##### deleteEvents()
```dart
Future<Event?> deleteEvents(
  List<String> eventIds,
  {List<String>? tempRelays, List<String>? targetRelays}
)
```
Send a deletion event for multiple events.

##### sendContactList()
```dart
Future<Event?> sendContactList(
  ContactList contacts,
  String content,
  {List<String>? tempRelays, List<String>? targetRelays}
)
```
Send a contact list event (NIP-02).

#### Subscription Methods

##### subscribe()
```dart
String subscribe(
  List<Map<String, dynamic>> filters,
  Function(Event) onEvent,
  {String? id, List<String>? tempRelays, List<String>? targetRelays, List<int> relayTypes = RelayType.ALL, bool sendAfterAuth = false}
)
```
Create a persistent subscription.

**Parameters:**
- `filters`: Nostr filters (JSON format)
- `onEvent`: Callback for received events
- `id`: Optional subscription ID
- `tempRelays`: Optional temporary relays
- `targetRelays`: Optional target relays
- `relayTypes`: Types of relays to use
- `sendAfterAuth`: Send subscription after relay authentication

**Returns:** Subscription ID

##### query()
```dart
String query(
  List<Map<String, dynamic>> filters,
  Function(Event) onEvent,
  {String? id, Function? onComplete, List<String>? tempRelays, List<String>? targetRelays, List<int> relayTypes = RelayType.ALL, bool sendAfterAuth = false}
)
```
Create a one-time query subscription.

**Parameters:**
- `filters`: Nostr filters
- `onEvent`: Callback for received events
- `id`: Optional query ID
- `onComplete`: Callback when query completes
- `tempRelays`: Optional temporary relays
- `targetRelays`: Optional target relays
- `relayTypes`: Types of relays to use
- `sendAfterAuth`: Send query after relay authentication

##### queryEvents()
```dart
Future<List<Event>> queryEvents(
  List<Map<String, dynamic>> filters,
  {String? id, List<String>? tempRelays, List<int> relayTypes = RelayType.ALL, bool sendAfterAuth = false}
)
```
Query events and return as a Future.

**Returns:** List of events matching the filters

##### unsubscribe()
```dart
void unsubscribe(String id)
```
Cancel a subscription by ID.

#### Relay Management

##### addRelay()
```dart
Future<bool> addRelay(
  Relay relay,
  {bool autoSubscribe = false, bool init = false, int relayType = RelayType.NORMAL}
)
```
Add a relay to the pool.

**Parameters:**
- `relay`: Relay instance to add
- `autoSubscribe`: Automatically subscribe to default filters
- `init`: Mark as initialization relay
- `relayType`: Type of relay (normal, cache, etc.)

##### removeRelay()
```dart
void removeRelay(String url, {int relayType = RelayType.NORMAL})
```
Remove a relay from the pool.

##### activeRelays()
```dart
List<Relay> activeRelays()
```
Get list of currently active relays.

##### getRelay()
```dart
Relay? getRelay(String url)
```
Get a specific relay by URL.

#### Utility Methods

##### signEvent()
```dart
Future<void> signEvent(Event event)
```
Sign an event using the current signer.

##### close()
```dart
void close()
```
Close all connections and cleanup resources.

##### readable()
```dart
bool readable()
```
Check if any relays are available for reading.

##### writable()
```dart
bool writable()
```
Check if any relays are available for writing.

##### isReadOnly()
```dart
bool isReadOnly()
```
Check if running in read-only mode.

### Event

Represents a Nostr event.

#### Constructor

```dart
Event(
  String pubkey,
  int kind,
  List<dynamic> tags,
  String content,
  {int? createdAt}
)
```

**Parameters:**
- `pubkey`: Author's public key (hex)
- `kind`: Event kind (see EventKind constants)
- `tags`: Array of tags
- `content`: Event content
- `createdAt`: Optional timestamp (defaults to current time)

#### Factory Constructors

##### fromJson()
```dart
factory Event.fromJson(Map<String, dynamic> data)
```
Create event from JSON data.

#### Properties

```dart
String id              // Event ID (SHA256 hash)
String pubkey          // Author's public key
int createdAt          // Creation timestamp
int kind              // Event kind
List<dynamic> tags    // Event tags
String content        // Event content
String sig            // Schnorr signature
List<String> sources  // Relay sources
bool cacheEvent       // Cache relay flag
```

#### Methods

##### toJson()
```dart
Map<String, dynamic> toJson()
```
Convert event to JSON format.

##### sign()
```dart
void sign(String privateKey)
```
Sign the event with a private key.

##### doProofOfWork()
```dart
void doProofOfWork(int difficulty)
```
Perform proof-of-work on the event.

**Parameters:**
- `difficulty`: PoW difficulty level

#### Validation Properties

```dart
bool get isValid       // Check if event data is valid
bool get isSigned      // Check if signature is valid
```

### EventKind

Constants for Nostr event kinds.

```dart
class EventKind {
  static const int METADATA = 0;
  static const int TEXT_NOTE = 1;
  static const int RECOMMEND_SERVER = 2;
  static const int CONTACT_LIST = 3;
  static const int DIRECT_MESSAGE = 4;
  static const int EVENT_DELETION = 5;
  static const int REPOST = 6;
  static const int REACTION = 7;
  static const int BADGE_AWARD = 8;
  static const int GROUP_CHAT_MESSAGE = 9;
  static const int GROUP_NOTE = 11;
  static const int SEAL_EVENT_KIND = 13;
  static const int PRIVATE_DIRECT_MESSAGE = 14;
  static const int GENERIC_REPOST = 16;
  static const int PICTURE = 20;
  static const int GIFT_WRAP = 1059;
  static const int FILE_HEADER = 1063;
  static const int STORAGE_SHARED_FILE = 1064;
  static const int COMMENT = 1111;
  static const int TORRENTS = 2003;
  static const int COMMUNITY_APPROVED = 4550;
  static const int POLL = 6969;
  static const int GROUP_ADD_USER = 9000;
  static const int GROUP_REMOVE_USER = 9001;
  static const int GROUP_EDIT_METADATA = 9002;
  static const int GROUP_ADD_PERMISSION = 9003;
  static const int GROUP_REMOVE_PERMISSION = 9004;
  static const int GROUP_DELETE_EVENT = 9005;
  static const int GROUP_EDIT_STATUS = 9006;
  static const int GROUP_CREATE_GROUP = 9007;
  static const int GROUP_JOIN = 9021;
  static const int ZAP_GOALS = 9041;
  static const int ZAP_REQUEST = 9734;
  static const int ZAP = 9735;
  static const int RELAY_LIST_METADATA = 10002;
  static const int BOOKMARKS_LIST = 10003;
  static const int GROUP_LIST = 10009;
  static const int EMOJIS_LIST = 10030;
  static const int NWC_INFO_EVENT = 13194;
  static const int AUTHENTICATION = 22242;
  static const int NWC_REQUEST_EVENT = 23194;
  static const int NWC_RESPONSE_EVENT = 23195;
  static const int NOSTR_REMOTE_SIGNING = 24133;
  static const int BLOSSOM_HTTP_AUTH = 24242;
  static const int HTTP_AUTH = 27235;
  static const int FOLLOW_SETS = 30000;
  static const int BADGE_ACCEPT = 30008;
  static const int BADGE_DEFINITION = 30009;
  static const int LONG_FORM = 30023;
  static const int LONG_FORM_LINKED = 30024;
  static const int LIVE_EVENT = 30311;
  static const int COMMUNITY_DEFINITION = 34550;
  static const int VIDEO_HORIZONTAL = 34235;
  static const int VIDEO_VERTICAL = 34236;
  static const int GROUP_METADATA = 39000;
  static const int GROUP_ADMINS = 39001;
  static const int GROUP_MEMBERS = 39002;
}
```

## Signing Interfaces

### NostrSigner

Abstract base class for all signing implementations.

```dart
abstract class NostrSigner {
  Future<String?> getPublicKey();
  Future<Event?> signEvent(Event event);
  Future<Map?> getRelays();
  Future<String?> encrypt(pubkey, plaintext);      // NIP-04
  Future<String?> decrypt(pubkey, ciphertext);     // NIP-04
  Future<String?> nip44Encrypt(pubkey, plaintext); // NIP-44
  Future<String?> nip44Decrypt(pubkey, ciphertext); // NIP-44
  void close();
}
```

### LocalNostrSigner

Local private key signing implementation.

#### Constructors

```dart
LocalNostrSigner.fromPrivateKey(String privateKey)
LocalNostrSigner.generate()  // Generates new key pair
```

### PubkeyOnlyNostrSigner

Read-only signer for public key operations.

```dart
PubkeyOnlyNostrSigner(String publicKey)
```

### NostrRemoteSigner

NIP-46 remote signing implementation.

```dart
NostrRemoteSigner({
  required String remoteSignerPubkey,
  required String relayUrl,
  // ... additional parameters
})
```

## Filter Objects

### EventFilter

Used for creating Nostr filters.

```dart
EventFilter({
  List<String>? ids,
  List<String>? authors,
  List<int>? kinds,
  Map<String, List<String>>? tags,
  int? since,
  int? until,
  int? limit,
})
```

**Properties:**
- `ids`: List of event IDs
- `authors`: List of author public keys
- `kinds`: List of event kinds
- `tags`: Map of tag filters (e.g., {"#e": ["event_id"]})
- `since`: Unix timestamp, events after this time
- `until`: Unix timestamp, events before this time
- `limit`: Maximum number of events

## Relay Management

### Relay

Represents a connection to a Nostr relay.

```dart
Relay(String url, {RelayStatus? status})
```

### RelayType

Constants for relay types:

```dart
class RelayType {
  static const int NORMAL = 1;
  static const int TEMP = 2;
  static const int CACHE = 4;
  static const List<int> ALL = [NORMAL, TEMP, CACHE];
}
```

## Error Handling

### Common Exceptions

- `ArgumentError`: Invalid parameters
- `StateError`: Invalid state operations
- `FormatException`: Invalid data formats
- `TimeoutException`: Network timeouts

### Error Checking Patterns

```dart
// Check event sending result
final event = await nostr.sendEvent(myEvent);
if (event == null) {
  // Handle send failure
}

// Check relay connectivity
if (!nostr.writable()) {
  // No writable relays available
}

// Validate events
if (!event.isValid) {
  // Invalid event structure
}

if (!event.isSigned) {
  // Invalid signature
}
```

## Constants and Enums

### RelayStatus

```dart
enum RelayStatus {
  init,
  connecting,
  connected,
  error,
  closed
}
```

### Common Filter Examples

```dart
// Text notes from specific author
{
  'kinds': [EventKind.TEXT_NOTE],
  'authors': ['author_pubkey'],
  'limit': 50
}

// Reactions to specific event
{
  'kinds': [EventKind.REACTION],
  '#e': ['event_id']
}

// Recent metadata events
{
  'kinds': [EventKind.METADATA],
  'since': DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch ~/ 1000
}
```

## NIP Implementations

### NIP-19 (Bech32 Encoding)

The `Nip19` class provides encoding and decoding of Nostr entities.

```dart
class Nip19 {
  static String encodePubKey(String pubkey);
  static String encodePrivateKey(String privateKey);
  static String encodeNoteId(String id);
  static String encodeSimplePubKey(String pubkey);
  static String decode(String npub);
  static bool isPubkey(String str);
  static bool isPrivateKey(String str);
  static bool isNoteId(String str);
}
```

**Examples:**
```dart
// Encode public key to npub format
final npub = Nip19.encodePubKey('hex_public_key');
// Result: npub1...

// Decode npub back to hex
final hexPubkey = Nip19.decode(npub);

// Create shortened display format
final shortKey = Nip19.encodeSimplePubKey(publicKey);
// Result: npub1a:bcdef2

// Validation
if (Nip19.isPubkey(someString)) {
  final decoded = Nip19.decode(someString);
}
```

### NIP-02 (Contact Lists)

```dart
class ContactList {
  List<Contact> contacts = [];
  
  void add(Contact contact);
  void remove(String pubkey);
  Contact? getContact(String pubkey);
  List<List<dynamic>> toJson();
  static ContactList fromJson(List<dynamic> tags);
}

class Contact {
  final String pubkey;
  final String? relay;
  final String? petname;
  
  Contact({required this.pubkey, this.relay, this.petname});
}
```

**Example:**
```dart
// Create contact list
final contacts = ContactList();
contacts.add(Contact(
  pubkey: 'friend_pubkey',
  relay: 'wss://relay.damus.io',
  petname: 'Alice'
));

// Send to network
await nostr.sendContactList(contacts, 'My follow list');
```

### NIP-29 (Relay-based Groups)

```dart
class NIP29 {
  static Future<void> addMember(Nostr nostr, GroupIdentifier group, String pubkey);
  static Future<void> removeMember(Nostr nostr, GroupIdentifier group, String pubkey);
  static Future<void> deleteEvent(Nostr nostr, GroupIdentifier group, String eventId);
  static Future<void> editStatus(Nostr nostr, GroupIdentifier group, bool? public, bool? open);
}

class GroupIdentifier {
  final String groupId;
  final String host;
  
  GroupIdentifier(this.groupId, this.host);
}
```

**Example:**
```dart
final group = GroupIdentifier('my-group', 'wss://groups.relay.com');

// Add member to group
await NIP29.addMember(nostr, group, memberPubkey);

// Change group visibility
await NIP29.editStatus(nostr, group, public: false, open: true);
```

### NIP-44 (Versioned Encryption)

Modern encryption support integrated into signers:

```dart
// Using NIP-44 encryption (recommended over NIP-04)
final encrypted = await signer.nip44Encrypt(recipientPubkey, 'Secret message');
final decrypted = await signer.nip44Decrypt(senderPubkey, encrypted);
```

### NIP-46 (Remote Signing)

```dart
class NostrRemoteSigner implements NostrSigner {
  NostrRemoteSigner({
    required String remoteSignerPubkey,
    required String relayUrl,
    String? secretKey,
  });
  
  // Implements all NostrSigner methods via remote calls
}
```

**Example:**
```dart
final remoteSigner = NostrRemoteSigner(
  remoteSignerPubkey: 'npub...',
  relayUrl: 'wss://relay.example.com',
);

final nostr = Nostr(remoteSigner, publicKey, filters, tempRelayGenerator);
```

## File Upload Implementations

### Upload Utilities

```dart
class UploadUtil {
  static String getFileType(String filePath);
}
```

### NIP-96 Uploader

```dart
class Nip96Uploader {
  final String serverUrl;
  
  Nip96Uploader(this.serverUrl);
  
  Future<UploadResult> upload(Uint8List fileBytes, String fileName);
}
```

### Blossom Uploader

```dart
class BlossomUploader {
  final String serverUrl;
  
  BlossomUploader(this.serverUrl);
  
  Future<UploadResult> upload(Uint8List fileBytes, NostrSigner signer);
}
```

**Example:**
```dart
// Upload via NIP-96
final uploader = Nip96Uploader('https://nostr.build');
final result = await uploader.upload(imageBytes, 'photo.jpg');

if (result.success) {
  // Create event with uploaded file
  final fileEvent = Event(
    publicKey,
    EventKind.TEXT_NOTE,
    [['r', result.url]],
    'Check out this image!',
  );
  await nostr.sendEvent(fileEvent);
}
```

## Database and Local Storage

### Relay Local Storage

```dart
class RelayLocal extends Relay {
  // Local SQLite-based relay implementation
  Future<void> broadcaseToLocal(Map<String, dynamic> event);
  // Stores events locally for offline access
}
```

### Database Utilities

```dart
class DbUtil {
  static Future<Database> getDatabase();
  static String getDocumentDir();
  // Platform-specific database utilities
}
```

## Utility Classes

### Date Formatting

```dart
class DateFormatUtil {
  static String formatTimestamp(int timestamp);
  static String timeAgo(int timestamp);
  // Human-readable date formatting
}
```

### String Utilities

```dart
class StringUtil {
  static bool isBlank(String? str);
  static bool isNotBlank(String? str);
  static String rndNameStr(int length);
  // Common string operations
}
```

### Hash Utilities

```dart
class HashUtil {
  static String sha256(String input);
  static String hmacSha256(String key, String message);
  // Cryptographic hash functions
}
```

## Advanced Event Patterns

### Proof of Work Events

```dart
// Add proof-of-work to events
final event = Event(publicKey, EventKind.TEXT_NOTE, [], content);
event.doProofOfWork(8); // 8-bit difficulty
await nostr.sendEvent(event);
```

### Tagged Events

```dart
// Create richly tagged events
final taggedEvent = Event(
  publicKey,
  EventKind.TEXT_NOTE,
  [
    ['e', replyToEventId, 'wss://relay.damus.io', 'reply'],
    ['p', mentionedPubkey, '', 'mention'],
    ['t', 'nostr'],
    ['t', 'programming'],
    ['r', 'https://example.com'],
    ['client', 'my-nostr-app'],
  ],
  'This is a reply with hashtags and mentions',
);
```

### Event Validation

```dart
// Validate events before processing
if (event.isValid && event.isSigned) {
  // Process valid, signed event
  processEvent(event);
} else {
  print('Invalid event: ${event.id}');
}
```

## Error Handling Patterns

### Comprehensive Error Handling

```dart
try {
  final event = await nostr.sendEvent(myEvent);
  if (event == null) {
    throw NostrException('Event rejected by all relays');
  }
} on TimeoutException {
  print('Network timeout - try again later');
} on FormatException catch (e) {
  print('Invalid event format: $e');
} on ArgumentError catch (e) {
  print('Invalid arguments: $e');
} catch (e) {
  print('Unexpected error: $e');
}
```

### Relay Status Checking

```dart
// Check individual relay status
for (final relay in nostr.activeRelays()) {
  switch (relay.relayStatus.connected) {
    case ClientConnected.CONNECTED:
      print('${relay.url} is connected');
      break;
    case ClientConnected.CONNECTING:
      print('${relay.url} is connecting...');
      break;
    case ClientConnected.UN_CONNECT:
      print('${relay.url} is disconnected');
      break;
  }
}
```

## Platform-Specific Features

### Android Integration

```dart
// NIP-55 Android signer integration
class AndroidNostrSigner implements NostrSigner {
  // Integrates with Android Nostr apps for signing
}

// Android content provider access
class AndroidPlugin {
  static Future<String?> getContentFromProvider(String uri);
  // Access shared content from other Android apps
}
```

### Cross-Platform Considerations

```dart
// Platform-aware initialization
if (Platform.isAndroid || Platform.isIOS) {
  // Mobile-specific setup
  await initMobileFeatures();
} else if (kIsWeb) {
  // Web-specific setup
  await initWebFeatures();
} else {
  // Desktop setup
  await initDesktopFeatures();
}
```

This comprehensive API reference covers all major components and patterns in the Nostr SDK. For detailed implementation examples and architectural guidance, refer to the main README.md and ARCHITECTURE.md files.