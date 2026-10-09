// ABOUTME: Authenticated repair entry points preserve session and read-only fences.
// ABOUTME: Applies audited evidence locally without publishing private payloads.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import '../../helpers/committed_list_account.dart';
import '../../helpers/curated_list_publish_stubs.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _RepairStore extends InMemorySharedPreferencesStore {
  _RepairStore() : super.empty();
  Completer<void>? markerStarted;
  Completer<bool>? markerAnswer;
  bool readbackUnavailable = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (markerAnswer != null &&
        key.contains(CuratedListRecoveryStorage.quarantinePrefix) &&
        (jsonDecode(value as String) as Map)['needsRepair'] == false) {
      markerStarted!.complete();
      if (!await markerAnswer!.future) return false;
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    if (readbackUnavailable) throw StateError('backend read unavailable');
    return super.getAllWithParameters(parameters);
  }
}

void main() {
  const owner =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const eventId =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  late SharedPreferences prefs;
  late CuratedListService service;
  late _Client client;
  late _Auth auth;
  late _RepairStore backend;
  late SharedPreferencesStorePlatform previous;
  final reconstructed = jsonEncode({
    'bad': const CuratedListRecoveryRecord(
      plaintextEventIds: [eventId],
    ).toJson(),
  });

  setUpAll(() => registerFallbackValue(<Filter>[]));
  setUp(() async {
    previous = SharedPreferencesStorePlatform.instance;
    backend = _RepairStore();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = backend;
    prefs = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026);
    await prefs.setString(
      'curated_lists',
      jsonEncode([
        CuratedList(
          id: CuratedListService.defaultListId,
          name: 'Existing list',
          pubkey: owner,
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
          nostrEventId: eventId,
        ).toJson(),
      ]),
    );
    await prefs.setString(
      CuratedListRecoveryJournal.storageKey(owner),
      jsonEncode({'bad': true}),
    );
    auth = _Auth();
    client = _Client();
    stubListSigner(client, owner);
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(owner);
    when(() => client.subscribe(any(), closeOnEose: true))
        .thenAnswer((_) => const Stream<Event>.empty());
    await stubCommittedListAccount(auth: auth, preferences: prefs);
    service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
    );
    await service.initialize();
  });
  tearDown(() {
    service.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
  });

  group('CuratedListRecoveryService', () {
    test('an invalid proposal retains read-only state, verified repair reinitializes safely', () async {
      expect(service.isInitialized, isTrue);
      expect(service.isReadyForMutations, isFalse);
      final snapshot = service.recoveryRepairSnapshot!;
      expect(
        await service.repairRecoveryFromVerifiedJournal(
          expectedSnapshot: snapshot,
          reconstructedJournal: '{}',
        ),
        isFalse,
      );
      expect(service.recoveryNeedsRepair, isTrue);
      expect(
        await service.repairRecoveryFromVerifiedJournal(
          expectedSnapshot: service.recoveryRepairSnapshot!,
          reconstructedJournal: reconstructed,
        ),
        isTrue,
      );
      expect(service.recoveryNeedsRepair, isFalse);
      expect(service.isInitialized, isTrue);
      expect(service.isReadyForMutations, isTrue);
      expect(service.hasDefaultList(), isTrue);
      verifyNever(() => client.publishEventAwaitOk(any()));
      verifyNever(() => client.publishEvent(any()));
    });

    test(
      'owner repair cannot report regained writes while a device hold remains',
      () async {
        await prefs.setString('curated_lists', 'unreadable shared evidence');
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
        var notifications = 0;
        service.addListener(() => notifications++);
        expect(
          await service.repairRecoveryFromVerifiedJournal(
            expectedSnapshot: service.recoveryRepairSnapshot!,
            reconstructedJournal: reconstructed,
          ),
          isFalse,
        );
        expect(service.isInitialized, isTrue);
        expect(service.initializationError, isNull);
        expect(service.recoveryNeedsRepair, isTrue);
        expect(service.isReadyForMutations, isFalse);
        expect(notifications, greaterThan(0));
        final ownerArchive = jsonDecode(
          prefs.getString(
            CuratedListRecoveryStorage.quarantineKey(owner),
          )!,
        ) as Map<String, dynamic>;
        expect(ownerArchive['needsRepair'], isFalse);
        expect(
          (jsonDecode(
            prefs.getString(
              CuratedListRecoveryStorage.sharedQuarantineKey,
            )!,
          ) as Map)['needsRepair'],
          isTrue,
        );
      },
    );

    test(
      'retiring the account container cancels its repair proposal',
      () async {
        final snapshot = service.recoveryRepairSnapshot!;
        await CuratedListSessionCoordinator.forPreferences(prefs)
            .retireAndDrain();
        expect(service.recoveryRepairSnapshot, isNull);
        expect(
          await service.repairRecoveryFromVerifiedJournal(
            expectedSnapshot: snapshot,
            reconstructedJournal: reconstructed,
          ),
          isFalse,
        );
        final journal = CuratedListRecoveryJournal(
          prefs: prefs,
          runCurrent: (op) => op(),
        );
        expect(journal.needsRepair(owner), isTrue);
      },
    );
    for (final peerWriter in [false, true]) {
      test(
        'no mutations before final repair marker is durable, peer=$peerWriter',
        () async {
          final peer = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: prefs,
          );
          addTearDown(peer.dispose);
          await peer.initialize();
          final writer = peerWriter ? peer : service;
          var notifications = 0;
          peer.addListener(() => notifications++);
          backend.markerStarted = Completer<void>();
          backend.markerAnswer = Completer<bool>();
          final repair = service.repairRecoveryFromVerifiedJournal(
            expectedSnapshot: service.recoveryRepairSnapshot!,
            reconstructedJournal: reconstructed,
          );
          await backend.markerStarted!.future;
          expect(writer.isReadyForMutations, isFalse);
          expect(
            await writer.createList(name: 'Before durable repair'),
            isNull,
          );
          backend.markerAnswer!.complete(false);
          expect(await repair, isFalse);
          expect(notifications, greaterThan(0));
          expect(service.recoveryNeedsRepair, isTrue);
          expect(peer.isReadyForMutations, isFalse);
          final replacement = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: prefs,
          );
          addTearDown(replacement.dispose);
          await replacement.initialize();
          expect(replacement.isReadyForMutations, isFalse);
          expect(
            await replacement.createList(name: 'After refused repair'),
            isNull,
          );
          expect(
            prefs.getString('curated_lists'),
            isNot(contains('Before durable repair')),
          );
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );
    }

    test('failed final readback stays held across replacement services until truthful refresh', () async {
      backend.markerStarted = Completer<void>();
      backend.markerAnswer = Completer<bool>();
      final repair = service.repairRecoveryFromVerifiedJournal(
        expectedSnapshot: service.recoveryRepairSnapshot!,
        reconstructedJournal: reconstructed,
      );
      await backend.markerStarted!.future;
      backend.readbackUnavailable = true;
      backend.markerAnswer!.complete(false);
      await expectLater(repair, throwsA(isA<CuratedListRecoveryException>()));
      final replacement = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(replacement.dispose);
      expect(replacement.recoveryNeedsRepair, isTrue);
      await replacement.initialize();
      expect(
        replacement.initializationError,
        isA<CuratedListRecoveryException>(),
      );
      expect(await replacement.createList(name: 'Unverified state'), isNull);
      backend.readbackUnavailable = false;
      await replacement.initialize();
      expect(replacement.initializationError, isNull);
      expect(replacement.isInitialized, isTrue);
      expect(replacement.recoveryNeedsRepair, isTrue);
      expect(replacement.isReadyForMutations, isFalse);
      final archive = jsonDecode(
        prefs.getString(CuratedListRecoveryStorage.quarantineKey(owner))!,
      ) as Map;
      expect(archive['needsRepair'], isTrue);
      expect(archive['rawBuckets'], contains('{"bad":true}'));
    });
  });
}
