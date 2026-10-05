// ABOUTME: Tests CuratedListInfoCubit against the real CuratedListService, for
// ABOUTME: what a save leaves stored when the relays refuse part of it.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

// Full-length 64-char pubkeys — never truncate.
const String _owner =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
final String _alice = 'a' * 64;

void main() {
  group('$CuratedListInfoCubit saving through $CuratedListService', () {
    late _MockNostrClient nostr;
    late _MockAuthService auth;
    late CuratedListService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      nostr = _MockNostrClient();
      auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      when(
        () => nostr.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => const Stream.empty());
      stubListPublishing(client: nostr, auth: auth, pubkey: _owner);
      service = CuratedListService(
        nostrService: nostr,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
    });

    /// Makes every relay turn down whatever is published next.
    void rejectPublishing() {
      when(() => nostr.publishEventAwaitOk(any())).thenAnswer(
        (invocation) async =>
            rejectedOutcome(invocation.positionalArguments[0] as Event),
      );
    }

    group('review9746 public collaboration privacy and queue', () {
      test('refused public to private keeps collaborators and does not break later rename', () async {
        final list = (await service.createList(
          name: 'Team',
          isCollaborative: true,
          allowedCollaborators: [_alice],
        ))!;
        final cubit = CuratedListInfoCubit(
          currentOwnerPubkey: () => auth.currentPublicKeyHex,
          resolveService: () => service,
          existingList: list,
        );
        addTearDown(cubit.close);
        cubit.visibilityChanged(isPublic: false);
        rejectPublishing();
        await cubit.submitted();
        expect(cubit.state.status, CuratedListInfoStatus.failure);
        expect(service.getListById(list.id)!.isPublic, isTrue);
        expect(service.getListById(list.id)!.allowedCollaborators, [_alice]);
        expect(service.getListById(list.id)!.isCollaborative, isTrue);
        stubListPublishing(client: nostr, auth: auth, pubkey: _owner);
        expect(
          await service.updateList(
            listId: list.id,
            name: 'Rename after refusal',
          ),
          isTrue,
        );
        expect(service.getListById(list.id)!.allowedCollaborators, [_alice]);
      });
      test(
        'accepted public to private encrypts videos and drops collaborators',
        () async {
          final list = (await service.createList(
            name: 'Team',
            isCollaborative: true,
            allowedCollaborators: [_alice],
          ))!;
          final cubit = CuratedListInfoCubit(
            currentOwnerPubkey: () => auth.currentPublicKeyHex,
            resolveService: () => service,
            existingList: list,
          );
          addTearDown(cubit.close);
          cubit.visibilityChanged(isPublic: false);
          await cubit.submitted();
          expect(cubit.state.status, CuratedListInfoStatus.saved);
          expect(service.getListById(list.id)!.isPublic, isFalse);
          expect(service.getListById(list.id)!.allowedCollaborators, isEmpty);
          expect(service.getListById(list.id)!.isCollaborative, isFalse);
        },
      );
      test(
        'created video pending sync retains its local membership',
        () async {
          when(() => nostr.publishEvent(any()))
              .thenAnswer((_) async => const PublishFailed());
          final video = 'b' * 64;
          final cubit = CuratedListInfoCubit(
            currentOwnerPubkey: () => auth.currentPublicKeyHex,
            resolveService: () => service,
            videoEventId: video,
          );
          addTearDown(cubit.close);
          cubit.nameChanged('Queued video');
          await cubit.submitted();
          expect(
            cubit.state.status,
            CuratedListInfoStatus.createdWithVideoPendingSync,
          );
          final list = service.lists.single;
          expect(list.videoEventIds, [video]);
          expect(list.pendingRepublish, isTrue);
        },
      );
      test(
        'queued rename waits until the local edit is persisted',
        () async {
          final list = (await service.createList(
            name: 'Original',
          ))!;
          final gate = Completer<PublishOutcome>();
          Event? first;
          when(() => nostr.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.first as Event;
            if (first == null) {
              first = event;
              return gate.future;
            }
            return acceptedOutcome(event);
          });
          final pending = service.updateList(
            listId: list.id,
            description: 'Earlier save',
          );
          for (var n = 0; first == null && n < 20; n++) {
            await pumpEventQueue();
          }
          expect(first, isNotNull);
          final cubit = CuratedListInfoCubit(
            currentOwnerPubkey: () => auth.currentPublicKeyHex,
            resolveService: () => service,
            existingList: list,
          );
          addTearDown(cubit.close);
          cubit.nameChanged('Queued rename');
          final saving = cubit.submitted();
          await pumpEventQueue();
          expect(cubit.state.status, CuratedListInfoStatus.saving);
          expect(cubit.state.canClose, isFalse);
          expect(service.getListById(list.id)!.name, 'Original');
          gate.complete(acceptedOutcome(first!));
          expect(await pending, isTrue);
          await saving;
          expect(service.getListById(list.id)!.name, 'Queued rename');
        },
      );
    });

    for (final targetPublic in [false, true]) {
      for (final accepts in [false, true]) {
        test('atomic visibility=$targetPublic keeps existing permissions '
            'while pending and commits only if accepted=$accepts', () async {
          final initialPublic = !targetPublic;
          final initialCollaborators = initialPublic ? [_alice] : <String>[];
          final list = (await service.createList(
            name: 'Team',
            isPublic: initialPublic,
            isCollaborative: initialPublic,
            allowedCollaborators: initialCollaborators,
          ))!;
          final videoId = 'b' * 64;
          expect(await service.addVideoToList(list.id, videoId), isTrue);
          final cubit = CuratedListInfoCubit(
            currentOwnerPubkey: () => auth.currentPublicKeyHex,
            resolveService: () => service,
            existingList: service.getListById(list.id),
          );
          addTearDown(cubit.close);
          cubit.visibilityChanged(isPublic: targetPublic);
          if (targetPublic) {
            cubit.collaboratorsPicked(offered: const {}, picked: {_alice});
          }
          final gate = Completer<PublishOutcome>();
          Event? event;
          var publishCalls = 0;
          when(() => nostr.publishEventAwaitOk(any())).thenAnswer((i) {
            final signed = i.positionalArguments.first as Event;
            if (signed.kind == 5) return Future.value(acceptedOutcome(signed));
            publishCalls++;
            event = signed;
            return gate.future;
          });
          final saving = cubit.submitted();
          for (var n = 0; event == null && n < 20; n++) {
            await pumpEventQueue();
          }
          expect(event, isNotNull);
          final pending = service.getListById(list.id)!;
          expect(pending.isPublic, initialPublic);
          expect(pending.isCollaborative, initialPublic);
          expect(pending.allowedCollaborators, initialCollaborators);
          expect(cubit.state.status, CuratedListInfoStatus.saving);
          final decoded = CuratedListConverter.fromEvent(
            event!,
            privateTags: targetPublic ? null : const [],
          )!;
          expect(decoded.isPublic, targetPublic);
          expect(decoded.isCollaborative, targetPublic);
          expect(
            decoded.allowedCollaborators,
            targetPublic ? [_alice] : <String>[],
          );
          if (targetPublic) {
            expect(event!.tags, contains(equals(['e', videoId])));
          } else {
            expect(unsealForTest(event!.content), contains(videoId));
            expect(event!.tags.where((t) => t.first == 'e'), isEmpty);
          }
          gate.complete(
            accepts ? acceptedOutcome(event!) : rejectedOutcome(event!),
          );
          await saving;
          final stored = service.getListById(list.id)!;
          expect(stored.isPublic, accepts ? targetPublic : initialPublic);
          expect(
            stored.isCollaborative,
            accepts ? targetPublic : initialPublic,
          );
          expect(
            stored.allowedCollaborators,
            accepts
                ? (targetPublic ? [_alice] : <String>[])
                : initialCollaborators,
          );
          expect(stored.videoEventIds, [videoId]);
          expect(
            cubit.state.status,
            accepts
                ? CuratedListInfoStatus.saved
                : CuratedListInfoStatus.failure,
          );
          expect(publishCalls, 1);
        });
      }
    }

    group('a private list made public with collaborators', () {
      late CuratedList list;
      late CuratedListInfoCubit cubit;

      setUp(() async {
        list = (await service.createList(name: 'Puppets', isPublic: false))!;
        cubit = CuratedListInfoCubit(
          currentOwnerPubkey: () => auth.currentPublicKeyHex,
          resolveService: () => service,
          existingList: list,
        );
        addTearDown(cubit.close);
        cubit
          ..visibilityChanged(isPublic: true)
          ..collaboratorsPicked(offered: const {}, picked: {_alice});
      });

      test('stays private, with nobody added, when no relay accepts the '
          'flip', () async {
        rejectPublishing();
        clearInteractions(nostr);

        await cubit.submitted();

        expect(cubit.state.status, equals(CuratedListInfoStatus.failure));
        final stored = service.getListById(list.id)!;
        expect(stored.isPublic, isFalse);
        expect(stored.isCollaborative, isFalse);
        expect(stored.allowedCollaborators, isEmpty);
        final published = verify(
          () => nostr.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(published, hasLength(1));
        expect(
          published.single.tags,
          contains(equals(['collaborator', _alice])),
        );
      });

      test(
        'ends public and collaborative in a single accepted replacement',
        () async {
          clearInteractions(nostr);
          await cubit.submitted();

          expect(cubit.state.status, equals(CuratedListInfoStatus.saved));
          final stored = service.getListById(list.id)!;
          expect(stored.isPublic, isTrue);
          expect(stored.isCollaborative, isTrue);
          expect(stored.allowedCollaborators, equals([_alice]));
          final published = verify(
            () => nostr.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          expect(published, hasLength(1));
          expect(
            published.single.tags,
            contains(equals(['collaborative', 'true'])),
          );
          expect(
            published.single.tags,
            contains(equals(['collaborator', _alice])),
          );
          verifyNever(() => nostr.publishEvent(any()));
        },
      );

      test('private to public accepted replacement retains remote permissions '
          'even when equal timestamps use the lower event id', () async {
        final public = list.copyWith(isPublic: true);
        final collaborative = public.copyWith(
          isCollaborative: true,
          allowedCollaborators: [_alice],
        );
        final content = 'Curated video list: ${list.name}';
        var stamp = DateTime.utc(2026, 10, 4).millisecondsSinceEpoch ~/ 1000;
        while (true) {
          final without = Event(
            _owner,
            30005,
            CuratedListConverter.toEventTags(public),
            content,
            createdAt: stamp,
          );
          final withPermissions = Event(
            _owner,
            30005,
            CuratedListConverter.toEventTags(collaborative),
            content,
            createdAt: stamp,
          );
          if (without.id.compareTo(withPermissions.id) < 0) break;
          stamp++;
        }
        when(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer(
          (i) async => Event(
            _owner,
            i.namedArguments[#kind] as int,
            i.namedArguments[#tags] as List<List<String>>,
            i.namedArguments[#content] as String,
            createdAt: stamp,
          ),
        );
        Event? remote;
        final sent = <Event>[];
        when(() => nostr.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.first as Event;
          sent.add(event);
          final earlier = remote;
          if (earlier == null ||
              event.createdAt > earlier.createdAt ||
              (event.createdAt == earlier.createdAt &&
                  event.id.compareTo(earlier.id) < 0)) {
            remote = event;
          }
          return acceptedOutcome(event);
        });
        await cubit.submitted();
        expect(cubit.state.status, CuratedListInfoStatus.saved);
        expect(service.getListById(list.id)!.allowedCollaborators, [_alice]);
        final remoteList = CuratedListConverter.fromEvent(remote!)!;
        expect(remoteList.allowedCollaborators, [_alice]);
        expect(remoteList.isCollaborative, isTrue);
        expect(sent, hasLength(1));
      });
    });
  });
}
