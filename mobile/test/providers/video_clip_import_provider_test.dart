// ABOUTME: Tests the wiring that decides whether a received clip's post is a
// ABOUTME: verified archived Vine, from those events' REST rows.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/video_clip_import_provider.dart';
import 'package:openvine/services/published_clip_source_resolver.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

const _verifiedId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _notVerifiedId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _uncheckedId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _missingId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

VideoStats _row(
  String id, {
  required bool verifiedArchive,
  bool provenanceAvailable = true,
}) => VideoStats.fromJson({
  'id': id,
  'pubkey': 'e' * 64,
  'created_at': 1458771798,
  'kind': 34236,
  'd_tag': id,
  'verified_archive': verifiedArchive,
  'archive_provenance_available': provenanceAvailable,
});

void main() {
  group('archiveVerdictsLookup', () {
    late _MockVideosRepository repository;

    setUp(() => repository = _MockVideosRepository());

    test('gives each row its verdict in one lookup', () async {
      when(() => repository.getVideoStatsByIds(any())).thenAnswer(
        (_) async => {
          _verifiedId: _row(_verifiedId, verifiedArchive: true),
          _notVerifiedId: _row(_notVerifiedId, verifiedArchive: false),
          _uncheckedId: _row(
            _uncheckedId,
            verifiedArchive: false,
            provenanceAvailable: false,
          ),
        },
      );

      final verdicts = await archiveVerdictsLookup(repository)(const [
        _verifiedId,
        _notVerifiedId,
        _uncheckedId,
        _missingId,
      ]);

      expect(verdicts, {
        _verifiedId: ArchiveVerdict.verified,
        _notVerifiedId: ArchiveVerdict.notVerified,
        _uncheckedId: ArchiveVerdict.unchecked,
      });
      verify(
        () => repository.getVideoStatsByIds(const [
          _verifiedId,
          _notVerifiedId,
          _uncheckedId,
          _missingId,
        ]),
      ).called(1);
    });

    test('has no verdicts when the API is not configured', () async {
      when(
        () => repository.getVideoStatsByIds(any()),
      ).thenAnswer((_) async => null);

      expect(
        await archiveVerdictsLookup(repository)(const [_verifiedId]),
        isEmpty,
      );
    });

    test('lets a failed request through to the caller', () async {
      final failure = Exception('the API did not answer');
      when(() => repository.getVideoStatsByIds(any())).thenThrow(failure);

      await expectLater(
        archiveVerdictsLookup(repository)(const [_verifiedId]),
        throwsA(same(failure)),
      );
    });
  });
}
