# Nostr Event Publishing Debug Guide

## Status: Enhanced Logging Added ✅

Added comprehensive logging to `NostrService.broadcastEvent()` to diagnose why Nostr events aren't reaching relays.

## What Was Added

### New Logging in `lib/services/nostr_service.dart`

**Lines 468-478**: Initial broadcast status
```dart
Log.info('🚀 Broadcasting event ${event.id} (kind ${event.kind})');
Log.info('📊 Relay Status:');
Log.info('   - Embedded relay initialized: ${_embeddedRelay!.isInitialized}');
Log.info('   - Configured relays: ${_configuredRelays.join(", ")}');
Log.info('   - Connected relays: ${_embeddedRelay!.connectedRelays.join(", ")}');
```

**Lines 529-536**: Publish attempt and result
```dart
Log.info('📤 Publishing to embedded relay...');
success = await _embeddedRelay!.publish(embeddedEvent);
Log.info('✅ Embedded relay publish result: $success');
// Error logging if publish fails
Log.error('❌ Embedded relay publish error: $e');
```

**Lines 581-610**: Detailed relay-by-relay results
```dart
// For successful publish:
Log.info('✅ Local embedded relay: SUCCESS');
for (final relayUrl in _configuredRelays) {
  if (isConnected) {
    Log.info('✅ External relay $relayUrl: CONNECTED (event forwarded)');
  } else {
    Log.warning('⚠️  External relay $relayUrl: NOT CONNECTED');
  }
}

// For failed publish:
Log.error('❌ Local embedded relay: REJECTED');
Log.error('❌ External relay $relayUrl: FAILED (local publish rejected)');
```

**Lines 625-634**: Final broadcast summary
```dart
Log.info('📊 Broadcast Summary:');
Log.info('   - Success: $successCount/${results.length} relays');
Log.info('   - Results: $results');
if (errors.isNotEmpty) {
  Log.info('   - Errors: $errors');
}
```

## Expected Log Flow (When Working)

When publishing a video (kind 34236 event), you should see:

```
[VideoEventPublisher] 📤 FULL EVENT TO PUBLISH:
[VideoEventPublisher]   ID: abc123...
[VideoEventPublisher]   Pubkey: def456...
[VideoEventPublisher]   Kind: 34236
[VideoEventPublisher]   Tags: [['d', 'video_id'], ['imeta', 'url ...'], ...]
[VideoEventPublisher] 📋 FULL EVENT JSON: {...}

[NostrService] 🚀 Broadcasting event abc123... (kind 34236)
[NostrService] 📊 Relay Status:
[NostrService]    - Embedded relay initialized: true
[NostrService]    - Configured relays: wss://relay3.openvine.co
[NostrService]    - Connected relays: wss://relay3.openvine.co

[NostrService] 📤 Publishing to embedded relay...
[NostrService] ✅ Embedded relay publish result: true

[NostrService] ✅ Local embedded relay: SUCCESS
[NostrService] ✅ External relay wss://relay3.openvine.co: CONNECTED (event forwarded)

[NostrService] 📊 Broadcast Summary:
[NostrService]    - Success: 2/2 relays
[NostrService]    - Results: {local: true, wss://relay3.openvine.co: true}

[VideoEventPublisher] ✅ Event successfully published to 2 relay(s)
```

## Common Failure Scenarios

### Scenario 1: Embedded Relay Not Initialized
```
[NostrService] 📊 Relay Status:
[NostrService]    - Embedded relay initialized: false
[NostrService]    - Configured relays: wss://relay3.openvine.co
[NostrService]    - Connected relays:

[NostrService] Embedded relay is not initialized, attempting to reinitialize
```

**Cause**: Embedded relay was disposed or never initialized
**Fix**: Check app initialization sequence

### Scenario 2: No External Relays Connected
```
[NostrService] 📊 Relay Status:
[NostrService]    - Embedded relay initialized: true
[NostrService]    - Configured relays: wss://relay3.openvine.co
[NostrService]    - Connected relays:

[NostrService] ✅ Local embedded relay: SUCCESS
[NostrService] ⚠️  External relay wss://relay3.openvine.co: NOT CONNECTED

[NostrService] 📊 Broadcast Summary:
[NostrService]    - Success: 1/2 relays
[NostrService]    - Errors: {wss://relay3.openvine.co: Relay not connected}
```

**Cause**: External relay connection failed or dropped
**Fix**: Check network connectivity, relay URL, relay availability

### Scenario 3: Embedded Relay Rejects Event
```
[NostrService] 📤 Publishing to embedded relay...
[NostrService] ❌ Embedded relay publish error: Invalid event signature

[NostrService] ❌ Local embedded relay: REJECTED
[NostrService] ❌ External relay wss://relay3.openvine.co: FAILED (local publish rejected)

[NostrService] 📊 Broadcast Summary:
[NostrService]    - Success: 0/2 relays
[NostrService]    - Errors: {local: Invalid event signature, wss://relay3.openvine.co: Local relay publish failed}
```

**Cause**: Invalid event (bad signature, wrong format, etc.)
**Fix**: Check event creation, signing, and validation

### Scenario 4: Stream Closure Error
```
[NostrService] ❌ Embedded relay publish error: Cannot add new events after calling close

[NostrService] Embedded relay stream closed, attempting recovery
[NostrService] Successfully published after stream recovery
```

**Cause**: Embedded relay stream was closed prematurely
**Fix**: This is handled automatically with recovery logic

## Testing Instructions

### 1. Run the App and Record a Video
```bash
./run_dev.sh chrome debug
```

### 2. Publish a Video
1. Record a video in the camera screen
2. Add title, description, hashtags
3. Click "Publish"
4. Watch the console logs

### 3. Analyze the Logs

Look for the log sequence above. Key questions:

**Q1: Is embedded relay initialized?**
- ✅ YES: Continue to Q2
- ❌ NO: Check app initialization, look for embedded relay init errors

**Q2: Are external relays connected?**
- ✅ YES: Continue to Q3
- ❌ NO: Check network, relay availability, `addExternalRelay()` calls

**Q3: Does embedded relay publish succeed?**
- ✅ YES: Event is in local database, should forward to connected external relays
- ❌ NO: Check event validity, signature, format

**Q4: What's the final success count?**
- `2/2 relays`: ✅ Perfect - local + 1 external relay
- `1/2 relays`: ⚠️  Local only - external relay not connected
- `0/2 relays`: ❌ Complete failure - check errors map

## Architecture Reminder

OpenVine uses **embedded relay architecture**:

1. **NostrService** connects to embedded relay at `ws://localhost:7447`
2. **Embedded relay** stores events in local SQLite database
3. **Embedded relay** automatically forwards events to external relays
4. **External relays** (like `wss://relay3.openvine.co`) receive forwarded events

**CRITICAL**: NostrService should NEVER connect directly to external relays. The embedded relay handles all external connections.

## Next Steps

After adding this logging and running the test:

1. **Identify the failure point** using the log sequence above
2. **Check specific scenario** from the Common Failure Scenarios section
3. **Apply the fix** based on the root cause
4. **Verify** that events reach external relays

## Verification Commands

### Check if event reached relay
```bash
# Use a Nostr client to query relay3.openvine.co
# Look for events with your pubkey and kind 34236
```

### Check embedded relay database
```bash
# The embedded relay stores events in SQLite
# Location varies by platform (iOS, macOS, web, etc.)
```

## Files Modified

- ✅ `lib/services/nostr_service.dart` - Enhanced logging in `broadcastEvent()`
- ✅ `test/manual/NOSTR_PUBLISHING_DEBUG.md` - This debug guide
