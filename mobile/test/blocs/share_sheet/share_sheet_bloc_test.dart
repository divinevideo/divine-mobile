// ABOUTME: Tests for ShareSheetBloc
// ABOUTME: Verifies contact loading, recipient selection, send-with-message,
// ABOUTME: save, copy, and share-via action flows

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:file/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockBookmarksRepository extends Mock implements BookmarksRepository {}

class _MockVideoClipImportService extends Mock
    implements VideoClipImportService {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockFile extends Mock implements File {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

DivineVideoClip _clip({String? libraryTitle}) {
  return DivineVideoClip(
    id: 'clip-1',
    video: EditorVideo.file('/tmp/clip.mp4'),
    libraryTitle: libraryTitle,
    duration: const Duration(seconds: 6),
    recordedAt: DateTime.utc(2026),
    targetAspectRatio: .square,
    originalAspectRatio: 1,
  );
}

/// A [VideoEvent] whose [toJson] always throws, used to test error paths.
class _ThrowingJsonVideoEvent extends Fake implements VideoEvent {
  @override
  String get id =>
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  @override
  String get pubkey =>
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  @override
  Map<String, dynamic> toJson() => throw const FormatException('bad json');
}

/// A [VideoEvent] with an invalid hex [id], causing nevent encoding to throw.
class _InvalidIdVideoEvent extends Fake implements VideoEvent {
  @override
  String get id => 'not-valid-hex';

  @override
  String get pubkey =>
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  group(ShareSheetBloc, () {
    late _MockVideoSharingService mockSharingService;
    late _MockProfileRepository mockProfileRepository;
    late _MockFollowRepository mockFollowRepository;
    late _MockBookmarksRepository mockBookmarksRepository;
    late VideoEvent testVideo;

    const testRecipient = ShareableUser(
      pubkey:
          'aaaa456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      displayName: 'Alice',
      picture: 'https://example.com/alice.png',
    );

    const currentUserPubkey =
        'facade00facade00facade00facade00facade00facade00facade00facade00';

    const viewerAsRecipient = ShareableUser(
      pubkey: currentUserPubkey,
      displayName: 'Me',
      picture: 'https://example.com/me.png',
    );

    setUp(() {
      mockSharingService = _MockVideoSharingService();
      mockProfileRepository = _MockProfileRepository();
      mockFollowRepository = _MockFollowRepository();
      mockBookmarksRepository = _MockBookmarksRepository();

      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );

      // Default stubs
      when(
        () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
      ).thenReturn(false);
      when(
        () => mockBookmarksRepository.hasUnreadablePrivateItems,
      ).thenReturn(false);
      when(() => mockSharingService.recentlySharedWith).thenReturn([]);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <String, UserProfile>{});
      when(
        () => mockProfileRepository.getCachedProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <UserProfile>[]);
    });

    ShareSheetBloc createBloc({
      FollowRepository? followRepository,
      Future<BookmarksRepository?>? bookmarksRepositoryFuture,
      String relayUrl = 'wss://relay.test.example',
      BaseCacheManager? cacheManager,
      VideoClipImportService? videoClipImportService,
    }) => ShareSheetBloc(
      video: testVideo,
      relayUrl: relayUrl,
      videoSharingService: mockSharingService,
      profileRepository: mockProfileRepository,
      followRepository: followRepository ?? mockFollowRepository,
      currentUserPubkey: currentUserPubkey,
      bookmarksRepositoryFuture:
          bookmarksRepositoryFuture ?? Future.value(mockBookmarksRepository),
      cacheManager: cacheManager,
      videoClipImportService: videoClipImportService,
    );

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, equals(ShareSheetStatus.initial));
      expect(bloc.state.contacts, isEmpty);
      expect(bloc.state.selectedRecipients, isEmpty);
      expect(bloc.state.isSending, isFalse);
      expect(bloc.state.actionResult, isNull);
      expect(
        bloc.state.bookmarkStatus,
        equals(ShareSheetBookmarkStatus.unknown),
      );
      bloc.close();
    });

    // -----------------------------------------------------------------------
    // Contact loading
    // -----------------------------------------------------------------------

    group('excludes the current user (#8351)', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'omits the viewer from contacts when their contact list self-follows',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([
            currentUserPubkey,
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: currentUserPubkey,
                createdAt: DateTime.now(),
                eventId: 'event-self',
                rawData: const {},
                name: 'Me',
              ),
              UserProfile(
                pubkey:
                    'bbbb456789abcdef0123456789abcdef0123456789abcdef'
                    '0123456789abcdef',
                createdAt: DateTime.now(),
                eventId: 'event-bob',
                rawData: const {},
                name: 'Bob',
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        verify: (bloc) {
          expect(
            bloc.state.contacts.map((c) => c.pubkey),
            isNot(contains(currentUserPubkey)),
          );
          expect(bloc.state.contacts, isNotEmpty);
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'omits the viewer from the recently-shared-with row',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenReturn([viewerAsRecipient, testRecipient]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        verify: (bloc) {
          expect(
            bloc.state.contacts.map((c) => c.pubkey),
            [testRecipient.pubkey],
          );
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'ignores a Find People selection that resolves to the viewer',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(viewerAsRecipient)),
        expect: () => <ShareSheetState>[],
      );
    });

    group('ShareSheetContactsLoadRequested', () {
      const profiledFollow =
          'cccc456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const unprofiledFollow =
          'dddd456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits [loading, ready] with empty contacts when no follows or recents',
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          const ShareSheetState(status: ShareSheetStatus.ready),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits contacts from recent users and follow list',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenReturn([testRecipient]);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts.first.pubkey,
                'first contact pubkey',
                testRecipient.pubkey,
              ),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having(
                (s) => s.contacts.first.pubkey,
                'first contact pubkey',
                testRecipient.pubkey,
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits ready with empty contacts on error',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenThrow(Exception('network failure'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          const ShareSheetState(status: ShareSheetStatus.ready),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'loads without follow repository when null',
        setUp: () {
          when(
            () => mockSharingService.recentlySharedWith,
          ).thenReturn([testRecipient]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'renders cached profiles immediately, then re-emits after hydration',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow, unprofiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: profiledFollow,
                createdAt: DateTime.now(),
                eventId: 'event-$profiledFollow',
                rawData: const {},
                name: 'CachedAlice',
              ),
            ],
          );
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => {
              unprofiledFollow: UserProfile(
                pubkey: unprofiledFollow,
                createdAt: DateTime.now(),
                eventId: 'event-$unprofiledFollow',
                rawData: const {},
                name: 'HydratedBob',
              ),
            },
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          // Cache-first render: the Drift-cached name shows now; the uncached
          // follow is present as a pending, non-interactive skeleton row rather
          // than blocking the whole row.
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts[0].displayName,
                'first contact name',
                'CachedAlice',
              )
              .having(
                (s) => s.contacts[1].displayName,
                'second contact name',
                isNull,
              ),
          // Hydration re-emit: misses filled in from the network batch.
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having(
                (s) => s.contacts[0].displayName,
                'first contact name',
                'CachedAlice',
              )
              .having(
                (s) => s.contacts[1].displayName,
                'second contact name',
                'HydratedBob',
              ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: [profiledFollow, unprofiledFollow],
            ),
          ).called(1);
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: [unprofiledFollow],
            ),
          ).called(1);
        },
      );

      late Completer<List<UserProfile>> cacheRead;
      late Completer<Map<String, UserProfile>> hydration;

      blocTest<ShareSheetBloc, ShareSheetState>(
        'preserves a find-people recipient picked during the cache read',
        setUp: () {
          cacheRead = Completer<List<UserProfile>>();
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => cacheRead.future);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <String, UserProfile>{});
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetContactsLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const ShareSheetRecipientToggled(
              ShareableUser(
                pubkey: 'zzzz56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                displayName: 'Picked Stranger',
              ),
            ),
          );
          await pumpEventQueue();
          cacheRead.complete([
            UserProfile(
              pubkey: profiledFollow,
              createdAt: DateTime.now(),
              eventId: 'event-$profiledFollow',
              rawData: const {},
              name: 'CachedAlice',
            ),
          ]);
          await pumpEventQueue();
        },
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.loading)
              .having(
                (s) => s.contacts.first.displayName,
                'picked first while loading',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having(
                (s) => s.contacts.map((c) => c.displayName).toList(),
                'row contents',
                ['Picked Stranger', 'CachedAlice'],
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'preserves a find-people-added recipient through the hydration re-emit',
        setUp: () {
          hydration = Completer<Map<String, UserProfile>>();
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => hydration.future);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetContactsLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const ShareSheetRecipientToggled(
              ShareableUser(
                pubkey: 'zzzz56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                displayName: 'Picked Stranger',
              ),
            ),
          );
          await pumpEventQueue();
          hydration.complete({
            profiledFollow: UserProfile(
              pubkey: profiledFollow,
              createdAt: DateTime.now(),
              eventId: 'event-$profiledFollow',
              rawData: const {},
              name: 'HydratedAlice',
            ),
          });
        },
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>().having(
            (s) => s.status,
            'status',
            ShareSheetStatus.ready,
          ),
          // The toggle prepends the picked stranger.
          isA<ShareSheetState>()
              .having(
                (s) => s.contacts.first.displayName,
                'picked first',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1),
          // Hydration re-emit must not drop them from the row or the selection.
          isA<ShareSheetState>()
              .having(
                (s) => s.contacts.first.displayName,
                'picked still first',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1)
              .having(
                (s) => s.contacts.map((c) => c.displayName).toList(),
                'row contents',
                ['Picked Stranger', 'HydratedAlice'],
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'keeps a deselected find-people recipient visible through hydration',
        setUp: () {
          hydration = Completer<Map<String, UserProfile>>();
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => hydration.future);
        },
        build: createBloc,
        act: (bloc) async {
          const picked = ShareableUser(
            pubkey: 'zzzz56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            displayName: 'Picked Stranger',
          );
          bloc.add(const ShareSheetContactsLoadRequested());
          await pumpEventQueue();
          bloc.add(const ShareSheetRecipientToggled(picked));
          await pumpEventQueue();
          bloc.add(const ShareSheetRecipientToggled(picked));
          await pumpEventQueue();
          hydration.complete({
            profiledFollow: UserProfile(
              pubkey: profiledFollow,
              createdAt: DateTime.now(),
              eventId: 'event-$profiledFollow',
              rawData: const {},
              name: 'HydratedAlice',
            ),
          });
        },
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>().having(
            (s) => s.status,
            'status',
            ShareSheetStatus.ready,
          ),
          isA<ShareSheetState>()
              .having(
                (s) => s.contacts.first.displayName,
                'picked first',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients.length, 'selected', 1),
          isA<ShareSheetState>()
              .having(
                (s) => s.contacts.first.displayName,
                'picked remains visible',
                'Picked Stranger',
              )
              .having((s) => s.selectedRecipients, 'selected', isEmpty),
          isA<ShareSheetState>()
              .having((s) => s.selectedRecipients, 'selected', isEmpty)
              .having(
                (s) => s.contacts.map((c) => c.displayName).toList(),
                'row contents',
                ['Picked Stranger', 'HydratedAlice'],
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'preserves find-people row order through hydration',
        setUp: () {
          hydration = Completer<Map<String, UserProfile>>();
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => hydration.future);
        },
        build: createBloc,
        act: (bloc) async {
          const firstPicked = ShareableUser(
            pubkey: 'yyyy56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            displayName: 'Picked First',
          );
          const secondPicked = ShareableUser(
            pubkey: 'zzzz56789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            displayName: 'Picked Second',
          );
          bloc.add(const ShareSheetContactsLoadRequested());
          await pumpEventQueue();
          bloc.add(const ShareSheetRecipientToggled(firstPicked));
          await pumpEventQueue();
          bloc.add(const ShareSheetRecipientToggled(secondPicked));
          await pumpEventQueue();
          hydration.complete({
            profiledFollow: UserProfile(
              pubkey: profiledFollow,
              createdAt: DateTime.now(),
              eventId: 'event-$profiledFollow',
              rawData: const {},
              name: 'HydratedAlice',
            ),
          });
        },
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>().having(
            (s) => s.status,
            'status',
            ShareSheetStatus.ready,
          ),
          isA<ShareSheetState>().having(
            (s) => s.contacts.map((c) => c.displayName).toList(),
            'row contents',
            ['Picked First', null],
          ),
          isA<ShareSheetState>().having(
            (s) => s.contacts.map((c) => c.displayName).toList(),
            'row contents',
            ['Picked Second', 'Picked First', null],
          ),
          isA<ShareSheetState>().having(
            (s) => s.contacts.map((c) => c.displayName).toList(),
            'row contents',
            ['Picked Second', 'Picked First', 'HydratedAlice'],
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'keeps the cache-first render when background hydration fails',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow, unprofiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: profiledFollow,
                createdAt: DateTime.now(),
                eventId: 'event-$profiledFollow',
                rawData: const {},
                name: 'CachedAlice',
              ),
            ],
          );
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenThrow(Exception('relay storm down'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          // The failure must not erase what was already on screen.
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts[0].displayName,
                'first contact name',
                'CachedAlice',
              )
              .having(
                (s) => s.contacts[1].displayName,
                'second contact name',
                isNull,
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'drops unresolved cache misses after hydration returns no profile',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([unprofiledFollow]);
          when(
            () => mockProfileRepository.getCachedProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <UserProfile>[]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => <String, UserProfile>{});
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having(
                (s) => s.contacts[0].displayName,
                'contact name',
                isNull,
              ),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts, 'contacts', isEmpty),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: [unprofiledFollow],
            ),
          ).called(1);
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'loads follow profiles via one fetchBatchProfiles call, no per-pubkey '
        'storm',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([]);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([profiledFollow, unprofiledFollow]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => {
              profiledFollow: UserProfile(
                pubkey: profiledFollow,
                createdAt: DateTime.now(),
                eventId: 'event-$profiledFollow',
                rawData: const {},
                name: 'Bob',
              ),
            },
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2),
          // The hydration re-emit lands when it changes what is on screen.
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having((s) => s.contacts[0].displayName, 'hydrated name', 'Bob'),
        ],
        verify: (_) {
          // Exactly one network batch covering both follows, in order — the
          // per-pubkey getCachedProfile/fetchFreshProfile storm is gone.
          final captured = verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: captureAny(named: 'pubkeys'),
            ),
          ).captured;
          expect(captured, hasLength(1));
          expect(captured.single, [profiledFollow, unprofiledFollow]);
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );
    });

    group('contact deduplication', () {
      const duplicatePubkey =
          'aaaa456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      blocTest<ShareSheetBloc, ShareSheetState>(
        'deduplicates contacts when pubkey appears in both recents and follows',
        setUp: () {
          when(() => mockSharingService.recentlySharedWith).thenReturn([
            const ShareableUser(
              pubkey: duplicatePubkey,
              displayName: 'Alice (recent)',
            ),
          ]);
          when(() => mockFollowRepository.followingPubkeys).thenReturn([
            duplicatePubkey,
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetContactsLoadRequested()),
        expect: () => [
          const ShareSheetState(status: ShareSheetStatus.loading),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 2)
              .having(
                (s) => s.contacts.first.displayName,
                'first is from recents',
                'Alice (recent)',
              )
              .having(
                (s) =>
                    s.contacts.where((c) => c.pubkey == duplicatePubkey).length,
                'no duplicate pubkey',
                1,
              ),
          isA<ShareSheetState>()
              .having((s) => s.status, 'status', ShareSheetStatus.ready)
              .having((s) => s.contacts.length, 'contacts.length', 1)
              .having(
                (s) => s.contacts.first.displayName,
                'first is from recents',
                'Alice (recent)',
              )
              .having(
                (s) =>
                    s.contacts.where((c) => c.pubkey == duplicatePubkey).length,
                'no duplicate pubkey',
                1,
              ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Recipient selection
    // -----------------------------------------------------------------------

    group('ShareSheetRecipientToggled', () {
      const otherRecipient = ShareableUser(
        pubkey:
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        displayName: 'Bob',
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'adds an unselected contact to the selection without reordering '
        'contacts',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: [otherRecipient, testRecipient],
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(testRecipient)),
        expect: () => [
          isA<ShareSheetState>()
              .having(
                (s) => s.selectedRecipients.map((r) => r.pubkey),
                'selected pubkeys',
                [testRecipient.pubkey],
              )
              .having(
                (s) => s.contacts.first.pubkey,
                'first contact unchanged',
                otherRecipient.pubkey,
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'accumulates multiple selected recipients in tap order',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: [testRecipient, otherRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc
          ..add(const ShareSheetRecipientToggled(testRecipient))
          ..add(const ShareSheetRecipientToggled(otherRecipient)),
        skip: 1,
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.selectedRecipients.map((r) => r.pubkey),
            'selected pubkeys',
            [testRecipient.pubkey, otherRecipient.pubkey],
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'removes an already-selected recipient, keeping the others',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: [testRecipient, otherRecipient],
          selectedRecipients: [testRecipient, otherRecipient],
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(testRecipient)),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.selectedRecipients.map((r) => r.pubkey),
            'selected pubkeys',
            [otherRecipient.pubkey],
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'inserts a Find People pick missing from contacts at the front',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          contacts: [otherRecipient],
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetRecipientToggled(testRecipient)),
        expect: () => [
          isA<ShareSheetState>()
              .having(
                (s) => s.selectedRecipients.map((r) => r.pubkey),
                'selected pubkeys',
                [testRecipient.pubkey],
              )
              .having((s) => s.contacts.map((c) => c.pubkey), 'contacts', [
                testRecipient.pubkey,
                otherRecipient.pubkey,
              ]),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Send with message
    // -----------------------------------------------------------------------

    group('ShareSheetSendRequested', () {
      const otherRecipient = ShareableUser(
        pubkey:
            'bbbb456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        displayName: 'Bob',
      );

      void stubMultiSend(Map<String, ShareResult> results) {
        when(
          () => mockSharingService.shareVideoWithMultipleUsers(
            video: any(named: 'video'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
            personalMessage: any(named: 'personalMessage'),
          ),
        ).thenAnswer((_) async => results);
      }

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits success carrying the conversation id for a single recipient',
        setUp: () => stubMultiSend({
          testRecipient.pubkey: ShareResult.createSuccess(
            'msg-event-id',
            conversationId: 'conversation-1',
          ),
        }),
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient],
        ),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ShareSheetSendRequested(message: 'Check this out!')),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.isSending,
            'isSending',
            isTrue,
          ),
          isA<ShareSheetState>()
              .having((s) => s.isSending, 'isSending', isFalse)
              .having((s) => s.selectedRecipients, 'selection cleared', isEmpty)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSendSuccess>()
                    .having((r) => r.recipientNames, 'names', ['Alice'])
                    .having(
                      (r) => r.recipientPubkey,
                      'recipientPubkey',
                      testRecipient.pubkey,
                    )
                    .having(
                      (r) => r.conversationId,
                      'conversationId',
                      'conversation-1',
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'fans out to every selected recipient with no View chat target',
        setUp: () => stubMultiSend({
          testRecipient.pubkey: ShareResult.createSuccess('msg-1'),
          otherRecipient.pubkey: ShareResult.createSuccess('msg-2'),
        }),
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient, otherRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested(message: 'yo')),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.isSending,
            'isSending',
            isTrue,
          ),
          isA<ShareSheetState>()
              .having((s) => s.selectedRecipients, 'selection cleared', isEmpty)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSendSuccess>()
                    .having((r) => r.recipientNames, 'names', ['Alice', 'Bob'])
                    .having((r) => r.conversationId, 'conversationId', isNull)
                    .having(
                      (r) => r.recipientPubkey,
                      'recipientPubkey',
                      isNull,
                    ),
              ),
        ],
        verify: (_) {
          final captured = verify(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: any(named: 'video'),
              recipientPubkeys: captureAny(named: 'recipientPubkeys'),
              personalMessage: captureAny(named: 'personalMessage'),
            ),
          ).captured;
          expect(
            captured[0],
            equals([testRecipient.pubkey, otherRecipient.pubkey]),
          );
          expect(captured[1], equals('yo'));
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'on partial failure reports the delivered recipients and clears the '
        'selection (durable queue retries the rest, no manual re-send)',
        setUp: () => stubMultiSend({
          testRecipient.pubkey: ShareResult.createSuccess('msg-1'),
          otherRecipient.pubkey: ShareResult.failure('Relay offline'),
        }),
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient, otherRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.isSending,
            'isSending',
            isTrue,
          ),
          isA<ShareSheetState>()
              .having((s) => s.isSending, 'isSending', isFalse)
              .having((s) => s.selectedRecipients, 'selection cleared', isEmpty)
              .having(
                (s) => s.actionResult,
                'actionResult',
                // Reports only the delivered recipient; no View chat because
                // more than one recipient was targeted.
                isA<ShareSheetSendSuccess>()
                    .having((r) => r.recipientNames, 'names', ['Alice'])
                    .having((r) => r.conversationId, 'conversationId', isNull),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits failure and clears the selection when every recipient fails',
        setUp: () => stubMultiSend({
          testRecipient.pubkey: ShareResult.failure('Relay offline'),
          otherRecipient.pubkey: ShareResult.failure('Relay offline'),
        }),
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient, otherRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.isSending,
            'isSending',
            isTrue,
          ),
          isA<ShareSheetState>()
              .having((s) => s.selectedRecipients, 'selection cleared', isEmpty)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSendFailure>(),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'sends null personalMessage when message is whitespace only',
        setUp: () => stubMultiSend({
          testRecipient.pubkey: ShareResult.createSuccess('msg-event-id'),
        }),
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested(message: '   ')),
        verify: (_) {
          final captured = verify(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: any(named: 'video'),
              recipientPubkeys: captureAny(named: 'recipientPubkeys'),
              personalMessage: captureAny(named: 'personalMessage'),
            ),
          ).captured;
          expect(captured[0], equals([testRecipient.pubkey]));
          expect(captured[1], isNull, reason: 'whitespace trimmed to null');
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits failure when the sharing service throws an exception',
        setUp: () {
          when(
            () => mockSharingService.shareVideoWithMultipleUsers(
              video: any(named: 'video'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
              personalMessage: any(named: 'personalMessage'),
            ),
          ).thenThrow(Exception('Unexpected error'));
        },
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.isSending,
            'isSending',
            isTrue,
          ),
          isA<ShareSheetState>()
              .having((s) => s.isSending, 'isSending', isFalse)
              .having((s) => s.selectedRecipients, 'selection cleared', isEmpty)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSendFailure>(),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'does nothing when no recipient selected',
        seed: () => const ShareSheetState(status: ShareSheetStatus.ready),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => <ShareSheetState>[],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'does nothing when already sending',
        seed: () => const ShareSheetState(
          status: ShareSheetStatus.ready,
          selectedRecipients: [testRecipient],
          isSending: true,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSendRequested()),
        expect: () => <ShareSheetState>[],
      );
    });

    // -----------------------------------------------------------------------
    // Save to bookmarks
    // -----------------------------------------------------------------------

    group('ShareSheetSaveRequested', () {
      // The save handler emits a pending state before it touches the
      // network, then the terminal result, so every expectation below opens
      // with this one and asserts the flag is cleared on the way out.
      final savePending = isA<ShareSheetState>()
          .having((s) => s.isSaving, 'isSaving', isTrue)
          .having((s) => s.actionResult, 'actionResult', isNull);

      late Completer<BookmarkToggleResult> saveGate;

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveResult with succeeded=true, removed=false when adding bookmark',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isTrue)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveResult with succeeded=true, removed=true when removing bookmark',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: true,
              isBookmarked: false,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isTrue)
                    .having((r) => r.removed, 'removed', isTrue)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isTrue,
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveResult with succeeded=false when bookmark fails',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: false,
              wasBookmarked: false,
              isBookmarked: false,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits failure with wasBookmarkedBeforeToggle true when removing '
        'bookmark fails',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: false,
              wasBookmarked: true,
              isBookmarked: true,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isTrue,
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveResult with succeeded=false when bookmark throws',
        setUp: () {
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenThrow(Exception('offline'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits failure with wasBookmarkedBeforeToggle true when toggle '
        'throws while bookmarked',
        setUp: () {
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
          ).thenReturn(true);
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenThrow(Exception('offline'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isTrue,
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetSaveResult with succeeded=false when no bookmark service',
        build: () => createBloc(
          bookmarksRepositoryFuture: Future<BookmarksRepository?>.value(),
        ),
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.succeeded, 'succeeded', isFalse)
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'consecutive saves emit distinct states via identity equality',
        setUp: () {
          var inGlobalBookmarks = false;
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer((_) async {
            final wasBookmarked = inGlobalBookmarks;
            inGlobalBookmarks = !inGlobalBookmarks;
            return BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: wasBookmarked,
              isBookmarked: inGlobalBookmarks,
            );
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetSaveRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const ShareSheetSaveRequested());
        },
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.removed, 'removed', isFalse)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isFalse,
                    ),
              ),
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>()
                    .having((r) => r.removed, 'removed', isTrue)
                    .having(
                      (r) => r.wasBookmarkedBeforeToggle,
                      'wasBookmarkedBeforeToggle',
                      isTrue,
                    ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'swallows a repeat save while the first is still in flight',
        setUp: () {
          saveGate = Completer<BookmarkToggleResult>();
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer((_) => saveGate.future);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetSaveRequested());
          await Future<void>.delayed(Duration.zero);
          // Still reconciling. The sheet is showing the pending affordance and
          // this second tap must not start another reconcile-and-publish of a
          // replaceable list.
          bloc.add(const ShareSheetSaveRequested());
          await Future<void>.delayed(Duration.zero);
          saveGate.complete(
            const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
        },
        expect: () => [
          savePending,
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>().having(
                  (r) => r.succeeded,
                  'succeeded',
                  isTrue,
                ),
              ),
        ],
        verify: (_) => verify(
          () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
        ).called(1),
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'does not emit after close when save completes late',
        setUp: () {
          saveGate = Completer<BookmarkToggleResult>();
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer((_) => saveGate.future);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetSaveRequested());
          await Future<void>.delayed(Duration.zero);
          await bloc.close();
          saveGate.complete(
            const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [savePending],
      );
    });

    // -----------------------------------------------------------------------
    // Add video to clips
    // -----------------------------------------------------------------------

    group('ShareSheetAddVideoToClipsRequested', () {
      late _MockVideoClipImportService mockImporter;

      setUp(() {
        mockImporter = _MockVideoClipImportService();
      });

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits import success when video is added to clips',
        setUp: () {
          when(
            () => mockImporter.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).thenAnswer(
            (_) async =>
                VideoClipImportSuccess(_clip(libraryTitle: 'My local cut')),
          );
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(
          const ShareSheetAddVideoToClipsRequested(
            libraryTitle: 'My local cut',
          ),
        ),
        expect: () => [
          isA<ShareSheetState>().having(
            (state) => state.actionResult,
            'actionResult',
            isA<ShareSheetVideoClipImportResult>()
                .having((result) => result.succeeded, 'succeeded', isTrue)
                .having(
                  (result) => result.libraryTitle,
                  'libraryTitle',
                  'My local cut',
                ),
          ),
        ],
        verify: (_) {
          verify(
            () => mockImporter.importToLibrary(
              testVideo,
              libraryTitle: 'My local cut',
            ),
          ).called(1);
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits import failure when importer cannot add the clip',
        setUp: () {
          when(
            () => mockImporter.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).thenAnswer(
            (_) async => const VideoClipImportFailure(
              VideoClipImportFailureReason.downloadFailed,
            ),
          );
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(const ShareSheetAddVideoToClipsRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (state) => state.actionResult,
            'actionResult',
            isA<ShareSheetVideoClipImportResult>().having(
              (result) => result.succeeded,
              'succeeded',
              isFalse,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits import failure when importer is unavailable',
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetAddVideoToClipsRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (state) => state.actionResult,
            'actionResult',
            isA<ShareSheetVideoClipImportResult>().having(
              (result) => result.succeeded,
              'succeeded',
              isFalse,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits import failure AND addError when importer throws (#3715)',
        setUp: () {
          when(
            () => mockImporter.importToLibrary(
              any(),
              libraryTitle: any(named: 'libraryTitle'),
            ),
          ).thenThrow(Exception('download failed'));
        },
        build: () => createBloc(videoClipImportService: mockImporter),
        act: (bloc) => bloc.add(const ShareSheetAddVideoToClipsRequested()),
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<Exception>(),
          ),
        ],
        expect: () => [
          isA<ShareSheetState>().having(
            (state) => state.actionResult,
            'actionResult',
            isA<ShareSheetVideoClipImportResult>().having(
              (result) => result.succeeded,
              'succeeded',
              isFalse,
            ),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Copy link
    // -----------------------------------------------------------------------

    group('ShareSheetCopyLinkRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetCopiedToClipboard with generated URL',
        setUp: () {
          when(
            () => mockSharingService.generateShareUrl(any()),
          ).thenReturn('https://divine.video/video/test-id');
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyLinkRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetCopiedToClipboard>()
                .having(
                  (r) => r.text,
                  'text',
                  'https://divine.video/video/test-id',
                )
                .having((r) => r.kind, 'kind', ShareSheetCopiedKind.postLink),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when generateShareUrl throws',
        setUp: () {
          when(
            () => mockSharingService.generateShareUrl(any()),
          ).thenThrow(Exception('url error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyLinkRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Share via
    // -----------------------------------------------------------------------

    group('ShareSheetShareViaRequested', () {
      late _MockCacheManager mockCacheManager;

      setUp(() {
        mockCacheManager = _MockCacheManager();
      });

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetShareViaTriggered with shareUrl and thumbnailPath',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
          final mockFile = _MockFile();
          when(() => mockFile.path).thenReturn('/tmp/cached_thumb');
          // Stub copy to return a file at the destination path.
          when(() => mockFile.copy(any())).thenAnswer((inv) async {
            final dest = inv.positionalArguments[0] as String;
            final copied = _MockFile();
            when(() => copied.path).thenReturn(dest);
            return copied;
          });
          when(
            () => mockCacheManager.getSingleFile(any()),
          ).thenAnswer((_) async => mockFile);
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having(
                  (r) => r.shareUrl,
                  'shareUrl',
                  'https://divine.video/video/test-id',
                )
                .having(
                  (r) => r.thumbnailPath,
                  'thumbnailPath',
                  endsWith('divine_share_thumb.jpg'),
                )
                .having((r) => r.title, 'title', 'Test Video')
                .having((r) => r.subject, 'subject', 'Test Video'),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when thumbnail download fails',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
          when(
            () => mockCacheManager.getSingleFile(any()),
          ).thenThrow(Exception('network error'));
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having(
                  (r) => r.shareUrl,
                  'shareUrl',
                  'https://divine.video/video/test-id',
                )
                .having((r) => r.thumbnailPath, 'thumbnailPath', isNull),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when no thumbnailUrl available',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: null,
            thumbnailUrl: null,
          ));
        },
        build: () => createBloc(cacheManager: mockCacheManager),
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>()
                .having((r) => r.thumbnailPath, 'thumbnailPath', isNull)
                .having((r) => r.title, 'title', isNull),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits with null thumbnailPath when no cache manager provided',
        setUp: () {
          when(() => mockSharingService.generateShareData(any())).thenReturn((
            shareUrl: 'https://divine.video/video/test-id',
            title: 'Test Video',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetShareViaTriggered>().having(
              (r) => r.thumbnailPath,
              'thumbnailPath',
              isNull,
            ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when generateShareData throws',
        setUp: () {
          when(
            () => mockSharingService.generateShareData(any()),
          ).thenThrow(Exception('share error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetShareViaRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Copy event JSON
    // -----------------------------------------------------------------------

    group('ShareSheetCopyEventJsonRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetCopiedToClipboard with formatted JSON',
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyEventJsonRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetCopiedToClipboard>()
                .having((r) => r.kind, 'kind', ShareSheetCopiedKind.eventJson)
                .having(
                  (r) => r.text.contains('"id"'),
                  'text contains id field',
                  isTrue,
                ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when toJson throws',
        build: () => ShareSheetBloc(
          video: _ThrowingJsonVideoEvent(),
          relayUrl: 'wss://relay.test.example',
          videoSharingService: mockSharingService,
          profileRepository: mockProfileRepository,
          followRepository: mockFollowRepository,
          currentUserPubkey: currentUserPubkey,
        ),
        act: (bloc) => bloc.add(const ShareSheetCopyEventJsonRequested()),
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<FormatException>(),
          ),
        ],
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
          ),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // Copy event ID
    // -----------------------------------------------------------------------

    group('ShareSheetCopyEventIdRequested', () {
      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetCopiedToClipboard with nevent-encoded ID',
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetCopyEventIdRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetCopiedToClipboard>()
                .having((r) => r.kind, 'kind', ShareSheetCopiedKind.eventId)
                .having(
                  (r) => r.text.startsWith('nevent'),
                  'text starts with nevent',
                  isTrue,
                ),
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'emits $ShareSheetActionFailure when encoding throws',
        build: () => ShareSheetBloc(
          video: _InvalidIdVideoEvent(),
          relayUrl: 'wss://relay.test.example',
          videoSharingService: mockSharingService,
          profileRepository: mockProfileRepository,
          followRepository: mockFollowRepository,
          currentUserPubkey: currentUserPubkey,
        ),
        act: (bloc) => bloc.add(const ShareSheetCopyEventIdRequested()),
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<FormatException>(),
          ),
        ],
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.actionResult,
            'actionResult',
            isA<ShareSheetActionFailure>(),
          ),
        ],
      );
    });

    group('ShareSheetBookmarkStatusRequested', () {
      late Completer<bool> bookmarkStatusSyncCompleter;

      blocTest<ShareSheetBloc, ShareSheetState>(
        'resolves saved when the reconciled list contains the video',
        setUp: () {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => true);
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetBookmarkStatusRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.bookmarkStatus,
            'bookmarkStatus',
            ShareSheetBookmarkStatus.saved,
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'resolves notSaved when the reconciled list omits the video',
        setUp: () {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => true);
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
          ).thenReturn(false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetBookmarkStatusRequested()),
        expect: () => [
          isA<ShareSheetState>().having(
            (s) => s.bookmarkStatus,
            'bookmarkStatus',
            ShareSheetBookmarkStatus.notSaved,
          ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'stays unknown when the list has private items it could not read',
        setUp: () {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => true);
          when(
            () => mockBookmarksRepository.hasUnreadablePrivateItems,
          ).thenReturn(true);
          // The public half says "not bookmarked", but the encrypted half is
          // exactly where the video might be — claiming notSaved here is the
          // mislabel that precedes the disclosure (#7136).
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
          ).thenReturn(false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetBookmarkStatusRequested()),
        expect: () => <ShareSheetState>[],
        verify: (bloc) =>
            expect(bloc.state.bookmarkStatus, ShareSheetBookmarkStatus.unknown),
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'does not let a late status read overwrite a successful toggle',
        setUp: () {
          bookmarkStatusSyncCompleter = Completer<bool>();
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) => bookmarkStatusSyncCompleter.future);
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
          ).thenReturn(false);
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: false,
              isBookmarked: true,
            ),
          );
          addTearDown(() {
            if (!bookmarkStatusSyncCompleter.isCompleted) {
              bookmarkStatusSyncCompleter.complete(false);
            }
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ShareSheetBookmarkStatusRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const ShareSheetSaveRequested());
          await Future<void>.delayed(Duration.zero);
          bookmarkStatusSyncCompleter.complete(true);
        },
        expect: () => [
          // The in-flight save (#7073) emits before the toggle resolves; the
          // label must not commit to a direction while it is pending.
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isTrue)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                ShareSheetBookmarkStatus.unknown,
              ),
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                ShareSheetBookmarkStatus.saved,
              )
              .having(
                (s) => s.actionResult,
                'actionResult',
                isA<ShareSheetSaveResult>().having(
                  (r) => r.succeeded,
                  'succeeded',
                  isTrue,
                ),
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'stays unknown when the reconcile is inconclusive, and never reads '
        'the stale local cache',
        setUp: () {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetBookmarkStatusRequested()),
        expect: () => <ShareSheetState>[],
        verify: (_) {
          verifyNever(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
          );
        },
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'stays unknown when the bookmark service is unavailable',
        build: () => createBloc(
          bookmarksRepositoryFuture: Future<BookmarksRepository?>.value(),
        ),
        act: (bloc) => bloc.add(const ShareSheetBookmarkStatusRequested()),
        expect: () => <ShareSheetState>[],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'a successful remove flips the status to notSaved',
        setUp: () {
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
          ).thenReturn(true);
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: true,
              wasBookmarked: true,
              isBookmarked: false,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isTrue)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                ShareSheetBookmarkStatus.unknown,
              ),
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                ShareSheetBookmarkStatus.notSaved,
              ),
        ],
      );

      blocTest<ShareSheetBloc, ShareSheetState>(
        'a failed toggle leaves the status untouched rather than adopting the '
        'pre-toggle guess',
        seed: () => const ShareSheetState(
          bookmarkStatus: ShareSheetBookmarkStatus.saved,
        ),
        setUp: () {
          when(
            () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
          ).thenReturn(false);
          when(
            () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
          ).thenAnswer(
            (_) async => const BookmarkToggleResult(
              succeeded: false,
              wasBookmarked: false,
              isBookmarked: false,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ShareSheetSaveRequested()),
        expect: () => [
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isTrue)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                ShareSheetBookmarkStatus.saved,
              ),
          isA<ShareSheetState>()
              .having((s) => s.isSaving, 'isSaving', isFalse)
              .having(
                (s) => s.bookmarkStatus,
                'bookmarkStatus',
                ShareSheetBookmarkStatus.saved,
              ),
        ],
      );
    });
  });
}
