// ABOUTME: Tests for path_resolver — web-safe document root joining
//
// `getDocumentsPath` on web is covered by the web-only test below; run it with
// `flutter test test/utils/path_resolver_test.dart --platform chrome` (manual /
// local — not executed in CI). `flutter build web` only checks compilation, not
// this runtime branch.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;
  int calls = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    calls++;
    return documentsPath;
  }
}

void main() {
  group('getDocumentsPath', () {
    test(
      'returns empty string on web without using path_provider',
      () async {
        expect(await getDocumentsPath(), '');
      },
      skip: !kIsWeb
          ? 'Web-only: run `flutter test test/utils/path_resolver_test.dart --platform chrome`'
          : null,
    );
  });

  group('cachedDocumentsPath', () {
    late PathProviderPlatform original;
    late _FakePathProvider fake;

    setUp(() {
      original = PathProviderPlatform.instance;
      fake = _FakePathProvider('/app/docs');
      PathProviderPlatform.instance = fake;
      resetCachedDocumentsPath();
    });

    tearDown(() {
      PathProviderPlatform.instance = original;
      resetCachedDocumentsPath();
    });

    test(
      'is null until the plugin has answered once',
      () {
        // The point of the getter is the first frame of a widget that cannot
        // await; it has to say "I do not know yet" rather than guess a root.
        expect(cachedDocumentsPath, isNull);
      },
      skip: kIsWeb ? 'Web has no plugin call to miss' : null,
    );

    test('serves the resolved path without asking the plugin again', () async {
      await getDocumentsPath();
      final callsAfterResolve = fake.calls;

      expect(callsAfterResolve, greaterThan(0));
      expect(cachedDocumentsPath, kIsWeb ? '' : '/app/docs');
      expect(fake.calls, callsAfterResolve);
    });
  });

  group('resolvePath', () {
    test('joins basename when documents root is empty (web)', () {
      expect(resolvePath('folder/clip.mp4', ''), 'clip.mp4');
    });

    test('joins basename under documents path on disk', () {
      expect(
        resolvePath('/old/container/clip.mp4', '/app/docs'),
        '/app/docs/clip.mp4',
      );
    });
  });
}
