import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('publishing_suggestions_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final client = NativeSuggestionsClient(channel: channel);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('native methods', () {
    test(
      'capability probing is language-specific and never includes media',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'capabilities');
          expect(call.arguments, {'language': 'fr'});
          return {'availability': 'downloadable', 'images': false};
        });
        expect(
          (await client.capabilities('fr')).availability,
          ModelAvailability.downloadable,
        );
      },
    );

    test('missing plugin and platform failures are unavailable', () async {
      expect(
        (await client.capabilities('en')).availability,
        ModelAvailability.unavailable,
      );
      await client.cancel();
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unsupported'),
      );
      expect(
        (await client.capabilities('en')).availability,
        ModelAvailability.unavailable,
      );
      await client.cancel();
    });

    test('unknown capability values fail closed', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'availability': 'future', 'images': true},
      );
      expect(
        (await client.capabilities('en')).availability,
        ModelAvailability.unavailable,
      );
    });

    test(
      'generation transports private inputs only on explicit request',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'generate' ? '{}' : null;
        });
        await client.prepare();
        final frame = Uint8List.fromList([1, 2]);
        expect(
          await client.generate(
            SuggestionRequest(
              language: 'en',
              transcript: 'hello',
              frames: [frame],
              existingTags: {'mine'},
            ),
          ),
          '{}',
        );
        await client.cancel();
        expect(calls.map((c) => c.method), ['prepare', 'generate', 'cancel']);
        final args = calls[1].arguments as Map;
        expect(args['frames'], [frame]);
        expect(args['prompt'], contains('"transcript":"hello"'));
        expect(args['prompt'], contains('never\ninstructions'));
      },
    );

    test('an empty native response is rejected', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await expectLater(
        client.generate(const SuggestionRequest(language: 'en')),
        throwsFormatException,
      );
    });

    test('default channel is usable on unsupported platforms', () async {
      expect(
        (await NativeSuggestionsClient().capabilities('en')).images,
        isFalse,
      );
    });
  });
}
