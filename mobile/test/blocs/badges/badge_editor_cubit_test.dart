import 'dart:async';
import 'dart:typed_data';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/badge_editor_cubit.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group(BadgeEditorCubit, () {
    late _MockBadgeRepository repository;
    late _MockBlossomUploadService uploadService;

    setUpAll(() {
      registerFallbackValue(
        const BadgeDefinitionDraft(
          identifier: 'x',
          name: 'x',
          imageUrl: _artworkUrl,
        ),
      );
      registerFallbackValue(
        const BadgeCoordinate(pubkey: '', identifier: ''),
      );
      registerFallbackValue(Uint8List(0));
    });

    setUp(() {
      repository = _MockBadgeRepository();
      uploadService = _MockBlossomUploadService();
    });

    BadgeEditorCubit buildCubit({BadgeCoordinate? coordinate}) {
      return BadgeEditorCubit(
        repository: repository,
        uploadService: uploadService,
        pubkey: _pubkey(1),
        coordinate: coordinate,
      );
    }

    test('starts in create mode without a coordinate', () {
      final cubit = buildCubit();

      expect(cubit.state.isEditing, isFalse);
      expect(cubit.state.status, BadgeEditorStatus.initial);
      expect(cubit.state.isValid, isFalse);
    });

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'load opens an empty form when creating',
      setUp: () {
        when(
          repository.loadCreatedIdentifiers,
        ).thenAnswer((_) async => const <String>{});
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      // One state, not two: an empty identifier set leaves the state equal,
      // so the second emit is suppressed.
      expect: () => [
        isA<BadgeEditorState>()
            .having((state) => state.status, 'status', BadgeEditorStatus.ready)
            .having((state) => state.name, 'name', isEmpty),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'refuses an identifier that would replace an existing badge',
      setUp: () {
        when(
          repository.loadCreatedIdentifiers,
        ).thenAnswer((_) async => const {'test'});
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        cubit.nameChanged('Test');
      },
      skip: 2,
      expect: () => [
        isA<BadgeEditorState>()
            .having((state) => state.identifier, 'identifier', 'test')
            .having(
              (state) => state.isIdentifierTaken,
              'isIdentifierTaken',
              isTrue,
            )
            .having((state) => state.isValid, 'isValid', isFalse),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'lets an edit keep its own identifier',
      setUp: () {
        when(() => repository.loadBadgeDetail(any())).thenAnswer(
          (_) async => _detail(
            definition: _definition(
              name: 'Scene Stealer',
              imageUrl: 'https://media.divine.video/scene.png',
            ),
          ),
        );
      },
      build: () => buildCubit(coordinate: _coordinate),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<BadgeEditorState>()
            .having(
              (state) => state.isIdentifierTaken,
              'isIdentifierTaken',
              isFalse,
            )
            .having((state) => state.isValid, 'isValid', isTrue),
      ],
      verify: (_) => verifyNever(repository.loadCreatedIdentifiers),
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'stays usable when the taken-identifier lookup fails',
      setUp: () {
        when(
          repository.loadCreatedIdentifiers,
        ).thenThrow(Exception('relay unavailable'));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        cubit.nameChanged('Test');
      },
      skip: 1,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.isIdentifierTaken,
          'isIdentifierTaken',
          isFalse,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    group('while the taken identifiers load', () {
      late Completer<Set<String>> identifiers;

      setUp(() {
        identifiers = Completer<Set<String>>();
      });

      blocTest<BadgeEditorCubit, BadgeEditorState>(
        'keeps a name typed before the lookup finishes',
        setUp: () {
          when(
            repository.loadCreatedIdentifiers,
          ).thenAnswer((_) => identifiers.future);
        },
        build: buildCubit,
        act: (cubit) async {
          final loading = cubit.load();
          cubit.nameChanged('Test');
          identifiers.complete(const {'other'});
          await loading;
        },
        skip: 2,
        expect: () => [
          isA<BadgeEditorState>()
              .having((state) => state.name, 'name', 'Test')
              .having((state) => state.identifier, 'identifier', 'test')
              .having(
                (state) => state.takenIdentifiers,
                'takenIdentifiers',
                {'other'},
              ),
        ],
      );

      blocTest<BadgeEditorCubit, BadgeEditorState>(
        'drops a lookup that finishes after close',
        setUp: () {
          when(
            repository.loadCreatedIdentifiers,
          ).thenAnswer((_) => identifiers.future);
        },
        build: buildCubit,
        act: (cubit) async {
          final loading = cubit.load();
          await cubit.close();
          identifiers.complete(const {'test'});
          await loading;
        },
        expect: () => [
          isA<BadgeEditorState>().having(
            (state) => state.status,
            'status',
            BadgeEditorStatus.ready,
          ),
        ],
        errors: () => isEmpty,
      );
    });

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'load prefills the form from the existing definition',
      setUp: () {
        when(() => repository.loadBadgeDetail(any())).thenAnswer(
          (_) async => _detail(
            definition: _definition(
              name: 'Scene Stealer',
              description: 'Steals the scroll.',
              imageUrl: 'https://media.divine.video/scene.png',
              thumbnails: const ['https://media.divine.video/thumb.png'],
            ),
          ),
        );
      },
      build: () => buildCubit(coordinate: _coordinate),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.status,
          'status',
          BadgeEditorStatus.loading,
        ),
        isA<BadgeEditorState>()
            .having((state) => state.status, 'status', BadgeEditorStatus.ready)
            .having((state) => state.name, 'name', 'Scene Stealer')
            .having((state) => state.identifier, 'identifier', 'scene-stealer')
            .having(
              (state) => state.description,
              'description',
              'Steals the scroll.',
            )
            .having(
              (state) => state.imageUrl,
              'imageUrl',
              'https://media.divine.video/scene.png',
            )
            .having(
              (state) => state.thumbnailUrl,
              'thumbnailUrl',
              'https://media.divine.video/thumb.png',
            ),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'load fails when the badge has no definition event',
      setUp: () {
        when(
          () => repository.loadBadgeDetail(any()),
        ).thenAnswer((_) async => _detail());
      },
      build: () => buildCubit(coordinate: _coordinate),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.status,
          'status',
          BadgeEditorStatus.loadFailure,
        ),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'load fails when the lookup throws',
      setUp: () {
        when(
          () => repository.loadBadgeDetail(any()),
        ).thenThrow(Exception('relay unavailable'));
      },
      build: () => buildCubit(coordinate: _coordinate),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.status,
          'status',
          BadgeEditorStatus.loadFailure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'nameChanged derives the identifier while creating',
      build: buildCubit,
      act: (cubit) => cubit.nameChanged('Scene Stealer!'),
      expect: () => [
        isA<BadgeEditorState>()
            .having((state) => state.name, 'name', 'Scene Stealer!')
            .having((state) => state.identifier, 'identifier', 'scene-stealer'),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'nameChanged stops deriving once the identifier was typed',
      build: buildCubit,
      act: (cubit) => cubit
        ..identifierChanged('my-own-slug')
        ..nameChanged('Scene Stealer'),
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.identifier,
          'identifier',
          'my-own-slug',
        ),
        isA<BadgeEditorState>()
            .having((state) => state.name, 'name', 'Scene Stealer')
            .having((state) => state.identifier, 'identifier', 'my-own-slug'),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'nameChanged never moves an existing badge identifier',
      setUp: () {
        when(() => repository.loadBadgeDetail(any())).thenAnswer(
          (_) async => _detail(definition: _definition(name: 'Scene Stealer')),
        );
      },
      build: () => buildCubit(coordinate: _coordinate),
      act: (cubit) async {
        await cubit.load();
        cubit.nameChanged('Something Else');
      },
      skip: 2,
      expect: () => [
        isA<BadgeEditorState>()
            .having((state) => state.name, 'name', 'Something Else')
            .having((state) => state.identifier, 'identifier', 'scene-stealer'),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'uploadArtwork stages the uploaded URL',
      setUp: () {
        when(
          () => uploadService.uploadImageBytes(
            bytes: any(named: 'bytes'),
            nostrPubkey: any(named: 'nostrPubkey'),
            filename: any(named: 'filename'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            url: 'https://media.divine.video/badge.jpg',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.uploadArtwork(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'badge.jpg',
        mimeType: 'image/jpeg',
      ),
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.artworkStatus,
          'artworkStatus',
          BadgeArtworkStatus.uploading,
        ),
        isA<BadgeEditorState>()
            .having(
              (state) => state.artworkStatus,
              'artworkStatus',
              BadgeArtworkStatus.idle,
            )
            .having(
              (state) => state.imageUrl,
              'imageUrl',
              'https://media.divine.video/badge.jpg',
            ),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'uploadArtwork drops a carried-over thumbnail',
      setUp: () {
        when(() => repository.loadBadgeDetail(any())).thenAnswer(
          (_) async => _detail(
            definition: _definition(
              name: 'Scene Stealer',
              imageUrl: 'https://media.divine.video/old.png',
              thumbnails: const ['https://media.divine.video/old-thumb.png'],
            ),
          ),
        );
        when(
          () => uploadService.uploadImageBytes(
            bytes: any(named: 'bytes'),
            nostrPubkey: any(named: 'nostrPubkey'),
            filename: any(named: 'filename'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            url: 'https://media.divine.video/new.jpg',
          ),
        );
      },
      build: () => buildCubit(coordinate: _coordinate),
      act: (cubit) async {
        await cubit.load();
        await cubit.uploadArtwork(
          bytes: Uint8List.fromList([1]),
          filename: 'badge.jpg',
          mimeType: 'image/jpeg',
        );
      },
      skip: 3,
      expect: () => [
        isA<BadgeEditorState>()
            .having(
              (state) => state.imageUrl,
              'imageUrl',
              'https://media.divine.video/new.jpg',
            )
            .having((state) => state.thumbnailUrl, 'thumbnailUrl', isEmpty),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'uploadArtwork reports a rejected upload',
      setUp: () {
        when(
          () => uploadService.uploadImageBytes(
            bytes: any(named: 'bytes'),
            nostrPubkey: any(named: 'nostrPubkey'),
            filename: any(named: 'filename'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(success: false),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.uploadArtwork(
        bytes: Uint8List.fromList([1]),
        filename: 'badge.jpg',
        mimeType: 'image/jpeg',
      ),
      skip: 1,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.artworkStatus,
          'artworkStatus',
          BadgeArtworkStatus.failure,
        ),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'uploadArtwork reports a thrown upload',
      setUp: () {
        when(
          () => uploadService.uploadImageBytes(
            bytes: any(named: 'bytes'),
            nostrPubkey: any(named: 'nostrPubkey'),
            filename: any(named: 'filename'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenThrow(Exception('network down'));
      },
      build: buildCubit,
      act: (cubit) => cubit.uploadArtwork(
        bytes: Uint8List.fromList([1]),
        filename: 'badge.jpg',
        mimeType: 'image/jpeg',
      ),
      skip: 1,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.artworkStatus,
          'artworkStatus',
          BadgeArtworkStatus.failure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'uploadArtwork fails fast without a signed-in pubkey',
      build: () => BadgeEditorCubit(
        repository: repository,
        uploadService: uploadService,
        pubkey: null,
      ),
      act: (cubit) => cubit.uploadArtwork(
        bytes: Uint8List.fromList([1]),
        filename: 'badge.jpg',
        mimeType: 'image/jpeg',
      ),
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.artworkStatus,
          'artworkStatus',
          BadgeArtworkStatus.failure,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => uploadService.uploadImageBytes(
            bytes: any(named: 'bytes'),
            nostrPubkey: any(named: 'nostrPubkey'),
          ),
        );
      },
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'artworkCleared drops the staged image',
      setUp: () {
        when(
          () => uploadService.uploadImageBytes(
            bytes: any(named: 'bytes'),
            nostrPubkey: any(named: 'nostrPubkey'),
            filename: any(named: 'filename'),
            mimeType: any(named: 'mimeType'),
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            url: 'https://media.divine.video/badge.jpg',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.uploadArtwork(
          bytes: Uint8List.fromList([1]),
          filename: 'badge.jpg',
          mimeType: 'image/jpeg',
        );
        cubit.artworkCleared();
      },
      skip: 2,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.imageUrl,
          'imageUrl',
          isEmpty,
        ),
      ],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'save publishes the draft and reports the new coordinate',
      setUp: () {
        _stubUpload(uploadService);
        when(() => repository.saveDefinition(any())).thenAnswer(
          (_) async => _definition(name: 'Scene Stealer'),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        cubit
          ..nameChanged('Scene Stealer')
          ..descriptionChanged('Steals the scroll.');
        await cubit.uploadArtwork(
          bytes: Uint8List.fromList([1]),
          filename: 'badge.jpg',
          mimeType: 'image/jpeg',
        );
        await cubit.save();
      },
      skip: 4,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.status,
          'status',
          BadgeEditorStatus.saving,
        ),
        isA<BadgeEditorState>()
            .having((state) => state.status, 'status', BadgeEditorStatus.saved)
            .having(
              (state) => state.savedCoordinate,
              'savedCoordinate',
              _coordinate,
            ),
      ],
      verify: (_) {
        final draft =
            verify(
                  () => repository.saveDefinition(captureAny()),
                ).captured.single
                as BadgeDefinitionDraft;
        expect(draft.identifier, 'scene-stealer');
        expect(draft.name, 'Scene Stealer');
        expect(draft.description, 'Steals the scroll.');
        expect(draft.imageUrl, _artworkUrl);
      },
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'save reports a publish failure',
      setUp: () {
        _stubUpload(uploadService);
        when(
          () => repository.saveDefinition(any()),
        ).thenThrow(Exception('no relay accepted'));
      },
      build: buildCubit,
      act: (cubit) async {
        cubit.nameChanged('Scene Stealer');
        await cubit.uploadArtwork(
          bytes: Uint8List.fromList([1]),
          filename: 'badge.jpg',
          mimeType: 'image/jpeg',
        );
        await cubit.save();
      },
      skip: 4,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.status,
          'status',
          BadgeEditorStatus.saveFailure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'save on an empty form records the attempt without publishing',
      build: buildCubit,
      act: (cubit) => cubit.save(),
      expect: () => [
        isA<BadgeEditorState>()
            .having(
              (state) => state.submitAttempted,
              'submitAttempted',
              isTrue,
            )
            .having(
              (state) => state.status,
              'status',
              isNot(BadgeEditorStatus.saving),
            ),
      ],
      verify: (_) => verifyNever(() => repository.saveDefinition(any())),
    );

    blocTest<BadgeEditorCubit, BadgeEditorState>(
      'save refuses a named badge that still has no artwork',
      build: buildCubit,
      act: (cubit) async {
        cubit.nameChanged('Scene Stealer');
        await cubit.save();
      },
      skip: 1,
      expect: () => [
        isA<BadgeEditorState>().having(
          (state) => state.showArtworkRequired,
          'showArtworkRequired',
          isTrue,
        ),
      ],
      verify: (_) => verifyNever(() => repository.saveDefinition(any())),
    );

    test('the missing-artwork message stays hidden until Publish', () {
      final cubit = buildCubit()..nameChanged('Scene Stealer');

      expect(cubit.state.isValid, isFalse);
      expect(cubit.state.hasRequiredText, isTrue);
      expect(cubit.state.showArtworkRequired, isFalse);
    });
  });
}

const _artworkUrl = 'https://media.divine.video/badge.jpg';

void _stubUpload(_MockBlossomUploadService uploadService) {
  when(
    () => uploadService.uploadImageBytes(
      bytes: any(named: 'bytes'),
      nostrPubkey: any(named: 'nostrPubkey'),
      filename: any(named: 'filename'),
      mimeType: any(named: 'mimeType'),
    ),
  ).thenAnswer(
    (_) async => const BlossomUploadResult(success: true, url: _artworkUrl),
  );
}

const _coordinate = BadgeCoordinate(
  pubkey: '0000000000000000000000000000000000000000000000000000000000000065',
  identifier: 'scene-stealer',
);

BadgeDetailData _detail({Nip58BadgeDefinition? definition}) {
  return BadgeDetailData(
    coordinate: _coordinate,
    definition: definition,
    recipients: const [],
    isOwner: true,
  );
}

Nip58BadgeDefinition _definition({
  required String name,
  String? description,
  String? imageUrl,
  List<String> thumbnails = const [],
}) {
  return Nip58BadgeDefinition(
    event: Event.fromJson({
      'id': '0'.padLeft(64, '0'),
      'pubkey': _pubkey(1),
      'created_at': 1000,
      'kind': EventKind.badgeDefinition,
      'tags': <List<String>>[],
      'content': '',
      'sig': '',
    }),
    coordinate: _coordinate.value,
    dTag: _coordinate.identifier,
    name: name,
    description: description,
    imageUrl: imageUrl,
    thumbnails: thumbnails,
  );
}

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');
