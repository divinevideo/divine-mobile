// ABOUTME: Regression tests for account cleanup provider wiring.
// ABOUTME: Ensures destructive cleanup reaches the live Hive upload store.

import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/models/pending_upload.dart' as hive_model;
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/personal_event_cache_clear_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkeyB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
final String _npubA = NostrKeyUtils.encodePubKey(_pubkeyA);
const _reactionIdA =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _reactionIdB =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _dmConversationId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _dmTargetMessageId =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _dmSecondTargetMessageId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _pendingReactionId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _pendingDeletionId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _legacyNullConversationId =
    '4444444444444444444444444444444444444444444444444444444444444444';

Event _personalEvent(String pubkey, int createdAt) => Event(
  pubkey,
  34236,
  const [
    ['d', 'video'],
  ],
  '',
  createdAt: createdAt,
)..sig = 'f' * 128;

void main() {
  group(userDataCleanupServiceProvider, () {
    late AppDatabase db;
    late SharedPreferences prefs;
    late _MockDmRepository dmRepository;
    late _MockBlossomUploadService blossomUploadService;
    late UploadManager uploadManager;
    late Directory tempDir;
    late PathProviderPlatform originalPathProviderInstance;
    late ProviderContainer container;

    setUpAll(() async {
      await initializeServiceTestEnvironment();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.test(NativeDatabase.memory());
      dmRepository = _MockDmRepository();
      blossomUploadService = _MockBlossomUploadService();
      when(() => dmRepository.stopListening()).thenAnswer((_) async {});
      when(
        () => blossomUploadService.isBlossomEnabled(),
      ).thenAnswer((_) async => false);

      tempDir = await Directory.systemTemp.createTemp(
        'social_cleanup_uploads_',
      );
      originalPathProviderInstance = PathProviderPlatform.instance;
      final mockPathProvider = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support')
        ..setApplicationCachePath('${tempDir.path}/cache');
      PathProviderPlatform.instance = mockPathProvider;
      await TestHelpers.initHiveHome();
      // Without this, UploadInitializationHelper's static _cachedBox short-
      // circuits initialize() past Hive.openBox entirely, so this suite can
      // inherit a previous suite's box -- and the non-destructive test below
      // then asserts on rows it never wrote.
      await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
      // UserDataCleanupService clears push preferences through the Hive-backed
      // store, so this suite also owns the notifications box it opens.
      await TestHelpers.cleanupHiveBox(HiveBoxNames.notifications);

      uploadManager = UploadManager(
        backgroundActivityManager: BackgroundActivityManager(),
        blossomService: blossomUploadService,
        currentNostrPubkey: _pubkeyB,
        scopeUploadsToCurrentUser: true,
      );
      await uploadManager.initialize();
      expect(
        uploadManager.pendingUploads,
        isEmpty,
        reason: 'setUp must hand each test an empty pending_uploads box',
      );

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          dmRepositoryProvider.overrideWithValue(dmRepository),
          openVineImageCacheClearProvider.overrideWithValue(() async {}),
          uploadManagerProvider.overrideWithValue(uploadManager),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      uploadManager.dispose();
      await db.close();
      PathProviderPlatform.instance = originalPathProviderInstance;
      try {
        await TestHelpers.cleanupHiveBox(HiveBoxNames.pendingUploads);
        await TestHelpers.cleanupHiveBox(HiveBoxNames.notifications);
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test(
      'destructive cleanup purges Hive uploads for the departing user',
      () async {
        await db.pendingUploadsDao.upsertUpload(
          model.PendingUpload.create(
            localVideoPath: '/tmp/a.mp4',
            nostrPubkey: _pubkeyA,
          ),
        );
        await db.pendingUploadsDao.upsertUpload(
          model.PendingUpload.create(
            localVideoPath: '/tmp/b.mp4',
            nostrPubkey: _pubkeyB,
          ),
        );
        final box = Hive.box<hive_model.PendingUpload>('pending_uploads');
        final a1 = hive_model.PendingUpload.create(
          localVideoPath: '/tmp/a1.mp4',
          nostrPubkey: _pubkeyA,
        );
        final a2 = hive_model.PendingUpload.create(
          localVideoPath: '/tmp/a2.mp4',
          nostrPubkey: _pubkeyA,
        );
        final b1 = hive_model.PendingUpload.create(
          localVideoPath: '/tmp/b1.mp4',
          nostrPubkey: _pubkeyB,
        );
        await box.put(a1.id, a1);
        await box.put(a2.id, a2);
        await box.put(b1.id, b1);

        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();

        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );

        expect(
          await db.pendingUploadsDao.getAllUploads(ownerPubkey: _pubkeyA),
          isEmpty,
        );
        final remainingDriftUploads = await db.pendingUploadsDao.getAllUploads(
          ownerPubkey: _pubkeyB,
        );
        expect(remainingDriftUploads, hasLength(1));
        expect(box.get(a1.id), isNull);
        expect(box.get(a2.id), isNull);
        expect(box.get(b1.id), isNotNull);
      },
    );

    test(
      'an account switch clears the departing account watch history',
      () async {
        // seen_videos has no owner column, so whatever is in it belongs to
        // whoever was last signed in. It also drives feed dedup, so inheriting
        // it hides videos the incoming account has never seen (#8314).
        await db.seenVideosDao.markSeenBatch([
          SeenVideoRow(
            videoId: _reactionIdA,
            firstSeenAt: DateTime.now().millisecondsSinceEpoch,
            lastSeenAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ]);
        expect(
          await db.seenVideosDao.getAll(),
          hasLength(1),
          reason:
              'the departing account must actually have watch history, '
              'otherwise this test passes on an empty table',
        );

        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();

        await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

        expect(await db.seenVideosDao.getAll(), isEmpty);
      },
    );

    test(
      'an account switch clears live watch history before it can be saved',
      () async {
        final oldMetrics = SeenVideoMetrics(
          videoId: _reactionIdA,
          firstSeenAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
        );
        await prefs.setString(
          SeenVideosService.seenVideosMetricsStorageKey,
          jsonEncode([oldMetrics.toJson()]),
        );
        final seenVideos = container.read(seenVideosServiceProvider);
        await seenVideos.initialize();
        expect(seenVideos.hasSeenVideo(_reactionIdA), isTrue);

        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await subscription.read().onDatabaseCleanup!(userPubkey: _pubkeyA);

        expect(seenVideos.hasSeenVideo(_reactionIdA), isFalse);
        await seenVideos.recordVideoView(_reactionIdB);
        expect(
          prefs.getString(SeenVideosService.seenVideosMetricsStorageKey),
          isNot(contains(_reactionIdA)),
        );
      },
    );

    test(
      'an account switch rebuilds live preference services from defaults',
      () async {
        await prefs.setBool(
          DivineHostFilterService.showDivineHostedOnlyStorageKey,
          false,
        );
        final hostFilterSubscription = container.listen(
          divineHostFilterServiceProvider,
          (_, _) {},
        );
        addTearDown(hostFilterSubscription.close);
        final departingService = hostFilterSubscription.read();
        expect(departingService.showDivineHostedOnly, isFalse);

        final cleanupSubscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(cleanupSubscription.close);
        await cleanupSubscription.read().clearUserSpecificData(
          isIdentityChange: true,
          userPubkey: _pubkeyA,
        );

        final incomingService = container.read(divineHostFilterServiceProvider);
        expect(incomingService, isNot(same(departingService)));
        expect(incomingService.showDivineHostedOnly, isTrue);
      },
    );

    test('account switch resets the live content language', () async {
      final language = container.read(languagePreferenceServiceProvider);
      await language.initialize();
      await language.setContentLanguage('es');
      expect(language.declaredContentLanguage, 'es');

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await subscription.read().clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: _pubkeyA,
      );

      final incoming = container.read(languagePreferenceServiceProvider);
      await incoming.initialize();
      expect(incoming.declaredContentLanguage, isNull);
    });

    test('account switch preserves owner-scoped personal events', () async {
      await db.personalEventsDao.upsertPersonalEvent(
        _personalEvent(_pubkeyA, 1700000000),
      );
      await db.personalEventsDao.upsertPersonalEvent(
        _personalEvent(_pubkeyB, 1700000001),
      );
      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await subscription.read().clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: _pubkeyA,
      );

      expect(await db.personalEventsDao.countForOwner(_pubkeyA), 1);
      expect(await db.personalEventsDao.countForOwner(_pubkeyB), 1);
    });

    test("direct clear removes only the requested owner's events", () async {
      await db.personalEventsDao.upsertPersonalEvent(
        _personalEvent(_pubkeyA, 1700000000),
      );
      await db.personalEventsDao.upsertPersonalEvent(
        _personalEvent(_pubkeyB, 1700000001),
      );
      expect(await db.personalEventsDao.countForOwner(_pubkeyA), 1);
      expect(await db.personalEventsDao.countForOwner(_pubkeyB), 1);

      await container.read(personalEventCacheClearProvider)(_pubkeyA);

      expect(await db.personalEventsDao.countForOwner(_pubkeyA), 0);
      expect(await db.personalEventsDao.countForOwner(_pubkeyB), 1);
    });

    test('clears every account when there is no departing pubkey', () async {
      await db.personalEventsDao.upsertPersonalEvent(
        _personalEvent(_pubkeyA, 1700000000),
      );
      await db.personalEventsDao.upsertPersonalEvent(
        _personalEvent(_pubkeyB, 1700000001),
      );
      expect(await db.personalEventsDao.countForOwner(_pubkeyB), 1);

      await container.read(personalEventCacheClearProvider)(null);

      expect(await db.personalEventsDao.countForOwner(_pubkeyA), 0);
      expect(await db.personalEventsDao.countForOwner(_pubkeyB), 0);
    });

    test(
      'destructive cleanup purges only the departing user personal events',
      () async {
        await db.personalEventsDao.upsertPersonalEvent(
          _personalEvent(_pubkeyA, 1700000000),
        );
        await db.personalEventsDao.upsertPersonalEvent(
          _personalEvent(_pubkeyB, 1700000001),
        );
        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        await subscription.read().onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );

        expect(await db.personalEventsDao.countForOwner(_pubkeyA), 0);
        expect(await db.personalEventsDao.countForOwner(_pubkeyB), 1);
      },
    );

    test(
      'destructive cleanup stops when personal-event cleanup fails',
      () async {
        final failure = StateError('cache cleanup failed');
        container.dispose();
        container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            dmRepositoryProvider.overrideWithValue(dmRepository),
            openVineImageCacheClearProvider.overrideWithValue(() async {}),
            uploadManagerProvider.overrideWithValue(uploadManager),
            personalEventCacheClearProvider.overrideWithValue((_) async {
              throw failure;
            }),
          ],
        );
        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        await expectLater(
          subscription.read().onDatabaseCleanup!(
            userPubkey: _pubkeyA,
            deleteUserData: true,
          ),
          throwsA(same(failure)),
        );
      },
    );

    test('account switch resets the live audio-sharing consent', () async {
      final audio = container.read(audioSharingPreferenceServiceProvider);
      await audio.setAudioSharingEnabled(true);
      expect(audio.isAudioSharingEnabled, isTrue);

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await subscription.read().clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: _pubkeyA,
      );

      expect(
        container
            .read(audioSharingPreferenceServiceProvider)
            .isAudioSharingEnabled,
        isFalse,
      );
    });

    test('account switch resets the live custom sound library', () async {
      final sounds = await container.read(soundLibraryServiceProvider.future);
      await sounds.addCustomSound(
        model.VineSound(
          id: 'departing-sound',
          title: 'Custom sound',
          assetPath: '/local/sound.mp3',
          duration: const Duration(seconds: 2),
        ),
      );
      expect(sounds.customSounds, hasLength(1));

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await subscription.read().clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: _pubkeyA,
      );

      final incoming = await container.read(soundLibraryServiceProvider.future);
      expect(incoming.customSounds, isEmpty);
    });

    test("deleting an account drops only that account's queued work", () async {
      // These rows carry an owner and are filtered by it at flush, so they
      // never leaked into another account. They were simply never deleted
      // when their owner was removed (#8314). The assertion that matters is
      // the second one: the surviving account keeps its queue.
      Future<void> enqueueFor(String pubkey, String suffix) async {
        await db.pendingViewEventsDao.enqueue(
          PendingViewEvent(
            id: 'view_$suffix',
            videoId: _reactionIdA,
            videoPubkey: _pubkeyB,
            userPubkey: pubkey,
            watchDurationMs: 1000,
            trafficSource: 'feed',
            status: PendingViewEventStatus.pending,
            createdAt: DateTime.now(),
          ),
        );
        await db.pendingProductEventsDao.enqueue(
          PendingProductEvent(
            id: 'product_$suffix',
            eventName: 'video_view',
            payloadJson: '{}',
            status: PendingProductEventStatus.pending,
            createdAt: DateTime.now(),
            ownerPubkey: pubkey,
          ),
        );
      }

      await enqueueFor(_pubkeyA, 'a');
      await enqueueFor(_pubkeyB, 'b');

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      await service.onDatabaseCleanup!(
        userPubkey: _pubkeyA,
        deleteUserData: true,
      );

      expect(await db.pendingViewEventsDao.getById('view_a'), isNull);
      expect(await db.pendingProductEventsDao.getById('product_a'), isNull);
      expect(
        await db.pendingViewEventsDao.getById('view_b'),
        isNotNull,
        reason: "the surviving account's queued views must be untouched",
      );
      expect(
        await db.pendingProductEventsDao.getById('product_b'),
        isNotNull,
        reason:
            "the surviving account's queued product events must be "
            'untouched',
      );
    });

    test('non-destructive cleanup preserves pending uploads', () async {
      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      expect(service.onDatabaseCleanup, isNotNull);
      await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

      expect(
        Hive.box<hive_model.PendingUpload>('pending_uploads').values,
        isEmpty,
      );
    });

    test(
      'database cleanup stops existing dm listener through cycle-safe port',
      () async {
        final fakeAuthProvider = Provider<Object>((ref) {
          ref.watch(userDataCleanupServiceProvider);
          return Object();
        });
        final cycleContainer = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            openVineImageCacheClearProvider.overrideWithValue(() async {}),
            uploadManagerProvider.overrideWithValue(uploadManager),
            dmRepositoryProvider.overrideWith((ref) {
              ref.watch(fakeAuthProvider);
              return dmRepository;
            }),
          ],
        );
        addTearDown(cycleContainer.dispose);

        final cleanupSubscription = cycleContainer.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(cleanupSubscription.close);
        cycleContainer.read(dmRepositoryProvider);

        final service = cleanupSubscription.read();
        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );

        verify(() => dmRepository.stopListening()).called(1);
      },
    );

    test('named account deletion preserves the active dm listener', () async {
      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await subscription.read().deleteAccountData(
        _pubkeyA,
        userNpub: _npubA,
        preserveActiveSession: true,
      );

      verifyNever(() => dmRepository.stopListening());
    });

    test(
      'signed-out account deletion clears device-wide media state',
      () async {
        var imageCacheClears = 0;
        final cleanupContainer = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            dmRepositoryProvider.overrideWithValue(dmRepository),
            openVineImageCacheClearProvider.overrideWithValue(() async {
              imageCacheClears++;
            }),
            uploadManagerProvider.overrideWithValue(uploadManager),
          ],
        );
        addTearDown(cleanupContainer.dispose);
        final subscription = cleanupContainer.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        cleanupContainer.read(dmRepositoryProvider);

        await subscription.read().deleteAccountData(
          _pubkeyA,
          userNpub: _npubA,
          preserveActiveSession: false,
        );

        expect(imageCacheClears, 1);
        expect(
          cleanupContainer.read(adultMediaAccessRevocationVersionProvider),
          1,
        );
        verify(() => dmRepository.stopListening()).called(1);
      },
    );

    test('named account deletion propagates database failures', () async {
      final failureContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          dmRepositoryProvider.overrideWithValue(dmRepository),
          openVineImageCacheClearProvider.overrideWithValue(() async {}),
          pendingUploadOwnerCleanupProvider.overrideWithValue(
            (_) async => throw StateError('delete failed'),
          ),
        ],
      );
      addTearDown(failureContainer.dispose);
      final subscription = failureContainer.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      await expectLater(
        service.deleteAccountData(
          _pubkeyA,
          userNpub: _npubA,
          preserveActiveSession: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'database cleanup does not build dm repository just to stop it',
      () async {
        var dmRepositoryBuilt = false;
        final fakeAuthProvider = Provider<Object>((ref) {
          ref.watch(userDataCleanupServiceProvider);
          return Object();
        });
        final cycleContainer = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            openVineImageCacheClearProvider.overrideWithValue(() async {}),
            uploadManagerProvider.overrideWithValue(uploadManager),
            dmRepositoryProvider.overrideWith((ref) {
              dmRepositoryBuilt = true;
              ref.watch(fakeAuthProvider);
              return dmRepository;
            }),
          ],
        );
        addTearDown(cycleContainer.dispose);

        final cleanupSubscription = cycleContainer.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(cleanupSubscription.close);

        final service = cleanupSubscription.read();
        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );

        expect(dmRepositoryBuilt, isFalse);
        verifyNever(() => dmRepository.stopListening());
      },
    );

    Future<void> seedDmReaction({
      required String id,
      required String ownerPubkey,
    }) {
      return db.dmReactionsDao.upsertIncoming(
        id: id,
        conversationId: _dmConversationId,
        targetMessageId: _dmTargetMessageId,
        targetMessageAuthor: _pubkeyB,
        reactorPubkey: _pubkeyB,
        emoji: '😂',
        createdAt: 1_700_000_000,
        giftWrapId: id,
        ownerPubkey: ownerPubkey,
      );
    }

    Future<void> seedPendingOwnReaction({
      required String id,
      required String targetMessageId,
    }) async {
      await db.dmReactionsDao.insertOwnReactionSuperseding(
        placeholderId: id,
        conversationId: _dmConversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: _pubkeyB,
        reactorPubkey: _pubkeyA,
        emoji: '😂',
        createdAt: 1_700_000_000,
        ownerPubkey: _pubkeyA,
        rumorEventJson: '{"id":"$id"}',
      );
    }

    Future<void> seedPendingOwnDeletion({
      required String id,
      required String targetMessageId,
    }) async {
      await seedPendingOwnReaction(id: id, targetMessageId: targetMessageId);
      await db.dmReactionsDao.markOwnDeletionPending(
        id: id,
        ownerPubkey: _pubkeyA,
        deletionRumorJson: '{"kind":5}',
      );
    }

    test(
      'destructive cleanup purges dm reactions for the departing user',
      () async {
        await seedDmReaction(id: _reactionIdA, ownerPubkey: _pubkeyA);
        await seedDmReaction(id: _reactionIdB, ownerPubkey: _pubkeyB);
        await seedPendingOwnReaction(
          id: _pendingReactionId,
          targetMessageId: _dmTargetMessageId,
        );
        await seedPendingOwnDeletion(
          id: _pendingDeletionId,
          targetMessageId: _dmSecondTargetMessageId,
        );

        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();

        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );

        expect(
          await db.dmReactionsDao.getById(
            id: _reactionIdA,
            ownerPubkey: _pubkeyA,
          ),
          isNull,
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _pendingReactionId,
            ownerPubkey: _pubkeyA,
          ),
          isNull,
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _pendingDeletionId,
            ownerPubkey: _pubkeyA,
          ),
          isNull,
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _reactionIdB,
            ownerPubkey: _pubkeyB,
          ),
          isNotNull,
        );
      },
    );

    test(
      'non-destructive cleanup preserves retryable outgoing dm reactions',
      () async {
        await seedDmReaction(id: _reactionIdA, ownerPubkey: _pubkeyA);
        await seedPendingOwnReaction(
          id: _pendingReactionId,
          targetMessageId: _dmTargetMessageId,
        );
        await seedPendingOwnDeletion(
          id: _pendingDeletionId,
          targetMessageId: _dmSecondTargetMessageId,
        );

        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();

        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

        expect(
          await db.dmReactionsDao.getById(
            id: _reactionIdA,
            ownerPubkey: _pubkeyA,
          ),
          isNull,
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _pendingReactionId,
            ownerPubkey: _pubkeyA,
          ),
          isNotNull,
        );
        final deletion = await db.dmReactionsDao.getById(
          id: _pendingDeletionId,
          ownerPubkey: _pubkeyA,
        );
        expect(deletion, isNotNull);
        expect(deletion!.publishStatus, equals('deletion_pending'));
      },
    );

    // The removal tombstone is what keeps a removed conversation from being
    // rebuilt by relay replay (#7804). It is the one DM table deliberately
    // NOT wiped on a plain sign-out, so these two cases pin the gate: move
    // the clear out of the `deleteUserData` branch and every tombstone dies
    // on logout, silently regressing #7804 on the next history drain.
    test('non-destructive cleanup preserves removal tombstones', () async {
      await db.removedConversationsDao.record(
        conversationId: _dmConversationId,
        ownerPubkey: _pubkeyA,
        removedAt: 1700000000,
      );

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      expect(service.onDatabaseCleanup, isNotNull);
      await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

      expect(
        await db.removedConversationsDao.removedAtFor(
          conversationId: _dmConversationId,
          ownerPubkey: _pubkeyA,
        ),
        1700000000,
      );
    });

    test('destructive cleanup purges removal tombstones', () async {
      await db.removedConversationsDao.record(
        conversationId: _dmConversationId,
        ownerPubkey: _pubkeyA,
        removedAt: 1700000000,
      );
      await db.removedConversationsDao.record(
        conversationId: _dmConversationId,
        ownerPubkey: _pubkeyB,
        removedAt: 1700000000,
      );

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      expect(service.onDatabaseCleanup, isNotNull);
      await service.onDatabaseCleanup!(
        userPubkey: _pubkeyA,
        deleteUserData: true,
      );

      expect(
        await db.removedConversationsDao.removedAtFor(
          conversationId: _dmConversationId,
          ownerPubkey: _pubkeyA,
        ),
        isNull,
      );
      // Owner-scoped: the other account's tombstone must survive.
      expect(
        await db.removedConversationsDao.removedAtFor(
          conversationId: _dmConversationId,
          ownerPubkey: _pubkeyB,
        ),
        1700000000,
      );
    });

    group('#7325 owner-scoped DM cleanup', () {
      Future<void> seedDm({
        required String messageId,
        required String conversationId,
        String? ownerPubkey,
      }) async {
        await db.conversationsDao.upsertConversation(
          id: conversationId,
          participantPubkeys: _pubkeyA,
          isGroup: false,
          createdAt: 1700000000,
          ownerPubkey: ownerPubkey,
        );
        await db.directMessagesDao.insertMessage(
          id: messageId,
          conversationId: conversationId,
          senderPubkey: _pubkeyA,
          content: 'hello',
          createdAt: 1700000000,
          giftWrapId: 'gw-$messageId',
          ownerPubkey: ownerPubkey,
        );
      }

      Future<int> dmCountFor(String? owner) async {
        final row = await db
            .customSelect(
              owner == null
                  ? 'SELECT COUNT(*) c FROM direct_messages '
                        'WHERE owner_pubkey IS NULL'
                  : 'SELECT COUNT(*) c FROM direct_messages '
                        'WHERE owner_pubkey = ?',
              variables: owner == null ? const [] : [Variable<String>(owner)],
            )
            .getSingle();
        return row.data['c']! as int;
      }

      Future<int> conversationCountFor(String? owner) async {
        final row = await db
            .customSelect(
              owner == null
                  ? 'SELECT COUNT(*) c FROM conversations '
                        'WHERE owner_pubkey IS NULL'
                  : 'SELECT COUNT(*) c FROM conversations '
                        'WHERE owner_pubkey = ?',
              variables: owner == null ? const [] : [Variable<String>(owner)],
            )
            .getSingle();
        return row.data['c']! as int;
      }

      UserDataCleanupService readService() {
        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        return subscription.read();
      }

      test("a plain switch keeps the other account's DM history", () async {
        await seedDm(
          messageId: _dmTargetMessageId,
          conversationId: _dmConversationId,
          ownerPubkey: _pubkeyA,
        );
        await seedDm(
          messageId: _dmSecondTargetMessageId,
          conversationId: _reactionIdB,
          ownerPubkey: _pubkeyB,
        );

        // The two gift-wrap tables ride the same cleanup path. Their
        // ownerPubkey is non-nullable (pending) / claimed (processed), so a
        // scoped delete must be exhaustive for A and inert for B.
        await db.pendingGiftWrapsDao.recordFailedDecrypt(
          giftWrapId: 'gw-a',
          ownerPubkey: _pubkeyA,
          rawJson: '{}',
          createdAt: 1700000000,
        );
        await db.pendingGiftWrapsDao.recordFailedDecrypt(
          giftWrapId: 'gw-b',
          ownerPubkey: _pubkeyB,
          rawJson: '{}',
          createdAt: 1700000000,
        );
        await db.processedGiftWrapsDao.record(
          giftWrapId: 'pw-a',
          ownerPubkey: _pubkeyA,
        );
        await db.processedGiftWrapsDao.record(
          giftWrapId: 'pw-b',
          ownerPubkey: _pubkeyB,
        );

        await readService().onDatabaseCleanup!(userPubkey: _pubkeyA);

        expect(await dmCountFor(_pubkeyA), 0);
        expect(await conversationCountFor(_pubkeyA), 0);
        expect(await dmCountFor(_pubkeyB), 1);
        expect(await conversationCountFor(_pubkeyB), 1);
        expect(await db.pendingGiftWrapsDao.countForOwner(_pubkeyA), 0);
        expect(await db.pendingGiftWrapsDao.countForOwner(_pubkeyB), 1);
        expect(
          await db.processedGiftWrapsDao.count(),
          1,
          reason: "only B's processed-wrap row should survive",
        );
      });

      test(
        'named deletion preserves other owners and unattributed DM rows',
        () async {
          await seedDm(
            messageId: _dmTargetMessageId,
            conversationId: _dmConversationId,
            ownerPubkey: _pubkeyA,
          );
          await seedDm(
            messageId: _dmSecondTargetMessageId,
            conversationId: _reactionIdB,
            ownerPubkey: _pubkeyB,
          );
          await seedDm(
            messageId: _pendingDeletionId,
            conversationId: _reactionIdA,
            ownerPubkey: '',
          );
          await seedDm(
            messageId: _pendingReactionId,
            conversationId: _legacyNullConversationId,
          );
          expect(await dmCountFor(''), 2);
          expect(await conversationCountFor(''), 2);
          expect(await dmCountFor(null), 0);
          expect(await conversationCountFor(null), 0);

          await readService().deleteAccountData(
            _pubkeyA,
            userNpub: _npubA,
            preserveActiveSession: true,
          );

          expect(await dmCountFor(_pubkeyA), 0);
          expect(await dmCountFor(_pubkeyB), 1);
          expect(await dmCountFor(''), 2);
          expect(await dmCountFor(null), 0);
          expect(await conversationCountFor(_pubkeyA), 0);
          expect(await conversationCountFor(_pubkeyB), 1);
          expect(await conversationCountFor(''), 2);
          expect(await conversationCountFor(null), 0);
        },
      );

      test(
        'a known-owner switch deletes NULL and empty-owner DM rows',
        () async {
          await seedDm(
            messageId: _dmTargetMessageId,
            conversationId: _dmConversationId,
          );
          await seedDm(
            messageId: _dmSecondTargetMessageId,
            conversationId: _reactionIdB,
            ownerPubkey: '',
          );

          await readService().onDatabaseCleanup!(userPubkey: _pubkeyA);
          expect(await dmCountFor(null), 0);
          expect(await dmCountFor(''), 0);
          expect(await conversationCountFor(null), 0);
          expect(await conversationCountFor(''), 0);
        },
      );

      test('an unknown leaving user deletes only ambiguous DM rows', () async {
        await seedDm(
          messageId: _dmTargetMessageId,
          conversationId: _dmConversationId,
          ownerPubkey: _pubkeyA,
        );
        await seedDm(
          messageId: _dmSecondTargetMessageId,
          conversationId: _reactionIdB,
        );
        await seedDm(
          messageId: _pendingDeletionId,
          conversationId: _reactionIdA,
          ownerPubkey: '',
        );

        await readService().onDatabaseCleanup!();

        expect(await dmCountFor(_pubkeyA), 1);
        expect(await conversationCountFor(_pubkeyA), 1);
        expect(await dmCountFor(null), 0);
        expect(await dmCountFor(''), 0);
        expect(await conversationCountFor(null), 0);
        expect(await conversationCountFor(''), 0);
      });

      test("only the leaving account's DM sync cursors are cleared", () async {
        final syncState = DmSyncState(prefs);
        await syncState.recordSeen(_pubkeyA, createdAt: 1700000000);
        await syncState.recordSeen(_pubkeyB, createdAt: 1700000000);
        await syncState.markHistoryDrainComplete(_pubkeyA);
        await syncState.markHistoryDrainComplete(_pubkeyB);

        await readService().clearUserSpecificData(
          reason: 'test_identity_change',
          isIdentityChange: true,
          userPubkey: _pubkeyA,
        );

        expect(syncState.newestSyncedAt(_pubkeyA), isNull);
        expect(syncState.historyDrainComplete(_pubkeyA), isFalse);
        expect(
          syncState.newestSyncedAt(_pubkeyB),
          isNotNull,
          reason: 'the other account must keep its cursor',
        );
        expect(syncState.historyDrainComplete(_pubkeyB), isTrue);
      });
    });
  });
}
