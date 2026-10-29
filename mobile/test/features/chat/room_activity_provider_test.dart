import 'package:concord_repository/concord_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/chat/room_activity_provider.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';

class _Auth extends Fake implements AuthService {
  _Auth(this.currentPublicKeyHex);
  @override
  String currentPublicKeyHex;
  @override
  bool isAuthenticated = true;
  @override
  NostrIdentity get currentIdentity =>
      PubkeyOnlyNostrIdentity(pubkey: currentPublicKeyHex);
  @override
  AuthState get authState => AuthState.authenticated;
  @override
  Stream<AuthState> get authStateStream => const Stream.empty();
}

void main() {
  group('roomActivityRepositoryProvider', () {
    test(
      'shares room sessions and closes old sessions on account/access changes',
      () async {
        final database = AppDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);
        final account = StateProvider((ref) => '01' * 32);
        final enabled = StateProvider((ref) => true);
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWith(
              (ref) => _Auth(ref.watch(account)),
            ),
            databaseProvider.overrideWithValue(database),
            isFeatureEnabledProvider(FeatureFlag.concordChat)
                .overrideWith((ref) => ref.watch(enabled)),
            isDmRestrictedProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen<RoomActivityRepository?>(
          roomActivityRepositoryProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final first = container.read(roomActivityRepositoryProvider)!;
        expect(
          identical(first, container.read(roomActivityRepositoryProvider)),
          isTrue,
        );
        expect(first.summaries, hasLength(2));
        // A queued send must fail closed even before provider invalidation.
        final auth = container.read(authServiceProvider) as _Auth;
        auth.currentPublicKeyHex = '03' * 32;
        await expectLater(
          first
              .repositoryFor(first.summaries.keys.first)
              .sealedTransport!
              .signer(
                {
                  'kind': 20013,
                  'tags': <List<String>>[],
                  'content': '',
                  'created_at': 1,
                },
              ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'chat session is no longer active',
            ),
          ),
        );
        auth.currentPublicKeyHex = '01' * 32;
        container.read(account.notifier).state = '02' * 32;
        await container.pump();
        final second = container.read(roomActivityRepositoryProvider)!;
        expect(identical(first, second), isFalse);
        await expectLater(
          first.ensureStarted(first.summaries.keys.first),
          throwsStateError,
        );
        container.read(enabled.notifier).state = false;
        await container.pump();
        expect(container.read(roomActivityRepositoryProvider), isNull);
        await expectLater(
          second.ensureStarted(second.summaries.keys.first),
          throwsStateError,
        );
      },
    );

    test(
      'closes the room sessions of an account that becomes restricted',
      () async {
        final database = AppDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);
        final restricted = StateProvider((ref) => false);
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(_Auth('01' * 32)),
            databaseProvider.overrideWithValue(database),
            isFeatureEnabledProvider(
              FeatureFlag.concordChat,
            ).overrideWith((ref) => true),
            isDmRestrictedProvider.overrideWith((ref) => ref.watch(restricted)),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen<RoomActivityRepository?>(
          roomActivityRepositoryProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final open = container.read(roomActivityRepositoryProvider)!;
        container.read(restricted.notifier).state = true;
        await container.pump();
        expect(container.read(roomActivityRepositoryProvider), isNull);
        await expectLater(
          open.ensureStarted(open.summaries.keys.first),
          throwsStateError,
        );
      },
    );

    test('fails a queued send closed once the account signs out', () async {
      final database = AppDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      final auth = _Auth('01' * 32);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          databaseProvider.overrideWithValue(database),
          isFeatureEnabledProvider(
            FeatureFlag.concordChat,
          ).overrideWith((ref) => true),
          isDmRestrictedProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<RoomActivityRepository?>(
        roomActivityRepositoryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final activity = container.read(roomActivityRepositoryProvider)!;
      auth.isAuthenticated = false;
      await expectLater(
        activity
            .repositoryFor(activity.summaries.keys.first)
            .sealedTransport!
            .signer(
              {
                'kind': 20013,
                'tags': <List<String>>[],
                'content': '',
                'created_at': 1,
              },
            ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'chat session is no longer active',
          ),
        ),
      );
    });
  });
}
