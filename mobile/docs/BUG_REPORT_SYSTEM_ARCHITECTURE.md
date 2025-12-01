# Bug Report System Architecture for diVine

**Version**: 1.0
**Author**: Architecture Design
**Date**: 2025-10-18
**Status**: Design Phase

## Executive Summary

This document defines the complete architecture for diVine's user-initiated bug report system. The system enables users to send comprehensive diagnostic reports for non-crash issues using **NIP-17 encrypted messages** to diVine support.

**Key Features**:
- Circular buffer log capture (recent 1000 entries, ~1MB max)
- Comprehensive diagnostic data collection
- Privacy-preserving NIP-17 encryption
- In-app bug report UI with optional user description
- Automatic sanitization of sensitive data

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Components](#architecture-components)
3. [Data Structures](#data-structures)
4. [NIP-17 Integration](#nip-17-integration)
5. [Implementation Plan](#implementation-plan)
6. [Test Strategy](#test-strategy)
7. [Privacy & Security](#privacy--security)
8. [Future Enhancements](#future-enhancements)

---

## 1. System Overview

### Current Error Handling Ecosystem

diVine already has robust error tracking:
- **UnifiedLogger**: Structured logging with categories (relay, video, ui, auth, storage, api, system)
- **ErrorAnalyticsTracker**: Comprehensive error tracking to Firebase Analytics
- **Firebase Crashlytics**: Automatic crash reporting

**Gap**: Users cannot manually report non-crash bugs with full diagnostic context.

### Bug Report System Goals

1. **User-Initiated**: Users can trigger bug reports from Settings or in-app dialog
2. **Comprehensive**: Include recent logs, device info, relay status, error counts
3. **Private**: NIP-17 encrypted messages ensure only support can read reports
4. **Non-Intrusive**: Minimal UI disruption, background log buffering
5. **Privacy-Safe**: Automatic sanitization of sensitive data (nsecs, passwords, private keys)

---

## 2. Architecture Components

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          UI Layer                               │
├─────────────────────────────────────────────────────────────────┤
│  SettingsScreen          BugReportDialog          AppErrorWidget│
│  [Report Bug Button]     [Description Input]      [Report Icon]  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     BugReportService                            │
├─────────────────────────────────────────────────────────────────┤
│  - collectDiagnostics()                                          │
│  - sanitizeSensitiveData()                                       │
│  - sendBugReport()                                               │
│  - getReportHistory()                                            │
└─────────────────────────────────────────────────────────────────┘
                    │                           │
                    ▼                           ▼
    ┌───────────────────────────┐   ┌───────────────────────────┐
    │   LogCaptureService       │   │   NIP17MessageService     │
    ├───────────────────────────┤   ├───────────────────────────┤
    │ - Circular buffer (1000)  │   │ - createKind14Message()   │
    │ - captureLog()            │   │ - sealMessage()           │
    │ - getRecentLogs()         │   │ - giftWrapMessage()       │
    │ - clearBuffer()           │   │ - sendEncryptedMessage()  │
    └───────────────────────────┘   └───────────────────────────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  ▼
                    ┌───────────────────────────┐
                    │  Existing Services        │
                    ├───────────────────────────┤
                    │  - UnifiedLogger          │
                    │  - ErrorAnalyticsTracker  │
                    │  - NostrService           │
                    │  - ProofModeAttestation   │
                    │  - AuthService            │
                    └───────────────────────────┘
```

---

## 3. Data Structures

### 3.1 LogEntry

```dart
// lib/models/log_entry.dart

/// Represents a single log entry in the circular buffer
class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.category,
    this.name,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final LogCategory? category;
  final String? name;
  final String? error;
  final String? stackTrace;

  /// Convert to JSON for bug report
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'message': message,
        'category': category?.name,
        'name': name,
        'error': error,
        'stackTrace': stackTrace,
      };

  /// Create from JSON
  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: LogLevel.fromString(json['level'] as String),
        message: json['message'] as String,
        category: json['category'] != null
            ? LogCategory.fromString(json['category'] as String)
            : null,
        name: json['name'] as String?,
        error: json['error'] as String?,
        stackTrace: json['stackTrace'] as String?,
      );
}
```

### 3.2 BugReportData

```dart
// lib/models/bug_report_data.dart

/// Complete diagnostic data for a bug report
class BugReportData {
  const BugReportData({
    required this.reportId,
    required this.timestamp,
    required this.userDescription,
    required this.deviceInfo,
    required this.appVersion,
    required this.recentLogs,
    required this.errorCounts,
    required this.relayStatus,
    this.currentScreen,
    this.userPubkey,
    this.additionalContext,
  });

  final String reportId; // UUID for tracking
  final DateTime timestamp;
  final String userDescription;
  final Map<String, dynamic> deviceInfo; // From ProofModeAttestationService
  final String appVersion; // From package_info_plus
  final List<LogEntry> recentLogs; // Last 1000 from buffer
  final Map<String, int> errorCounts; // From ErrorAnalyticsTracker
  final Map<String, dynamic> relayStatus; // From NostrService
  final String? currentScreen; // Active route/screen
  final String? userPubkey; // Anonymous if not logged in
  final Map<String, dynamic>? additionalContext;

  /// Convert to JSON for NIP-17 message
  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'timestamp': timestamp.toIso8601String(),
        'userDescription': userDescription,
        'deviceInfo': deviceInfo,
        'appVersion': appVersion,
        'recentLogs': recentLogs.map((log) => log.toJson()).toList(),
        'errorCounts': errorCounts,
        'relayStatus': relayStatus,
        'currentScreen': currentScreen,
        'userPubkey': userPubkey,
        'additionalContext': additionalContext,
      };

  /// Create formatted report text for NIP-17 message content
  String toFormattedReport() {
    final buffer = StringBuffer();

    buffer.writeln('🐛 diVine Bug Report');
    buffer.writeln('═' * 50);
    buffer.writeln('Report ID: $reportId');
    buffer.writeln('Timestamp: ${timestamp.toIso8601String()}');
    buffer.writeln('Version: $appVersion');
    buffer.writeln();

    buffer.writeln('📝 User Description:');
    buffer.writeln(userDescription);
    buffer.writeln();

    buffer.writeln('📱 Device Info:');
    deviceInfo.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    buffer.writeln();

    buffer.writeln('📡 Relay Status:');
    relayStatus.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    buffer.writeln();

    if (errorCounts.isNotEmpty) {
      buffer.writeln('❌ Recent Errors:');
      errorCounts.forEach((error, count) {
        buffer.writeln('  $error: $count occurrences');
      });
      buffer.writeln();
    }

    buffer.writeln('📋 Recent Logs (${recentLogs.length} entries):');
    buffer.writeln('See attached JSON for full log data');

    return buffer.toString();
  }
}
```

### 3.3 BugReportResult

```dart
// lib/models/bug_report_result.dart

/// Result of bug report submission
class BugReportResult {
  const BugReportResult({
    required this.success,
    this.reportId,
    this.messageEventId,
    this.error,
    this.timestamp,
  });

  final bool success;
  final String? reportId;
  final String? messageEventId; // NIP-17 gift wrap event ID
  final String? error;
  final DateTime? timestamp;

  static BugReportResult createSuccess({
    required String reportId,
    required String messageEventId,
  }) =>
      BugReportResult(
        success: true,
        reportId: reportId,
        messageEventId: messageEventId,
        timestamp: DateTime.now(),
      );

  static BugReportResult failure(String error) =>
      BugReportResult(success: false, error: error);
}
```

---

## 4. NIP-17 Integration

### 4.1 NIP-17 Message Structure

NIP-17 uses **three-layer encryption** for maximum privacy:

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Gift Wrap (kind 1059)                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ - Signed with RANDOM keypair (anonymity)                    │ │
│ │ - Timestamp randomized (up to 2 days in past)               │ │
│ │ - Encrypted to RECIPIENT pubkey with NIP-44                 │ │
│ │ ┌─────────────────────────────────────────────────────────┐ │ │
│ │ │ Layer 2: Seal (kind 13)                                 │ │ │
│ │ │ ┌───────────────────────────────────────────────────────┐│ │ │
│ │ │ │ - Signed with SENDER's actual keypair               ││ │ │
│ │ │ │ - Encrypted to RECIPIENT pubkey with NIP-44         ││ │ │
│ │ │ │ ┌─────────────────────────────────────────────────┐ ││ │ │
│ │ │ │ │ Layer 1: Chat Message (kind 14)                │ ││ │ │
│ │ │ │ │ ┌───────────────────────────────────────────┐   │ ││ │ │
│ │ │ │ │ │ - UNSIGNED (prevents signature leak)     │   │ ││ │ │
│ │ │ │ │ │ - Plain JSON bug report data             │   │ ││ │ │
│ │ │ │ │ │ - p-tag: recipient pubkey                │   │ ││ │ │
│ │ │ │ │ │ - client-tag: "openvine_bug_report"      │   │ ││ │ │
│ │ │ │ │ └───────────────────────────────────────────┘   │ ││ │ │
│ │ │ │ └─────────────────────────────────────────────────┘ ││ │ │
│ │ │ └───────────────────────────────────────────────────────┘│ │ │
│ │ └─────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 NIP-17 Service Interface

```dart
// lib/services/nip17_message_service.dart

/// Service for creating and sending NIP-17 encrypted messages
class NIP17MessageService {
  NIP17MessageService({
    required INostrService nostrService,
    required AuthService authService,
  })  : _nostrService = nostrService,
        _authService = authService;

  final INostrService _nostrService;
  final AuthService _authService;

  /// Send NIP-17 encrypted message to recipient
  Future<NIP17SendResult> sendPrivateMessage({
    required String recipientPubkey,
    required String content,
    List<List<String>> additionalTags = const [],
  }) async {
    // Implementation details in Phase 3
  }

  /// Create unsigned kind 14 chat message
  Map<String, dynamic> _createKind14Message({
    required String recipientPubkey,
    required String content,
    List<List<String>> additionalTags = const [],
  }) {
    // Kind 14 must be UNSIGNED
    return {
      'kind': 14,
      'content': content,
      'created_at': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      'tags': [
        ['p', recipientPubkey],
        ['client', 'diVine_bug_report'],
        ...additionalTags,
      ],
    };
  }

  /// Seal the kind 14 message (create kind 13)
  Future<Event> _sealMessage({
    required Map<String, dynamic> kind14,
    required String recipientPubkey,
  }) async {
    // Encrypt kind14 JSON with NIP-44 to recipient
    // Sign with sender's actual keys
    // Return kind 13 sealed event
  }

  /// Gift wrap the sealed message (create kind 1059)
  Future<Event> _giftWrapMessage({
    required Event sealedEvent,
    required String recipientPubkey,
  }) async {
    // Generate random keypair for anonymity
    // Encrypt sealed event with NIP-44 to recipient
    // Randomize timestamp (up to 2 days in past)
    // Sign with random keypair
    // Return kind 1059 gift wrap event
  }
}
```

### 4.3 Bug Report Recipient Configuration

```dart
// lib/config/bug_report_config.dart

/// Configuration for bug report system
class BugReportConfig {
  /// diVine support pubkey for receiving bug reports
  static const String supportPubkey =
      'YOUR_SUPPORT_PUBKEY_HERE'; // TODO: Set actual support pubkey

  /// Maximum log entries to include in bug report
  static const int maxLogEntries = 1000;

  /// Maximum bug report size in bytes (~1MB)
  static const int maxReportSizeBytes = 1024 * 1024;

  /// Sensitive data patterns to sanitize
  static final List<RegExp> sensitivePatterns = [
    RegExp(r'nsec1[a-z0-9]{58}', caseSensitive: false), // nsec keys
    RegExp(r'[0-9a-fA-F]{64}'), // Hex private keys (64 chars)
    RegExp(r'password[:\s=]+\S+', caseSensitive: false),
    RegExp(r'token[:\s=]+\S+', caseSensitive: false),
    RegExp(r'secret[:\s=]+\S+', caseSensitive: false),
  ];
}
```

---

## 5. Implementation Plan

### Phase 1: LogCaptureService (TDD)

**Objective**: Create circular buffer for log capture

**Files to Create**:
- `lib/models/log_entry.dart`
- `lib/services/log_capture_service.dart`
- `test/unit/services/log_capture_service_test.dart`

**TDD Steps**:

1. **Write failing test**: Buffer stores logs
   ```dart
   test('captureLog should store log entry in buffer', () {
     final service = LogCaptureService();
     final entry = LogEntry(
       timestamp: DateTime.now(),
       level: LogLevel.info,
       message: 'Test log',
     );

     service.captureLog(entry);

     expect(service.getRecentLogs(), contains(entry));
   });
   ```

2. **Implement**: Basic log storage
3. **Write failing test**: Buffer respects max size (1000)
4. **Implement**: Circular buffer eviction
5. **Write failing test**: getRecentLogs returns chronological order
6. **Implement**: Sort by timestamp
7. **Write failing test**: clearBuffer removes all entries
8. **Implement**: Buffer clearing

**Integration with UnifiedLogger**:
```dart
// Modify lib/utils/unified_logger.dart
static void _log(...) {
  // Existing logging code...

  // Capture to buffer for bug reports
  final entry = LogEntry(
    timestamp: DateTime.now(),
    level: level,
    message: message,
    category: category,
    name: name,
    error: error,
    stackTrace: stackTrace,
  );
  LogCaptureService.instance.captureLog(entry);
}
```

---

### Phase 2: BugReportService (TDD)

**Objective**: Collect diagnostics and prepare bug report data

**Files to Create**:
- `lib/models/bug_report_data.dart`
- `lib/models/bug_report_result.dart`
- `lib/config/bug_report_config.dart`
- `lib/services/bug_report_service.dart`
- `test/unit/services/bug_report_service_test.dart`

**TDD Steps**:

1. **Write failing test**: collectDiagnostics gathers device info
   ```dart
   test('collectDiagnostics should gather device info', () async {
     final service = BugReportService(
       logCaptureService: mockLogCapture,
       nostrService: mockNostr,
       errorTracker: mockErrorTracker,
       proofModeService: mockProofMode,
     );

     final diagnostics = await service.collectDiagnostics(
       userDescription: 'App crashed',
     );

     expect(diagnostics.deviceInfo, isNotEmpty);
     expect(diagnostics.deviceInfo['platform'], isNotNull);
   });
   ```

2. **Implement**: Device info collection
3. **Write failing test**: collectDiagnostics includes recent logs
4. **Implement**: Log retrieval from LogCaptureService
5. **Write failing test**: collectDiagnostics includes error counts
6. **Implement**: Error count retrieval from ErrorAnalyticsTracker
7. **Write failing test**: collectDiagnostics includes relay status
8. **Implement**: Relay status from NostrService
9. **Write failing test**: sanitizeSensitiveData removes nsec keys
10. **Implement**: Regex-based sanitization

**Diagnostic Collection Logic**:
```dart
Future<BugReportData> collectDiagnostics({
  required String userDescription,
}) async {
  // Device info from ProofModeAttestationService
  final deviceInfo = await _proofModeService.getDeviceInfo();

  // App version from package_info_plus
  final packageInfo = await PackageInfo.fromPlatform();

  // Recent logs from LogCaptureService
  final recentLogs = _logCaptureService.getRecentLogs(
    limit: BugReportConfig.maxLogEntries,
  );

  // Error counts from ErrorAnalyticsTracker
  final errorCounts = _errorTracker.getAllErrorCounts();

  // Relay status from NostrService
  final relayStatus = _nostrService.getRelayStatus();

  final reportData = BugReportData(
    reportId: Uuid().v4(),
    timestamp: DateTime.now(),
    userDescription: userDescription,
    deviceInfo: deviceInfo.toJson(),
    appVersion: packageInfo.version,
    recentLogs: recentLogs,
    errorCounts: errorCounts,
    relayStatus: relayStatus,
    userPubkey: _authService.publicKey,
  );

  // Sanitize sensitive data
  return _sanitizeSensitiveData(reportData);
}
```

---

### Phase 3: NIP17MessageService (TDD)

**Objective**: Implement NIP-17 three-layer encryption

**Files to Create**:
- `lib/services/nip17_message_service.dart`
- `test/unit/services/nip17_message_service_test.dart`
- `test/integration/nip17_message_integration_test.dart`

**CRITICAL**: Verify nostr_sdk NIP-44 and NIP-59 support first!

**TDD Steps**:

1. **Write failing test**: createKind14Message creates unsigned event
   ```dart
   test('createKind14Message should create unsigned kind 14', () {
     final service = NIP17MessageService(
       nostrService: mockNostr,
       authService: mockAuth,
     );

     final kind14 = service._createKind14Message(
       recipientPubkey: 'recipient123',
       content: 'Test message',
     );

     expect(kind14['kind'], equals(14));
     expect(kind14['content'], equals('Test message'));
     expect(kind14['tags'], contains(['p', 'recipient123']));
     expect(kind14, isNot(contains('sig'))); // Must be unsigned
   });
   ```

2. **Implement**: Kind 14 message creation
3. **Write failing test**: sealMessage encrypts with NIP-44
4. **Implement**: NIP-44 encryption to kind 13
5. **Write failing test**: giftWrapMessage uses random keypair
6. **Implement**: Random keypair generation + kind 1059
7. **Write failing test**: giftWrapMessage randomizes timestamp
8. **Implement**: Timestamp randomization (up to 2 days past)
9. **Write failing test**: sendPrivateMessage broadcasts gift wrap
10. **Implement**: Complete NIP-17 send flow

**Integration Test**:
```dart
test('sendPrivateMessage should send encrypted bug report', () async {
  // Use real nostr_sdk with test relay
  final nip17Service = NIP17MessageService(
    nostrService: realNostrService,
    authService: realAuthService,
  );

  final result = await nip17Service.sendPrivateMessage(
    recipientPubkey: testRecipientPubkey,
    content: 'Test bug report',
  );

  expect(result.success, isTrue);
  expect(result.messageEventId, isNotNull);

  // Verify recipient can decrypt (requires recipient's private key)
  // This requires a separate test account
});
```

---

### Phase 4: UI Integration (TDD)

**Objective**: Add bug report UI to Settings screen

**Files to Create**:
- `lib/screens/bug_report_screen.dart` (optional full-screen form)
- `lib/widgets/bug_report_dialog.dart` (quick report dialog)
- `test/widgets/bug_report_dialog_test.dart`
- `test/goldens/widgets/bug_report_dialog_golden_test.dart`

**TDD Steps**:

1. **Write failing test**: BugReportDialog shows description field
   ```dart
   testWidgets('BugReportDialog should show description field', (tester) async {
     await tester.pumpWidget(
       MaterialApp(
         home: Scaffold(
           body: BugReportDialog(),
         ),
       ),
     );

     expect(find.byType(TextField), findsOneWidget);
     expect(find.text('Describe the issue'), findsOneWidget);
   });
   ```

2. **Implement**: Dialog with TextField
3. **Write failing test**: Submit button calls BugReportService
4. **Implement**: Service integration
5. **Write failing test**: Shows success/error snackbar
6. **Implement**: Result handling
7. **Add golden test**: Dialog appearance

**Settings Screen Integration**:
```dart
// lib/screens/settings_screen.dart
ListTile(
  leading: Icon(Icons.bug_report),
  title: Text('Report a Bug'),
  subtitle: Text('Send diagnostic report to support'),
  onTap: () => _showBugReportDialog(context),
),

void _showBugReportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => BugReportDialog(),
  );
}
```

**In-App Error Widget** (optional):
```dart
// lib/widgets/app_error_widget.dart
/// Shows error UI with "Report Bug" button
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    required this.error,
    this.onRetry,
    super.key,
  });

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          SizedBox(height: 24),
          if (onRetry != null)
            ElevatedButton(
              onPressed: onRetry,
              child: Text('Retry'),
            ),
          TextButton.icon(
            icon: Icon(Icons.bug_report),
            label: Text('Report Bug'),
            onPressed: () => _reportBug(context),
          ),
        ],
      ),
    );
  }

  void _reportBug(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BugReportDialog(
        prefilledDescription: 'Error: $error',
      ),
    );
  }
}
```

---

### Phase 5: Testing & Polish

**Objective**: Comprehensive testing and refinement

**Tasks**:

1. **Unit Tests**: All services (100% coverage)
2. **Integration Tests**: End-to-end bug report flow with real relay
3. **Golden Tests**: UI components
4. **Manual Testing**:
   - Submit bug report from Settings
   - Submit bug report from error screen
   - Verify encryption (recipient can decrypt)
   - Test with/without authentication
   - Test on iOS, Android, Web
5. **Documentation**:
   - User guide: "How to report bugs"
   - Developer guide: "How to decrypt bug reports"
6. **Analytics**: Track bug report usage
   ```dart
   _analytics.logEvent(
     name: 'bug_report_submitted',
     parameters: {
       'report_id': reportData.reportId,
       'log_count': reportData.recentLogs.length,
       'error_count': reportData.errorCounts.length,
     },
   );
   ```

---

## 6. Test Strategy

### 6.1 Unit Tests

**LogCaptureService**:
- ✅ Circular buffer stores logs
- ✅ Buffer respects max size (1000 entries)
- ✅ getRecentLogs returns chronological order
- ✅ clearBuffer removes all entries
- ✅ Thread-safe concurrent writes

**BugReportService**:
- ✅ collectDiagnostics gathers all data sources
- ✅ sanitizeSensitiveData removes nsec keys
- ✅ sanitizeSensitiveData removes hex private keys
- ✅ sanitizeSensitiveData removes password patterns
- ✅ Report size does not exceed 1MB limit
- ✅ Handles missing device info gracefully
- ✅ Handles unauthenticated users (no pubkey)

**NIP17MessageService**:
- ✅ createKind14Message creates unsigned event
- ✅ sealMessage signs with sender's key
- ✅ giftWrapMessage uses random keypair
- ✅ giftWrapMessage randomizes timestamp
- ✅ sendPrivateMessage broadcasts to relay
- ✅ Encryption is NIP-44 compatible
- ✅ Handles NIP-44 encryption errors

### 6.2 Integration Tests

**End-to-End Bug Report Flow**:
```dart
// test/integration/bug_report_e2e_test.dart
test('complete bug report submission flow', () async {
  // Setup: Initialize all services with test relay
  final testRelay = 'wss://test-relay.openvine.co';
  final recipientPubkey = 'test_recipient_pubkey';

  // Step 1: Generate logs
  Log.info('Test log 1', category: LogCategory.video);
  Log.error('Test error', category: LogCategory.relay);

  // Step 2: Collect diagnostics
  final bugReportService = container.read(bugReportServiceProvider);
  final diagnostics = await bugReportService.collectDiagnostics(
    userDescription: 'Test bug report',
  );

  expect(diagnostics.recentLogs.length, greaterThan(0));
  expect(diagnostics.deviceInfo, isNotEmpty);

  // Step 3: Send via NIP-17
  final result = await bugReportService.sendBugReport(diagnostics);

  expect(result.success, isTrue);
  expect(result.messageEventId, isNotNull);

  // Step 4: Verify recipient can decrypt (requires recipient test account)
  // This would be done manually or in a separate decryption test
});
```

**NIP-17 Decryption Test** (requires recipient account):
```dart
// test/integration/nip17_decryption_test.dart
test('recipient can decrypt bug report', () async {
  // Requires recipient's private key for decryption
  // This test validates the full NIP-17 encryption chain

  final recipientNostrService = NostrService(
    keyManager: recipientKeyManager,
  );

  // Subscribe to kind 1059 gift wraps
  final giftWraps = recipientNostrService.subscribeToEvents(
    filters: [
      Filter(kinds: [1059], p: [recipientPubkey]),
    ],
  );

  // Decrypt gift wrap -> seal -> kind 14
  final decrypted = await _decryptNIP17Message(giftWraps.first);

  expect(decrypted.kind, equals(14));
  expect(decrypted.content, contains('Bug Report'));
});
```

### 6.3 Widget Tests

**BugReportDialog**:
- ✅ Renders description TextField
- ✅ Submit button disabled when empty
- ✅ Submit button enabled when text entered
- ✅ Shows loading indicator during submission
- ✅ Shows success message on completion
- ✅ Shows error message on failure
- ✅ Closes dialog on success

### 6.4 Golden Tests

**BugReportDialog UI**:
```dart
// test/goldens/widgets/bug_report_dialog_golden_test.dart
testGoldens('BugReportDialog renders correctly', (tester) async {
  await tester.pumpWidgetBuilder(
    BugReportDialog(),
  );

  await screenMatchesGolden(tester, 'bug_report_dialog_initial');

  // Enter text
  await tester.enterText(find.byType(TextField), 'Test bug');
  await tester.pump();

  await screenMatchesGolden(tester, 'bug_report_dialog_with_text');
});
```

---

## 7. Privacy & Security

### 7.1 Sensitive Data Sanitization

**Patterns to Remove**:
- nsec1... keys (Nostr secret keys)
- 64-character hex private keys
- password=... / password: ...
- token=... / token: ...
- secret=... / secret: ...
- Authorization: Bearer ...

**Implementation**:
```dart
BugReportData _sanitizeSensitiveData(BugReportData data) {
  return BugReportData(
    reportId: data.reportId,
    timestamp: data.timestamp,
    userDescription: _sanitizeString(data.userDescription),
    deviceInfo: data.deviceInfo, // Safe - no user data
    appVersion: data.appVersion,
    recentLogs: data.recentLogs.map((log) => LogEntry(
      timestamp: log.timestamp,
      level: log.level,
      message: _sanitizeString(log.message),
      category: log.category,
      name: log.name,
      error: log.error != null ? _sanitizeString(log.error!) : null,
      stackTrace: log.stackTrace, // Safe - no user data
    )).toList(),
    errorCounts: data.errorCounts,
    relayStatus: data.relayStatus,
    currentScreen: data.currentScreen,
    userPubkey: data.userPubkey, // Public key - safe to include
    additionalContext: data.additionalContext,
  );
}

String _sanitizeString(String input) {
  String sanitized = input;

  for (final pattern in BugReportConfig.sensitivePatterns) {
    sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
  }

  return sanitized;
}
```

### 7.2 NIP-17 Encryption Guarantees

**Privacy Features**:
- ✅ No metadata leak (sender/recipient hidden via random keypair)
- ✅ Timestamp obfuscation (randomized up to 2 days past)
- ✅ Forward secrecy (each message uses unique random keypair)
- ✅ End-to-end encryption (only recipient can decrypt)
- ✅ No signature leak (kind 14 is unsigned)

**Security Considerations**:
- Bug reports contain diagnostic data - ensure user consent
- Gift wrap relays cannot see sender or recipient
- Only diVine support team can decrypt reports
- Reports are not stored locally (only in relay network)

### 7.3 User Consent

**Disclosure in UI**:
```dart
// lib/widgets/bug_report_dialog.dart
AlertDialog(
  title: Text('Send Bug Report'),
  content: Column(
    children: [
      Text(
        'This report will include:\n'
        '• Recent app logs (sanitized)\n'
        '• Device information\n'
        '• Relay connection status\n'
        '• Error counts\n\n'
        'Your private keys will NOT be included.',
        style: TextStyle(fontSize: 12),
      ),
      SizedBox(height: 16),
      TextField(
        decoration: InputDecoration(
          labelText: 'Describe the issue',
          hintText: 'What happened? What were you trying to do?',
        ),
        maxLines: 5,
        onChanged: (value) => setState(() => _description = value),
      ),
    ],
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text('Cancel'),
    ),
    ElevatedButton(
      onPressed: _description.isEmpty ? null : _submitReport,
      child: Text('Send Report'),
    ),
  ],
);
```

---

## 8. Future Enhancements

### 8.1 Phase 6: Advanced Features

**Screenshot Attachment**:
- Capture current screen on error
- Include in bug report as base64 image
- Requires user permission

**Log Filtering**:
- Allow user to filter by LogCategory
- Show preview of logs before sending
- Exclude verbose logs by default

**Report History**:
- Store sent report IDs locally
- Allow user to view past reports
- Track report status (pending, received, resolved)

**Auto-Report Critical Errors**:
- Prompt user to send report on critical errors
- Pre-fill description with error message
- One-tap submission

### 8.2 Phase 7: Support Dashboard

**Recipient Decryption Tool**:
- Web dashboard for diVine support team
- Decrypt NIP-17 bug reports
- View formatted diagnostics
- Link to GitHub issues

**Analytics Dashboard**:
- Track bug report frequency
- Categorize by error type
- Identify common issues
- Measure response time

---

## Summary

This architecture provides a **comprehensive, privacy-preserving bug report system** for diVine using NIP-17 encrypted messages. The phased TDD implementation ensures quality, while the three-layer encryption guarantees user privacy.

**Key Deliverables**:
1. ✅ LogCaptureService - Circular buffer for logs
2. ✅ BugReportService - Diagnostic collection
3. ✅ NIP17MessageService - NIP-17 encryption
4. ✅ UI Integration - Settings + in-app dialogs
5. ✅ Comprehensive testing at all levels

**Next Steps**:
1. Verify nostr_sdk NIP-44/NIP-59 support
2. Set up support recipient pubkey
3. Begin Phase 1: LogCaptureService (TDD)
4. Iterate through phases with continuous testing
