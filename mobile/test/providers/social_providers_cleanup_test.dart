// ABOUTME: Regression tests for account cleanup provider wiring.
// ABOUTME: Ensures destructive cleanup reaches the live Hive upload store.

import 'dart:async';
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
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/relay/query_result.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/models/content_label.dart';
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
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upload_repository/upload_repository.dart' as hive_model;

import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockNostrClient extends Mock implements NostrClient {}

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
const _pubkeyQ =
    '6666666666666666666666666666666666666666666666666666666666666666';

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
      'an account switch resets the live Divine-host filter in place',
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
        var notifications = 0;
        departingService.addListener(() => notifications++);

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
        expect(incomingService, same(departingService));
        expect(incomingService.showDivineHostedOnly, isTrue);
        expect(notifications, equals(1));
      },
    );

    test(
      'an account switch resets the live provenance filter in place',
      () async {
        await prefs.setBool(
          VideoProvenanceFilterService.showVerifiedOnlyStorageKey,
          true,
        );
        final provenanceFilter = container.read(
          videoProvenanceFilterServiceProvider,
        );
        expect(provenanceFilter.showVerifiedOnly, isTrue);
        var notifications = 0;
        provenanceFilter.addListener(() => notifications++);

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
          container.read(videoProvenanceFilterServiceProvider),
          same(provenanceFilter),
        );
        expect(provenanceFilter.showVerifiedOnly, isFalse);
        expect(notifications, equals(1));
      },
    );

    test('an account switch resets the live content filter in place', () async {
      final contentFilter = container.read(contentFilterServiceProvider);
      await contentFilter.initialized;
      await contentFilter.setPreference(
        ContentLabel.spoiler,
        ContentFilterPreference.hide,
      );
      expect(
        contentFilter.getPreference(ContentLabel.spoiler),
        ContentFilterPreference.hide,
      );
      var notifications = 0;
      contentFilter.addListener(() => notifications++);

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await subscription.read().clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: _pubkeyA,
      );

      expect(container.read(contentFilterServiceProvider), same(contentFilter));
      expect(
        contentFilter.getPreference(ContentLabel.spoiler),
        ContentFilterPreference.warn,
      );
      expect(notifications, equals(1));
    });

    test('account switch resets the live content language', () async {
      final language = container.read(languagePreferenceServiceProvider);
      await language.initialize();
      await language.setContentLanguage('es');
      expect(language.declaredContentLanguage, 'es');
      var notifications = 0;
      language.addListener(() => notifications++);

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await subscription.read().clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: _pubkeyA,
      );

      expect(container.read(languagePreferenceServiceProvider), same(language));
      expect(language.declaredContentLanguage, isNull);
      expect(notifications, equals(1));
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
      expect(incoming, same(sounds));
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

    test(
      "deleting an account drops only that account's Concord room data",
      () async {
        // Concord rows hold the account's signed seals and its unsent outbox,
        // so they must not outlive the account. A plain switch keeps them,
        // like the DM tables.
        for (final pubkey in [_pubkeyA, _pubkeyB]) {
          await db.concordStoreDao.put(
            account: pubkey,
            scope: 'wss://relay.example/general',
            key: 'sealed',
            value: '{}',
          );
        }
        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();

        await service.onDatabaseCleanup!(userPubkey: _pubkeyA);
        expect(
          await db.concordStoreDao.get(
            account: _pubkeyA,
            scope: 'wss://relay.example/general',
            key: 'sealed',
          ),
          isNotNull,
          reason: 'a plain switch keeps the room data',
        );

        await service.onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );
        expect(
          await db.concordStoreDao.get(
            account: _pubkeyA,
            scope: 'wss://relay.example/general',
            key: 'sealed',
          ),
          isNull,
        );
        expect(
          await db.concordStoreDao.get(
            account: _pubkeyB,
            scope: 'wss://relay.example/general',
            key: 'sealed',
          ),
          isNotNull,
          reason: "the surviving account's room data must be untouched",
        );
      },
    );

    test(
      'deleting an account clears only its sound request workflow',
      () async {
        for (final owner in [_pubkeyA, _pubkeyB]) {
          await db.soundRequestStateDao.writeAccount(owner, {
            'jobs': {'pending': '{}'},
          });
        }
        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();
        await service.onDatabaseCleanup!(userPubkey: _pubkeyA);
        expect(
          await db.soundRequestStateDao.readAccount(_pubkeyA),
          hasLength(1),
        );
        await service.onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );
        expect(await db.soundRequestStateDao.readAccount(_pubkeyA), isEmpty);
        expect(
          await db.soundRequestStateDao.readAccount(_pubkeyB),
          hasLength(1),
        );
      },
    );

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

    PendingReport reportFor(String id, String pubkey) => PendingReport(
      reportId: id,
      userPubkey: pubkey,
      eventJson: '{}',
      zendeskPayload: '{}',
      createdAt: DateTime.utc(2026),
    );

    test(
      'destructive cleanup purges the departing user pending reports (#8053)',
      () async {
        await db.pendingReportsDao.enqueue(reportFor('ra', _pubkeyA));
        await db.pendingReportsDao.enqueue(reportFor('rb', _pubkeyB));

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

        expect(await db.pendingReportsDao.getById('ra'), isNull);
        expect(
          await db.pendingReportsDao.getById('rb'),
          isNotNull,
          reason: 'only the departing account queue is purged',
        );
      },
    );

    ScheduledPost scheduledPostFor(String eventId, String pubkey) =>
        ScheduledPost(
          eventId: eventId,
          ownerPubkey: pubkey,
          draftId: 'draft-$eventId',
          kind: 34236,
          signedEventJson: '{}',
          publishAt: 1790000000,
          createdAt: DateTime.utc(2026),
        );

    test(
      "destructive cleanup purges the departing user's scheduled posts",
      () async {
        await db.scheduledPostsDao.enqueue(scheduledPostFor('sa', _pubkeyA));
        await db.scheduledPostsDao.enqueue(scheduledPostFor('sb', _pubkeyB));

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
          await db.scheduledPostsDao.getById('sa'),
          isNull,
          reason: "the removed account's signed events must not linger",
        );
        expect(
          await db.scheduledPostsDao.getById('sb'),
          isNotNull,
          reason: "another account's scheduled posts are untouched",
        );
      },
    );

    test('non-destructive cleanup preserves scheduled posts', () async {
      await db.scheduledPostsDao.enqueue(scheduledPostFor('sa', _pubkeyA));

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      expect(service.onDatabaseCleanup, isNotNull);
      await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

      expect(
        await db.scheduledPostsDao.getById('sa'),
        isNotNull,
        reason: 'the relay still holds the post; signing back in shows it',
      );
    });

    Future<void> saveCaptionStyleFor(String id, String? pubkey) =>
        db.savedCaptionStylesDao.upsertStyle(
          id: id,
          name: 'Intro',
          style: '{}',
          createdAt: DateTime.utc(2026),
          ownerPubkey: pubkey,
        );

    test(
      "destructive cleanup drops only the departing user's saved caption "
      'styles (#7742)',
      () async {
        await saveCaptionStyleFor('style_a', _pubkeyA);
        await saveCaptionStyleFor('style_b', _pubkeyB);

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

        final remaining = await db.savedCaptionStylesDao.getStyles();
        expect(remaining.map((row) => row.id), ['style_b']);
      },
    );

    test('a plain account switch keeps saved caption styles (#7742)', () async {
      await saveCaptionStyleFor('style_a', _pubkeyA);

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

      final remaining = await db.savedCaptionStylesDao.getStyles();
      expect(remaining.map((row) => row.id), ['style_a']);
    });

    test('sign-in claims ownerless saved caption styles (#7742)', () async {
      await saveCaptionStyleFor('style_legacy', null);
      await saveCaptionStyleFor('style_b', _pubkeyB);

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      expect(service.onClaimLegacyRows, isNotNull);
      await service.onClaimLegacyRows!(_pubkeyA);

      final claimed = await db.savedCaptionStylesDao.getStyles(
        ownerPubkey: _pubkeyA,
      );
      expect(claimed.map((row) => row.id), ['style_legacy']);
      expect(claimed.single.ownerPubkey, _pubkeyA);
    });

    Future<void> saveTitleStyleFor(String id, String? pubkey) =>
        db.savedTitleStylesDao.upsertStyle(
          id: id,
          name: 'Intro',
          style: '{}',
          createdAt: DateTime.utc(2026),
          ownerPubkey: pubkey,
        );

    test(
      "destructive cleanup drops only the departing user's saved title "
      'styles (#7742)',
      () async {
        await saveTitleStyleFor('title_a', _pubkeyA);
        await saveTitleStyleFor('title_b', _pubkeyB);

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

        final remaining = await db.savedTitleStylesDao.getStyles();
        expect(remaining.map((row) => row.id), ['title_b']);
      },
    );

    test('a plain account switch keeps saved title styles (#7742)', () async {
      await saveTitleStyleFor('title_a', _pubkeyA);

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

      final remaining = await db.savedTitleStylesDao.getStyles();
      expect(remaining.map((row) => row.id), ['title_a']);
    });

    test('sign-in claims ownerless saved title styles (#7742)', () async {
      await saveTitleStyleFor('title_legacy', null);
      await saveTitleStyleFor('title_b', _pubkeyB);

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      expect(service.onClaimLegacyRows, isNotNull);
      await service.onClaimLegacyRows!(_pubkeyA);

      final claimed = await db.savedTitleStylesDao.getStyles(
        ownerPubkey: _pubkeyA,
      );
      expect(claimed.map((row) => row.id), ['title_legacy']);
      expect(claimed.single.ownerPubkey, _pubkeyA);
    });

    test('non-destructive cleanup preserves pending reports (#8053)', () async {
      await db.pendingReportsDao.enqueue(reportFor('ra', _pubkeyA));

      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      expect(service.onDatabaseCleanup, isNotNull);
      await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

      expect(
        await db.pendingReportsDao.getById('ra'),
        isNotNull,
        reason: 'a plain switch must not drop an undelivered report',
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

    group('dismissal account lifetime', () {
      final conversationId = '9' * 64;

      Future<void> rebuild(String owner) =>
          db.conversationsDao.upsertConversation(
            id: conversationId,
            participantPubkeys: jsonEncode([_pubkeyA, _pubkeyB]),
            isGroup: false,
            createdAt: 100,
            lastMessageTimestamp: 100,
            ownerPubkey: owner,
            isRead: false,
          );

      Future<bool> dismissed(String owner) async =>
          (await db.conversationsDao.getConversation(
            conversationId,
            ownerPubkey: owner,
          ))!.isDismissed;

      test(
        'sign-out and switch cleanup retain dismissal through history recovery',
        () async {
          await rebuild(_pubkeyA);
          await db.conversationsDao.setDismissed(
            conversationId,
            ownerPubkey: _pubkeyA,
            dismissed: true,
          );
          final subscription = container.listen(
            userDataCleanupServiceProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          final cleanup = subscription.read().onDatabaseCleanup!;

          // This is the callback invoked by ordinary sign-out: cached message
          // and conversation rows go away, account-lifetime state stays.
          await cleanup(userPubkey: _pubkeyA);
          expect(
            await db.conversationsDao.getConversation(
              conversationId,
              ownerPubkey: _pubkeyA,
            ),
            isNull,
          );
          await rebuild(_pubkeyA);
          expect(await dismissed(_pubkeyA), isTrue);

          // Switch away, use a different account with the same conversation id,
          // then return and replay the first account's history.
          await cleanup(userPubkey: _pubkeyA);
          await rebuild(_pubkeyB);
          expect(await dismissed(_pubkeyB), isFalse);
          await cleanup(userPubkey: _pubkeyB);
          await rebuild(_pubkeyA);
          expect(await dismissed(_pubkeyA), isTrue);
        },
      );

      test(
        'explicit local-account deletion clears only that owner’s dismissal',
        () async {
          for (final owner in [_pubkeyA, _pubkeyB]) {
            await rebuild(owner);
            await db.conversationsDao.setDismissed(
              conversationId,
              ownerPubkey: owner,
              dismissed: true,
            );
          }
          final subscription = container.listen(
            userDataCleanupServiceProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          await subscription.read().onDatabaseCleanup!(
            userPubkey: _pubkeyA,
            deleteUserData: true,
          );
          await rebuild(_pubkeyA);
          expect(await dismissed(_pubkeyA), isFalse);
          expect(await dismissed(_pubkeyB), isTrue);
        },
      );
    });

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

    // The ids of messages removed with a conversation settle later retractions
    // of them (#8179). Like the tombstone they outlive a plain sign-out, so a
    // retraction that drains after the user signs back in is still settled.
    group('removed message ids', () {
      const messageIdA =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
      const messageIdB =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

      Future<void> seedRemovedMessage({
        required String messageId,
        required String ownerPubkey,
      }) async {
        final inserted = await db.directMessagesDao.insertMessage(
          id: messageId,
          conversationId: _dmConversationId,
          senderPubkey: _pubkeyB,
          content: 'removed with its conversation',
          createdAt: 1700000000,
          giftWrapId: 'wrap-$messageId',
          ownerPubkey: ownerPubkey,
        );
        expect(inserted, isTrue, reason: 'the fixture row must really exist');
        await db.removedMessageIdsDao.captureForConversations(
          conversationIds: [_dmConversationId],
          ownerPubkey: ownerPubkey,
          removedAt: 1700000001,
        );
      }

      test('non-destructive cleanup preserves them', () async {
        await seedRemovedMessage(messageId: messageIdA, ownerPubkey: _pubkeyA);

        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();

        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

        expect(
          await db.removedMessageIdsDao.contains(
            rumorId: messageIdA,
            ownerPubkey: _pubkeyA,
          ),
          isTrue,
        );
      });

      test('destructive cleanup purges that owner only', () async {
        await seedRemovedMessage(messageId: messageIdA, ownerPubkey: _pubkeyA);
        await seedRemovedMessage(messageId: messageIdB, ownerPubkey: _pubkeyB);

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
          await db.removedMessageIdsDao.contains(
            rumorId: messageIdA,
            ownerPubkey: _pubkeyA,
          ),
          isFalse,
        );
        expect(
          await db.removedMessageIdsDao.contains(
            rumorId: messageIdB,
            ownerPubkey: _pubkeyB,
          ),
          isTrue,
          reason: "the other account's ids must survive",
        );
      });
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
        // The conversation row stays: it carries A's read state, which a
        // re-download cannot restore on its own (#10276).
        expect(await conversationCountFor(_pubkeyA), 1);
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

    group('#10276 conversations kept across an account boundary', () {
      Future<void> seedConversation({
        required String id,
        required String? ownerPubkey,
        required int lastMessageAt,
        required bool isRead,
      }) => db.conversationsDao.upsertConversation(
        id: id,
        participantPubkeys: '["$_pubkeyA","$_pubkeyB"]',
        isGroup: false,
        createdAt: 1700000000,
        lastMessageContent: 'hello',
        lastMessageTimestamp: lastMessageAt,
        lastMessageSenderPubkey: _pubkeyB,
        isRead: isRead,
        ownerPubkey: ownerPubkey,
      );

      Future<ConversationRow> conversationOf(String id, String owner) async =>
          (await db.conversationsDao.getAllConversations(
            ownerPubkey: owner,
          )).singleWhere((row) => row.id == id && row.ownerPubkey == owner);

      Future<int> conversationCountFor(String owner) async =>
          (await db.conversationsDao.getAllConversations(
            ownerPubkey: owner,
          )).where((row) => row.ownerPubkey == owner).length;

      UserDataCleanupService readService() {
        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        return subscription.read();
      }

      /// Three read states for the leaving account A, one row for B, and one
      /// unattributed legacy row.
      Future<void> seedBoundary() async {
        await seedConversation(
          id: 'conv_marked_read',
          ownerPubkey: _pubkeyA,
          lastMessageAt: 1700000300,
          isRead: false,
        );
        await db.conversationsDao.markAsRead(
          'conv_marked_read',
          ownerPubkey: _pubkeyA,
        );
        // Read only because A sent the last message: no cursor yet.
        await seedConversation(
          id: 'conv_replied_last',
          ownerPubkey: _pubkeyA,
          lastMessageAt: 1700000400,
          isRead: true,
        );
        await seedConversation(
          id: 'conv_unread',
          ownerPubkey: _pubkeyA,
          lastMessageAt: 1700000500,
          isRead: false,
        );
        await db.conversationsDao.applyReadCursor(
          'conv_unread',
          1700000100,
          ownerPubkey: _pubkeyA,
        );
        await db.directMessagesDao.insertMessage(
          id: _dmTargetMessageId,
          conversationId: 'conv_marked_read',
          senderPubkey: _pubkeyB,
          content: 'hello',
          createdAt: 1700000300,
          giftWrapId: 'gw-$_dmTargetMessageId',
          ownerPubkey: _pubkeyA,
        );
        await seedConversation(
          id: 'conv_b',
          ownerPubkey: _pubkeyB,
          lastMessageAt: 1700000300,
          isRead: true,
        );
        await seedConversation(
          id: _legacyNullConversationId,
          ownerPubkey: '',
          lastMessageAt: 1700000300,
          isRead: true,
        );
      }

      test(
        "a plain switch keeps the leaving account's conversations and "
        'records their read state in the cursor',
        () async {
          await seedBoundary();

          await readService().onDatabaseCleanup!(userPubkey: _pubkeyA);

          expect(await conversationCountFor(_pubkeyA), 3);
          final repliedLast = await conversationOf(
            'conv_replied_last',
            _pubkeyA,
          );
          expect(repliedLast.isRead, isTrue);
          expect(repliedLast.lastReadTimestamp, 1700000400);
          final markedRead = await conversationOf(
            'conv_marked_read',
            _pubkeyA,
          );
          expect(markedRead.lastReadTimestamp, 1700000300);
          final unread = await conversationOf('conv_unread', _pubkeyA);
          expect(unread.isRead, isFalse);
          expect(unread.lastReadTimestamp, 1700000100);
          expect(
            await db.directMessagesDao.getMessagesForConversation(
              'conv_marked_read',
              ownerPubkey: _pubkeyA,
            ),
            isEmpty,
            reason: 'messages still re-download; only conversations stay',
          );
          expect(await conversationCountFor(_pubkeyB), 1);
          expect(await conversationCountFor(''), 0);
        },
      );

      test(
        'removing the account from the device deletes its conversations',
        () async {
          await seedBoundary();

          await readService().onDatabaseCleanup!(
            userPubkey: _pubkeyA,
            forgetAccount: true,
          );

          expect(await conversationCountFor(_pubkeyA), 0);
          expect(await conversationCountFor(_pubkeyB), 1);
        },
      );

      test('deleting the account deletes its conversations', () async {
        await seedBoundary();

        await readService().onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );

        expect(await conversationCountFor(_pubkeyA), 0);
        expect(await conversationCountFor(_pubkeyB), 1);
      });

      test(
        'a sign-out that removes the keys passes that on to the database '
        'cleanup',
        () async {
          await seedBoundary();

          await readService().clearUserSpecificData(
            reason: 'explicit_logout',
            userPubkey: _pubkeyA,
            forgetAccount: true,
          );

          expect(await conversationCountFor(_pubkeyA), 0);
        },
      );

      group('returning to the account', () {
        late Map<String, Event> rumorByWrapId;

        setUpAll(() {
          registerFallbackValue(Duration.zero);
        });

        setUp(() {
          rumorByWrapId = <String, Event>{};
        });

        /// A real [DmRepository] session for A over the suite's database. The
        /// returned controller stands in for the relay.
        Future<(DmRepository, StreamController<Event>)>
        startSessionForA() async {
          final nostrClient = _MockNostrClient();
          final relay = StreamController<Event>();
          addTearDown(relay.close);
          when(() => nostrClient.connectedRelayCount).thenReturn(1);
          when(() => nostrClient.configuredRelayCount).thenReturn(1);
          when(
            () => nostrClient.readEvents(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              useCache: any(named: 'useCache'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => const QueryResult(
              events: [],
              endedBy: QueryEnd.complete,
              answeredNetworkRelayCount: 1,
            ),
          );
          when(
            () => nostrClient.queryEvents(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => const <Event>[]);
          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              useCache: any(named: 'useCache'),
              tempRelays: any(named: 'tempRelays'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              acceptRelayClosedWhenOthersAnswered: any(
                named: 'acceptRelayClosedWhenOthersAnswered',
              ),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async =>
                (events: const <Event>[], timedOut: false, noRelays: false),
          );
          when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
          when(
            () => nostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              onStoredEventsStart: any(named: 'onStoredEventsStart'),
              onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
            ),
          ).thenAnswer((_) => relay.stream);

          final repository = DmRepository(
            nostrClient: nostrClient,
            directMessagesDao: db.directMessagesDao,
            conversationsDao: db.conversationsDao,
            processedGiftWrapsDao: db.processedGiftWrapsDao,
            userPubkey: _pubkeyA,
            syncState: DmSyncState(prefs),
            signer: LocalNostrSigner('7' * 64),
            rumorDecryptor: (_, giftWrap) async => rumorByWrapId[giftWrap.id],
            nip04Decryptor: (_, ciphertext) async => ciphertext,
          );
          await repository.startListening();
          addTearDown(repository.stopListening);
          return (repository, relay);
        }

        /// Delivers a kind-14 rumor from [sender] to [recipient] in a gift
        /// wrap addressed to A, and waits until its message row exists.
        Future<void> deliver(
          StreamController<Event> relay, {
          required String wrapId,
          required String rumorId,
          required String sender,
          required String recipient,
          required int at,
        }) async {
          rumorByWrapId[wrapId] = Event.fromJson({
            'id': rumorId,
            'pubkey': sender,
            'created_at': at,
            'kind': EventKind.privateDirectMessage,
            'tags': [
              ['p', recipient],
            ],
            'content': 'hello at $at',
            'sig': '',
          });
          relay.add(
            Event.fromJson({
              'id': wrapId,
              'pubkey': sender,
              'created_at': at,
              'kind': EventKind.giftWrap,
              'tags': [
                ['p', _pubkeyA],
              ],
              'content': 'wrapped-$wrapId',
              'sig': '',
            }),
          );
          for (var i = 0; i < 50; i++) {
            if (await db.directMessagesDao.hasGiftWrap(wrapId)) return;
            await pumpEventQueue();
          }
          fail('wrap $wrapId was never stored');
        }

        test(
          're-downloaded chats keep the read state they had when A left, '
          'without the history drain',
          () async {
            final withB = DmRepository.computeConversationId([
              _pubkeyA,
              _pubkeyB,
            ]);
            final withQ = DmRepository.computeConversationId([
              _pubkeyA,
              _pubkeyQ,
            ]);

            final (firstSession, firstRelay) = await startSessionForA();
            await deliver(
              firstRelay,
              wrapId: 'b' * 64,
              rumorId: 'ab' * 32,
              sender: _pubkeyB,
              recipient: _pubkeyA,
              at: 1700000300,
            );
            await firstSession.markConversationAsRead(withB);
            // Q's chat is read only because A answered last.
            await deliver(
              firstRelay,
              wrapId: 'c' * 64,
              rumorId: 'ac' * 32,
              sender: _pubkeyQ,
              recipient: _pubkeyA,
              at: 1700000350,
            );
            await deliver(
              firstRelay,
              wrapId: 'd' * 64,
              rumorId: 'ad' * 32,
              sender: _pubkeyA,
              recipient: _pubkeyQ,
              at: 1700000400,
            );
            expect(
              (await conversationOf(withQ, _pubkeyA)).isRead,
              isTrue,
              reason: 'A replied last, so the chat starts out read',
            );
            await firstSession.stopListening();

            await readService().onDatabaseCleanup!(userPubkey: _pubkeyA);

            final (secondSession, secondRelay) = await startSessionForA();
            // Startup maintenance rebuilds previews from messages, and A's
            // messages are gone: the kept rows lose their last-message stamp.
            await secondSession.getConversations();
            expect(
              (await conversationOf(withB, _pubkeyA)).lastMessageTimestamp,
              isNull,
            );
            // The re-download holds no read marker and misses A's reply.
            await deliver(
              secondRelay,
              wrapId: 'b' * 64,
              rumorId: 'ab' * 32,
              sender: _pubkeyB,
              recipient: _pubkeyA,
              at: 1700000300,
            );
            await deliver(
              secondRelay,
              wrapId: 'c' * 64,
              rumorId: 'ac' * 32,
              sender: _pubkeyQ,
              recipient: _pubkeyA,
              at: 1700000350,
            );

            expect((await conversationOf(withB, _pubkeyA)).isRead, isTrue);
            expect((await conversationOf(withQ, _pubkeyA)).isRead, isTrue);
            expect(await secondSession.watchUnreadCount().first, 0);

            // A message B sent while A was away is still new.
            await deliver(
              secondRelay,
              wrapId: 'e' * 64,
              rumorId: 'ae' * 32,
              sender: _pubkeyB,
              recipient: _pubkeyA,
              at: 1700000600,
            );
            expect((await conversationOf(withB, _pubkeyA)).isRead, isFalse);
          },
        );
      });
    });
  });
}
