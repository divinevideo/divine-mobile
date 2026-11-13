import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

const _authorPubkey =
    'aabbccddaabbccddaabbccddaabbccdd'
    'aabbccddaabbccddaabbccddaabbccdd';
const _eventId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _editedEventId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _otherEventId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _address = '34236:$_authorPubkey:clip';
const _otherAddress = '34236:$_authorPubkey:other-clip';

CuratedList _listWith(List<String> items) => CuratedList(
  id: 'list',
  name: 'List',
  videoEventIds: items,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group(CuratedListVideo, () {
    group('reference', () {
      test('is the coordinate of an addressable video', () {
        // Built at runtime so coverage instruments the const constructor.
        // ignore: prefer_const_constructors
        final video = CuratedListVideo(eventId: _eventId, address: _address);

        expect(video.reference, equals(_address));
      });

      test('is the event id of a video without a coordinate', () {
        const video = CuratedListVideo(eventId: _eventId);

        expect(video.reference, equals(_eventId));
      });
    });

    group('referencesIn', () {
      test('finds an item naming the version by its event id', () {
        const video = CuratedListVideo(eventId: _eventId, address: _address);

        expect(
          video.referencesIn(_listWith([_otherEventId, _eventId])),
          equals([_eventId]),
        );
      });

      test('finds an item naming an edited version by its coordinate', () {
        const video = CuratedListVideo(
          eventId: _editedEventId,
          address: _address,
        );

        expect(
          video.referencesIn(_listWith([_address, _otherAddress])),
          equals([_address]),
        );
      });

      test('finds both names, in list order', () {
        const video = CuratedListVideo(eventId: _eventId, address: _address);

        expect(
          video.referencesIn(_listWith([_address, _otherEventId, _eventId])),
          equals([_address, _eventId]),
        );
      });

      // Until #10776 Divine wrote a Kind 34235 video's coordinate under kind
      // 34236, and lists saved then still hold that alias.
      test('finds the 34236 alias of a Kind 34235 video', () {
        const horizontal = '34235:$_authorPubkey:wide';
        const alias = '34236:$_authorPubkey:wide';
        const video = CuratedListVideo(
          eventId: _editedEventId,
          address: horizontal,
        );

        expect(video.referencesIn(_listWith([alias])), equals([alias]));
        expect(video.isIn(_listWith([alias])), isTrue);
      });

      // Removing an item drops every copy of it, so a second name for the
      // same item would only publish the list again.
      test('names an item the list holds twice once', () {
        const video = CuratedListVideo(eventId: _eventId, address: _address);

        expect(
          video.referencesIn(_listWith([_address, _eventId, _address])),
          equals([_address, _eventId]),
        );
      });

      test('finds nothing in a list that holds other videos', () {
        const video = CuratedListVideo(eventId: _eventId, address: _address);

        expect(
          video.referencesIn(_listWith([_otherEventId, _otherAddress])),
          isEmpty,
        );
      });
    });

    // An item saved before #7135 names the version it saw by event id; once a
    // lookup reports that version's coordinate, it names the same video.
    group('with the addresses of older versions', () {
      const olderEventId =
          '4444444444444444444444444444444444444444444444444444444444444444';
      const video = CuratedListVideo(
        eventId: _editedEventId,
        address: _address,
      );

      test('finds an older version by its event id', () {
        final list = _listWith([_otherEventId, olderEventId]);
        const addresses = {olderEventId: _address};

        expect(
          video.referencesIn(list, addressByEventId: addresses),
          equals([olderEventId]),
        );
        expect(video.isIn(list, addressByEventId: addresses), isTrue);
      });

      test('finds an older version reported under the 34236 alias', () {
        const horizontal = '34235:$_authorPubkey:wide';
        const alias = '34236:$_authorPubkey:wide';
        const wide = CuratedListVideo(
          eventId: _editedEventId,
          address: horizontal,
        );

        expect(
          wide.referencesIn(
            _listWith([olderEventId]),
            addressByEventId: const {olderEventId: alias},
          ),
          equals([olderEventId]),
        );
      });

      test('does not take an event id mapped to another video', () {
        expect(
          video.isIn(
            _listWith([olderEventId]),
            addressByEventId: const {olderEventId: _otherAddress},
          ),
          isFalse,
        );
      });

      test('knows no older version unless told', () {
        expect(video.isIn(_listWith([olderEventId])), isFalse);
      });

      test('does not apply to a video without a coordinate', () {
        const plain = CuratedListVideo(eventId: _editedEventId);

        expect(
          plain.isIn(
            _listWith([olderEventId]),
            addressByEventId: const {olderEventId: _address},
          ),
          isFalse,
        );
      });
    });

    group('eventIdItemsOf', () {
      test('lists each event-id item once, in list order, except the '
          'given ones', () {
        final lists = [
          _listWith([_address, _eventId, _otherEventId]),
          _listWith([_otherEventId, _editedEventId, _otherAddress]),
        ];

        expect(
          CuratedListVideo.eventIdItemsOf(lists, except: const {_eventId}),
          equals([_otherEventId, _editedEventId]),
        );
      });

      test('lists every event-id item when nothing is excepted', () {
        expect(
          CuratedListVideo.eventIdItemsOf([
            _listWith([_eventId, _address]),
          ]),
          equals([_eventId]),
        );
      });

      // One id a relay cannot parse closes the whole `ids` lookup, so another
      // client's malformed item would hide every older version on the list.
      test('leaves out items that are not 64-character lowercase hex', () {
        expect(
          CuratedListVideo.eventIdItemsOf([
            _listWith([
              'not-an-event-id',
              'A' * 64,
              'a' * 63,
              'a' * 65,
              _otherEventId,
            ]),
          ]),
          equals([_otherEventId]),
        );
      });
    });

    group('isIn', () {
      test('is true for a list holding the video by its coordinate', () {
        const video = CuratedListVideo(
          eventId: _editedEventId,
          address: _address,
        );

        expect(video.isIn(_listWith([_address])), isTrue);
      });

      test('is true for a list holding the video by its event id', () {
        const video = CuratedListVideo(eventId: _eventId);

        expect(video.isIn(_listWith([_eventId])), isTrue);
      });

      test('is false for a list holding neither name', () {
        const video = CuratedListVideo(eventId: _eventId, address: _address);

        expect(video.isIn(_listWith([_otherEventId])), isFalse);
      });
    });
  });
}
