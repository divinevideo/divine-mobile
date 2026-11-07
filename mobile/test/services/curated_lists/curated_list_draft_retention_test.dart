// ABOUTME: Exercises private list-draft retention through real account cleanup.
// ABOUTME: Covers secure failures, owner restoration, account races and deletion.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_draft_archive.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/committed_list_account.dart';
import '../../helpers/curated_list_publish_stubs.dart';
import '../../helpers/shared_channel_override.dart';
import '../../helpers/signed_curated_list.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

class _SecureDevice {
  final values = <String, String>{};
  bool rejectWrites = false;
  bool ignoreWrites = false;
  bool rejectDeletes = false;
  String? pausedReadKey;
  Completer<void>? readStarted;
  Completer<void>? releaseRead;
  bool _readPaused = false;

  Future<Object?> handle(MethodCall call) async {
    final args = call.arguments as Map;
    final key = args['key'] as String?;
    switch (call.method) {
      case 'read':
        final before = values[key];
        if (key == pausedReadKey && !_readPaused) {
          _readPaused = true;
          readStarted?.complete();
          await releaseRead?.future;
        }
        return before;
      case 'write':
        if (rejectWrites) throw PlatformException(code: 'secure_write_failed');
        if (!ignoreWrites) values[key!] = args['value'] as String;
        return null;
      case 'delete':
        if (rejectDeletes)
          throw PlatformException(code: 'secure_delete_failed');
        values.remove(key);
        return null;
      case 'readAll':
        return Map<String, String>.of(values);
      case 'containsKey':
        return values.containsKey(key);
    }
    return null;
  }
}

void main() {
  const owner = signedListFixtureOwner;
  final other = 'b' * 64;
  final first = '1' * 64;
  final added = '2' * 64;
  final third = '3' * 64;
  late SharedPreferences prefs;
  late _SecureDevice device;
  late SecureCuratedListDraftArchive archive;
  late _Auth auth;
  late _Client client;
  final opened = <CuratedListService>[];

  CuratedList row(String pubkey, {String name = 'Private draft'}) {
    final baseline = CuratedList(
      id: 'retained',
      name: 'Original',
      description: 'Private description',
      pubkey: pubkey,
      isPublic: false,
      videoEventIds: [first],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      nostrEventId: 'd' * 64,
    );
    final desired = baseline.copyWith(
      name: name,
      videoEventIds: [first, added],
    );
    return desired.copyWith(
      localEditDraft: CuratedListEditDraft(
        baseline: baseline,
        desired: desired,
      ),
    );
  }

  Future<void> activate(String pubkey, {List<CuratedList>? cache}) async {
    await prefs.setString('current_user_pubkey_hex', pubkey);
    if (cache != null)
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode(cache.map((r) => r.toJson()).toList()),
      );
    auth = _Auth();
    client = _Client();
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(pubkey);
    stubListPublishing(client: client, auth: auth, pubkey: pubkey);
    when(
      () => client.subscribe(
        any(),
        closeOnEose: true,
        onEose: any(named: 'onEose'),
      ),
    ).thenAnswer((_) => const Stream<Event>.empty());
    await stubCommittedListAccount(
      auth: auth,
      preferences: prefs,
      replaceLiveAccount: true,
    );
  }

  CuratedListService open({bool retain = true}) {
    final service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
      draftArchive: retain ? archive : null,
    );
    opened.add(service);
    return service;
  }

  UserDataCleanupService cleanup() =>
      UserDataCleanupService(prefs, listDraftArchive: archive);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    device = _SecureDevice();
    overrideSharedChannel(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      device.handle,
    );
    archive = SecureCuratedListDraftArchive(const FlutterSecureStorage());
    opened.clear();
    await activate(owner, cache: [row(owner)]);
  });

  tearDown(() {
    for (final service in opened) {
      service.dispose();
    }
  });

  group('owner-private draft archive', () {
    test('secure archive rejects foreign rows and stale consumption', () async {
      await expectLater(
        archive.replaceOwner(owner, [row(other)]),
        throwsA(isA<CuratedListDraftArchiveException>()),
      );
      await archive.replaceOwner(owner, [row(owner)]);
      final before = (await archive.readOwner(owner))!;
      await archive.replaceOwner(owner, [row(owner, name: 'Newer draft')]);
      expect(await archive.consumeOwner(owner, before.revision), isFalse);
      expect(
        (await archive.readOwner(owner))!.lists.single.name,
        'Newer draft',
      );
      expect(
        prefs.getKeys().any(
          (key) => key.startsWith(SecureCuratedListDraftArchive.storagePrefix),
        ),
        isFalse,
      );
    });

    test(
      'ordinary logout and A to B to A restore only the active owner',
      () async {
        await cleanup().clearUserSpecificData(
          reason: 'logout',
          userPubkey: owner,
        );
        expect(prefs.getString(CuratedListService.listsStorageKey), isNull);
        final retained = (await archive.readOwner(owner))!;
        expect(retained.lists.single.localEditDraft!.desired.videoEventIds, [
          first,
          added,
        ]);
        await activate(other, cache: [row(other, name: 'Other private draft')]);
        final b = open();
        await b.initialize();
        expect(b.getListById('$owner:retained'), isNull);
        expect(b.myLists.every((r) => r.pubkey == other), isTrue);
        await cleanup().clearUserSpecificData(
          isIdentityChange: true,
          userPubkey: owner,
        );
        expect(await archive.readOwner(owner), isNotNull);
        expect(await archive.readOwner(other), isNotNull);
        await activate(owner);
        final a = open();
        await a.initialize();
        expect(a.getListById('$owner:retained')!.videoEventIds, [first, added]);
        expect(
          a.getListById('$owner:retained')!.localEditDraft!.desired.name,
          'Private draft',
        );
        expect(a.getListById('$other:retained'), isNull);
        expect(await archive.readOwner(owner), isNull);
        expect(await archive.readOwner(other), isNotNull);
      },
    );

    for (final refusal in ['throws', 'readback']) {
      test(
        'secure archive $refusal failure keeps the complete live cache',
        () async {
          final before = prefs.getString(CuratedListService.listsStorageKey);
          device.rejectWrites = refusal == 'throws';
          device.ignoreWrites = refusal == 'readback';
          await expectLater(
            cleanup().clearUserSpecificData(userPubkey: owner),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(prefs.getString(CuratedListService.listsStorageKey), before);
          expect(await archive.readOwner(owner), isNull);
        },
      );
    }

    test(
      'cleanup replay after the cache sweep preserves the secure archive',
      () async {
        final service = cleanup();
        service.onDatabaseCleanup =
            ({
              String? userPubkey,
              bool deleteUserData = false,
              bool preserveActiveSession = false,
              bool forgetAccount = false,
            }) async {
              throw StateError('Synthetic database refusal');
            };
        await expectLater(
          service.clearUserSpecificData(
            isIdentityChange: true,
            userPubkey: other,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        final retained =
            device.values[SecureCuratedListDraftArchive.storageKey(owner)];
        expect(retained, isNotNull);
        expect(prefs.getString(CuratedListService.listsStorageKey), isNull);
        service.onDatabaseCleanup = null;
        await service.clearUserSpecificData(
          isIdentityChange: true,
          userPubkey: other,
        );
        expect(
          device.values[SecureCuratedListDraftArchive.storageKey(owner)],
          retained,
        );
      },
    );

    test('constructor mutation waits for restore without retargeting another account', () async {
      await archive.replaceOwner(owner, [row(owner)]);
      await prefs.setString(CuratedListService.listsStorageKey, '[]');
      device.pausedReadKey = SecureCuratedListDraftArchive.storageKey(owner);
      device.readStarted = Completer<void>();
      device.releaseRead = Completer<void>();
      final a = open();
      final changing = a.addVideoToList('$owner:retained', third);
      await device.readStarted!.future;
      await cleanup().clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: other,
      );
      expect(await archive.readOwner(other), isNull);
      await activate(other, cache: [row(other)]);
      final before = prefs.getString(CuratedListService.listsStorageKey);
      device.releaseRead!.complete();
      expect(await changing, isFalse);
      expect(prefs.getString(CuratedListService.listsStorageKey), before);
      expect(await archive.readOwner(owner), isNotNull);
      expect(open().getListById('$owner:retained'), isNull);
    });

    test(
      'constructor mutation restores the saved intent before editing',
      () async {
        await archive.replaceOwner(owner, [row(owner)]);
        await prefs.remove(CuratedListService.listsStorageKey);
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: true, noRelays: false),
        );
        final service = open();
        expect(await service.addVideoToList('$owner:retained', third), isFalse);
        expect(service.getListById('$owner:retained')!.videoEventIds, [
          first,
          added,
          third,
        ]);
        expect(await archive.readOwner(owner), isNull);
      },
    );

    test('a concurrent accepted cache winner retains the archived intent separately', () async {
      await archive.replaceOwner(owner, [row(owner)]);
      await prefs.setString(CuratedListService.listsStorageKey, '[]');
      device.pausedReadKey = SecureCuratedListDraftArchive.storageKey(owner);
      device.readStarted = Completer<void>();
      device.releaseRead = Completer<void>();
      final service = open();
      final initializing = service.initialize();
      await device.readStarted!.future;
      final winner = row(owner).copyWith(
        name: 'Remote winner',
        videoEventIds: [third],
        clearLocalEditDraft: true,
        nostrEventId: 'e' * 64,
      );
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([winner.toJson()]),
      );
      device.releaseRead!.complete();
      await initializing;
      final restored = service.getListById('$owner:retained')!;
      expect(restored.name, 'Remote winner');
      expect(restored.videoEventIds, [third]);
      expect(restored.localEditDraft!.desired.videoEventIds, [first, added]);
      expect(restored.hasRelayConflict, isTrue);
    });

    test(
      'restoration honors a deleted coordinate instead of resurrecting it',
      () async {
        await archive.replaceOwner(owner, [row(owner)]);
        await prefs.remove(CuratedListService.listsStorageKey);
        await prefs.setStringList(
          PrefsCuratedListStore.deletedCoordinatesStorageKey,
          ['$owner:retained'],
        );
        final service = open();
        await service.initialize();
        expect(service.getListById('$owner:retained'), isNull);
        expect(await archive.readOwner(owner), isNull);
      },
    );

    test('removing inactive A preserves active B and only deletes A secure payload', () async {
      await archive.replaceOwner(owner, [row(owner)]);
      await archive.replaceOwner(other, [row(other)]);
      final retainedB =
          device.values[SecureCuratedListDraftArchive.storageKey(other)];
      await activate(other, cache: [row(other)]);
      final b = open(retain: false);
      final cached = prefs.getString(CuratedListService.listsStorageKey);
      await cleanup().deleteAccountData(
        owner,
        userNpub: NostrKeyUtils.encodePubKey(owner),
        preserveActiveSession: true,
      );
      expect(await archive.readOwner(owner), isNull);
      expect(
        device.values[SecureCuratedListDraftArchive.storageKey(other)],
        retainedB,
      );
      expect(prefs.getString(CuratedListService.listsStorageKey), cached);
      expect(b.isCurrentSession, isTrue);
    });

    test(
      'failed forget remains retryable without dropping either owner payload',
      () async {
        await archive.replaceOwner(owner, [row(owner)]);
        await archive.replaceOwner(other, [row(other)]);
        device.rejectDeletes = true;
        await expectLater(
          cleanup().clearUserSpecificData(
            userPubkey: owner,
            forgetAccount: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(prefs.getString(PendingAccountCleanup.storageKey), isNotNull);
        expect(await archive.readOwner(owner), isNotNull);
        expect(await archive.readOwner(other), isNotNull);
        device.rejectDeletes = false;
        await cleanup().clearUserSpecificData(
          userPubkey: owner,
          forgetAccount: true,
        );
        expect(await archive.readOwner(owner), isNull);
        expect(await archive.readOwner(other), isNotNull);
        expect(prefs.getString(PendingAccountCleanup.storageKey), isNull);
      },
    );
  });
}
