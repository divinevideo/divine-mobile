// ABOUTME: Verifies editor saves and retries use an author's exact list identity.
// ABOUTME: Exercises real preferences and service with colliding raw d-tags.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/committed_list_account.dart';
import '../../helpers/curated_list_publish_stubs.dart';

class _Nostr extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

void main() {
  final owner = 'f' * 64;
  final otherAuthor = 'a' * 64;
  const rawId = 'same-d-tag';

  CuratedList row(String? author, String name, {bool pending = false}) =>
      CuratedList(
        id: rawId,
        pubkey: author,
        name: name,
        description: 'Description for $name',
        videoEventIds: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        nostrEventId: author == null
            ? null
            : author == owner
            ? 'b' * 64
            : 'c' * 64,
        pendingRepublish: pending,
      );

  group('submitted and syncRequested author identity', () {
    for (final withLegacyDraft in [false, true]) {
      for (final retry in [false, true]) {
        test(
          '${retry ? 'Sync' : 'Save'} reaches the owned coordinate with '
          '${withLegacyDraft ? 'a legacy draft and ' : ''}another author sharing its d-tag',
          () async {
            final legacy = row(null, 'Guest draft');
            final foreign = row(otherAuthor, 'Foreign list');
            final owned = row(owner, 'Owned list', pending: retry);
            final rows = [if (withLegacyDraft) legacy, foreign, owned];
            SharedPreferences.setMockInitialValues({
              CuratedListService.listsStorageKey: jsonEncode(
                rows.map((list) => list.toJson()).toList(),
              ),
            });
            final prefs = await SharedPreferences.getInstance();
            final nostr = _Nostr();
            final auth = _Auth();
            when(() => auth.isAuthenticated).thenReturn(true);
            when(() => auth.currentPublicKeyHex).thenReturn(owner);
            when(() => nostr.subscribe(any(), onEose: any(named: 'onEose')))
                .thenAnswer((_) => const Stream.empty());
            stubListPublishing(client: nostr, auth: auth, pubkey: owner);
            final published = <Event>[];
            when(() => nostr.publishEventAwaitOk(any()))
                .thenAnswer((invocation) async {
                  final event = invocation.positionalArguments.single as Event;
                  published.add(event);
                  return acceptedOutcome(event);
                });
            when(() => nostr.publishEvent(any()))
                .thenAnswer((invocation) async {
                  final event = invocation.positionalArguments.single as Event;
                  published.add(event);
                  return PublishSuccess(event: event);
                });
            await stubCommittedListAccount(auth: auth, preferences: prefs);
            final service = CuratedListService(
              nostrService: nostr,
              authService: auth,
              prefs: prefs,
            );
            addTearDown(service.dispose);
            expect(service.getListById(owned.authorScopedId), owned);
            expect(service.getListById(foreign.authorScopedId), foreign);
            if (withLegacyDraft) {
              expect(
                service.getListById(rawId),
                legacy,
                reason: 'The compatibility alias can select the guest draft',
              );
              expect(service.getListById(legacy.authorScopedId), legacy);
            }
            final editor = CuratedListInfoCubit(
              resolveService: () => service,
              currentOwnerPubkey: () => auth.currentPublicKeyHex,
              existingList: owned,
            );
            addTearDown(editor.close);
            editor.nameChanged('Unsaved name');

            if (retry) {
              await editor.retrySync();
              expect(editor.state.status, CuratedListInfoStatus.editing);
              expect(editor.state.name, 'Unsaved name');
              expect(editor.state.needsSync, isFalse);
            } else {
              await editor.submitted();
              expect(editor.state.status, CuratedListInfoStatus.saved);
            }

            final current = service.getListById(owned.authorScopedId)!;
            expect(current.pubkey, owner);
            expect(current.id, rawId);
            expect(current.name, retry ? owned.name : 'Unsaved name');
            expect(current.pendingRepublish, isFalse);
            expect(service.getListById(foreign.authorScopedId), foreign);
            if (withLegacyDraft) {
              expect(service.getListById(legacy.authorScopedId), legacy);
              expect(legacy.authorScopedId, ':$rawId');
            }
            expect(published, hasLength(1));
            expect(published.single.pubkey, owner);
            expect(published.single.kind, 30005);
            expect(
              published.single.tags.where((tag) => tag.first == 'd').single,
              ['d', rawId],
              reason: 'Qualified local IDs never alter Nostr d-tags',
            );
            final stored =
                (jsonDecode(
                      prefs.getString(CuratedListService.listsStorageKey)!,
                    ) as List<dynamic>)
                    .map(
                      (value) =>
                          CuratedList.fromJson(value as Map<String, dynamic>),
                    )
                    .toList();
            expect(
              stored.singleWhere(
                (value) => value.authorScopedId == foreign.authorScopedId,
              ),
              foreign,
            );
            if (withLegacyDraft) {
              expect(
                stored.singleWhere(
                  (value) => value.authorScopedId == legacy.authorScopedId,
                ),
                legacy,
              );
            }
            expect(
              stored.singleWhere(
                (value) => value.authorScopedId == owned.authorScopedId,
              ),
              current,
            );
          },
        );
      }
    }
  });
}
