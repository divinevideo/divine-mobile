import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/consent_operation_queue.dart';

void main() {
  group('ConsentOperationQueue', () {
    test(
      'native operations and settled wait for the previous operation',
      () async {
        final queue = ConsentOperationQueue();
        final release = Completer<void>();
        final calls = <String>[];
        final first = queue.run(() async {
          calls.add('first');
          await release.future;
        });
        final second = queue.run(() async {
          calls.add('second');
        });
        var settled = false;
        final completion = queue.settled.then((_) => settled = true);
        await Future<void>.value();
        expect(calls, ['first']);
        expect(settled, isFalse);
        release.complete();
        await Future.wait([first, second, completion]);
        expect(calls, ['first', 'second']);
        expect(settled, isTrue);
      },
    );
  });
}
