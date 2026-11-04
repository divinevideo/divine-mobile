// ABOUTME: Seeds a Concord room's history straight into its store for tests.
// ABOUTME: Keeps ConcordRepository's private record layout in one place.

import 'package:concord_repository/concord_repository.dart';

/// Stores [ids] in [store] as sent messages from [author] in [channelId],
/// using the records that `ConcordRepository.restore` reads back.
///
/// Each message is dated a minute ago unless [sentAt] says otherwise.
Future<void> storeRoomMessages(
  AccountScopedStore store, {
  required String channelId,
  required String author,
  required List<String> ids,
  String body = 'Hello from the room',
  int? sentAt,
}) async {
  if (ids.isEmpty) return;
  final at = sentAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
  await store.writeBatch({
    'index': ids.join(','),
    for (final id in ids) ...{
      'msg:$id': body,
      'meta:$id': '$channelId|$author|$at|',
      'sent:$id': '1',
    },
  });
}
