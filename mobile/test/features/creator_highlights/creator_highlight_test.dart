import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_highlights/creator_highlight.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final _video = VideoEvent(
  id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  pubkey: _owner,
  createdAt: 1793304000,
  timestamp: DateTime.utc(2026, 10, 30),
  content: '',
);

CreatorHighlight _highlight({
  int createdToday = 0,
  int? views,
  int? topVideoViews,
  int? likes,
  int? comments,
  int rotation = 0,
}) => CreatorHighlight(
  owner: _owner,
  localDate: '2026-10-30',
  createdToday: createdToday,
  creationDaysThisWeek: 3,
  views: views,
  topVideo: topVideoViews == null ? null : _video,
  topVideoViews: topVideoViews,
  likes: likes,
  comments: comments,
  celebrate: false,
  rotation: rotation,
);

void main() {
  group(CreatorHighlight, () {
    group('spotlights', () {
      test('offers only facts that are known and worth celebrating', () {
        expect(_highlight(views: 0, likes: 0, comments: 0).spotlights, [
          CreatorSpotlight.creativeDays,
        ]);
      });

      test('skips a weekly total that only repeats the top video', () {
        expect(_highlight(views: 12, topVideoViews: 12).spotlights, [
          CreatorSpotlight.topVideo,
          CreatorSpotlight.creativeDays,
        ]);
        expect(_highlight(views: 15, topVideoViews: 12).spotlights, [
          CreatorSpotlight.topVideo,
          CreatorSpotlight.weeklyViews,
          CreatorSpotlight.creativeDays,
        ]);
      });
    });

    group('spotlight', () {
      test('each rotation step leads with a different fact, then wraps', () {
        final shown = [
          for (var rotation = 0; rotation < 5; rotation++)
            _highlight(
              createdToday: 1,
              likes: 4,
              comments: 2,
              rotation: rotation,
            ).spotlight,
        ];
        expect(shown, [
          CreatorSpotlight.createdToday,
          CreatorSpotlight.weeklyLikes,
          CreatorSpotlight.weeklyComments,
          CreatorSpotlight.creativeDays,
          CreatorSpotlight.createdToday,
        ]);
      });
    });
  });
}
