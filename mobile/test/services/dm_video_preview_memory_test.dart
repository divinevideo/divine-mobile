// ABOUTME: Tests for DmVideoPreviewMemory: which video DMs were played this
// ABOUTME: session, and the blurhash read once from each kept frame.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/dm_video_preview_memory.dart';

void main() {
  group(DmVideoPreviewMemory, () {
    final first = 'a' * 64;
    final second = 'b' * 64;

    group('markWatched', () {
      test('marks only the played message', () {
        final memory = DmVideoPreviewMemory();
        addTearDown(memory.dispose);
        expect(memory.isWatched(first), isFalse);

        memory.markWatched(first);

        expect(memory.isWatched(first), isTrue);
        expect(memory.isWatched(second), isFalse);
      });

      test('announces a message the first time it is played', () async {
        final memory = DmVideoPreviewMemory();
        addTearDown(memory.dispose);
        final announced = <String>[];
        final subscription = memory.watched.listen(announced.add);
        addTearDown(subscription.cancel);

        memory
          ..markWatched(first)
          ..markWatched(first);
        await pumpEventQueue();

        expect(announced, equals([first]));
      });

      test('is safe after the account it belonged to is gone', () {
        final memory = DmVideoPreviewMemory()..dispose();

        expect(() => memory.markWatched(first), returnsNormally);
      });
    });

    group('frameBlurhashFor', () {
      late Directory dir;

      setUp(() => dir = Directory.systemTemp.createTempSync('dm_preview_mem_'));
      tearDown(() => dir.deleteSync(recursive: true));

      test("encodes each message's kept frame once", () async {
        final frame = File('${dir.path}/frame.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        final encoded = <Uint8List>[];
        final memory = DmVideoPreviewMemory(
          encodeBlurhash: (bytes) async {
            encoded.add(bytes);
            return 'LEHV6nWB2yk8';
          },
        );
        addTearDown(memory.dispose);

        final hashes = await Future.wait([
          memory.frameBlurhashFor(messageId: first, framePath: frame.path),
          memory.frameBlurhashFor(messageId: first, framePath: frame.path),
        ]);

        expect(hashes, equals(['LEHV6nWB2yk8', 'LEHV6nWB2yk8']));
        expect(encoded, hasLength(1));
        expect(encoded.single, equals([1, 2, 3]));
      });

      test('remembers the blurhash it read, for a card built again', () async {
        final frame = File('${dir.path}/frame.jpg')..writeAsBytesSync([1]);
        final memory = DmVideoPreviewMemory(
          encodeBlurhash: (_) async => 'LEHV6nWB2yk8',
        );
        addTearDown(memory.dispose);
        expect(memory.knownFrameBlurhashFor(first), isNull);

        await memory.frameBlurhashFor(messageId: first, framePath: frame.path);

        expect(memory.knownFrameBlurhashFor(first), 'LEHV6nWB2yk8');
        expect(memory.knownFrameBlurhashFor(second), isNull);
      });

      test('is null when the kept frame is gone', () async {
        var encodes = 0;
        final memory = DmVideoPreviewMemory(
          encodeBlurhash: (_) async {
            encodes++;
            return 'LEHV6nWB2yk8';
          },
        );
        addTearDown(memory.dispose);

        final hash = await memory.frameBlurhashFor(
          messageId: first,
          framePath: '${dir.path}/missing.jpg',
        );

        expect(hash, isNull);
        expect(encodes, equals(0));
      });
    });
  });
}
