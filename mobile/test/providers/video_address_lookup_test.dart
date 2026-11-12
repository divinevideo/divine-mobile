// ABOUTME: Tests lookUpVideoAddresses: event ids of video versions map to the
// ABOUTME: coordinate of the video each is a version of, and nothing else.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/video_address_lookup.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

// Full-length 64-char ids — never truncate.
final String _author = '4' * 64;
final String _addressableId = '1' * 64;
final String _regularId = '2' * 64;
final String _missingId = '3' * 64;

VideoEvent _video(String id, {required int kind, String? dTag}) =>
    VideoEvent.fromNostrEvent(
      Event(_author, kind, [
        if (dTag != null) ['d', dTag],
        ['url', 'https://media.example/$id.mp4'],
      ], ''),
      permissive: true,
    ).copyWith(id: id);

void main() {
  group('lookUpVideoAddresses', () {
    late _MockVideosRepository videosRepository;

    setUp(() => videosRepository = _MockVideosRepository());

    test('maps each found addressable version to its coordinate, leaving out '
        'regular and missing videos', () async {
      when(
        () => videosRepository.getVideosByIds(
          [_addressableId, _regularId, _missingId],
          hydrateBulkStats: false,
          includeFeedShape: false,
        ),
      ).thenAnswer(
        (_) async => [
          _video(_addressableId, kind: 34236, dTag: 'clip'),
          _video(_regularId, kind: 22),
        ],
      );

      final addresses = await lookUpVideoAddresses(videosRepository, [
        _addressableId,
        _regularId,
        _missingId,
      ]);

      expect(addresses, {_addressableId: '34236:$_author:clip'});
    });
  });
}
