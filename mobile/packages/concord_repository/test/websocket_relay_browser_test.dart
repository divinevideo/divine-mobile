// MPL-2.0
@TestOn('browser')
library;

import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

void main() {
  test('gateway is available in browsers and disposal is terminal', () async {
    final gateway = WebSocketRelayGateway('ws://127.0.0.1:1');
    final stream = gateway.subscribe({});
    await gateway.close();
    await expectLater(stream, emitsDone);
    await expectLater(gateway.connect(), throwsStateError);
    await expectLater(
      gateway.publish({'id': 'a' * 64}),
      throwsStateError,
    );
    await expectLater(gateway.subscribe({}), emitsError(isStateError));
  });
}
