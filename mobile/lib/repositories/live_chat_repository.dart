import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/services/live_nostr_codec.dart';

class LiveChatRepository {
  LiveChatRepository({
    required NostrClient nostrClient,
    required LiveNostrCodec codec,
  }) : _nostrClient = nostrClient,
       _codec = codec;

  final NostrClient _nostrClient;
  final LiveNostrCodec _codec;

  Future<List<LiveChatMessage>> fetchChatMessages({
    required String sessionAddress,
    int limit = 100,
  }) async {
    final events = await _nostrClient.queryEvents([
      Filter(
        kinds: const <int>[1311],
        a: <String>[sessionAddress],
        limit: limit,
      ),
    ]);

    final messages = <String, LiveChatMessage>{};
    for (final event in events) {
      final message = _tryParseChatMessage(event);
      if (message != null) {
        messages[message.id] = message;
      }
    }

    return _sortedMessages(messages.values);
  }

  Stream<List<LiveChatMessage>> watchChatMessages({
    required String sessionAddress,
    int limit = 100,
  }) {
    final filters = <Filter>[
      Filter(
        kinds: const <int>[1311],
        a: <String>[sessionAddress],
        limit: limit,
      ),
    ];
    final subscriptionId = 'live_chat-${DateTime.now().microsecondsSinceEpoch}';
    final cache = <String, LiveChatMessage>{};
    late final StreamController<List<LiveChatMessage>> controller;
    StreamSubscription<Event>? subscription;

    Future<void> loadInitial() async {
      final events = await _nostrClient.queryEvents(
        filters,
        subscriptionId: '${subscriptionId}_initial',
      );
      for (final event in events) {
        final message = _tryParseChatMessage(event);
        if (message != null) {
          cache[message.id] = message;
        }
      }
      if (!controller.isClosed) {
        controller.add(_sortedMessages(cache.values));
      }
    }

    void handleEvent(Event event) {
      final message = _tryParseChatMessage(event);
      if (message == null) {
        return;
      }
      cache[message.id] = message;
      if (!controller.isClosed) {
        controller.add(_sortedMessages(cache.values));
      }
    }

    controller = StreamController<List<LiveChatMessage>>(
      onListen: () {
        unawaited(loadInitial());
        subscription = _nostrClient
            .subscribe(
              filters,
              subscriptionId: subscriptionId,
            )
            .listen(handleEvent);
      },
      onCancel: () async {
        await subscription?.cancel();
        await _nostrClient.unsubscribe(subscriptionId);
      },
    );

    return controller.stream;
  }

  Future<LiveChatMessage?> publishMessage({
    required String sessionAddress,
    required String content,
  }) async {
    final signedEvent = await _codec.buildChatMessageEvent(
      sessionAddress: sessionAddress,
      content: content,
      signer: _nostrClient.signer,
    );
    final result = await _nostrClient.publishEvent(signedEvent);
    return switch (result) {
      PublishSuccess(:final event) => _tryParseChatMessage(event),
      PublishNoRelays() || PublishFailed() => null,
    };
  }

  LiveChatMessage? _tryParseChatMessage(Event event) {
    try {
      return _codec.parseChatMessage(event);
    } on FormatException {
      return null;
    }
  }

  List<LiveChatMessage> _sortedMessages(Iterable<LiveChatMessage> items) {
    final messages = items.toList(growable: false);
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }
}
