import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'autofill_context_mock.dart';

void main() {
  group(AutofillContextRecorder, () {
    test('captures finishAutofillContext call', () async {
      final recorder = AutofillContextRecorder.install();

      TextInput.finishAutofillContext();

      // Let the async channel microtask drain.
      await pumpEventQueue();

      expect(recorder.didFinishAutofillContext, isTrue);
    });

    test('ignores unrelated channel traffic', () async {
      final recorder = AutofillContextRecorder.install();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            SystemChannels.textInput.name,
            SystemChannels.textInput.codec.encodeMethodCall(
              const MethodCall('TextInput.hide'),
            ),
            (_) {},
          );

      expect(recorder.didFinishAutofillContext, isFalse);
    });
  });
}
