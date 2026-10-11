// ABOUTME: The real service supplies safe display rows independently of writing.
// ABOUTME: Recovery keeps proven own rows visible without granting a capability.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/committed_list_account.dart';
import '../helpers/curated_list_publish_stubs.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

class _ObservedService extends CuratedListService {
  _ObservedService({
    required super.nostrService,
    required super.authService,
    required super.prefs,
  });

  String? lastRemovalCoordinate;

  @override
  Future<bool> removeVideoFromList(String listId, String videoId) {
    lastRemovalCoordinate = listId;
    return super.removeVideoFromList(listId, videoId);
  }
}

void main() {
  group('real picker ownership projection', () {
    final alice = 'a' * 64;
    final bob = 'b' * 64;
    final video = 'c' * 64;
    late SharedPreferences prefs;
    late _Auth auth;
    late _Client client;
    late _ObservedService service;

    CuratedList row(String id, {String? owner, bool pending = false}) =>
        CuratedList(
          id: id,
          name: id,
          pubkey: owner,
          isPublic: false,
          pendingRepublish: pending,
          videoEventIds: [video],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );

    Future<void> load(List<CuratedList> rows, {Object? follows}) async {
      SharedPreferences.setMockInitialValues({
        CuratedListService.listsStorageKey: jsonEncode(
          rows.map((list) => list.toJson()).toList(),
        ),
        CuratedListService.subscribedListsStorageKey: ?follows,
      });
      prefs = await SharedPreferences.getInstance();
      auth = _Auth();
      client = _Client();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(alice);
      stubListPublishing(client: client, auth: auth, pubkey: alice);
      await stubCommittedListAccount(auth: auth, preferences: prefs);
      service = _ObservedService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
    }

    Map<String, Object?> rawSnapshot() => {
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };

    test(
      'an unrelated journal hold retains an own row but blocks every action',
      () async {
        final own = row('Own', owner: alice, pending: true);
        final foreign = row('Foreign', owner: bob);
        await load([own, foreign]);
        await prefs.setString(
          CuratedListRecoveryJournal.storageKey(alice),
          'broken journal',
        );
        expect(service.recoveryNeedsRepair, isTrue);
        final before = rawSnapshot();
        clearInteractions(auth);
        clearInteractions(client);
        final cubit = SelectListCubit(
          service: service,
          videoEventId: video,
          currentOwnerPubkey: () => alice,
        );
        addTearDown(cubit.close);

        expect(cubit.state.lists, [own]);
        expect(cubit.state.selectedListIds, {'Own'});
        expect(cubit.state.recoveryReadOnly, isTrue);
        expect(cubit.state.canEdit, isFalse);
        cubit.toggled('Own');
        expect(await cubit.submitted(), isNull);
        await cubit.syncRequested('Own');
        expect(cubit.state.lists, [own]);
        expect(cubit.state.selectedListIds, {'Own'});
        expect(rawSnapshot(), before);
        verifyNever(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        );
        verifyZeroInteractions(client);
      },
    );

    test(
      'contradictory raw owner metadata cannot become a picker row',
      () async {
        final own = row('Own', owner: alice);
        final doubtful = row('Doubtful', owner: alice);
        final foreign = row('Foreign', owner: bob);
        await load([own, doubtful, foreign]);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([
            own.toJson(),
            {...doubtful.toJson(), 'authorPubkey': bob},
            foreign.toJson(),
          ]),
        );
        final before = rawSnapshot();

        expect(service.pickerListsForOwner(alice), [own]);
        expect(service.pickerListsForOwner(bob), isEmpty);
        expect(rawSnapshot(), before);
      },
    );

    test(
      'a draft already stamped by the editor stays visible under a hold',
      () async {
        final draft = row('Saved draft', owner: alice, pending: true);
        await load([draft]);
        await prefs.setString(
          CuratedListRecoveryJournal.storageKey(alice),
          'broken journal',
        );
        final before = rawSnapshot();

        expect(service.pickerListsForOwner(alice), [draft]);
        expect(rawSnapshot(), before);
      },
    );

    test(
      'one acknowledged legacy draft has positive ownership proof',
      () async {
        final draft = row('Legacy');
        await load([draft], follows: '[]');
        final before = rawSnapshot();

        expect(service.pickerListsForOwner(alice), [draft]);
        expect(rawSnapshot(), before);
      },
    );

    test(
      'a foreign-first namesake cannot redirect a legacy draft mutation',
      () async {
        final foreign = row('Legacy', owner: bob);
        final draft = row('Legacy');
        await load([foreign, draft], follows: '[]');
        final foreignBefore = jsonEncode(foreign.toJson());
        final cubit = SelectListCubit(
          service: service,
          videoEventId: video,
          currentOwnerPubkey: () => alice,
        );
        addTearDown(cubit.close);
        expect(cubit.state.lists, [draft]);
        cubit.toggled('Legacy');
        expect(await cubit.submitted(), SelectListStatus.saved);
        expect(service.lastRemovalCoordinate, ':Legacy');
        expect(service.getListById('$alice:Legacy')?.pubkey, alice);
        expect(service.getListById('$alice:Legacy')?.videoEventIds, isEmpty);
        expect(service.getListById('$bob:Legacy'), foreign);
        final persisted = (jsonDecode(
          prefs.getString(CuratedListService.listsStorageKey)!,
        ) as List<dynamic>).cast<Map<String, dynamic>>();
        expect(
          jsonEncode(persisted.singleWhere((list) => list['pubkey'] == bob)),
          foreignBefore,
        );
        expect(
          prefs.getString(CuratedListService.subscribedListsStorageKey),
          '[]',
        );
      },
    );

    for (final aliases in [
      ['Legacy'],
      [':Legacy'],
    ]) {
      test(
        'a followed ${aliases.single} alias cannot be offered as a local draft',
        () async {
          await load([row('Legacy')], follows: jsonEncode(aliases));
          final before = rawSnapshot();
          expect(service.pickerListsForOwner(alice), isEmpty);
          expect(rawSnapshot(), before);
        },
      );
    }

    test('unreadable follows never prove legacy-draft ownership', () async {
      await load([row('Legacy')], follows: 'broken follows');
      final before = rawSnapshot();
      expect(service.pickerListsForOwner(alice), isEmpty);
      expect(rawSnapshot(), before);
    });

    test('an existing owned destination excludes a legacy namesake', () async {
      final own = row('Legacy', owner: alice);
      await load([row('Legacy'), own], follows: '[]');
      expect(service.pickerListsForOwner(alice), [own]);
    });

    test('a retired service never exposes private picker rows', () async {
      await load([row('Own', owner: alice)]);
      service.dispose();
      expect(service.pickerListsForOwner(alice), isEmpty);
    });
  });
}
