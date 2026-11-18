// ABOUTME: Tests how long contentDeletionServiceProvider keeps its service:
// ABOUTME: an account switch must reach it, and a failed start must not stick.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('contentDeletionServiceProvider', () {
    late _MockNostrClient nostrClient;
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      nostrClient = _MockNostrClient();
      database = AppDatabase.test(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostrClient),
          authServiceProvider.overrideWithValue(_MockAuthService()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('keeps a started service for the account container', () async {
      when(() => nostrClient.isInitialized).thenReturn(true);

      final first = await container.read(contentDeletionServiceProvider.future);
      await container.pump();
      final second = await container.read(
        contentDeletionServiceProvider.future,
      );

      expect(first.isInitialized, isTrue);
      expect(second, same(first));
    });

    test(
      'builds a working service once the relay client has started',
      () async {
        when(() => nostrClient.isInitialized).thenReturn(false);
        final early = await container.read(
          contentDeletionServiceProvider.future,
        );
        expect(early.isInitialized, isFalse);
        await container.pump();

        when(() => nostrClient.isInitialized).thenReturn(true);
        final later = await container.read(
          contentDeletionServiceProvider.future,
        );

        expect(later.isInitialized, isTrue);
      },
    );
  });
}
