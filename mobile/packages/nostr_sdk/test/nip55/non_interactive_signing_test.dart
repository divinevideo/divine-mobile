import 'dart:convert';

import 'package:android_content_provider/android_content_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Android noninteractive signing', () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const intentChannel = MethodChannel('nostrmoPlugin');
    final resolverChannel = AndroidContentResolver.methodChannel;
    final cursorChannel = MethodChannel(
      '${resolverChannel.name.replaceFirst('/ContentResolver', '')}'
      '/Cursor/activity-test',
      resolverChannel.codec,
    );
    late List<MethodCall> intents;
    var signatureAvailable = false;
    var resolverThrows = false;

    setUp(() {
      intents = [];
      signatureAvailable = false;
      resolverThrows = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(intentChannel, (call) async {
        intents.add(call);
        return null;
      });
      messenger.setMockMethodCallHandler(resolverChannel, (call) async {
        if (resolverThrows) throw PlatformException(code: 'unavailable');
        return signatureAvailable ? 'activity-test' : null;
      });
      messenger.setMockMethodCallHandler(cursorChannel, (call) async {
        if (call.method == 'moveToFirst') return true;
        if (call.method == 'commitGetBatch') {
          final args = call.arguments as Map;
          final operations = args['operations'] as List;
          return (operations.first as List).first == 'getColumnIndex'
              ? [0, -1, -1, -1]
              : ['c' * 128];
        }
        return null;
      });
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(intentChannel, null);
      messenger.setMockMethodCallHandler(resolverChannel, null);
      messenger.setMockMethodCallHandler(cursorChannel, null);
    });

    AndroidNostrSigner signer() =>
        AndroidNostrSigner(pubkey: owner, package: 'test.synthetic.signer');

    test('missing permission cannot fall back to an activity intent', () async {
      final signed = await signer().signEventWithoutUserInteraction(
        Event(owner, 27235, [], ''),
      );
      expect(signed, isNull);
      expect(intents, isEmpty);
    });

    test(
      'an unavailable resolver cannot fall back to an activity intent',
      () async {
        resolverThrows = true;
        expect(
          await signer().signEventWithoutUserInteraction(
            Event(owner, 27235, [], ''),
          ),
          isNull,
        );
        expect(intents, isEmpty);
      },
    );

    test(
      'approved permission signs through the content resolver only',
      () async {
        signatureAvailable = true;
        final signed = await signer().signEventWithoutUserInteraction(
          Event(owner, 27235, [], ''),
        );
        expect(signed?.sig, 'c' * 128);
        expect(intents, isEmpty);
      },
    );

    test('user initiated signing retains its intent fallback', () async {
      await signer().signEvent(Event(owner, 27235, [], ''));
      expect(intents.single.method, 'startActivityForResult');
    });

    test('explicit connection requests HTTP auth permission once', () async {
      await AndroidNostrSigner().getPublicKey();
      final args = intents.single.arguments as Map;
      final extras = args['extra'] as Map;
      final permissions = jsonDecode(extras['permissions'] as String) as List;
      expect(
        permissions,
        contains(equals({'type': 'sign_event', 'kind': 27235})),
      );
      expect(
        permissions,
        contains(equals({'type': 'sign_event', 'kind': 22242})),
      );
    });
  });
}
