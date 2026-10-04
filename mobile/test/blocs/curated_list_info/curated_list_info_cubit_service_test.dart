// ABOUTME: Tests CuratedListInfoCubit against the real CuratedListService, for
// ABOUTME: what a save leaves stored when the relays refuse part of it.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
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

    group('a private list made public with collaborators', () {
      late CuratedList list;
      late CuratedListInfoCubit cubit;

      setUp(() async {
        list = (await service.createList(name: 'Puppets', isPublic: false))!;
        cubit = CuratedListInfoCubit(service: service, existingList: list);
        addTearDown(cubit.close);
        cubit
          ..visibilityChanged(isPublic: true)
          ..collaboratorsPicked(offered: const {}, picked: {_alice});
      });

      test('stays private, with nobody added, when no relay accepts the '
          'flip', () async {
        rejectPublishing();

        await cubit.submitted();

        expect(cubit.state.status, equals(CuratedListInfoStatus.failure));
        final stored = service.getListById(list.id)!;
        expect(stored.isPublic, isFalse);
        expect(stored.isCollaborative, isFalse);
        expect(stored.allowedCollaborators, isEmpty);
      });

      test('ends public and collaborative once the relays accept', () async {
        await cubit.submitted();

        expect(cubit.state.status, equals(CuratedListInfoStatus.saved));
        final stored = service.getListById(list.id)!;
        expect(stored.isPublic, isTrue);
        expect(stored.isCollaborative, isTrue);
        expect(stored.allowedCollaborators, equals([_alice]));
      });
    });
  });
}
