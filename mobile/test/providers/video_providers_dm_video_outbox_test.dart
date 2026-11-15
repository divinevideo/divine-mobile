// ABOUTME: Verifies the video DM outbox is one instance per signed-in account
// ABOUTME: and survives a rebuild of the services it sends through.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/dm_video_send_cancellation.dart';
import 'package:openvine/services/dm_video_send_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _TestSession extends NostrSession {
  @override
  NostrSessionReadiness build() => const NostrSessionReadiness.signedOut();
}

class _MockDmVideoSendService extends Mock implements DmVideoSendService {}

/// Stands in for the signed-in account, so a test can switch it.
final _signedIn = StateProvider<String?>((_) => null);

/// Stands in for an auth state change that keeps the same account, such as
/// an OAuth signer refresh or the RPC capability coming up.
final _authStateTick = StateProvider<int>((_) => 0);

/// Stands in for whatever makes the DM repository rebuild.
final _repositoryGeneration = StateProvider<int>((_) => 0);

void main() {
  final first = 'a' * 64;
  final second = 'b' * 64;

  late int accountIdBuilds;
  final client = _MockNostrClient();

  void ready(ProviderContainer container, String pubkey) {
    when(() => client.hasKeys).thenReturn(true);
    when(() => client.publicKey).thenReturn(pubkey);
    container
        .read(nostrSessionProvider.notifier)
        .update(
          NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client),
        );
  }

  ProviderContainer buildContainer() {
    accountIdBuilds = 0;
    final container = ProviderContainer(
      overrides: [
        nostrSessionProvider.overrideWith(_TestSession.new),
        // Mirrors the real provider: rebuilt on every auth state change,
        // returning the signed-in pubkey.
        currentAccountIdProvider.overrideWith((ref) {
          ref.watch(_authStateTick);
          accountIdBuilds++;
          return ref.watch(_signedIn);
        }),
        dmVideoSendServiceProvider.overrideWith((ref) {
          ref.watch(_repositoryGeneration);
          return _MockDmVideoSendService();
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(_signedIn.notifier).state = first;
    ready(container, first);
    return container;
  }

  group('videoDmOutboxProvider', () {
    setUpAll(() {
      registerFallbackValue(File('/tmp/fallback.mp4'));
      registerFallbackValue((DmVideoSendPhase _) {});
      registerFallbackValue((double _) {});
      registerFallbackValue(DmVideoSendCancellation()..finish());
    });

    test(
      'waits for the originating signer before reading the send service',
      () async {
        final container = buildContainer();
        container
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.identityKnown(pubkey: first),
            );
        final outbox = container.read(videoDmOutboxProvider);
        outbox.sendVideo(
          conversationId: 'c',
          recipientPubkey: second,
          file: File('/v/a.mp4'),
        );
        await pumpEventQueue();
        expect(container.exists(dmVideoSendServiceProvider), isFalse);
        container.read(_repositoryGeneration.notifier).state++;
        final current = container.read(
          dmVideoSendServiceProvider,
        ) as _MockDmVideoSendService;
        when(
          () => current.sendVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            videoFile: any(named: 'videoFile'),
            mimeType: any(named: 'mimeType'),
            extraTags: any(named: 'extraTags'),
            onPhase: any(named: 'onPhase'),
            onUploadProgress: any(named: 'onUploadProgress'),
            cancellation: any(named: 'cancellation'),
          ),
        ).thenAnswer((_) => Completer<NIP17SendResult>().future);
        ready(container, first);
        await pumpEventQueue();
        expect(container.read(videoDmOutboxProvider), same(outbox));
        verify(
          () => current.sendVideo(
            recipientPubkey: second,
            videoFile: any(named: 'videoFile'),
            mimeType: any(named: 'mimeType'),
            extraTags: any(named: 'extraTags'),
            onPhase: any(named: 'onPhase'),
            onUploadProgress: any(named: 'onUploadProgress'),
            cancellation: any(named: 'cancellation'),
          ),
        ).called(1);
      },
    );

    test('keeps the same outbox when the DM repository rebuilds', () {
      final container = buildContainer();
      final before = container.read(videoDmOutboxProvider);
      final serviceBefore = container.read(dmVideoSendServiceProvider);

      container.read(_repositoryGeneration.notifier).state++;

      expect(
        container.read(dmVideoSendServiceProvider),
        isNot(same(serviceBefore)),
      );
      expect(container.read(videoDmOutboxProvider), same(before));
    });

    test('keeps the same outbox across an auth state change that keeps the '
        'account', () {
      final container = buildContainer();
      final before = container.read(videoDmOutboxProvider);
      final buildsBefore = accountIdBuilds;

      container.read(_authStateTick.notifier).state++;

      expect(container.read(currentAccountIdProvider), equals(first));
      expect(accountIdBuilds, greaterThan(buildsBefore));
      expect(container.read(videoDmOutboxProvider), same(before));
    });

    test('sends through the send service that is current when the send '
        'starts', () async {
      final container = buildContainer();
      final outbox = container.read(videoDmOutboxProvider);
      container.read(_repositoryGeneration.notifier).state++;
      final current =
          container.read(dmVideoSendServiceProvider) as _MockDmVideoSendService;
      when(
        () => current.sendVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          videoFile: any(named: 'videoFile'),
          mimeType: any(named: 'mimeType'),
          extraTags: any(named: 'extraTags'),
          onPhase: any(named: 'onPhase'),
          onUploadProgress: any(named: 'onUploadProgress'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) => Completer<NIP17SendResult>().future);

      outbox.sendVideo(
        conversationId: 'c',
        recipientPubkey: second,
        file: File('/v/a.mp4'),
      );

      await pumpEventQueue();
      verify(
        () => current.sendVideo(
          recipientPubkey: second,
          videoFile: any(named: 'videoFile'),
          mimeType: any(named: 'mimeType'),
          extraTags: any(named: 'extraTags'),
          onPhase: any(named: 'onPhase'),
          onUploadProgress: any(named: 'onUploadProgress'),
          cancellation: any(named: 'cancellation'),
        ),
      ).called(1);
    });

    test('builds a new outbox and disposes the old one when the account '
        'changes', () async {
      final container = buildContainer();
      final before = container.read(videoDmOutboxProvider);
      final done = before.watchConversation('c').toList();

      container.read(_signedIn.notifier).state = second;

      expect(container.read(videoDmOutboxProvider), isNot(same(before)));
      expect(await done, isNotEmpty);
    });

    test(
      'refuses a send started after the account changed, before the outbox '
      'rebuild lands',
      () async {
        final container = buildContainer();
        final outbox = container.read(videoDmOutboxProvider);

        // Switching only marks the outbox for rebuild; nothing has read it
        // again, so its dispose has not landed — exactly the window a queued
        // job used to be able to start in. Send immediately, with no provider
        // read in between (a read flushes the rebuild).
        container.read(_signedIn.notifier).state = second;
        outbox.sendVideo(
          conversationId: 'c',
          recipientPubkey: first,
          file: File('/v/a.mp4'),
        );
        await pumpEventQueue();
        // Read after the send: the send service is what the lazy reader would
        // have handed the job — the incoming account's, since reading it
        // flushes the rebuild chain against the switched session.
        final serviceAfterSwitch = container.read(dmVideoSendServiceProvider);

        // Nothing was handed to any send service: the outgoing account's
        // video never leaves under the incoming account's keys.
        verifyNever(
          () => serviceAfterSwitch.sendVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            videoFile: any(named: 'videoFile'),
            mimeType: any(named: 'mimeType'),
            extraTags: any(named: 'extraTags'),
            onPhase: any(named: 'onPhase'),
            onUploadProgress: any(named: 'onUploadProgress'),
            cancellation: any(named: 'cancellation'),
          ),
        );
      },
    );
  });
}
