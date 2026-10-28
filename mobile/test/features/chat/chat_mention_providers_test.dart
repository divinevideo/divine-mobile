import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/chat/chat_mention_providers.dart';
import 'package:openvine/features/chat/chat_mention_repository.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

class _Room extends Mock implements ConcordRepository {}

class _Follows extends Mock implements FollowRepository {}

class _Blocks extends Mock implements ContentBlocklistRepository {}

class _Auth extends Fake implements AuthService {
  _Auth(String pubkey, {this.isAuthenticated = true})
    : currentPublicKeyHex = pubkey,
      currentIdentity = PubkeyOnlyNostrIdentity(pubkey: pubkey);
  @override
  final bool isAuthenticated;
  @override
  final String? currentPublicKeyHex;
  @override
  final NostrIdentity? currentIdentity;
  @override
  AuthState get authState =>
      isAuthenticated ? AuthState.authenticated : AuthState.unauthenticated;
  @override
  Stream<AuthState> get authStateStream => const Stream.empty();
}

final String _me = 'a' * 64;
final String _friend = 'b' * 64;
final String _stranger = 'c' * 64;
final String _mutedFriend = 'd' * 64;

void main() {
  group('chatMentionRepositoryProvider', () {
    late AppDatabase database;
    late _Room room;
    late StreamController<void> roomChanges;
    late StreamController<List<String>> following;
    late StreamController<BlocklistChange> blockChanges;
    late Set<String> followed;
    late Set<String> blocked;
    late List<ChatMessage> messages;

    setUp(() {
      database = AppDatabase.test(NativeDatabase.memory());
      room = _Room();
      roomChanges = StreamController<void>.broadcast();
      following = StreamController<List<String>>.broadcast();
      blockChanges = StreamController<BlocklistChange>.broadcast();
      followed = {_friend, _mutedFriend};
      blocked = {};
      messages = [];
      when(
        () => room.startChannel(
          channelId: any(named: 'channelId'),
          epoch: any(named: 'epoch'),
          streamSeedHex: any(named: 'streamSeedHex'),
          streamPubkey: any(named: 'streamPubkey'),
        ),
      ).thenAnswer((_) async {});
      when(() => room.changes).thenAnswer((_) => roomChanges.stream);
      when(
        () => room.timeline(now: any(named: 'now')),
      ).thenAnswer((_) => FoldedThread(messages, {}));
      when(room.close).thenAnswer((_) async {});
    });

    tearDown(() async {
      await roomChanges.close();
      await following.close();
      await blockChanges.close();
      await database.close();
    });

    ProviderContainer container({
      bool enabled = true,
      bool restricted = false,
      AuthService? auth,
    }) {
      final follows = _Follows();
      when(
        () => follows.isFollowing(any()),
      ).thenAnswer((i) => followed.contains(i.positionalArguments.first));
      when(() => follows.followingStream).thenAnswer((_) => following.stream);
      final blocks = _Blocks();
      when(() => blocks.changes).thenAnswer((_) => blockChanges.stream);
      when(() => blocks.currentState).thenAnswer(
        (_) => ContentPolicyState(
          currentUserPubkey: _me,
          blockedPubkeys: blocked,
          mutedPubkeys: {_mutedFriend},
          pubkeysBlockingUs: const {},
          pubkeysMutingUs: const {},
        ),
      );
      final container = ProviderContainer(
        overrides: [
          featureFlagStateProvider.overrideWithValue({
            FeatureFlag.concordChat: enabled,
          }),
          isDmRestrictedProvider.overrideWithValue(restricted),
          authServiceProvider.overrideWithValue(auth ?? _Auth(_me)),
          databaseProvider.overrideWithValue(database),
          followRepositoryProvider.overrideWithValue(follows),
          contentBlocklistRepositoryProvider.overrideWithValue(blocks),
          profileRepositoryProvider.overrideWithValue(null),
          chatMentionRoomBuilderProvider.overrideWithValue(
            ({required pubkey, required signer, required store}) => room,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// A mention of the owner sent a few seconds after the room was opened.
    ChatMessage mention(String author) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return ChatMessage(
        id: author,
        channelId: 'general',
        author: author,
        body: 'hello nostr:${NostrKeyUtils.encodePubKey(_me)}',
        createdAt: now + 10,
        mentionedPubkeys: [_me],
      );
    }

    Future<ChatMentionRepository> openedRoom(
      ProviderContainer container,
    ) async {
      final repository = container.read(chatMentionRepositoryProvider)!;
      await repository.enroll('general');
      messages = [mention(_friend), mention(_stranger), mention(_mutedFriend)];
      roomChanges.add(null);
      await pumpEventQueue();
      return repository;
    }

    group('gates', () {
      test('is null while the chat flag is off', () {
        expect(
          container(enabled: false).read(chatMentionRepositoryProvider),
          isNull,
        );
      });

      test('is null for a messaging-restricted account', () {
        expect(
          container(restricted: true).read(chatMentionRepositoryProvider),
          isNull,
        );
      });

      test('is null once the account is signed out', () {
        expect(
          container(
            auth: _Auth(_me, isAuthenticated: false),
          ).read(chatMentionRepositoryProvider),
          isNull,
        );
      });
    });

    group('trust policy', () {
      test('only followed senders that are not muted produce a row', () async {
        final repository = await openedRoom(container());
        expect(
          repository.items.map(
            (item) => (item as ActorNotification).actor.pubkey,
          ),
          [_friend],
        );
      });

      test('blocking a sender removes the row it already produced', () async {
        final repository = await openedRoom(container());
        expect(repository.items, hasLength(1));
        blocked = {_friend};
        blockChanges.add(
          BlocklistChange(pubkey: _friend, op: BlocklistOp.blocked),
        );
        await pumpEventQueue();
        expect(repository.items, isEmpty);
      });

      test(
        'unfollowing a sender removes the row it already produced',
        () async {
          final repository = await openedRoom(container());
          expect(repository.items, hasLength(1));
          followed = {_mutedFriend};
          following.add([_mutedFriend]);
          await pumpEventQueue();
          expect(repository.items, isEmpty);
        },
      );
    });

    group('lifecycle', () {
      test('disposing the account closes its observed rooms', () async {
        final owner = container();
        final repository = await openedRoom(owner);
        final done = expectLater(
          repository.watchSnapshot(),
          emitsThrough(emitsDone),
        );
        owner.dispose();
        await done;
        verify(room.close).called(1);
      });
    });
  });
}
