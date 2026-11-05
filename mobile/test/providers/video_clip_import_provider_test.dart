// ABOUTME: Tests the wiring that decides whether a received clip's post is a
// ABOUTME: verified archived Vine, from that event's REST stats row.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/video_clip_import_provider.dart';
import 'package:openvine/services/published_clip_source_resolver.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

const _eventId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

VideoStats _row({
  required bool verifiedArchive,
  bool provenanceAvailable = true,
}) => VideoStats.fromJson({
  'id': _eventId,
  'pubkey': 'a' * 64,
  'created_at': 1458771798,
  'kind': 34236,
  'd_tag': 'vine-id',
  'verified_archive': verifiedArchive,
  'archive_provenance_available': provenanceAvailable,
});

void main() {
  group('verifiedArchiveLookup', () {
    late _MockVideosRepository repository;

    setUp(() => repository = _MockVideosRepository());

    test('is true when the event row is verified', () async {
      when(
        () => repository.getVideoStats(_eventId),
      ).thenAnswer((_) async => _row(verifiedArchive: true));

      expect(await verifiedArchiveLookup(repository)(_eventId), isTrue);
    });

    test('is false when the event row is not verified', () async {
      when(
        () => repository.getVideoStats(_eventId),
      ).thenAnswer((_) async => _row(verifiedArchive: false));

      expect(await verifiedArchiveLookup(repository)(_eventId), isFalse);
    });

    test('throws when the server could not check its archive', () async {
      when(() => repository.getVideoStats(_eventId)).thenAnswer(
        (_) async => _row(verifiedArchive: false, provenanceAvailable: false),
      );

      await expectLater(
        verifiedArchiveLookup(repository)(_eventId),
        throwsA(isA<ArchiveVerificationUnavailableException>()),
      );
    });

    test('is false when the server has no row for the event', () async {
      when(
        () => repository.getVideoStats(_eventId),
      ).thenAnswer((_) async => null);

      expect(await verifiedArchiveLookup(repository)(_eventId), isFalse);
    });

    test('lets a failed request through to the caller', () async {
      final failure = Exception('the API did not answer');
      when(() => repository.getVideoStats(_eventId)).thenThrow(failure);

      await expectLater(
        verifiedArchiveLookup(repository)(_eventId),
        throwsA(same(failure)),
      );
    });
  });
}
