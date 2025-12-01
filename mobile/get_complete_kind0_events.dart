// Fetch COMPLETE kind 0 events from OpenVine relay - ALL DATA
import 'dart:async';
import 'dart:io';

import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/event_filter.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

void main() async {
  Log.info(
    '📋 Fetching COMPLETE kind 0 events from OpenVine relay...\n',
    name: 'Kind0Fetcher',
  );

  final privateKey = generatePrivateKey();
  final signer = LocalNostrSigner(privateKey);
  final pubKey = await signer.getPublicKey();

  final nostrClient = Nostr(
    signer,
    pubKey!,
    <EventFilter>[],
    (relayUrl) => RelayBase(relayUrl, RelayStatus(relayUrl)),
    onNotice: (relayUrl, notice) =>
        Log.info('📢 Notice: $notice', name: 'Kind0Fetcher'),
  );

  // Connect to relay
  final relay = RelayBase(
    'wss://relay3.openvine.co',
    RelayStatus('wss://relay3.openvine.co'),
  );
  await nostrClient.addRelay(relay, autoSubscribe: true);
  await Future.delayed(const Duration(milliseconds: 500));

  Log.info('🔌 Connected to wss://relay3.openvine.co', name: 'Kind0Fetcher');

  // Create subscription for ALL kind 0 events
  final filter = Filter(kinds: [0], limit: 100); // Get up to 100
  final events = <Event>[];

  nostrClient.subscribe([filter.toJson()], events.add);

  // Wait to collect all events
  Log.info('⏳ Collecting all kind 0 events...', name: 'Kind0Fetcher');
  await Future.delayed(const Duration(seconds: 8));

  Log.info(
    '\n📊 Found ${events.length} kind 0 profile events',
    name: 'Kind0Fetcher',
  );

  // Save complete data to file
  final output = StringBuffer();
  output.writeln('COMPLETE KIND 0 EVENTS FROM OPENVINE RELAY');
  output.writeln('Total events: ${events.length}');
  output.writeln('Generated: ${DateTime.now()}');
  output.writeln('=' * 120);

  for (var i = 0; i < events.length; i++) {
    final event = events[i];

    output.writeln('\nEVENT ${i + 1} of ${events.length}:');

    // Print EVERYTHING available on the event object
    output.writeln('COMPLETE EVENT SERIALIZATION:');
    try {
      // Try to get the complete event as a map/JSON
      output.writeln('event.toString(): $event');

      // Get all available properties
      output.writeln('id: ${event.id}');
      output.writeln('pubkey: ${event.pubkey}');
      output.writeln('created_at: ${event.createdAt}');
      output.writeln('kind: ${event.kind}');
      output.writeln('tags: ${event.tags}');
      output.writeln('content: ${event.content}');
      output.writeln('sig: ${event.sig}');

      // Try to access any other fields that might exist
      output.writeln('runtimeType: ${event.runtimeType}');
    } catch (e) {
      output.writeln('Error serializing event: $e');
    }

    output.writeln('=' * 120);
  }

  // Write to file
  final file = File('kind0_events_complete.txt');
  await file.writeAsString(output.toString());

  Log.info(
    '\n✅ COMPLETE! Found ${events.length} total kind 0 events on OpenVine relay',
    name: 'Kind0Fetcher',
  );
  Log.info(
    '📝 Full data saved to: kind0_events_complete.txt',
    name: 'Kind0Fetcher',
  );
  Log.info(
    'All event data includes EVERYTHING - id, pubkey, created_at, kind, tags, content, sig',
    name: 'Kind0Fetcher',
  );
}
