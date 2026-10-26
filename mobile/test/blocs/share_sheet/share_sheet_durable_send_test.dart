// ABOUTME: Real repository/SQLite coverage for dismissing a shared video once
// ABOUTME: it is durable locally, independently of relay discovery and delivery.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _NostrClient extends Mock implements NostrClient {}

class _AuthService extends Mock implements AuthService {}

class _ProfileRepository extends Mock implements ProfileRepository {}

class _FollowRepository extends Mock implements FollowRepository {}

class _RankingSignalsLoader extends Mock implements UserRankingSignalsLoader {}

class _FallbackEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(_FallbackEvent());
  });

  group('durable video sharing', () {
    test(
      'closes the send flow before discovery and delivers after sheet close',
      () async {
        final signer = LocalNostrSigner(generatePrivateKey());
        final owner = (await signer.getPublicKey())!;
        final peer = getPublicKey(generatePrivateKey());
        final db = AppDatabase.test(NativeDatabase.memory());
        final outgoing = OutgoingDmsDao(db);
        final messages = DirectMessagesDao(db);
        final conversations = ConversationsDao(db);
        final client = _NostrClient();
        final auth = _AuthService();
        final profiles = _ProfileRepository();
        final discoveryStarted = Completer<void>();
        final releaseDiscovery = Completer<void>();
        final recipientPublishStarted = Completer<Event>();
        final releaseRecipientOk = Completer<void>();

        when(() => auth.isAuthenticated).thenReturn(true);
        when(() => auth.canPublishNostrWritesNow).thenReturn(true);
        when(() => client.connectedRelayCount).thenReturn(1);
        when(() => client.configuredRelayCount).thenReturn(1);
        when(() => client.configuredRelays).thenReturn(['wss://relay.example']);
        when(
          () => profiles.fetchFreshProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) async => null);
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            acceptRelayClosedWhenOthersAnswered: any(
              named: 'acceptRelayClosedWhenOthersAnswered',
            ),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async {
          if (!discoveryStarted.isCompleted) discoveryStarted.complete();
          await releaseDiscovery.future;
          return (events: <Event>[], timedOut: false, noRelays: false);
        });
        when(
          () => client.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          final wrap = invocation.positionalArguments.single as Event;
          if (!recipientPublishStarted.isCompleted) {
            recipientPublishStarted.complete(wrap);
          }
          await releaseRecipientOk.future;
          return PublishOutcome(
            eventId: wrap.id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });
        when(
          () => client.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.single as Event,
          ),
        );
        when(() => client.unsubscribe(any())).thenAnswer((_) async {});

        final repository = DmRepository(
          nostrClient: client,
          directMessagesDao: messages,
          conversationsDao: conversations,
          outgoingDmsDao: outgoing,
          userPubkey: owner,
          signer: signer,
          messageService: NIP17MessageService(
            signer: signer,
            senderPublicKey: owner,
            nostrService: client,
          ),
        );
        final sharing = VideoSharingService(
          authService: auth,
          profileRepository: profiles,
          dmRepository: repository,
        );
        final video = VideoEvent(
          id: 'a' * 64,
          pubkey: peer,
          createdAt: 1700000000,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          content: 'A synthetic shared reel',
          videoUrl: 'https://example.com/video.mp4',
          vineId: 'synthetic-reel',
        );
        final sheet = ShareSheetBloc(
          video: video,
          relayUrl: 'wss://relay.example',
          videoSharingService: sharing,
          profileRepository: profiles,
          followRepository: _FollowRepository(),
          rankingSignalsLoader: _RankingSignalsLoader(),
          currentUserPubkey: owner,
        );
        addTearDown(() async {
          if (!releaseDiscovery.isCompleted) releaseDiscovery.complete();
          if (!releaseRecipientOk.isCompleted) releaseRecipientOk.complete();
          if (!sheet.isClosed) await sheet.close();
          // Also drain a held attempt if a pre-delivery assertion failed. The
          // recovery key joins the original transport rather than republishing.
          for (final row in await outgoing.getAllForOwner(owner)) {
            try {
              final _ = await repository.recoverFullSend(rumorId: row.id);
            } on Object catch (error) {
              // The original transport finalized it between the read and join.
              if (error is! ArgumentError) rethrow;
            }
          }
          await repository.stopListening();
          await db.close();
          signer.close();
        });

        final selected = sheet.stream.firstWhere(
          (state) => state.selectedRecipients.isNotEmpty,
        );
        sheet.add(
          ShareSheetRecipientToggled(
            ShareableUser(pubkey: peer, displayName: 'A friend'),
          ),
        );
        await selected;
        final completed = Completer<ShareSheetState>();
        final completionSubscription = sheet.stream.listen((state) {
          if (state.actionResult is ShareSheetSendSuccess &&
              !completed.isCompleted) {
            completed.complete(state);
          }
        });
        addTearDown(completionSubscription.cancel);
        sheet.add(const ShareSheetSendRequested(message: 'Look at this'));
        await discoveryStarted.future.timeout(const Duration(seconds: 5));
        final result = await completed.future.timeout(
          const Duration(seconds: 5),
        );

        expect(result.isSending, isFalse);
        expect(result.selectedRecipients, isEmpty);
        expect(releaseDiscovery.isCompleted, isFalse);
        expect(recipientPublishStarted.isCompleted, isFalse);
        final row = (await outgoing.getAllForOwner(owner)).single;
        expect(row.content, contains('Look at this'));
        expect(
          row.content,
          contains('https://divine.video/video/synthetic-reel'),
        );
        final rumor = Event.fromJson(
          jsonDecode(row.rumorEventJson) as Map<String, dynamic>,
        );
        expect(rumor.tags.any((tag) => tag.first == 'q'), isTrue);
        expect(
          await conversations.getConversation(
            row.conversationId,
            ownerPubkey: owner,
          ),
          isNotNull,
        );

        // Closing the actual composer must not own/cancel network work.
        await sheet.close();
        releaseDiscovery.complete();
        await recipientPublishStarted.future.timeout(
          const Duration(seconds: 10),
        );
        expect(releaseRecipientOk.isCompleted, isFalse);
        expect((await outgoing.getAllForOwner(owner)).single.id, row.id);
        final persisted = messages
            .watchMessagesForConversation(
              row.conversationId,
              ownerPubkey: owner,
            )
            .firstWhere((rows) => rows.isNotEmpty);
        releaseRecipientOk.complete();
        final sent = await persisted.timeout(const Duration(seconds: 10));
        expect(sent.single.id, rumor.id);
        expect(sent.single.content, row.content);
        await outgoing
            .watchAllForOwner(owner)
            .firstWhere((rows) => rows.isEmpty)
            .timeout(const Duration(seconds: 10));
      },
    );
  });
}
