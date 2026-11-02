// ABOUTME: Matchers and a default for the two live DM REQs: the DMs (kinds
// ABOUTME: 1059 and 4) and the deletions (kind 5) are separate REQs (#9468).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';

/// The live DM read: gift wraps and NIP-04 messages.
final Matcher isLiveDmRead = isA<List<Filter>>().having(
  (filters) => filters.single.kinds,
  'kinds',
  contains(EventKind.giftWrap),
);

/// The live deletions read, kind 5 alone.
final Matcher isLiveDeletionsRead = isA<List<Filter>>().having(
  (filters) => filters.single.kinds,
  'kinds',
  equals([EventKind.eventDeletion]),
);

/// Answers [client]'s live deletions REQ with a stream that stays open and
/// sends nothing, so a test about the DMs sees no deletion and no teardown.
void stubQuietLiveDeletions(NostrClient client) => when(
  () => client.subscribe(
    any(that: isLiveDeletionsRead),
    subscriptionId: any(named: 'subscriptionId'),
    tempRelays: any(named: 'tempRelays'),
    targetRelays: any(named: 'targetRelays'),
    onStoredEventsStart: any(named: 'onStoredEventsStart'),
    onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
  ),
).thenAnswer((_) => StreamController<Event>().stream);
