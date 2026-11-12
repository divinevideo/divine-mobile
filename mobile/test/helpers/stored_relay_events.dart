// ABOUTME: Stubs a mocked NostrClient to answer queries like a relay that
// ABOUTME: holds a fixed set of events, for tests over a real repository.

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Answers [NostrClient.queryEvents] on the mocked [client] the way a relay
/// holding [stored] would: an event is returned when any requested filter
/// accepts it under [Filter.checkEvent], so an `authors` list is matched
/// exactly and a filter without one matches every author.
///
/// The calling test must `registerFallbackValue(<Filter>[])`.
void answerQueriesFromStoredEvents(NostrClient client, List<Event> stored) {
  when(() => client.queryEvents(any())).thenAnswer((invocation) async {
    final filters = invocation.positionalArguments.single as List<Filter>;
    return [
      for (final event in stored)
        if (filters.any((filter) => filter.checkEvent(event))) event,
    ];
  });
}
