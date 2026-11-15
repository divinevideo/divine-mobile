// ABOUTME: Tests the account-wide remix setting: strict kind 0 load, the
// ABOUTME: optimistic toggle publish, and revert-on-failure behaviour.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/remix_settings/remix_settings_cubit.dart';
import 'package:openvine/blocs/remix_settings/remix_settings_state.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

UserProfile _profile({
  bool? allowVideoReuse,
  String pubkey = _pubkey,
  String displayName = 'Creator',
  String about = 'bio',
  DateTime? createdAt,
  String? eventId,
}) => UserProfile(
  pubkey: pubkey,
  displayName: displayName,
  about: about,
  website: 'https://creator.example',
  picture: 'https://cdn.example/p.png',
  banner: '#112233',
  rawData: {
    'display_name': displayName,
    'about': about,
    'custom_field': 'kept',
    divineAllowVideoReuseKey: ?allowVideoReuse,
  },
  createdAt: createdAt ?? DateTime(2026),
  eventId: eventId ?? 'a' * 64,
);

void main() {
  group(RemixSettingsCubit, () {
    late _MockProfileRepository repository;
    late List<UserProfile> savedProfiles;

    RemixSettingsCubit buildCubit({
      bool withRepository = true,
      String? pubkey = _pubkey,
    }) => RemixSettingsCubit(
      repository: withRepository ? repository : null,
      pubkey: pubkey,
      onProfileSaved: savedProfiles.add,
    );

    void stubReadResult(Future<FreshProfileRead> Function() answer) {
      when(
        () => repository.readFreshProfile(
          pubkey: _pubkey,
          requireRawKind0: true,
        ),
      ).thenAnswer((_) => answer());
    }

    void stubRead(Future<UserProfile?> Function() answer) => stubReadResult(
      () async => (profile: await answer(), conclusive: true),
    );

    /// Answers successive reads in order: the load first, then each save.
    void stubReads(List<FreshProfileRead> reads) {
      final pending = [...reads];
      stubReadResult(() async => pending.removeAt(0));
    }

    void stubCached(UserProfile? profile) {
      when(
        () => repository.getCachedProfile(pubkey: _pubkey),
      ).thenAnswer((_) async => profile);
    }

    void stubSave(Future<UserProfile> Function(bool? allow) answer) {
      when(
        () => repository.saveProfileEvent(
          displayName: any(named: 'displayName'),
          about: any(named: 'about'),
          website: any(named: 'website'),
          picture: any(named: 'picture'),
          banner: any(named: 'banner'),
          allowVideoReuse: any(named: 'allowVideoReuse'),
          currentProfile: any(named: 'currentProfile'),
        ),
      ).thenAnswer(
        (invocation) =>
            answer(invocation.namedArguments[#allowVideoReuse] as bool?),
      );
    }

    setUpAll(() {
      registerFallbackValue(_profile());
    });

    setUp(() {
      repository = _MockProfileRepository();
      savedProfiles = [];
    });

    group('load', () {
      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'reads the strict raw kind 0 and reflects a blocked account',
        setUp: () => stubRead(() async => _profile(allowVideoReuse: false)),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.loading),
          const RemixSettingsState(
            loadStatus: RemixSettingsLoadStatus.ready,
            allowVideoReuse: false,
          ),
        ],
        verify: (_) => verify(
          () => repository.readFreshProfile(
            pubkey: _pubkey,
            requireRawKind0: true,
          ),
        ).called(1),
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'allows remixing when the key is absent',
        setUp: () => stubRead(() async => _profile()),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.loading),
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.ready),
        ],
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'loads as allowed and editable when the account has no kind 0',
        setUp: () =>
            stubReadResult(() async => (profile: null, conclusive: true)),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.loading),
          isA<RemixSettingsState>()
              .having(
                (s) => s.loadStatus,
                'loadStatus',
                RemixSettingsLoadStatus.ready,
              )
              .having((s) => s.allowVideoReuse, 'allowVideoReuse', isTrue)
              .having((s) => s.canEdit, 'canEdit', isTrue),
        ],
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'fails when the kind 0 read is inconclusive',
        setUp: () =>
            stubReadResult(() async => (profile: null, conclusive: false)),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.loading),
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.failure),
        ],
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'fails when the profile belongs to another account',
        setUp: () => stubRead(() async => _profile(pubkey: 'b' * 64)),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.loading),
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.failure),
        ],
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'fails and reports when the read throws',
        setUp: () => stubRead(() async => throw Exception('offline')),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        errors: () => [isA<Exception>()],
        expect: () => [
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.loading),
          const RemixSettingsState(loadStatus: RemixSettingsLoadStatus.failure),
        ],
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'fails, reports and can retry when the read throws an Error',
        setUp: () {
          var reads = 0;
          stubReadResult(() async {
            if (reads++ == 0) throw StateError('broken read');
            return (
              profile: _profile(allowVideoReuse: false),
              conclusive: true,
            );
          });
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.load();
        },
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
        expect: () => const [
          RemixSettingsState(loadStatus: RemixSettingsLoadStatus.loading),
          RemixSettingsState(loadStatus: RemixSettingsLoadStatus.failure),
          RemixSettingsState(loadStatus: RemixSettingsLoadStatus.loading),
          RemixSettingsState(
            loadStatus: RemixSettingsLoadStatus.ready,
            allowVideoReuse: false,
          ),
        ],
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'does nothing without a repository or signed-in account',
        build: () => buildCubit(withRepository: false),
        act: (cubit) => cubit.load(),
        expect: () => const <RemixSettingsState>[],
      );
    });

    group('setAllowVideoReuse', () {
      setUp(() => stubRead(() async => _profile()));

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'publishes the block over the current profile',
        setUp: () =>
            stubSave((allow) async => _profile(allowVideoReuse: allow)),
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.setAllowVideoReuse(false);
        },
        skip: 2,
        expect: () => const [
          RemixSettingsState(
            loadStatus: RemixSettingsLoadStatus.ready,
            allowVideoReuse: false,
            saveStatus: RemixSettingsSaveStatus.saving,
          ),
          RemixSettingsState(
            loadStatus: RemixSettingsLoadStatus.ready,
            allowVideoReuse: false,
          ),
        ],
        verify: (_) {
          verify(
            () => repository.saveProfileEvent(
              displayName: 'Creator',
              about: 'bio',
              website: 'https://creator.example',
              picture: 'https://cdn.example/p.png',
              banner: '#112233',
              allowVideoReuse: false,
              currentProfile: _profile(),
            ),
          ).called(1);
          expect(savedProfiles, [_profile(allowVideoReuse: false)]);
        },
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'publishes the fields of an edit made elsewhere since the load',
        setUp: () {
          final edited = _profile(
            displayName: 'Renamed',
            about: 'new bio',
            createdAt: DateTime(2026, 2),
            eventId: 'b' * 64,
          );
          stubReads([
            (profile: _profile(), conclusive: true),
            (profile: edited, conclusive: true),
          ]);
          stubSave((allow) async => _profile(allowVideoReuse: allow));
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.setAllowVideoReuse(false);
        },
        verify: (_) => verify(
          () => repository.saveProfileEvent(
            displayName: 'Renamed',
            about: 'new bio',
            website: 'https://creator.example',
            picture: 'https://cdn.example/p.png',
            banner: '#112233',
            allowVideoReuse: false,
            currentProfile: _profile(
              displayName: 'Renamed',
              about: 'new bio',
              createdAt: DateTime(2026, 2),
              eventId: 'b' * 64,
            ),
          ),
        ).called(1),
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'publishes a first kind 0 when the account has none',
        setUp: () {
          stubReadResult(() async => (profile: null, conclusive: true));
          stubCached(null);
          stubSave((allow) async => _profile(allowVideoReuse: allow));
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.setAllowVideoReuse(false);
        },
        skip: 3,
        expect: () => const [
          RemixSettingsState(
            loadStatus: RemixSettingsLoadStatus.ready,
            allowVideoReuse: false,
          ),
        ],
        verify: (_) => verify(
          () => repository.saveProfileEvent(
            displayName: '',
            allowVideoReuse: false,
          ),
        ).called(1),
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'seeds a first kind 0 from the cached profile, not empty fields',
        setUp: () {
          stubReadResult(() async => (profile: null, conclusive: true));
          stubCached(_profile());
          stubSave((allow) async => _profile(allowVideoReuse: allow));
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.setAllowVideoReuse(false);
        },
        verify: (_) => verify(
          () => repository.saveProfileEvent(
            displayName: 'Creator',
            about: 'bio',
            website: 'https://creator.example',
            picture: 'https://cdn.example/p.png',
            banner: '#112233',
            allowVideoReuse: false,
            currentProfile: _profile(),
          ),
        ).called(1),
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'refuses the save and reverts when the re-read is inconclusive',
        setUp: () {
          stubReads([
            (profile: _profile(), conclusive: true),
            (profile: null, conclusive: false),
          ]);
          stubSave((allow) async => _profile(allowVideoReuse: allow));
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.setAllowVideoReuse(false);
        },
        skip: 3,
        errors: () => [isA<ProfilePublishFailedException>()],
        expect: () => const [
          RemixSettingsState(
            loadStatus: RemixSettingsLoadStatus.ready,
            saveStatus: RemixSettingsSaveStatus.failedPublish,
          ),
        ],
        verify: (_) {
          verifyNever(
            () => repository.saveProfileEvent(
              displayName: any(named: 'displayName'),
              about: any(named: 'about'),
              website: any(named: 'website'),
              picture: any(named: 'picture'),
              banner: any(named: 'banner'),
              allowVideoReuse: any(named: 'allowVideoReuse'),
              currentProfile: any(named: 'currentProfile'),
            ),
          );
          expect(savedProfiles, isEmpty);
        },
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'reverts the switch when the publish is rejected',
        setUp: () => stubSave(
          (_) async => throw const ProfilePublishFailedException('rejected'),
        ),
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.setAllowVideoReuse(false);
        },
        skip: 3,
        errors: () => [isA<ProfilePublishFailedException>()],
        expect: () => const [
          RemixSettingsState(
            loadStatus: RemixSettingsLoadStatus.ready,
            saveStatus: RemixSettingsSaveStatus.failedPublish,
          ),
        ],
        verify: (_) => expect(savedProfiles, isEmpty),
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'names the network when no relays are connected',
        setUp: () => stubSave(
          (_) async => throw const NoRelaysConnectedException('offline'),
        ),
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.setAllowVideoReuse(false);
        },
        skip: 3,
        errors: () => [isA<NoRelaysConnectedException>()],
        expect: () => const [
          RemixSettingsState(
            loadStatus: RemixSettingsLoadStatus.ready,
            saveStatus: RemixSettingsSaveStatus.failedNoRelays,
          ),
        ],
      );

      blocTest<RemixSettingsCubit, RemixSettingsState>(
        'ignores a flip before the stored answer is known',
        build: buildCubit,
        act: (cubit) => cubit.setAllowVideoReuse(false),
        expect: () => const <RemixSettingsState>[],
        verify: (_) => verifyNever(
          () => repository.saveProfileEvent(
            displayName: any(named: 'displayName'),
            allowVideoReuse: any(named: 'allowVideoReuse'),
            currentProfile: any(named: 'currentProfile'),
          ),
        ),
      );

      test('drops a late publish result after close', () async {
        final publish = Completer<UserProfile>();
        stubSave((_) => publish.future);
        final cubit = buildCubit();
        await cubit.load();

        final pending = cubit.setAllowVideoReuse(false);
        expect(cubit.state.saveStatus, RemixSettingsSaveStatus.saving);
        await cubit.close();
        publish.complete(_profile(allowVideoReuse: false));
        await pending;

        expect(cubit.state.saveStatus, RemixSettingsSaveStatus.saving);
        expect(savedProfiles, isEmpty);
      });
    });
  });
}
