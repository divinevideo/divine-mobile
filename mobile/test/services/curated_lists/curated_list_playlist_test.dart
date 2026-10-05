// ABOUTME: Validates playlist ordering through durable public mutation outcomes.
// ABOUTME: Refused storage preserves both playback mode and stored video order.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/curated_list_publish_stubs.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

class _RefusingListPreferences extends Fake implements SharedPreferences {
  _RefusingListPreferences(this.backing);

  final SharedPreferences backing;
  bool refuseListWrite = true;

  @override
  Object? get(String key) => backing.get(key);

  @override
  Set<String> getKeys() => backing.getKeys();

  @override
  bool containsKey(String key) => backing.containsKey(key);

  @override
  int? getInt(String key) => backing.getInt(key);

  @override
  Future<void> reload() => backing.reload();

  @override
  Future<bool> setInt(String key, int value) => backing.setInt(key, value);

  @override
  String? getString(String key) => backing.getString(key);

  @override
  List<String>? getStringList(String key) => backing.getStringList(key);

  @override
  bool? getBool(String key) => backing.getBool(key);

  @override
  Future<bool> setString(String key, String value) =>
      key == CuratedListService.listsStorageKey && refuseListWrite
      ? Future.value(false)
      : backing.setString(key, value);
}

void main() {
  group('CuratedListService playlist persistence', () {
    test(
      'rejected ordering retains playback mode and retries durably',
      () async {
        const owner =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final videos = ['b' * 64, 'c' * 64, 'd' * 64];
        final original = CuratedList(
          id: 'playlist',
          pubkey: owner,
          name: 'Playlist',
          videoEventIds: videos,
          playOrder: PlayOrder.reverse,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final stored = jsonEncode([original.toJson()]);
        SharedPreferences.setMockInitialValues({
          CuratedListService.listsStorageKey: stored,
        });
        final prefs = _RefusingListPreferences(
          await SharedPreferences.getInstance(),
        );
        final auth = _Auth();
        final client = _Client();
        when(() => auth.isAuthenticated).thenReturn(true);
        when(() => auth.currentPublicKeyHex).thenReturn(owner);
        stubListPublishing(client: client, auth: auth, pubkey: owner);
        final published = <Event>[];
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.single as Event;
          published.add(event);
          return PublishSuccess(event: event);
        });
        when(() => client.publishEventAwaitOk(any()))
            .thenAnswer((invocation) async {
              final event = invocation.positionalArguments.single as Event;
              published.add(event);
              return acceptedOutcome(event);
            });
        final service = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(service.dispose);
        final newOrder = [videos[1], videos[0], videos[2]];

        expect(
          await service.reorderVideos(original.authorScopedId, newOrder),
          isFalse,
        );
        expect(
          service.getOrderedVideoIds(original.authorScopedId),
          videos.reversed.toList(),
        );
        expect(
          service.getListById(original.authorScopedId)?.playOrder,
          PlayOrder.reverse,
        );
        expect(prefs.getString(CuratedListService.listsStorageKey), stored);
        expect(published, isEmpty);

        prefs.refuseListWrite = false;
        expect(
          await service.reorderVideos(original.authorScopedId, newOrder),
          isTrue,
        );
        expect(service.getOrderedVideoIds(original.authorScopedId), newOrder);
        expect(
          service.getListById(original.authorScopedId)?.playOrder,
          PlayOrder.manual,
        );
        final durable = jsonDecode(
          prefs.getString(CuratedListService.listsStorageKey)!,
        ) as List<dynamic>;
        final restored = CuratedList.fromJson(
          durable.single as Map<String, dynamic>,
        );
        expect(restored.videoEventIds, newOrder);
        expect(restored.playOrder, PlayOrder.manual);
        expect(published, hasLength(1));
      },
    );
  });
}
