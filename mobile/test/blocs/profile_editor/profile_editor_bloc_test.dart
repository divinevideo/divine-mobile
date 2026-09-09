// ABOUTME: Unit tests for ProfileEditorBloc
// ABOUTME: Asserts claim-before-publish ordering — kind 0 must never be
// ABOUTME: broadcast unless the username claim succeeded first. Also
// ABOUTME: covers the staged-avatar contract: upload stages, save persists,
// ABOUTME: failure preserves the prior preview, no publish on upload alone.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/services/staged_profile_media_store.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockMentionResolutionService extends Mock
    implements MentionResolutionService {}

class _FakeFile extends Fake implements File {}

class _FakeStagedProfileMediaStore implements StagedProfileMediaStore {
  final Map<String, StagedProfileMedia> values = {};
  final List<String> clearedPubkeys = [];

  @override
  StagedProfileMedia? load(String pubkey) => values[pubkey];

  @override
  Future<void> save(
    String pubkey, {
    String? pictureUrl,
    String? bannerUrl,
    bool pictureCleared = false,
    bool bannerCleared = false,
  }) async {
    final staged = StagedProfileMedia(
      pictureUrl: pictureUrl,
      bannerUrl: bannerUrl,
      pictureCleared: pictureCleared,
      bannerCleared: bannerCleared,
      stagedAt: DateTime.utc(2026, 8, 4),
    );
    if (staged.isEmpty) {
      values.remove(pubkey);
      clearedPubkeys.add(pubkey);
      return;
    }
    values[pubkey] = staged;
  }

  @override
  Future<void> clear(String pubkey) async {
    values.remove(pubkey);
    clearedPubkeys.add(pubkey);
  }
}

void main() {
  group('ProfileEditorBloc', () {
    late _MockProfileRepository mockProfileRepository;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testDisplayName = 'Test User';
    const testAbout = 'Test bio';
    const testUsername = 'testuser';
    const testPicture = 'https://example.com/avatar.png';
    const alicePubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    /// Helper to create a test UserProfile
    UserProfile createTestProfile({String? nip05}) {
      return UserProfile(
        pubkey: testPubkey,
        displayName: testDisplayName,
        about: testAbout,
        picture: testPicture,
        nip05: nip05,
        rawData: const {},
        createdAt: DateTime.now(),
        eventId:
            'event123456789012345678901234567890123456789012345678901234567890',
      );
    }

    late _MockBlossomUploadService mockBlossomUploadService;
    late _MockMentionResolutionService mockMentionResolutionService;

    setUpAll(() {
      registerFallbackValue(
        UserProfile(
          pubkey: testPubkey,
          displayName: testDisplayName,
          rawData: const {},
          createdAt: DateTime.now(),
          eventId: 'fallback12345678901234567890123456789012345678901234567890123456',
        ),
      );
      registerFallbackValue(_FakeFile());
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(
        const PendingProfileSave(pubkey: testPubkey, displayName: 'fallback'),
      );
    });

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      mockBlossomUploadService = _MockBlossomUploadService();
      mockMentionResolutionService = _MockMentionResolutionService();
      when(
        () => mockProfileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});
      // Optimistic-save path (#3161): every save enqueues the durable slot and
      // re-drives it. Default the slot to a confirmed publish so success-path
      // tests read [loading, success] unchanged; failure-path tests override.
      when(
        () => mockProfileRepository.enqueuePendingSave(
          any(),
          claimConfirmed: any(named: 'claimConfirmed'),
        ),
      ).thenAnswer((_) async => 'gen-test');
      when(
        () => mockProfileRepository.drivePendingSave(
          any(),
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async => PendingSaveDriveOutcome.confirmed);
    });

    ProfileEditorBloc createBloc({
      bool hasExistingProfile = true,
      MentionResolutionService? mentionResolutionService,
      StagedProfileMediaStore? stagedProfileMediaStore,
      String? currentUserPubkey,
    }) => ProfileEditorBloc(
      profileRepository: mockProfileRepository,
      blossomUploadService: mockBlossomUploadService,
      hasExistingProfile: hasExistingProfile,
      mentionResolutionService: mentionResolutionService,
      currentUserPubkey: currentUserPubkey,
      stagedProfileMediaStore: stagedProfileMediaStore,
    );

    test('initial state is ProfileEditorStatus.initial', () {
      final bloc = createBloc();
      expect(bloc.state.status, ProfileEditorStatus.initial);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('ProfileSaved', () {
      group('without username', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, success] when profile publishes successfully',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, testAbout);
            expect(payload.picture, testPicture);
            expect(payload.username, isNull);
            verifyNever(
              () => mockProfileRepository.claimUsername(
                username: any(named: 'username'),
              ),
            );
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'publishes profile with existing profile data',
          setUp: () {
            final existingProfile = createTestProfile(
              nip05: 'original@example.com',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => existingProfile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'publishes profile with null username when username is empty string',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: '',
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, testAbout);
            expect(payload.picture, testPicture);
            expect(payload.username, isNull);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'passes clearNip05: false when no username and initialUsername is null '
          '(profile not loaded — must not destroy an unloaded NIP-05)',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
            ),
          ),
          verify: (_) {
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, testAbout);
            expect(payload.picture, testPicture);
            expect(payload.clearNip05, isFalse);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'passes clearNip05: true when user explicitly removes a known username',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          // Dispatch InitialUsernameSet first so the bloc knows the user had
          // 'testuser' — then saving with no username is an explicit removal.
          act: (bloc) async {
            bloc.add(const InitialUsernameSet(testUsername));
            await Future<void>.delayed(Duration.zero);
            bloc.add(
              const ProfileSaved(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
              ),
            );
          },
          verify: (_) {
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, testAbout);
            expect(payload.picture, testPicture);
            expect(payload.clearNip05, isTrue);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'canonicalizes exact bio mentions before publishing profile metadata',
          setUp: () {
            when(
              () => mockProfileRepository.searchUsersLocally(
                query: 'alice',
                limit: any(named: 'limit'),
              ),
            ).thenAnswer(
              (_) async => [
                UserProfile(
                  pubkey: alicePubkey,
                  name: 'alice',
                  rawData: const {},
                  createdAt: DateTime.utc(2026),
                  eventId: 'event-$alicePubkey',
                ),
              ],
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: () => createBloc(
            mentionResolutionService: MentionResolutionService(
              profileRepository: mockProfileRepository,
            ),
          ),
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: 'hi @alice',
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            final aliceNpub = NostrKeyUtils.encodePubKey(alicePubkey);
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, 'hi nostr:$aliceNpub');
            expect(payload.picture, testPicture);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'preserves unresolved bio text when mention resolution fails',
          setUp: () {
            when(
              () => mockProfileRepository.searchUsersLocally(
                query: 'alice',
                limit: any(named: 'limit'),
              ),
            ).thenThrow(Exception('lookup unavailable'));
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: () => createBloc(
            mentionResolutionService: MentionResolutionService(
              profileRepository: mockProfileRepository,
            ),
          ),
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: 'hi @alice',
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, 'hi @alice');
            expect(payload.picture, testPicture);
          },
        );
      });

      group('with username', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'emits [loading, success] when profile and username claim succeed',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimSuccess());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            // Claim must run before publish so kind 0 is only broadcast
            // after the registry confirms the name belongs to this pubkey.
            final results = verifyInOrder([
              () => mockProfileRepository.claimUsername(username: testUsername),
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ]);
            final payload = results[1].captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, testAbout);
            expect(payload.username, testUsername);
            expect(payload.picture, testPicture);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'publishes without claiming when username matches initialUsername',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          seed: () => const ProfileEditorState(initialUsername: testUsername),
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verifyNever(
              () => mockProfileRepository.claimUsername(
                username: any(named: 'username'),
              ),
            );
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, testAbout);
            expect(payload.username, testUsername);
            expect(payload.picture, testPicture);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'publishes without claiming when the username is already owned via '
          'the loaded profile NIP-05 and initialUsername is unset (#4199)',
          setUp: () {
            // Cold web load: the editor never seeded initialUsername, but the
            // loaded profile already carries this divine.video username, so the
            // claim must be skipped (and, before the CORS fix, would have failed
            // on web).
            final owned = createTestProfile(
              nip05: '_@$testUsername.divine.video',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => owned);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verifyNever(
              () => mockProfileRepository.claimUsername(
                username: any(named: 'username'),
              ),
            );
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, testAbout);
            expect(payload.username, testUsername);
            expect(payload.picture, testPicture);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'supports admin-assigned username for current user through '
          'availability check then save/claim success',
          setUp: () {
            when(
              () => mockProfileRepository.checkUsernameAvailability(
                username: testUsername,
                currentUserPubkey: testPubkey,
              ),
            ).thenAnswer((_) async => const UsernameAvailable());
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimSuccess());
          },
          build: () => ProfileEditorBloc(
            profileRepository: mockProfileRepository,
            blossomUploadService: mockBlossomUploadService,
            hasExistingProfile: true,
            currentUserPubkey: testPubkey,
          ),
          act: (bloc) async {
            bloc.add(const UsernameChanged(testUsername));
            await Future<void>.delayed(const Duration(milliseconds: 700));
            bloc.add(
              const ProfileSaved(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              ),
            );
          },
          wait: const Duration(milliseconds: 700),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.usernameStatus,
              'usernameStatus',
              UsernameStatus.checking,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.usernameStatus,
              'usernameStatus',
              UsernameStatus.available,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verify(
              () => mockProfileRepository.checkUsernameAvailability(
                username: testUsername,
                currentUserPubkey: testPubkey,
              ),
            ).called(1);
            final captured = verify(
              () => mockProfileRepository.enqueuePendingSave(
                captureAny(),
                claimConfirmed: captureAny(named: 'claimConfirmed'),
              ),
            ).captured;
            final payload = captured[0] as PendingProfileSave;
            expect(payload.displayName, testDisplayName);
            expect(payload.about, testAbout);
            expect(payload.username, testUsername);
            expect(payload.picture, testPicture);
            verify(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).called(1);
          },
        );
      });

      group('profile publish failure', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'retryable publish failure no longer blocks the save — emits '
          'optimistic success and leaves the slot queued for retry',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.drivePendingSave(
                testPubkey,
                expectedGeneration: any(named: 'expectedGeneration'),
              ),
            ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verify(
              () => mockProfileRepository.enqueuePendingSave(
                any(),
                claimConfirmed: any(named: 'claimConfirmed'),
              ),
            ).called(1);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'still emits optimistic success when claim succeeds but publish '
          'fails — slot stays queued for retry',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimSuccess());
            when(
              () => mockProfileRepository.drivePendingSave(
                testPubkey,
                expectedGeneration: any(named: 'expectedGeneration'),
              ),
            ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            // Claim happens first; the slot is then enqueued and driven —
            // a retryable publish failure no longer blocks Save.
            verifyInOrder([
              () => mockProfileRepository.claimUsername(username: testUsername),
              () => mockProfileRepository.enqueuePendingSave(
                any(),
                claimConfirmed: any(named: 'claimConfirmed'),
              ),
            ]);
          },
        );
      });

      group('no relays connected', () {
        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'no relays connected → optimistic success, slot stays queued '
          'for retry',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.drivePendingSave(
                testPubkey,
                expectedGeneration: any(named: 'expectedGeneration'),
              ),
            ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verify(
              () => mockProfileRepository.enqueuePendingSave(
                any(),
                claimConfirmed: any(named: 'claimConfirmed'),
              ),
            ).called(1);
          },
        );

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'still optimistic success when claim succeeded but publish '
          'cannot reach any relay — slot stays queued for retry',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimSuccess());
            when(
              () => mockProfileRepository.drivePendingSave(
                testPubkey,
                expectedGeneration: any(named: 'expectedGeneration'),
              ),
            ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.success,
            ),
          ],
          verify: (_) {
            verifyInOrder([
              () => mockProfileRepository.claimUsername(username: testUsername),
              () => mockProfileRepository.enqueuePendingSave(
                any(),
                claimConfirmed: any(named: 'claimConfirmed'),
              ),
            ]);
          },
        );
      });

      // Regression: kind 0 metadata is gossiped to relays and effectively
      // immutable once broadcast. If we publish before confirming the username
      // claim, a single name-server hiccup leaves the user advertising a
      // _@<name>.divine.video identifier with no registry record. These tests
      // assert that the durable save slot is never enqueued/driven when the
      // claim fails.
      group('claim failure does not broadcast kind 0', () {
        for (final scenario in [
          (
            label: 'username taken',
            result: const UsernameClaimTaken(),
            expectedError: ProfileEditorError.usernameTaken,
            expectedUsernameStatus: UsernameStatus.taken,
          ),
          (
            label: 'username reserved',
            result: const UsernameClaimReserved(),
            expectedError: ProfileEditorError.usernameReserved,
            expectedUsernameStatus: UsernameStatus.reserved,
          ),
          (
            label: 'name server error',
            result: const UsernameClaimError('Server unavailable'),
            expectedError: ProfileEditorError.claimFailed,
            expectedUsernameStatus: null,
          ),
          (
            label: 'name server unreachable',
            result: const UsernameClaimNetworkError(),
            expectedError: ProfileEditorError.claimNetworkError,
            expectedUsernameStatus: null,
          ),
        ]) {
          blocTest<ProfileEditorBloc, ProfileEditorState>(
            'emits failure and never enqueues/drives the pending save on '
            '${scenario.label}',
            setUp: () {
              final existingProfile = createTestProfile(
                nip05: 'original@example.com',
              );
              when(
                () =>
                    mockProfileRepository.getCachedProfile(pubkey: testPubkey),
              ).thenAnswer((_) async => existingProfile);
              when(
                () =>
                    mockProfileRepository.claimUsername(username: testUsername),
              ).thenAnswer((_) async => scenario.result);
            },
            build: createBloc,
            act: (bloc) => bloc.add(
              const ProfileSaved(
                pubkey: testPubkey,
                displayName: testDisplayName,
                about: testAbout,
                picture: testPicture,
                username: testUsername,
              ),
            ),
            expect: () => [
              isA<ProfileEditorState>().having(
                (s) => s.status,
                'status',
                ProfileEditorStatus.loading,
              ),
              isA<ProfileEditorState>()
                  .having(
                    (s) => s.status,
                    'status',
                    ProfileEditorStatus.failure,
                  )
                  .having((s) => s.error, 'error', scenario.expectedError)
                  .having(
                    (s) => s.usernameStatus,
                    'usernameStatus',
                    scenario.expectedUsernameStatus ?? UsernameStatus.idle,
                  ),
            ],
            verify: (_) {
              verify(
                () =>
                    mockProfileRepository.claimUsername(username: testUsername),
              ).called(1);
              verifyNever(
                () => mockProfileRepository.enqueuePendingSave(
                  any(),
                  claimConfirmed: any(named: 'claimConfirmed'),
                ),
              );
              verifyNever(
                () => mockProfileRepository.drivePendingSave(
                  any(),
                  expectedGeneration: any(named: 'expectedGeneration'),
                ),
              );
            },
          );
        }

        blocTest<ProfileEditorBloc, ProfileEditorState>(
          'records reserved username in state for re-check support',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.claimUsername(username: testUsername),
            ).thenAnswer((_) async => const UsernameClaimReserved());
          },
          build: createBloc,
          act: (bloc) => bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          ),
          expect: () => [
            isA<ProfileEditorState>().having(
              (s) => s.status,
              'status',
              ProfileEditorStatus.loading,
            ),
            isA<ProfileEditorState>()
                .having((s) => s.status, 'status', ProfileEditorStatus.failure)
                .having(
                  (s) => s.reservedUsernames,
                  'reservedUsernames',
                  contains(testUsername),
                ),
          ],
        );
      });
    });

    // Defensive try/catch on the 5 handlers + narrowed publish branch +
    // mention-resolution wrap. Per .claude/rules/error_handling.md, only
    // `Error` subclasses (StateError, TypeError, RangeError) escape the
    // repository's `on Exception` filters; these tests pin that the bloc
    // now wraps them as `Reportable<T>` and still emits a sensible
    // status-enum failure value.
    group('handler-level invariant Reportable wraps', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected claimUsername Error in _onProfileSaved as '
        'Reportable and emits failure(publishFailed)',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.claimUsername(username: testUsername),
          ).thenThrow(StateError('claim invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
            picture: testPicture,
            username: testUsername,
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>()
              .having((s) => s.status, 'status', ProfileEditorStatus.failure)
              .having(
                (s) => s.error,
                'error',
                ProfileEditorError.publishFailed,
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        verify: (_) {
          // Claim threw — never reach the publish step.
          verifyNever(
            () => mockProfileRepository.enqueuePendingSave(
              any(),
              claimConfirmed: any(named: 'claimConfirmed'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.drivePendingSave(
              any(),
              expectedGeneration: any(named: 'expectedGeneration'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected drivePendingSave Error in narrowed publish catch '
        'as Reportable but keeps the optimistic success emitted earlier',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.drivePendingSave(
              testPubkey,
              expectedGeneration: any(named: 'expectedGeneration'),
            ),
          ).thenThrow(StateError('publish invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
            picture: testPicture,
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.success,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected drivePendingSave Error in _onProfileNip05Saved as '
        'Reportable but keeps the optimistic success emitted earlier',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.drivePendingSave(
              testPubkey,
              expectedGeneration: any(named: 'expectedGeneration'),
            ),
          ).thenThrow(StateError('nip05 save invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfileNip05Saved(
            currentProfile: UserProfile(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              rawData: const {},
              createdAt: DateTime.now(),
              eventId: 'nip05evt567890123456789012345678901234567890123456789012345678',
            ),
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.success,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected drivePendingSave Error in _onProfileSaveConfirmed '
        'as Reportable but keeps the optimistic success emitted earlier',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockProfileRepository.drivePendingSave(
              testPubkey,
              expectedGeneration: any(named: 'expectedGeneration'),
            ),
          ).thenThrow(StateError('confirmed save invariant'));
        },
        build: () => createBloc(hasExistingProfile: false),
        seed: () => const ProfileEditorState(
          status: ProfileEditorStatus.confirmationRequired,
          pendingEvent: ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
          ),
        ),
        act: (bloc) => bloc.add(const ProfileSaveConfirmed()),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.success,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected checkUsernameAvailability Error in '
        '_onUsernameChanged as Reportable and emits error(networkError)',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenThrow(StateError('availability check invariant'));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const UsernameChanged(testUsername));
          // Wait out the 500ms debounce + buffer
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        wait: const Duration(milliseconds: 700),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.usernameStatus,
            'usernameStatus',
            UsernameStatus.checking,
          ),
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                UsernameValidationError.networkError,
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected checkUsernameAvailability Error in '
        '_onUsernameRechecked as Reportable and re-reserves the name',
        build: createBloc,
        seed: () => const ProfileEditorState(
          username: testUsername,
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: {testUsername},
        ),
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenThrow(StateError('recheck invariant'));
        },
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              )
              .having((s) => s.reservedUsernames, 'reservedUsernames', isEmpty),
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.reserved,
              )
              .having(
                (s) => s.reservedUsernames,
                'reservedUsernames',
                contains(testUsername),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'wraps unexpected MentionResolutionService Error as Reportable '
        'but continues the save with the raw bio text',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockMentionResolutionService.resolveTextMentions(
              rawText: any(named: 'rawText'),
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenThrow(StateError('mention service invariant'));
        },
        build: () =>
            createBloc(mentionResolutionService: mockMentionResolutionService),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: 'hi @alice',
            picture: testPicture,
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.success,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        verify: (_) {
          // Save still happens with the raw (unresolved) bio.
          final captured = verify(
            () => mockProfileRepository.enqueuePendingSave(
              captureAny(),
              claimConfirmed: captureAny(named: 'claimConfirmed'),
            ),
          ).captured;
          final payload = captured[0] as PendingProfileSave;
          expect(payload.about, 'hi @alice');
        },
      );
    });

    group('hasUnsavedChanges', () {
      test('is false for clean initial profile fields and media', () {
        const state = ProfileEditorState(
          displayName: 'Liz',
          initialDisplayName: 'Liz',
          about: 'Bio',
          initialAbout: 'Bio',
          website: 'https://divine.video',
          initialWebsite: 'https://divine.video',
          username: 'liz',
          initialUsername: 'Liz',
          externalNip05: 'liz@example.com',
          initialExternalNip05: 'liz@example.com',
          persistedPictureUrl: 'https://cdn.example.com/avatar.jpg',
          persistedBanner: '0x33ccbf',
          pendingBannerColor: Color(0xFF33CCBF),
        );

        expect(state.hasUnsavedChanges, isFalse);
      });

      test('detects dirty text fields', () {
        expect(
          const ProfileEditorState(
            displayName: 'Liz',
            initialDisplayName: 'Dr. Liz',
          ).hasUnsavedChanges,
          isTrue,
        );
        expect(
          const ProfileEditorState(
            about: 'new',
            initialAbout: 'old',
          ).hasUnsavedChanges,
          isTrue,
        );
        expect(
          const ProfileEditorState(
            website: 'https://new.example',
            initialWebsite: 'https://old.example',
          ).hasUnsavedChanges,
          isTrue,
        );
      });

      test('detects dirty identity and staged media fields', () {
        expect(
          const ProfileEditorState(
            username: 'new',
            initialUsername: 'old',
          ).hasUnsavedChanges,
          isTrue,
        );
        expect(
          const ProfileEditorState(
            externalNip05: 'new@example.com',
            initialExternalNip05: 'old@example.com',
          ).hasUnsavedChanges,
          isTrue,
        );
        expect(
          const ProfileEditorState(
            pendingPictureUrl: 'https://cdn.example.com/new.jpg',
            persistedPictureUrl: 'https://cdn.example.com/old.jpg',
          ).hasUnsavedChanges,
          isTrue,
        );
        expect(
          const ProfileEditorState(
            pendingBannerUrl: 'https://cdn.example.com/new.jpg',
            persistedBanner: 'https://cdn.example.com/old.jpg',
          ).hasUnsavedChanges,
          isTrue,
        );
        expect(
          const ProfileEditorState(
            bannerCleared: true,
            persistedBanner: 'https://cdn.example.com/old.jpg',
          ).hasUnsavedChanges,
          isTrue,
        );
      });
    });

    group('InitialUsernameSet', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'stores initial username in state',
        build: createBloc,
        act: (bloc) => bloc.add(const InitialUsernameSet('alice')),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.initialUsername,
            'initialUsername',
            'alice',
          ),
        ],
      );
    });

    group('UsernameChanged', () {
      // Debounce duration used in the BLoC (500ms) + buffer
      const debounceDuration = Duration(milliseconds: 600);

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits idle status when username is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', '')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.idle,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits error status for username too short',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('ab')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'ab')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidLength),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits error status for username too long',
        build: createBloc,
        act: (bloc) => bloc.add(
          UsernameChanged(
            List.filled(kDivineUsernameMaxLength + 1, 'a').join(),
          ),
        ),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.username,
                'username',
                List.filled(kDivineUsernameMaxLength + 1, 'a').join(),
              )
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidLength),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits error status for invalid characters',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('test@user')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'test@user')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.invalidFormat,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidCharacters),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects username with a dot before API (DNS label policy)',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('mr.')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'mr.')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.invalidFormat,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidCharacters),
              ),
        ],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects username with underscore before API (DNS label policy)',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('my_name')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', 'my_name')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.invalidFormat,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.invalidCharacters),
              ),
        ],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'classifies a leading hyphen without relying on error copy',
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged('-alice')),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', '-alice')
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.invalidFormat,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                UsernameValidationError.invalidHyphenPlacement,
              ),
        ],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, available] when username is available',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameAvailable());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.available,
              ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).called(1);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, taken] when username is taken',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameTaken());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.taken,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, reserved] when username is reserved',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameReserved());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.reserved,
              )
              .having(
                (s) => s.reservedUsernames,
                'reservedUsernames',
                contains(testUsername),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, burned] when username is burned',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameBurned());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.burned,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, available] when username is admin-assigned to '
        'current user',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: testPubkey,
            ),
          ).thenAnswer((_) async => const UsernameAvailable());
        },
        build: () => ProfileEditorBloc(
          profileRepository: mockProfileRepository,
          blossomUploadService: mockBlossomUploadService,
          hasExistingProfile: true,
          currentUserPubkey: testPubkey,
        ),
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.available,
              ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: testPubkey,
            ),
          ).called(1);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [checking, error] when check fails',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          ).thenAnswer((_) async => const UsernameCheckError('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UsernameChanged(testUsername)),
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              ),
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.error,
              )
              .having(
                (s) => s.usernameError,
                'usernameError',
                equals(UsernameValidationError.networkError),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'debounces rapid username changes',
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          ).thenAnswer((_) async => const UsernameAvailable());
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const UsernameChanged('test1'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const UsernameChanged('test2'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const UsernameChanged('test3'));
        },
        wait: debounceDuration,
        verify: (_) {
          // Should only call API once for the final username due to restartable transformer
          verify(
            () => mockProfileRepository.checkUsernameAvailability(
              username: 'test3',
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: 'test1',
            ),
          );
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: 'test2',
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'skips API check when username matches initial username',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const InitialUsernameSet(testUsername));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const UsernameChanged(testUsername));
        },
        wait: debounceDuration,
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.initialUsername, 'initialUsername', testUsername)
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.idle,
              ),
        ],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'checks reserved cache before making API call',
        setUp: () {
          // First, trigger a ProfileSaved that returns UsernameClaimReserved
          final existingProfile = createTestProfile(
            nip05: 'original@example.com',
          );
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => existingProfile);
          when(
            () => mockProfileRepository.claimUsername(username: testUsername),
          ).thenAnswer((_) async => const UsernameClaimReserved());
        },
        build: createBloc,
        act: (bloc) async {
          // First save profile with reserved username to populate cache
          bloc.add(
            const ProfileSaved(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              username: testUsername,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
          // Now check username again - should use cache
          bloc.add(const UsernameChanged(testUsername));
        },
        wait: debounceDuration,
        verify: (_) {
          // Should not call checkUsernameAvailability since it's in reserved cache
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
            ),
          );
        },
        expect: () => containsAll([
          isA<ProfileEditorState>()
              .having((s) => s.username, 'username', testUsername)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.reserved,
              ),
        ]),
      );
    });

    group('UsernameRechecked', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits available when nameserver releases reserved username',
        build: createBloc,
        seed: () => const ProfileEditorState(
          username: testUsername,
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: {testUsername},
        ),
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer((_) async => const UsernameAvailable());
        },
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              )
              .having((s) => s.reservedUsernames, 'reservedUsernames', isEmpty),
          isA<ProfileEditorState>().having(
            (s) => s.usernameStatus,
            'usernameStatus',
            UsernameStatus.available,
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits taken when username is now taken by someone else',
        build: createBloc,
        seed: () => const ProfileEditorState(
          username: testUsername,
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: {testUsername},
        ),
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer((_) async => const UsernameTaken());
        },
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.usernameStatus,
            'usernameStatus',
            UsernameStatus.checking,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.usernameStatus,
            'usernameStatus',
            UsernameStatus.taken,
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'restores reserved status on network error',
        build: createBloc,
        seed: () => const ProfileEditorState(
          username: testUsername,
          usernameStatus: UsernameStatus.reserved,
          reservedUsernames: {testUsername},
        ),
        setUp: () {
          when(
            () => mockProfileRepository.checkUsernameAvailability(
              username: testUsername,
              currentUserPubkey: any(named: 'currentUserPubkey'),
            ),
          ).thenAnswer((_) async => const UsernameCheckError('Network error'));
        },
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.checking,
              )
              .having((s) => s.reservedUsernames, 'reservedUsernames', isEmpty),
          isA<ProfileEditorState>()
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.reserved,
              )
              .having(
                (s) => s.reservedUsernames,
                'reservedUsernames',
                contains(testUsername),
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'does nothing when username is empty',
        build: createBloc,
        seed: () =>
            const ProfileEditorState(usernameStatus: UsernameStatus.reserved),
        act: (bloc) => bloc.add(const UsernameRechecked()),
        expect: () => <ProfileEditorState>[],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.checkUsernameAvailability(
              username: any(named: 'username'),
            ),
          );
        },
      );
    });

    group('Nip05ModeChanged', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'switches to external mode and resets username status',
        build: createBloc,
        act: (bloc) => bloc.add(const Nip05ModeChanged(Nip05Mode.external_)),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.nip05Mode, 'nip05Mode', Nip05Mode.external_)
              .having(
                (s) => s.usernameStatus,
                'usernameStatus',
                UsernameStatus.idle,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'switches to divine mode and clears external NIP-05 state',
        build: createBloc,
        seed: () => const ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'alice@example.com',
        ),
        act: (bloc) => bloc.add(const Nip05ModeChanged(Nip05Mode.divine)),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.nip05Mode, 'nip05Mode', Nip05Mode.divine)
              .having((s) => s.externalNip05, 'externalNip05', ''),
        ],
      );
    });

    group('ExternalNip05Changed', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'accepts valid external NIP-05 format',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ExternalNip05Changed('alice@example.com')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.externalNip05,
                'externalNip05',
                'alice@example.com',
              )
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                isNull,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects invalid format without @ symbol',
        build: createBloc,
        act: (bloc) => bloc.add(const ExternalNip05Changed('invalidemail')),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.externalNip05, 'externalNip05', 'invalidemail')
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                ExternalNip05ValidationError.invalidFormat,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'clears error when input is empty',
        build: createBloc,
        seed: () => const ProfileEditorState(
          externalNip05: 'invalid',
          externalNip05Error: ExternalNip05ValidationError.invalidFormat,
        ),
        act: (bloc) => bloc.add(const ExternalNip05Changed('')),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.externalNip05, 'externalNip05', '')
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                isNull,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'normalizes to lowercase',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ExternalNip05Changed('Alice@Example.COM')),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.externalNip05,
            'externalNip05',
            'alice@example.com',
          ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects divine.video domain',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ExternalNip05Changed('_@user.divine.video')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.externalNip05,
                'externalNip05',
                '_@user.divine.video',
              )
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                ExternalNip05ValidationError.divineDomain,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'rejects openvine.co domain',
        build: createBloc,
        act: (bloc) => bloc.add(const ExternalNip05Changed('user@openvine.co')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.externalNip05,
                'externalNip05',
                'user@openvine.co',
              )
              .having(
                (s) => s.externalNip05Error,
                'externalNip05Error',
                ExternalNip05ValidationError.divineDomain,
              ),
        ],
      );
    });

    group('InitialExternalNip05Set', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'stores initial external NIP-05 in state',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const InitialExternalNip05Set('alice@example.com')),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.initialExternalNip05,
            'initialExternalNip05',
            'alice@example.com',
          ),
        ],
      );
    });

    group('ProfileSaved with external NIP-05', () {
      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'emits [loading, success] when saving with external NIP-05',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        seed: () => const ProfileEditorState(nip05Mode: Nip05Mode.external_),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
            picture: testPicture,
            externalNip05: 'alice@example.com',
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.success,
          ),
        ],
        verify: (_) {
          final captured = verify(
            () => mockProfileRepository.enqueuePendingSave(
              captureAny(),
              claimConfirmed: captureAny(named: 'claimConfirmed'),
            ),
          ).captured;
          final payload = captured[0] as PendingProfileSave;
          expect(payload.displayName, testDisplayName);
          expect(payload.about, testAbout);
          expect(payload.nip05, 'alice@example.com');
          expect(payload.picture, testPicture);
          expect(payload.username, isNull);
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'drops username and skips claim when both username and '
        'externalNip05 are sent in external mode',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        seed: () => const ProfileEditorState(nip05Mode: Nip05Mode.external_),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
            picture: testPicture,
            username: testUsername,
            externalNip05: 'alice@example.com',
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.loading,
          ),
          isA<ProfileEditorState>().having(
            (s) => s.status,
            'status',
            ProfileEditorStatus.success,
          ),
        ],
        verify: (_) {
          // Username should be dropped — enqueued payload carries no username.
          final captured = verify(
            () => mockProfileRepository.enqueuePendingSave(
              captureAny(),
              claimConfirmed: captureAny(named: 'claimConfirmed'),
            ),
          ).captured;
          final payload = captured[0] as PendingProfileSave;
          expect(payload.displayName, testDisplayName);
          expect(payload.about, testAbout);
          expect(payload.nip05, 'alice@example.com');
          expect(payload.picture, testPicture);
          expect(payload.username, isNull);
          // No username claim should be attempted
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
        },
      );
    });

    group('isUsernameSaveReady', () {
      test('returns true when username is empty', () {
        const state = ProfileEditorState();
        expect(state.isUsernameSaveReady, isTrue);
      });

      test('returns true when username is available', () {
        const state = ProfileEditorState(
          username: 'newuser',
          usernameStatus: UsernameStatus.available,
        );
        expect(state.isUsernameSaveReady, isTrue);
      });

      test('returns false when checking availability', () {
        const state = ProfileEditorState(
          username: 'newuser',
          usernameStatus: UsernameStatus.checking,
        );
        expect(state.isUsernameSaveReady, isFalse);
      });

      test('returns true when username matches initial (same case)', () {
        const state = ProfileEditorState(
          username: 'alice',
          initialUsername: 'alice',
        );
        expect(state.isUsernameSaveReady, isTrue);
      });

      test('returns true when username matches initial (different case)', () {
        const state = ProfileEditorState(
          username: 'Alice',
          initialUsername: 'alice',
        );
        expect(state.isUsernameSaveReady, isTrue);
      });

      test('returns false when username is taken', () {
        const state = ProfileEditorState(
          username: 'taken',
          usernameStatus: UsernameStatus.taken,
        );
        expect(state.isUsernameSaveReady, isFalse);
      });

      test('returns false when username has validation error', () {
        const state = ProfileEditorState(
          username: 'bad!',
          usernameStatus: UsernameStatus.error,
          usernameError: UsernameValidationError.invalidFormat,
        );
        expect(state.isUsernameSaveReady, isFalse);
      });

      test('returns false when no initial username and status is idle', () {
        const state = ProfileEditorState(username: 'someuser');
        expect(state.isUsernameSaveReady, isFalse);
      });
    });

    group('isExternalNip05SaveReady', () {
      test('returns true when external NIP-05 is empty', () {
        const state = ProfileEditorState(nip05Mode: Nip05Mode.external_);
        expect(state.isExternalNip05SaveReady, isTrue);
      });

      test('returns true when external NIP-05 is valid', () {
        const state = ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'alice@example.com',
        );
        expect(state.isExternalNip05SaveReady, isTrue);
      });

      test('returns false when external NIP-05 has format error', () {
        const state = ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'invalid',
          externalNip05Error: ExternalNip05ValidationError.invalidFormat,
        );
        expect(state.isExternalNip05SaveReady, isFalse);
      });
    });

    group('isSaveReady', () {
      test('delegates to isUsernameSaveReady in divine mode', () {
        const state = ProfileEditorState(
          username: 'alice',
          usernameStatus: UsernameStatus.available,
        );
        expect(state.isSaveReady, isTrue);
      });

      test('delegates to isExternalNip05SaveReady in external mode', () {
        const state = ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'alice@example.com',
        );
        expect(state.isSaveReady, isTrue);
      });

      test('returns false in external mode with invalid NIP-05', () {
        const state = ProfileEditorState(
          nip05Mode: Nip05Mode.external_,
          externalNip05: 'invalid',
          externalNip05Error: ExternalNip05ValidationError.invalidFormat,
        );
        expect(state.isSaveReady, isFalse);
      });

      test('returns false while an avatar upload is in flight', () {
        // Reviewer #3916 bullet: Save must be unavailable during upload so
        // the publish path can't race the staged URL.
        const state = ProfileEditorState(
          username: 'alice',
          usernameStatus: UsernameStatus.available,
          pendingAvatarStatus: PendingAvatarStatus.uploading,
        );
        expect(state.isSaveReady, isFalse);
      });

      test(
        'returns true once the upload settles to staged (otherwise valid)',
        () {
          // Sanity check the gate is purely the uploading status, not
          // "any non-idle pendingAvatarStatus".
          const state = ProfileEditorState(
            username: 'alice',
            usernameStatus: UsernameStatus.available,
            pendingAvatarStatus: PendingAvatarStatus.staged,
            pendingPictureUrl: 'https://media.divine.video/staged-hash',
          );
          expect(state.isSaveReady, isTrue);
        },
      );
    });

    // Reviewer-mandated coverage for option C from PR #3916: avatar uploads
    // stage in bloc state, save is the only publish point, failures preserve
    // the prior preview, no kind-0 churn from upload alone.
    group('profile picture staging', () {
      const testStagedUrl = 'https://media.divine.video/staged-hash';
      const testPersistedUrl = 'https://media.divine.video/persisted-hash';
      final testBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUploadRequested with bytes stages on success',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: testStagedUrl,
              fallbackUrl: testStagedUrl,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.pendingAvatarStatus,
            'pendingAvatarStatus',
            PendingAvatarStatus.uploading,
          ),
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.staged,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              ),
        ],
        verify: (_) {
          verify(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: testBytes,
              filename: 'avatar.jpg',
              nostrPubkey: testPubkey,
            ),
          ).called(1);
          verifyNever(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUploadRequested persists staged URL on success',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: testStagedUrl,
              fallbackUrl: testStagedUrl,
            ),
          );
        },
        build: () {
          final store = _FakeStagedProfileMediaStore();
          addTearDown(() {
            expect(store.values[testPubkey]!.pictureUrl, testStagedUrl);
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
      );

      test('restores staged picture and banner when bloc is recreated', () {
        final store = _FakeStagedProfileMediaStore()
          ..values[testPubkey] = StagedProfileMedia(
            pictureUrl: testStagedUrl,
            bannerUrl: 'https://media.divine.video/staged-banner-hash',
            stagedAt: DateTime.utc(2026, 8, 4),
          );

        final bloc = createBloc(
          stagedProfileMediaStore: store,
          currentUserPubkey: testPubkey,
        );
        addTearDown(bloc.close);

        expect(bloc.state.pendingAvatarStatus, PendingAvatarStatus.staged);
        expect(bloc.state.pendingPictureUrl, testStagedUrl);
        expect(bloc.state.pendingBannerStatus, PendingBannerStatus.staged);
        expect(
          bloc.state.pendingBannerUrl,
          'https://media.divine.video/staged-banner-hash',
        );
        expect(bloc.state.pendingBannerColor, isNull);
      });

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'InitialPersistedBannerSet does not resurrect color over restored banner URL',
        build: () {
          final store = _FakeStagedProfileMediaStore()
            ..values[testPubkey] = StagedProfileMedia(
              bannerUrl: 'https://media.divine.video/staged-banner-hash',
              stagedAt: DateTime.utc(2026, 8, 4),
            );
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        act: (bloc) => bloc.add(const InitialPersistedBannerSet('0x33ccbf')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingBannerUrl,
                'pendingBannerUrl',
                'https://media.divine.video/staged-banner-hash',
              )
              .having((s) => s.pendingBannerColor, 'pendingBannerColor', isNull)
              .having((s) => s.persistedBanner, 'persistedBanner', '0x33ccbf'),
        ],
      );

      test('restores a staged removal when bloc is recreated', () {
        final store = _FakeStagedProfileMediaStore()
          ..values[testPubkey] = StagedProfileMedia(
            pictureCleared: true,
            bannerCleared: true,
            stagedAt: DateTime.utc(2026, 8, 4),
          );

        final bloc = createBloc(
          stagedProfileMediaStore: store,
          currentUserPubkey: testPubkey,
        );
        addTearDown(bloc.close);

        expect(bloc.state.pictureCleared, isTrue);
        expect(bloc.state.bannerCleared, isTrue);
      });

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'seeding the persisted profile does not undo a restored removal',
        build: () {
          final store = _FakeStagedProfileMediaStore()
            ..values[testPubkey] = StagedProfileMedia(
              pictureCleared: true,
              bannerCleared: true,
              stagedAt: DateTime.utc(2026, 8, 4),
            );
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        // What the editor dispatches off its first profile snapshot. It runs
        // unconditionally, so it is the one thing a restored removal has to
        // survive.
        act: (bloc) => bloc
          ..add(const InitialPersistedPictureSet(testPersistedUrl))
          ..add(const InitialPersistedBannerSet('0x33ccbf')),
        verify: (bloc) {
          expect(bloc.state.effectivePictureUrl, isNull);
          expect(bloc.state.effectiveBanner, isNull);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'upload failure leaves pendingPictureUrl untouched and emits failed',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Server error (503): unavailable',
              failureReason: BlossomUploadFailureReason.server,
            ),
          );
        },
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: testStagedUrl,
        ),
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        expect: () => [
          // Optimistic transition to uploading retains the prior staged URL
          // (so the avatar widget can show the previously-staged image while
          // the next attempt is in flight).
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.uploading,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              ),
          // Failure preserves the prior URL — no fake-success preview — and
          // classifies the error so the UI can show the right localized
          // snackbar (server error, in this case).
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.failed,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              )
              .having(
                (s) => s.avatarUploadError,
                'avatarUploadError',
                AvatarUploadError.server,
              ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps network failureReason to AvatarUploadError.network',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Connection timeout',
              failureReason: BlossomUploadFailureReason.network,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        skip: 1, // skip the "uploading" emission, only assert final state
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.network,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps auth failureReason to AvatarUploadError.auth',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Upload rejected: 401 Unauthorized',
              failureReason: BlossomUploadFailureReason.auth,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.auth,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps authUnavailable failureReason to AvatarUploadError.network',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Failed to create Blossom authentication',
              failureReason: BlossomUploadFailureReason.authUnavailable,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.network,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps fileTooLarge failureReason to AvatarUploadError.fileTooLarge',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'Payload too large (413)',
              failureReason: BlossomUploadFailureReason.fileTooLarge,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.fileTooLarge,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'maps unknown failureReason to AvatarUploadError.generic',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: false,
              errorMessage: 'something weird happened',
              failureReason: BlossomUploadFailureReason.unknown,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>().having(
            (s) => s.avatarUploadError,
            'avatarUploadError',
            AvatarUploadError.generic,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'unexpected thrown upload exception falls back to generic',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenThrow(Exception('socket exploded'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        skip: 1,
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.failed,
              )
              .having(
                (s) => s.avatarUploadError,
                'avatarUploadError',
                AvatarUploadError.generic,
              ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUploadCleared resets pending to idle',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: testStagedUrl,
        ),
        act: (bloc) => bloc.add(const ProfilePictureUploadCleared()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.idle,
              )
              .having((s) => s.pendingPictureUrl, 'pendingPictureUrl', isNull),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUploadCleared preserves staged banner in store',
        build: () {
          final store = _FakeStagedProfileMediaStore()
            ..values[testPubkey] = StagedProfileMedia(
              pictureUrl: testStagedUrl,
              bannerUrl: 'https://media.divine.video/staged-banner-hash',
              stagedAt: DateTime.utc(2026, 8, 4),
            );
          addTearDown(() {
            expect(store.values[testPubkey]!.pictureUrl, isNull);
            expect(
              store.values[testPubkey]!.bannerUrl,
              'https://media.divine.video/staged-banner-hash',
            );
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        act: (bloc) => bloc.add(const ProfilePictureUploadCleared()),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.idle,
              )
              .having((s) => s.pendingPictureUrl, 'pendingPictureUrl', isNull),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUrlSet stages without an upload call',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ProfilePictureUrlSet('  $testStagedUrl  ')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingAvatarStatus,
                'pendingAvatarStatus',
                PendingAvatarStatus.staged,
              )
              .having(
                (s) => s.pendingPictureUrl,
                'pendingPictureUrl',
                testStagedUrl,
              ),
        ],
        verify: (_) {
          verifyNever(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
            ),
          );
          verifyNever(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              nostrPubkey: any(named: 'nostrPubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUrlSet persists manual staged URL',
        build: () {
          final store = _FakeStagedProfileMediaStore();
          addTearDown(() {
            expect(store.values[testPubkey]!.pictureUrl, testStagedUrl);
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        act: (bloc) =>
            bloc.add(const ProfilePictureUrlSet('  $testStagedUrl  ')),
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved publishes staged picture from state',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: testStagedUrl,
          persistedPictureUrl: testPersistedUrl,
        ),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
        ),
        verify: (_) {
          final captured = verify(
            () => mockProfileRepository.enqueuePendingSave(
              captureAny(),
              claimConfirmed: captureAny(named: 'claimConfirmed'),
            ),
          ).captured;
          final payload = captured[0] as PendingProfileSave;
          expect(payload.displayName, testDisplayName);
          expect(payload.about, testAbout);
          expect(payload.picture, testStagedUrl);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved clears staged media after durable save is enqueued',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
        },
        build: () {
          final store = _FakeStagedProfileMediaStore()
            ..values[testPubkey] = StagedProfileMedia(
              pictureUrl: testStagedUrl,
              bannerUrl: 'https://media.divine.video/staged-banner-hash',
              stagedAt: DateTime.utc(2026, 8, 4),
            );
          addTearDown(() {
            expect(store.values[testPubkey], isNull);
            expect(store.clearedPubkeys, contains(testPubkey));
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
        ),
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileEditDiscarded clears in-memory and persisted staged media',
        build: () {
          final store = _FakeStagedProfileMediaStore()
            ..values[testPubkey] = StagedProfileMedia(
              pictureUrl: testStagedUrl,
              bannerUrl: 'https://media.divine.video/staged-banner-hash',
              stagedAt: DateTime.utc(2026, 8, 4),
            );
          addTearDown(() {
            expect(store.values[testPubkey], isNull);
            expect(store.clearedPubkeys, contains(testPubkey));
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        seed: () => const ProfileEditorState(
          displayName: 'Edited',
          initialDisplayName: 'Initial',
          about: 'Edited bio',
          initialAbout: 'Initial bio',
          website: 'https://new.example',
          initialWebsite: 'https://old.example',
          username: 'newname',
          initialUsername: 'oldname',
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: testStagedUrl,
          pendingBannerStatus: PendingBannerStatus.staged,
          pendingBannerUrl: 'https://media.divine.video/staged-banner-hash',
          persistedBanner: '0x33ccbf',
        ),
        act: (bloc) => bloc.add(const ProfileEditDiscarded()),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.displayName, 'displayName', 'Initial')
              .having((s) => s.about, 'about', 'Initial bio')
              .having((s) => s.website, 'website', 'https://old.example')
              .having((s) => s.username, 'username', 'oldname')
              .having((s) => s.pendingPictureUrl, 'pendingPictureUrl', isNull)
              .having((s) => s.pendingBannerUrl, 'pendingBannerUrl', isNull)
              .having((s) => s.hasUnsavedChanges, 'hasUnsavedChanges', isFalse),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileEditDiscarded puts a cleared avatar back',
        build: createBloc,
        seed: () => const ProfileEditorState(
          persistedPictureUrl: 'https://cdn.example.com/old-avatar.jpg',
          pictureCleared: true,
        ),
        act: (bloc) => bloc.add(const ProfileEditDiscarded()),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.pictureCleared, 'pictureCleared', isFalse)
              .having(
                (s) => s.effectivePictureUrl,
                'effectivePictureUrl',
                'https://cdn.example.com/old-avatar.jpg',
              )
              .having((s) => s.hasUnsavedChanges, 'hasUnsavedChanges', isFalse),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved with no staged change publishes the persisted picture',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        seed: () =>
            const ProfileEditorState(persistedPictureUrl: testPersistedUrl),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
        ),
        verify: (_) {
          // Picture argument falls back to persisted URL — Save with no edits
          // must not silently blank an existing avatar.
          final captured = verify(
            () => mockProfileRepository.enqueuePendingSave(
              captureAny(),
              claimConfirmed: captureAny(named: 'claimConfirmed'),
            ),
          ).captured;
          final payload = captured[0] as PendingProfileSave;
          expect(payload.picture, testPersistedUrl);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved publishes null banner after explicit banner clear',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        seed: () => const ProfileEditorState(
          persistedBanner: 'https://cdn.example.com/banner.jpg',
          bannerCleared: true,
        ),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
        ),
        verify: (_) {
          final captured = verify(
            () => mockProfileRepository.enqueuePendingSave(
              captureAny(),
              claimConfirmed: captureAny(named: 'claimConfirmed'),
            ),
          ).captured;
          final payload = captured[0] as PendingProfileSave;
          expect(payload.banner, isNull);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved after a clear publishes no picture at all',
        setUp: () {
          when(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        seed: () => const ProfileEditorState(
          persistedPictureUrl: testPersistedUrl,
          pictureCleared: true,
        ),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
            // The legacy caller-supplied fallback must not resurrect it either.
            picture: testPersistedUrl,
          ),
        ),
        verify: (bloc) {
          final captured = verify(
            () => mockProfileRepository.enqueuePendingSave(
              captureAny(),
              claimConfirmed: captureAny(named: 'claimConfirmed'),
            ),
          ).captured;
          final payload = captured[0] as PendingProfileSave;
          expect(payload.picture, isNull);
          // The removal is spent once it is published. Left standing, it keeps
          // vetoing every later persisted-picture seed for the session.
          expect(bloc.state.pictureCleared, isFalse);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileBannerUploadRequested persists staged banner URL',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: 'https://media.divine.video/staged-banner-hash',
              fallbackUrl: 'https://media.divine.video/staged-banner-hash',
            ),
          );
        },
        build: () {
          final store = _FakeStagedProfileMediaStore();
          addTearDown(() {
            expect(store.values[testPubkey]!.pictureUrl, testStagedUrl);
            expect(
              store.values[testPubkey]!.bannerUrl,
              'https://media.divine.video/staged-banner-hash',
            );
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.staged,
          pendingPictureUrl: testStagedUrl,
        ),
        act: (bloc) => bloc.add(
          ProfileBannerUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'banner.jpg',
          ),
        ),
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileBannerColorSelected removes staged banner URL from store',
        build: () {
          final store = _FakeStagedProfileMediaStore()
            ..values[testPubkey] = StagedProfileMedia(
              pictureUrl: testStagedUrl,
              bannerUrl: 'https://media.divine.video/staged-banner-hash',
              stagedAt: DateTime.utc(2026, 8, 4),
            );
          addTearDown(() {
            expect(store.values[testPubkey]!.pictureUrl, testStagedUrl);
            expect(store.values[testPubkey]!.bannerUrl, isNull);
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        act: (bloc) =>
            bloc.add(const ProfileBannerColorSelected(Color(0xFF33CCBF))),
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'upload success alone does not publish kind 0',
        setUp: () {
          when(
            () => mockBlossomUploadService.uploadImageBytes(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
              nostrPubkey: any(named: 'nostrPubkey'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: testStagedUrl,
              fallbackUrl: testStagedUrl,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          ProfilePictureUploadRequested(
            pubkey: testPubkey,
            bytes: testBytes,
            filename: 'avatar.jpg',
          ),
        ),
        verify: (_) {
          // The load-bearing invariant from reviewer bullet 6: upload alone
          // must not call into the profile-publish path.
          verifyNever(
            () => mockProfileRepository.enqueuePendingSave(
              any(),
              claimConfirmed: any(named: 'claimConfirmed'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.drivePendingSave(
              any(),
              expectedGeneration: any(named: 'expectedGeneration'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaved while uploading is dropped — no publish, no claim',
        // Pins the bloc-side guard from reviewer #3916 follow-up: even if the
        // UI gate (`isSaveReady`) is bypassed, the bloc must not enqueue the
        // pending save / claimUsername with a stale `persistedPictureUrl`
        // while the staged URL is still in flight.
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
          persistedPictureUrl: testPersistedUrl,
        ),
        act: (bloc) => bloc.add(
          const ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
        ),
        expect: () => const <ProfileEditorState>[],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.enqueuePendingSave(
              any(),
              claimConfirmed: any(named: 'claimConfirmed'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.drivePendingSave(
              any(),
              expectedGeneration: any(named: 'expectedGeneration'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileNip05Saved while avatar upload is in flight is dropped',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
          persistedPictureUrl: testPersistedUrl,
        ),
        act: (bloc) => bloc.add(
          ProfileNip05Saved(
            currentProfile: UserProfile(
              pubkey: testPubkey,
              displayName: testDisplayName,
              about: testAbout,
              picture: testPicture,
              rawData: const {},
              createdAt: DateTime.now(),
              eventId:
                  'nip05evt-uploading-1234567890123456789012345678901234567890',
            ),
          ),
        ),
        expect: () => const <ProfileEditorState>[],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.enqueuePendingSave(
              any(),
              claimConfirmed: any(named: 'claimConfirmed'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.drivePendingSave(
              any(),
              expectedGeneration: any(named: 'expectedGeneration'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileSaveConfirmed while banner upload is in flight is dropped',
        build: () => createBloc(hasExistingProfile: false),
        seed: () => const ProfileEditorState(
          status: ProfileEditorStatus.confirmationRequired,
          pendingEvent: ProfileSaved(
            pubkey: testPubkey,
            displayName: testDisplayName,
            about: testAbout,
          ),
          pendingBannerStatus: PendingBannerStatus.uploading,
        ),
        act: (bloc) => bloc.add(const ProfileSaveConfirmed()),
        expect: () => const <ProfileEditorState>[],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.enqueuePendingSave(
              any(),
              claimConfirmed: any(named: 'claimConfirmed'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.drivePendingSave(
              any(),
              expectedGeneration: any(named: 'expectedGeneration'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.claimUsername(
              username: any(named: 'username'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileBannerUrlSet stages the trimmed URL and drops a staged color',
        build: createBloc,
        seed: () =>
            const ProfileEditorState(pendingBannerColor: VineTheme.vineGreen),
        act: (bloc) =>
            bloc.add(const ProfileBannerUrlSet('  $testStagedUrl  ')),
        expect: () => [
          isA<ProfileEditorState>()
              .having(
                (s) => s.pendingBannerStatus,
                'pendingBannerStatus',
                PendingBannerStatus.staged,
              )
              .having(
                (s) => s.pendingBannerUrl,
                'pendingBannerUrl',
                testStagedUrl,
              )
              .having(
                (s) => s.pendingBannerColor,
                'pendingBannerColor',
                isNull,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileBannerUrlSet with an empty string clears the staged URL',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingBannerUrl: testStagedUrl,
          pendingBannerStatus: PendingBannerStatus.staged,
        ),
        act: (bloc) => bloc.add(const ProfileBannerUrlSet('   ')),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.pendingBannerUrl, 'pendingBannerUrl', isNull)
              .having(
                (s) => s.pendingBannerStatus,
                'pendingBannerStatus',
                PendingBannerStatus.idle,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileBannerCleared drops a persisted banner, not just the staged one',
        build: createBloc,
        seed: () => const ProfileEditorState(
          persistedBanner: 'https://cdn.example.com/old.jpg',
          pendingBannerUrl: testStagedUrl,
          pendingBannerStatus: PendingBannerStatus.staged,
        ),
        act: (bloc) => bloc.add(const ProfileBannerCleared()),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.bannerCleared, 'bannerCleared', isTrue)
              // What Save publishes — null, not the persisted value.
              .having((s) => s.effectiveBanner, 'effectiveBanner', isNull),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'staging a new banner after a clear cancels the removal',
        build: createBloc,
        seed: () => const ProfileEditorState(
          persistedBanner: 'https://cdn.example.com/old.jpg',
          bannerCleared: true,
        ),
        act: (bloc) => bloc.add(const ProfileBannerUrlSet(testStagedUrl)),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.bannerCleared, 'bannerCleared', isFalse)
              .having(
                (s) => s.effectiveBanner,
                'effectiveBanner',
                testStagedUrl,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureCleared drops a persisted picture, not just the staged '
        'one',
        build: createBloc,
        seed: () => const ProfileEditorState(
          persistedPictureUrl: 'https://cdn.example.com/old-avatar.jpg',
          pendingPictureUrl: 'https://cdn.example.com/staged-avatar.jpg',
          pendingAvatarStatus: PendingAvatarStatus.staged,
        ),
        act: (bloc) => bloc.add(const ProfilePictureCleared()),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.pictureCleared, 'pictureCleared', isTrue)
              // What Save publishes — null, not the persisted value.
              .having(
                (s) => s.effectivePictureUrl,
                'effectivePictureUrl',
                isNull,
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureCleared drops the staged picture from the store',
        build: () {
          final store = _FakeStagedProfileMediaStore()
            ..values[testPubkey] = StagedProfileMedia(
              pictureUrl: testStagedUrl,
              stagedAt: DateTime.utc(2026, 8, 4),
            );
          addTearDown(() {
            // Left behind, `_initialState` restores it on the next editor
            // build and the removed avatar comes back.
            expect(store.values[testPubkey]?.pictureUrl, isNull);
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        seed: () => const ProfileEditorState(
          persistedPictureUrl: 'https://cdn.example.com/old-avatar.jpg',
          pendingPictureUrl: testStagedUrl,
          pendingAvatarStatus: PendingAvatarStatus.staged,
        ),
        act: (bloc) => bloc.add(const ProfilePictureCleared()),
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileBannerUrlSet persists the pasted banner link',
        build: () {
          final store = _FakeStagedProfileMediaStore();
          addTearDown(() {
            expect(store.values[testPubkey]?.bannerUrl, testStagedUrl);
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        act: (bloc) => bloc.add(const ProfileBannerUrlSet(testStagedUrl)),
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureCleared writes the removal through to the store',
        build: () {
          final store = _FakeStagedProfileMediaStore();
          addTearDown(() {
            // Dropping the staged URL is only half of it: without the flag the
            // rebuilt editor seeds the persisted picture back and the removal
            // is forgotten instead of merely un-staged.
            expect(store.values[testPubkey]?.pictureCleared, isTrue);
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        seed: () => const ProfileEditorState(
          persistedPictureUrl: 'https://cdn.example.com/old-avatar.jpg',
        ),
        act: (bloc) => bloc.add(const ProfilePictureCleared()),
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileBannerCleared writes the removal through to the store',
        build: () {
          final store = _FakeStagedProfileMediaStore();
          addTearDown(() {
            expect(store.values[testPubkey]?.bannerCleared, isTrue);
          });
          return createBloc(
            stagedProfileMediaStore: store,
            currentUserPubkey: testPubkey,
          );
        },
        seed: () => const ProfileEditorState(persistedBanner: '0x33ccbf'),
        act: (bloc) => bloc.add(const ProfileBannerCleared()),
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'staging a new picture after a clear cancels the removal',
        build: createBloc,
        seed: () => const ProfileEditorState(
          persistedPictureUrl: 'https://cdn.example.com/old-avatar.jpg',
          pictureCleared: true,
        ),
        act: (bloc) => bloc.add(
          const ProfilePictureUrlSet('https://cdn.example.com/n.jpg'),
        ),
        expect: () => [
          isA<ProfileEditorState>()
              .having((s) => s.pictureCleared, 'pictureCleared', isFalse)
              .having(
                (s) => s.effectivePictureUrl,
                'effectivePictureUrl',
                'https://cdn.example.com/n.jpg',
              ),
        ],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'an empty picture URL after a clear leaves the removal staged',
        build: createBloc,
        seed: () => const ProfileEditorState(
          persistedPictureUrl: 'https://cdn.example.com/old-avatar.jpg',
          pictureCleared: true,
        ),
        // Reachable from the UI: Remove empties the sheet's controller, so
        // re-opening "Paste an image link" and saving hands back an empty
        // string. That stages nothing and must not resurrect the picture.
        act: (bloc) => bloc.add(const ProfilePictureUrlSet('   ')),
        // Nothing changes, so nothing is emitted. Resetting the flag here
        // emitted `pictureCleared: false` and handed the avatar back.
        expect: () => <ProfileEditorState>[],
        verify: (bloc) {
          expect(bloc.state.pictureCleared, isTrue);
          expect(bloc.state.effectivePictureUrl, isNull);
        },
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureCleared while uploading is ignored',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
          persistedPictureUrl: 'https://cdn.example.com/old-avatar.jpg',
        ),
        act: (bloc) => bloc.add(const ProfilePictureCleared()),
        expect: () => <ProfileEditorState>[],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfileBannerUrlSet while uploading is ignored',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingBannerStatus: PendingBannerStatus.uploading,
        ),
        act: (bloc) => bloc.add(const ProfileBannerUrlSet(testStagedUrl)),
        expect: () => const <ProfileEditorState>[],
      );

      blocTest<ProfileEditorBloc, ProfileEditorState>(
        'ProfilePictureUrlSet while uploading is ignored',
        build: createBloc,
        seed: () => const ProfileEditorState(
          pendingAvatarStatus: PendingAvatarStatus.uploading,
          persistedPictureUrl: testPersistedUrl,
        ),
        act: (bloc) => bloc.add(const ProfilePictureUrlSet(testStagedUrl)),
        expect: () => const <ProfileEditorState>[],
      );
    });
  });
}
